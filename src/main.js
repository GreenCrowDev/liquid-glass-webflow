import './styles/style.css'

// document.body.innerHTML = "Vite is running"
console.log('Hello from me')

import * as THREE from 'three';

import vertexShader from './shaders/vertex.glsl?raw'
import fragmentShader from './shaders/fragment.glsl?raw'

let camera, scene, renderer;

let uniforms;

init();

function init() {
    const container = document.getElementById('container');

    camera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);
    scene = new THREE.Scene();

    const geometry = new THREE.PlaneGeometry(2, 2);

    uniforms = {
        time: { value: 1.0 }
    };

    const material = new THREE.ShaderMaterial( {
        uniforms: uniforms,
        vertexShader: vertexShader,
        fragmentShader: fragmentShader
    } );

    const mesh = new THREE.Mesh(geometry, material);
    scene.add(mesh);

    renderer = new THREE.WebGLRenderer();
    renderer.setPixelRatio(window.devicePixelRatio);
    renderer.setSize(window.innerWidth, window.innerHeight);
    renderer.setAnimationLoop(animate);
    container.appendChild(renderer.domElement);

    window.addEventListener('resize', onWindowResize);
}

function onWindowResize() {
    renderer.setSize(window.innerWidth, window.innerHeight);
}

function animate() {
    uniforms['time'].value = performance.now() / 1000;
    renderer.render(scene, camera);
}
