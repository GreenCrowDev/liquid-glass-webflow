uniform vec2 uResolution;
uniform vec2 uMouse;
uniform float uTime;
uniform sampler2D uBackground;

varying vec2 vUv;

// IQ's superellipse SDF design
vec3 sdSuperellipse(vec2 p, float r, float n) {
    p = p / r;
    vec2 gs = sign(p);
    vec2 ps = abs(p);
    float gm = pow(ps.x, n) + pow(ps.y, n);
    float gd = pow(gm, 1.0 / n) - 1.0;
    vec2 g = gs * pow(ps, vec2(n - 1.0)) * pow(gm, 1.0 / n - 1.0);
    p = abs(p); if (p.y > p.x) p = p.yx;
    n = 2.0 / n;
    float s = 1.0;
    float d = 1e20;
    const int num = 12;
    vec2 oq = vec2(1.0, 0.0);
    for (int i = 1; i < num; i++) {
        float h = float(i)/float(num-1);
        vec2 q = vec2(pow(cos(h * 3.1415927 / 4.0), n),
                      pow(sin(h * 3.1415927 / 4.0), n));
        vec2 pa = p - oq;
        vec2 ba = q - oq;
        vec2 z = pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
        float d2 = dot(z, z);
        if (d2 < d) {
            d = d2;
            s = pa.x * ba.y - pa.y * ba.x;
        }
        oq = q;
    }
    return vec3(sqrt(d) * sign(s) * r, g);
}

// Maps aspect-corrected UV space accurately back to screen-space [0,1] for texture sampling
vec3 sampleBackground(vec2 uv) {
    vec2 screenUV = (uv * uResolution.y + 0.5 * uResolution.xy) / uResolution.xy;
    return texture2D(uBackground, screenUV).rgb;
}

// Fresnel reflectance calculation
float fresnel(vec3 I, vec3 N, float ior) {
    float cosi = clamp(-1.0, 1.0, dot(I, N));
    float etai = 1.0, etat = ior;
    if (cosi > 0.0) {
        float temp = etai;
        etai = etat;
        etat = temp;
    }
    float sint = etai / etat * sqrt(max(0.0, 1.0 - cosi * cosi));
    if (sint >= 1.0) {
        return 1.0; 
    }
    float cost = sqrt(max(0.0, 1.0 - sint * sint));
    cosi = abs(cosi);
    float Rs = ((etat * cosi) - (etai * cost)) / ((etat * cosi) + (etai * cost));
    float Rp = ((etai * cosi) - (etat * cost)) / ((etai * cosi) + (etat * cost));
    return (Rs * Rs + Rp * Rp) / 2.0;
}

// Blur settings
const int samples = 32;
const int LOD = 1;
const int sLOD = 1 << LOD;
const float sigma = float(samples) * 0.35;

float gaussian(vec2 i) {
    return exp(-0.5 * dot(i /= sigma, i)) / (6.28 * sigma * sigma);
}

vec3 efficientBlur(vec2 uv, float blurStrength) {
    vec3 O = vec3(0.0);
    float totalWeight = 0.0;
    int s = samples / sLOD;
    
    for (int i = 0; i < s * s; i++) {
        vec2 d = vec2(i % s, i / s) * float(sLOD) - float(samples) / 2.0;
        vec2 offset = d * blurStrength * 0.0005;
        float weight = gaussian(d);
        
        vec3 sampleColor = sampleBackground(uv + offset);
        O += sampleColor * weight;
        totalWeight += weight;
    }
    
    return O / totalWeight;
}

