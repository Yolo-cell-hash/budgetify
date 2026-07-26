import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Encodes the captured Wrapped card frames into a looping H.264/MP4 through
/// the platform encoder (Android MediaCodec — see `WrappedVideoEncoder.kt`).
///
/// The animated share used to be a GIF, which failed on both targets it exists
/// for: Instagram flattens a shared GIF to a still image, and a GIF's
/// 256-colour palette can't hold the card's midnight-to-gold gradients, so
/// WhatsApp was re-encoding an already dithered source. Video is what both
/// platforms animate, in full colour.
///
/// This rides a platform API — no new dependency, nothing added to the APK, no
/// network — so the offline guarantee is intact. Where it isn't available
/// (iOS, or a device whose encoder refuses), callers fall back to the GIF.
class WrappedVideo {
  static const MethodChannel _channel =
      MethodChannel('budgetify/wrapped_video');

  /// Whether this platform can encode video at all. False off Android, and
  /// false on an Android device with no usable H.264 encoder.
  static Future<bool> isSupported() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Encode [framePaths] (PNGs, every one [width]×[height]) to [outPath].
  ///
  /// The frames span exactly one period of the card's motion, so passing
  /// [loops] > 1 repeats them back to back into a longer seamless cycle
  /// without capturing anything extra. Returns the written file, or null if
  /// the encoder failed — the caller should then fall back to the GIF.
  static Future<File?> encode({
    required List<String> framePaths,
    required String outPath,
    required int width,
    required int height,
    required int fps,
    int loops = 1,
    int bitRate = 8000000,
  }) async {
    try {
      final path = await _channel.invokeMethod<String>('encode', {
        'frames': framePaths,
        'outPath': outPath,
        'width': width,
        'height': height,
        'fps': fps,
        'loops': loops,
        'bitRate': bitRate,
      });
      if (path == null) return null;
      final file = File(path);
      return await file.exists() && await file.length() > 0 ? file : null;
    } on PlatformException catch (e) {
      debugPrint('Wrapped video encode failed: ${e.message}');
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
