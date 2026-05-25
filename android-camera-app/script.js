const video = document.getElementById('preview');
const canvas = document.getElementById('capture-canvas');
const shutterBtn = document.getElementById('shutter');
const switchBtn = document.getElementById('switch-camera');
const galleryPreview = document.getElementById('gallery-preview');
const lastPhotoImg = document.getElementById('last-photo');
const flashOverlay = document.getElementById('flash-overlay');
const viewport = document.getElementById('viewport');
const focusRing = document.getElementById('focus-ring');
const zoomSlider = document.getElementById('zoom-slider');
const zoomLabel = document.getElementById('zoom-label');
const filterItems = document.querySelectorAll('.filter-item');

let currentStream = null;
let useFrontCamera = false;
let currentZoom = 1;
let currentFilter = 'none';

// 1. Initialize Camera
async function initCamera() {
    if (currentStream) {
        currentStream.getTracks().forEach(track => track.stop());
    }

    const constraints = {
        video: {
            facingMode: useFrontCamera ? 'user' : 'environment',
            width: { ideal: 1920 },
            height: { ideal: 1080 }
        },
        audio: false
    };

    try {
        currentStream = await navigator.mediaDevices.getUserMedia(constraints);
        video.srcObject = currentStream;
        video.onloadedmetadata = () => {
            video.play();
        };
    } catch (err) {
        console.error("Error accessing camera: ", err);
        alert("Camera access denied or not available. Please ensure you're using HTTPS and have granted permissions.");
    }
}

// 2. Capture Photo
function capturePhoto() {
    // Visual feedback
    flashOverlay.classList.add('flash-anim');
    setTimeout(() => flashOverlay.classList.remove('flash-anim'), 150);

    // Capture to canvas
    const context = canvas.getContext('2d');
    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;
    
    // Draw current frame
    context.drawImage(video, 0, 0, canvas.width, canvas.height);
    
    // Get data URL
    const imageData = canvas.toDataURL('image/jpeg');
    
    // Update gallery preview
    lastPhotoImg.src = imageData;
    lastPhotoImg.style.display = 'block';
    document.querySelector('.empty-gallery').style.display = 'none';

    // Add a little pop animation to gallery
    galleryPreview.style.transform = 'scale(1.1)';
    setTimeout(() => galleryPreview.style.transform = 'scale(1)', 200);
}

// 3. Switch Camera
switchBtn.addEventListener('click', () => {
    useFrontCamera = !useFrontCamera;
    
    // Rotate animation for the button
    switchBtn.style.transform = `rotate(${useFrontCamera ? 180 : 0}deg)`;
    
    // Flip the video preview horizontally if it's the front camera
    video.style.transform = useFrontCamera ? 'scaleX(-1)' : 'scaleX(1)';
    
    initCamera();
});

// 4. Shutter Event
shutterBtn.addEventListener('click', capturePhoto);

// 5. Focus Animation on Viewport Click
viewport.addEventListener('mousedown', (e) => {
    if (e.target.closest('.bottom-section') || e.target.closest('.top-bar') || e.target.closest('.zoom-container')) return;
    
    const rect = viewport.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;

    focusRing.style.left = `${x - 40}px`;
    focusRing.style.top = `${y - 40}px`;
    focusRing.classList.remove('active');
    
    // Trigger reflow
    void focusRing.offsetWidth;
    
    focusRing.classList.add('active');
    
    // Remove after a delay
    setTimeout(() => {
        focusRing.classList.remove('active');
    }, 1000);
});

// 6. Zoom Logic
zoomSlider.addEventListener('input', (e) => {
    currentZoom = e.target.value;
    document.querySelector('.zoom-label').innerText = `${parseFloat(currentZoom).toFixed(1)}x`;
    applyTransforms();
});

// 7. Filter Logic
filterItems.forEach(item => {
    item.addEventListener('click', () => {
        filterItems.forEach(i => i.classList.remove('active'));
        item.classList.add('active');
        currentFilter = item.dataset.filter;
        video.style.filter = currentFilter;
    });
});

function applyTransforms() {
    const flip = useFrontCamera ? 'scaleX(-1)' : 'scaleX(1)';
    const zoom = `scale(${currentZoom})`;
    video.style.transform = `${flip} ${zoom}`;
}

// 8. Switch Camera Logic
switchBtn.addEventListener('click', () => {
    useFrontCamera = !useFrontCamera;
    switchBtn.style.transform = `rotate(${useFrontCamera ? 180 : 0}deg)`;
    applyTransforms();
    initCamera();
});

// Initialize on load
window.addEventListener('load', initCamera);
