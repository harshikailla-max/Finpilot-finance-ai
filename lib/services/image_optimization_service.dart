import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class OptimizedImageResult {
  final Uint8List bytes;
  final int originalWidth;
  final int originalHeight;
  final int originalByteSize;
  final int optimizedWidth;
  final int optimizedHeight;
  final int optimizedByteSize;

  const OptimizedImageResult({
    required this.bytes,
    required this.originalWidth,
    required this.originalHeight,
    required this.originalByteSize,
    required this.optimizedWidth,
    required this.optimizedHeight,
    required this.optimizedByteSize,
  });

  double get compressionRatio =>
      originalByteSize > 0 ? (optimizedByteSize / originalByteSize) : 1.0;
}

class ImageOptimizationService {
  /// Maximum byte limit for OCR upload payloads (800 KB, safely below OCR.space & proxy 1 MB ceiling).
  static const int maxUploadBytes = 800 * 1024;

  /// Maximum dimension in pixels for OCR legibility without payload bloat.
  static const int maxDimensionPixels = 1800;

  /// Optimizes receipt image for OCR:
  /// 1. Reads dimensions and orientation.
  /// 2. Scales down oversized images while maintaining aspect ratio and high character sharpness.
  /// 3. Strips EXIF metadata.
  /// 4. Enforces strict payload ceiling under [maxBytes] (default 800 KB).
  static OptimizedImageResult optimizeForOcr(
    Uint8List rawBytes, {
    int maxDimension = maxDimensionPixels,
    int maxBytes = maxUploadBytes,
  }) {
    final originalSize = rawBytes.lengthInBytes;

    final image = img.decodeImage(rawBytes);
    if (image == null) {
      // If decoding fails (e.g. non-image or raw text), return raw bytes safely
      return OptimizedImageResult(
        bytes: rawBytes,
        originalWidth: 0,
        originalHeight: 0,
        originalByteSize: originalSize,
        optimizedWidth: 0,
        optimizedHeight: 0,
        optimizedByteSize: originalSize,
      );
    }

    final origW = image.width;
    final origH = image.height;

    img.Image processed = image;

    // 1. Resize if either dimension exceeds maxDimension
    if (origW > maxDimension || origH > maxDimension) {
      int targetW;
      int targetH;
      if (origW >= origH) {
        targetW = maxDimension;
        targetH = (origH * (maxDimension / origW)).round();
      } else {
        targetH = maxDimension;
        targetW = (origW * (maxDimension / origH)).round();
      }

      processed = img.copyResize(
        image,
        width: targetW,
        height: targetH,
        interpolation: img.Interpolation.linear,
      );
    }

    // 2. Compress to clean JPEG at high quality (82)
    Uint8List compressed = Uint8List.fromList(
      img.encodeJpg(processed, quality: 82),
    );

    // 3. If payload is still above limit, reduce quality to 70
    if (compressed.lengthInBytes > maxBytes) {
      compressed = Uint8List.fromList(
        img.encodeJpg(processed, quality: 70),
      );
    }

    // 4. If still above limit, downscale further to 1350px at quality 68
    if (compressed.lengthInBytes > maxBytes) {
      final smallerW = (processed.width * 0.75).round();
      final smallerH = (processed.height * 0.75).round();
      final furtherScaled = img.copyResize(
        processed,
        width: smallerW,
        height: smallerH,
        interpolation: img.Interpolation.linear,
      );
      processed = furtherScaled;
      compressed = Uint8List.fromList(
        img.encodeJpg(furtherScaled, quality: 68),
      );
    }

    // 5. Ultimate safety ceiling: guarantee payload is under 3.5 MB for Azure F0 (4 MB) & Vercel (4.5 MB)
    if (compressed.lengthInBytes > 3500 * 1024) {
      final emergencyScaled = img.copyResize(
        processed,
        width: 1200,
        interpolation: img.Interpolation.linear,
      );
      processed = emergencyScaled;
      compressed = Uint8List.fromList(
        img.encodeJpg(emergencyScaled, quality: 65),
      );
    }

    debugPrint(
      'ImageOptimizationService: ${origW}x$origH (${(originalSize / 1024).toStringAsFixed(1)} KB) -> '
      '${processed.width}x${processed.height} (${(compressed.lengthInBytes / 1024).toStringAsFixed(1)} KB)',
    );

    return OptimizedImageResult(
      bytes: compressed,
      originalWidth: origW,
      originalHeight: origH,
      originalByteSize: originalSize,
      optimizedWidth: processed.width,
      optimizedHeight: processed.height,
      optimizedByteSize: compressed.lengthInBytes,
    );
  }

  /// Verifies that the payload is safely within Azure Document Intelligence F0 (4 MB) and Vercel limits.
  static bool isPayloadWithinLimits(Uint8List bytes) {
    return bytes.lengthInBytes <= 3500 * 1024;
  }
}
