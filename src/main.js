import './styles/style.css'

// document.body.innerHTML = "Vite is running"
console.log('Hello from me')

import * as THREE from 'three';

// import vertexShader from './shaders/monjori_vertex.glsl?raw'
// import fragmentShader from './shaders/monjori_fragment.glsl?raw'
import vertexShader from './shaders/glass_vertex.glsl?raw'
import fragmentShader from './shaders/glass_fragment.glsl?raw'

let camera, scene, renderer;

let uniforms;

init();

function init() {
    const container = document.getElementById('container');

    camera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);
    scene = new THREE.Scene();

    const geometry = new THREE.PlaneGeometry(2, 2);

    const textureLoader = new THREE.TextureLoader();
    const bgTexture = textureLoader.load('../assets/img/pexels-egorkomarov-13219418.jpg');

    bgTexture.wrapS = THREE.ClampToEdgeWrapping;
    bgTexture.wrapT = THREE.ClampToEdgeWrapping;

    uniforms = {
        uTime: { value: 0.0 },
        uBackground: { value: bgTexture },
        uResolution: { value: new THREE.Vector2(window.innerWidth, window.innerHeight) },
        // 1. Pass your background asset's real pixel size (e.g., 1920x1080)
        uBgResolution: { value: new THREE.Vector2(1920, 1080) }, 
        // 2. Tracks scroll progress normalized between 0.0 and 1.0
        uProgress: { value: 0.0 } 
    };

    const material = new THREE.ShaderMaterial( {
        uniforms: uniforms,
        vertexShader: vertexShader,
        fragmentShader: fragmentShader,
        transparent: true
    } );

    const mesh = new THREE.Mesh(geometry, material);
    scene.add(mesh);

    renderer = new THREE.WebGLRenderer({
        alpha: true,
        antialias: true
    });
    renderer.setClearColor(0x000000, 0);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2)); // Cap at 2 for performance
    renderer.setSize(window.innerWidth, window.innerHeight);
    renderer.setAnimationLoop(animate);
    container.appendChild(renderer.domElement);

    window.addEventListener('resize', onWindowResize);
    window.addEventListener('scroll', () => {
        const maxScroll = document.documentElement.scrollHeight - window.innerHeight;
        if (maxScroll <= 0) return;
        
        // Track percentage scrolled from 0.0 to 1.0
        const scrollPercent = window.scrollY / maxScroll;
        uniforms.uProgress.value = scrollPercent;
    });
}

function onWindowResize() {
    renderer.setSize(window.innerWidth, window.innerHeight);
    uniforms.uResolution.value.set(window.innerWidth, window.innerHeight);
}

function animate() {
    uniforms['uTime'].value = performance.now() / 1000;
    renderer.render(scene, camera);
}
