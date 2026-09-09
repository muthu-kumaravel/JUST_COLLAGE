let _libheifInstance = null;

async function _getLibheif() {
  if (_libheifInstance) return _libheifInstance;
  const fn = window.libheif || (typeof libheif !== 'undefined' ? libheif : null);
  if (typeof fn === 'function') {
    _libheifInstance = await fn();
    return _libheifInstance;
  }
  if (typeof fn === 'object' && fn !== null) {
    _libheifInstance = fn;
    return _libheifInstance;
  }
  return null;
}

window.convertHeicToJpeg = async function(heicUint8Array) {
  // 1. Tier 1: Hardware-accelerated native browser decoding (Safari on macOS / iOS / iPadOS)
  try {
    const blob = new Blob([heicUint8Array], { type: 'image/heic' });
    if (typeof createImageBitmap === 'function') {
      const bitmap = await createImageBitmap(blob);
      if (bitmap && bitmap.width > 0 && bitmap.height > 0) {
        const canvas = document.createElement('canvas');
        canvas.width = bitmap.width;
        canvas.height = bitmap.height;
        const ctx = canvas.getContext('2d');
        ctx.drawImage(bitmap, 0, 0);
        const jpegBlob = await new Promise((resolve) => canvas.toBlob(resolve, 'image/jpeg', 0.92));
        if (jpegBlob) {
          const buffer = await jpegBlob.arrayBuffer();
          return new Uint8Array(buffer);
        }
      }
    }
  } catch (_) {
    // Native browser decode unsupported (Google Chrome, Edge, Firefox) - proceed to WASM
  }

  // 2. Tier 2: Modern libheif 1.19+ WebAssembly Decoder (supports iPhone 10-bit HDR, Gain Maps & Live Photos)
  try {
    const lib = await _getLibheif();
    if (!lib || !lib.HeifDecoder) {
      console.warn('libheif WASM decoder is not available');
      return null;
    }

    const decoder = new lib.HeifDecoder();
    const data = decoder.decode(heicUint8Array);
    if (!data || data.length === 0) {
      console.error('libheif: no images found in HEIC container');
      return null;
    }

    const image = data[0];
    const width = image.get_width();
    const height = image.get_height();

    const displayData = await new Promise((resolve) => {
      image.display({ data: new Uint8ClampedArray(width * height * 4), width, height }, (result) => {
        resolve(result);
      });
    });

    // Free WASM handles to prevent memory leaks
    data.forEach((item) => {
      try { if (item.free) item.free(); } catch(_) {}
    });

    if (!displayData || !displayData.data) {
      console.error('libheif: display failed to generate RGBA pixel buffer');
      return null;
    }

    const srcCanvas = document.createElement('canvas');
    srcCanvas.width = width;
    srcCanvas.height = height;
    const srcCtx = srcCanvas.getContext('2d');
    const imgData = srcCtx.createImageData(width, height);
    imgData.data.set(displayData.data);
    srcCtx.putImageData(imgData, 0, 0);

    // Bounding-box scale if larger than 3840px (4K) to optimize memory and speed
    const maxDim = 3840;
    let exportCanvas = srcCanvas;
    if (Math.max(width, height) > maxDim) {
      const scale = maxDim / Math.max(width, height);
      const targetW = Math.round(width * scale);
      const targetH = Math.round(height * scale);
      const scaledCanvas = document.createElement('canvas');
      scaledCanvas.width = targetW;
      scaledCanvas.height = targetH;
      const scaledCtx = scaledCanvas.getContext('2d');
      scaledCtx.drawImage(srcCanvas, 0, 0, targetW, targetH);
      exportCanvas = scaledCanvas;
    }

    const jpegBlob = await new Promise((resolve) => exportCanvas.toBlob(resolve, 'image/jpeg', 0.92));
    if (!jpegBlob) {
      console.error('Canvas failed to export JPEG blob');
      return null;
    }

    const arrayBuffer = await jpegBlob.arrayBuffer();
    return new Uint8Array(arrayBuffer);
  } catch (err) {
    console.error('libheif WASM conversion failed:', err);
    return null;
  }
};