void main() {
    // Coordinate configurations normalized around center matching original design
    vec2 uv = (gl_FragCoord.xy - 0.5 * uResolution.xy) / uResolution.y;
    vec2 mouse = (uMouse.xy - 0.5 * uResolution.xy) / uResolution.y;
    
    // Superellipse structural dimensions
    float radius = 0.2;
    float n = 4.0;
    
    // Compute distance field for a single tracking squircle
    vec3 dg = sdSuperellipse(uv - mouse, radius, n);
    float d = dg.x;
    
    // Calculate drop shadows
    vec2 shadowOffset = vec2(0.0, -0.01); 
    float shadowBlur = 0.05; 
    
    float shadowSDF = sdSuperellipse(uv - mouse - shadowOffset, radius, n).x;
    float shadowMask = 1.0 - smoothstep(0.0, shadowBlur, shadowSDF);
    shadowMask *= 0.1; 
    
    // Apply background generation and drop shadow calculation
    vec3 baseColor = sampleBackground(uv);
    baseColor = mix(baseColor, vec3(0.0), shadowMask);
    
    // Internal Glass Rendering Calculations
    if (d < 0.0) {
        vec2 center = mouse;
        vec2 offset = uv - center;
        float distFromCenter = length(offset);
        
        float depthInShape = abs(d);
        float normalizedDepth = clamp(depthInShape / (radius * 0.8), 0.0, 1.0);
        
        float edgeFactor = 1.0 - normalizedDepth;
        float exponentialDistortion = exp(edgeFactor * 3.0) - 1.0;
        
        float baseMagnification = 0.75;
        float lensStrength = 0.4;
        float distortionAmount = exponentialDistortion * lensStrength;
        
        // Chromatic Aberration Mapping
        float baseDistortion = baseMagnification + distortionAmount * distFromCenter;
        
        float redDistortion = baseDistortion * 0.9;
        float greenDistortion = baseDistortion * 1.0;
        float blueDistortion = baseDistortion * 1.1;
        
        vec2 redUV = center + offset * redDistortion;
        vec2 greenUV = center + offset * greenDistortion;
        vec2 blueUV = center + offset * blueDistortion;
        
        float blurStrength = edgeFactor * 0.0 + 1.5;
        
        vec3 redBlur = efficientBlur(redUV, blurStrength);
        vec3 greenBlur = efficientBlur(greenUV, blurStrength);
        vec3 blueBlur = efficientBlur(blueUV, blurStrength);
        
        vec3 refractedColor = vec3(redBlur.r, greenBlur.g, blueBlur.b);
        
        refractedColor *= vec3(0.95, 0.98, 1.0);
        refractedColor += vec3(0.2);
        
        // Lens Normal and Fresnel Calculation
        vec2 eps = vec2(0.01, 0.0);
        vec2 gradient = vec2(
            sdSuperellipse(uv + eps.xy - mouse, radius, n).x - sdSuperellipse(uv - eps.xy - mouse, radius, n).x,
            sdSuperellipse(uv + eps.yx - mouse, radius, n).x - sdSuperellipse(uv - eps.yx - mouse, radius, n).x
        );
        vec3 normal = normalize(vec3(gradient, 1.0));
        vec3 viewDir = vec3(0.0, 0.0, -1.0);
        float fresnelAmount = fresnel(viewDir, normal, 1.5);
        
        vec3 fresnelColor = vec3(1.0);
        vec3 finalColor = mix(refractedColor, fresnelColor, fresnelAmount * 0.3);
        
        gl_FragColor = vec4(finalColor, 1.0);
    } else {
        gl_FragColor = vec4(baseColor, 1.0);
    }
    
    // Prominent High-Contrast Edge Highlights Logic
    float edgeThickness = 0.008; 
    float edgeMask = smoothstep(edgeThickness, 0.0, abs(d));
    
    if (edgeMask > 0.0) {
        vec2 normalizedPos = uv * 1.5; 
        
        float diagonal1 = abs(normalizedPos.x + normalizedPos.y); 
        float diagonal2 = abs(normalizedPos.x - normalizedPos.y); 
        
        float diagonalFactor = max(
            smoothstep(1.0, 0.1, diagonal1), 
            smoothstep(1.0, 0.5, diagonal2)  
        );
        
        diagonalFactor = pow(diagonalFactor, 1.8); 
        
        vec3 edgeWhite = vec3(1.2); 
        vec3 internalColor = gl_FragColor.rgb * 0.4; 
        
        vec3 edgeColor = mix(internalColor, edgeWhite, diagonalFactor);
        gl_FragColor.rgb = mix(gl_FragColor.rgb, edgeColor, edgeMask * 1.0);
    }
}
