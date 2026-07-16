import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Everything the GIF encoder needs, bundled so the whole job can hop to a
/// background isolate via `compute` (encoding ~24 frames takes seconds of
/// CPU and must not jank the UI).
///
/// Frames are raw RGBA captures of the Wrapped card, all [width]×[height].
class WrappedGifRequest {
  final int width;
  final int height;

  /// Playback rate. Frames span exactly one loop of the card's animation,
  /// so the resulting GIF loops seamlessly.
  final int fps;
  final List<Uint8List> rgbaFrames;

  const WrappedGifRequest({
    required this.width,
    required this.height,
    required this.fps,
    required this.rgbaFrames,
  });
}

/// Encodes the captured card frames into a looping GIF. Pure Dart (no
/// platform channels, no network) — the offline guarantee is preserved.
/// Top-level so it can be handed straight to `compute`.
Uint8List buildWrappedGif(WrappedGifRequest req) {
  if (req.rgbaFrames.isEmpty) {
    throw ArgumentError('No frames to encode');
  }
  // samplingFactor trades palette-quantisation quality for speed; the card
  // is mostly flat, dark surfaces, so a coarse sample still looks rich.
  final encoder = img.GifEncoder(repeat: 0, samplingFactor: 30);
  final delayCs = (100 / req.fps).round(); // GIF delays tick in 1/100 s
  for (final bytes in req.rgbaFrames) {
    if (bytes.length != req.width * req.height * 4) {
      throw ArgumentError('Frame byte length does not match dimensions');
    }
    final frame = img.Image.fromBytes(
      width: req.width,
      height: req.height,
      bytes: bytes.buffer,
      order: img.ChannelOrder.rgba,
    );
    encoder.addFrame(frame, duration: delayCs);
  }
  final out = encoder.finish();
  if (out == null || out.isEmpty) {
    throw StateError('GIF encoding produced no data');
  }
  return out;
}
