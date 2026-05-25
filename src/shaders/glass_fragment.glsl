uniform vec2 uResolution;
uniform vec2 uBgResolution; // Native resolution of background image (e.g., 1920, 1080)
uniform sampler2D uBackground;
uniform float uTime;
uniform float uProgress;    // Normalized scroll value from 0.0 to 1.0

varying vec2 vUv;

// Calculates object-fit: cover coordinates for the background texture
vec2 getCoverUV(vec2 uvAspect) {
    // Convert back from aspect-corrected space to standard screen [0,1] UV
    vec2 screenUV = (uvAspect * uResolution.y + 0.5 * uResolution.xy) / uResolution.xy;
    
    float screenAspect = uResolution.x / uResolution.y;
    float texAspect = uBgResolution.x / uBgResolution.y;
    vec2 coverUV = screenUV;
    
    if (screenAspect > texAspect) {
        float scale = screenAspect / texAspect;
        coverUV.y = (coverUV.y - 0.5) * scale + 0.5;
    } else {
        float scale = texAspect / screenAspect;
        coverUV.x = (coverUV.x - 0.5) * scale + 0.5;
    }
    return coverUV;
}

// Global background sampling wrapper using cover rules
vec3 sampleBackground(vec2 uvAspect) {
    vec2 coverUV = getCoverUV(uvAspect);
    return texture2D(uBackground, coverUV).rgb;
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

vec3 efficientBlur(vec2 uvAspect, float blurStrength) {
    vec3 O = vec3(0.0);
    float totalWeight = 0.0;
    int s = samples / sLOD;
    
    for (int i = 0; i < s * s; i++) {
        vec2 d = vec2(i % s, i / s) * float(sLOD) - float(samples) / 2.0;
        vec2 offset = d * blurStrength * 0.0005;
        float weight = gaussian(d);
        
        vec3 sampleColor = sampleBackground(uvAspect + offset);
        O += sampleColor * weight;
        totalWeight += weight;
    }
    return O / totalWeight;
}

// 2D Box SDF to define individual column shapes mathematically
float getColumnSDF(vec2 p, float xLeft, float xRight, float yBottom, float yTop) {
    float dl = p.x - xLeft;
    float dr = xRight - p.x;
    float db = p.y - yBottom;
    float dt = yTop - p.y;
    // Returns negative values inside the panel bounds
    return -min(min(dl, dr), min(db, dt));
}

void main() {
    // 1. Setup normalized screen space and aspect-corrected space
    vec2 screenUV = gl_FragCoord.xy / uResolution.xy;
    vec2 uvAspect = (gl_FragCoord.xy - 0.5 * uResolution.xy) / uResolution.y;
    
    // 2. Segment Workspace into 5 Columns
    float numColumns = 5.0;
    float colIdx = floor(screenUV.x * numColumns);
    
    // 3. Compute V-Pattern Timeline Stagger (0.0 to 1.0)
    float startTime = 0.0;
    if (colIdx == 0.0 || colIdx == 4.0) {
        startTime = 0.0;   // Outermost curtains leave first
    } else if (colIdx == 1.0 || colIdx == 3.0) {
        startTime = 0.25;  // Intermediate curtains leave second
    } else if (colIdx == 2.0) {
        startTime = 0.5;   // Center curtain leaves last
    }
    
    float duration = 0.5;
    float colProgress = clamp((uProgress - startTime) / duration, 0.0, 1.0);
    colProgress = smoothstep(0.0, 1.0, colProgress); // Smooth exit velocity
    
    // 4. Calculate Column Geometric Boundaries in Aspect-Correct Space
    float xLeft = ((colIdx / numColumns) * uResolution.x - 0.5 * uResolution.x) / uResolution.y;
    float xRight = (((colIdx + 1.0) / numColumns) * uResolution.x - 0.5 * uResolution.x) / uResolution.y;
    float yBottom = (colProgress * uResolution.y - 0.5 * uResolution.y) / uResolution.y;
    float yTop = (1.5 * uResolution.y - 0.5 * uResolution.y) / uResolution.y; // Extend past top screen bound
    
    // 5. Generate Distance Field for current curtain
    float d = getColumnSDF(uvAspect, xLeft, xRight, yBottom, yTop);
    
    vec3 baseColor = sampleBackground(uvAspect);
    
    // 6. Execute Glass Rendering if inside active curtain boundary
    if (d < 0.0) {
        // Define local spatial structural anchors
        vec2 panelCenter = vec2((xLeft + xRight) * 0.5, (yBottom + yTop) * 0.5);
        vec2 offset = uvAspect - panelCenter;
        float distFromCenter = length(offset);
        float thickness = (xRight - xLeft) * 0.5;
        
        // Depth-based magnification mapping
        float depthInShape = abs(d);
        float normalizedDepth = clamp(depthInShape / (thickness * 0.8), 0.0, 1.0);
        
        float edgeFactor = 1.0 - normalizedDepth;
        float exponentialDistortion = exp(edgeFactor * 3.0) - 1.0;
        
        float baseMagnification = 0.75;
        float lensStrength = 0.4;
        float distortionAmount = exponentialDistortion * lensStrength;
        float baseDistortion = baseMagnification + distortionAmount * distFromCenter;
        
        // Chromatic Aberration Vectors
        float redDistortion = baseDistortion * 0.92;
        float greenDistortion = baseDistortion * 1.0;
        float blueDistortion = baseDistortion * 1.08;
        
        vec2 redUV = panelCenter + offset * redDistortion;
        vec2 greenUV = panelCenter + offset * greenDistortion;
        vec2 blueUV = panelCenter + offset * blueDistortion;
        
        float blurStrength = edgeFactor * 0.0 + 1.5;
        
        vec3 redBlur = efficientBlur(redUV, blurStrength);
        vec3 greenBlur = efficientBlur(greenUV, blurStrength);
        vec3 blueBlur = efficientBlur(blueUV, blurStrength);
        
        vec3 refractedColor = vec3(redBlur.r, greenBlur.g, blueBlur.b);
        
        // Color profiling and internal tint shifts
        refractedColor *= vec3(0.95, 0.98, 1.0);
        refractedColor += vec3(0.15); 
        
        // Dynamic Surface Normal generation based on our Box Boundary
        vec2 eps = vec2(0.005, 0.0);
        vec2 gradient = vec2(
            getColumnSDF(uvAspect + eps.xy, xLeft, xRight, yBottom, yTop) - getColumnSDF(uvAspect - eps.xy, xLeft, xRight, yBottom, yTop),
            getColumnSDF(uvAspect + eps.yx, xLeft, xRight, yBottom, yTop) - getColumnSDF(uvAspect - eps.yx, xLeft, xRight, yBottom, yTop)
        );
        vec3 normal = normalize(vec3(gradient, 1.0));
        vec3 viewDir = vec3(0.0, 0.0, -1.0);
        float fresnelAmount = fresnel(viewDir, normal, 1.5);
        
        vec3 fresnelColor = vec3(1.0);
        gl_FragColor = vec4(mix(refractedColor, fresnelColor, fresnelAmount * 0.35), 1.0);
    } else {
        // Outside / Revealed area underneath curtain
        gl_FragColor = vec4(baseColor, 1.0);
    }
    
    // 7. Render High-Contrast Perimeter Seams and Diagonal Glass Highlights
    float edgeThickness = 0.006;
    float edgeMask = smoothstep(edgeThickness, 0.0, abs(d));
    
    if (edgeMask > 0.0) {
        vec2 normalizedPos = uvAspect * 1.5;
        
        float diagonal1 = abs(normalizedPos.x + normalizedPos.y);
        float diagonal2 = abs(normalizedPos.x - normalizedPos.y);
        
        float diagonalFactor = max(
            smoothstep(1.0, 0.1, diagonal1),
            smoothstep(1.0, 0.5, diagonal2)
        );
        
        diagonalFactor = pow(diagonalFactor, 1.8);
        
        vec3 edgeWhite = vec3(1.4);                 // Strong crisp highlight reflection
        vec3 internalColor = gl_FragColor.rgb * 0.35; // Internal panel self-shadowing accent
        
        vec3 edgeColor = mix(internalColor, edgeWhite, diagonalFactor);
        gl_FragColor.rgb = mix(gl_FragColor.rgb, edgeColor, edgeMask * 1.0);
    }
}
