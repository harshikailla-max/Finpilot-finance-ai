/**
 * FinPilot AI - Browser-based Tesseract.js OCR Interop
 * Provides 100% free, on-device OCR without external API keys or server fees.
 */
(function() {
  'use strict';

  var worker = null;
  var workerInitializing = null;

  async function ensureTesseractLoaded() {
    if (typeof Tesseract !== 'undefined') return;

    return new Promise(function(resolve, reject) {
      var existing = document.querySelector('script[data-tesseract-cdn]');
      if (existing) {
        existing.addEventListener('load', resolve);
        existing.addEventListener('error', function() {
          reject(new Error('Failed to load Tesseract.js CDN'));
        });
        return;
      }

      var script = document.createElement('script');
      script.setAttribute('data-tesseract-cdn', 'true');
      script.src = 'https://cdn.jsdelivr.net/npm/tesseract.js@5/dist/tesseract.min.js';
      script.async = true;
      script.onload = resolve;
      script.onerror = function() {
        reject(new Error('Failed to load Tesseract.js from CDN'));
      };
      document.head.appendChild(script);
    });
  }

  /**
   * Resizes an image (base64 data URI or blob) on an off-screen canvas
   * if max dimension exceeds maxDim (default 1800px).
   */
  function resizeImageIfNeeded(dataUri, maxDim) {
    maxDim = maxDim || 1800;
    return new Promise(function(resolve) {
      var img = new Image();
      img.onload = function() {
        var w = img.naturalWidth || img.width;
        var h = img.naturalHeight || img.height;
        if (!w || !h || (w <= maxDim && h <= maxDim)) {
          resolve(dataUri);
          return;
        }

        var nw, nh;
        if (w >= h) {
          nw = maxDim;
          nh = Math.round(h * (maxDim / w));
        } else {
          nh = maxDim;
          nw = Math.round(w * (maxDim / h));
        }

        var canvas = document.createElement('canvas');
        canvas.width = nw;
        canvas.height = nh;
        var ctx = canvas.getContext('2d');
        ctx.imageSmoothingEnabled = true;
        ctx.imageSmoothingQuality = 'high';
        ctx.drawImage(img, 0, 0, nw, nh);
        resolve(canvas.toDataURL('image/jpeg', 0.85));
      };
      img.onerror = function() {
        resolve(dataUri); // Fallback to original on error
      };
      img.src = dataUri;
    });
  }

  async function initWorker(onProgress) {
    if (worker) return worker;
    if (workerInitializing) return await workerInitializing;

    workerInitializing = (async function() {
      await ensureTesseractLoaded();
      var w = await Tesseract.createWorker('eng', 1, {
        logger: function(m) {
          if (onProgress && m) {
            try {
              var prog = typeof m.progress === 'number' ? m.progress : 0;
              var status = m.status || 'processing';
              onProgress(status, prog);
            } catch (e) {
              console.warn('OCR progress callback error:', e);
            }
          }
        }
      });
      worker = w;
      return w;
    })();

    var res = await workerInitializing;
    workerInitializing = null;
    return res;
  }

  window.finpilotOcr = {
    isSupported: function() {
      return true;
    },

    /**
     * Performs client-side OCR on a base64 image data URI.
     * @param {string} base64DataUri - "data:image/jpeg;base64,..."
     * @param {function(status: string, progress: number)} onProgress
     * @returns {Promise<{isSuccess: boolean, text: string, confidence: number, errorMessage?: string}>}
     */
    recognize: async function(base64DataUri, onProgress) {
      try {
        if (!base64DataUri) {
          throw new Error('Image data is empty');
        }

        if (onProgress) onProgress('preparing image', 0.05);
        var optimizedUri = await resizeImageIfNeeded(base64DataUri, 1800);

        if (onProgress) onProgress('initializing tesseract worker', 0.15);
        var w = await initWorker(onProgress);

        if (onProgress) onProgress('recognizing text', 0.3);
        var ret = await w.recognize(optimizedUri);

        if (onProgress) onProgress('complete', 1.0);

        var data = ret && ret.data ? ret.data : {};
        var text = (data.text || '').trim();
        var confidence = typeof data.confidence === 'number' ? data.confidence : 0;

        return {
          isSuccess: true,
          text: text,
          confidence: confidence,
          errorMessage: null
        };
      } catch (err) {
        console.error('Tesseract.js OCR execution error:', err);
        return {
          isSuccess: false,
          text: '',
          confidence: 0,
          errorMessage: err.message || 'Browser OCR recognition failed'
        };
      }
    }
  };
})();
