import 'dart:typed_data';

import 'package:budget_tracker/services/wrapped_gif.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Uint8List frame(int w, int h, int shade) {
    final bytes = Uint8List(w * h * 4);
    for (var i = 0; i < bytes.length; i += 4) {
      bytes[i] = shade; // R
      bytes[i + 1] = (shade * 2) % 256; // G
      bytes[i + 2] = 40; // B
      bytes[i + 3] = 255; // A
    }
    return bytes;
  }

  test('encodes RGBA frames into a forever-looping GIF', () {
    const w = 12, h = 20;
    final gif = buildWrappedGif(WrappedGifRequest(
      width: w,
      height: h,
      fps: 10,
      rgbaFrames: [frame(w, h, 30), frame(w, h, 120), frame(w, h, 220)],
    ));

    // GIF89a header, NETSCAPE loop block (repeat forever), GIF trailer.
    expect(String.fromCharCodes(gif.sublist(0, 6)), 'GIF89a');
    expect(String.fromCharCodes(gif).contains('NETSCAPE2.0'), isTrue);
    expect(gif.last, 0x3B);
  });

  test('rejects an empty capture', () {
    expect(
      () => buildWrappedGif(const WrappedGifRequest(
          width: 4, height: 4, fps: 10, rgbaFrames: [])),
      throwsArgumentError,
    );
  });

  test('rejects frames that do not match the declared dimensions', () {
    expect(
      () => buildWrappedGif(WrappedGifRequest(
          width: 10, height: 10, fps: 10, rgbaFrames: [Uint8List(12)])),
      throwsArgumentError,
    );
  });
}
