// The MP4 encoder itself is Kotlin (MediaCodec), so what Dart can pin is the
// channel contract and the fallback behaviour — which is exactly where a
// platform bridge breaks silently. If an argument is renamed on one side only,
// the Kotlin handler reads null, and the animated share quietly degrades to a
// GIF forever without anyone noticing. These tests fail instead.
import 'dart:io';

import 'package:budget_tracker/services/wrapped_video.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('budgetify/wrapped_video');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('wrapped_video_test'));

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('sends every argument the Kotlin encoder reads', () async {
    final out = File('${tmp.path}/out.mp4')..writeAsBytesSync([0, 1, 2, 3]);
    MethodCall? seen;
    messenger.setMockMethodCallHandler(channel, (call) async {
      seen = call;
      return out.path;
    });

    final file = await WrappedVideo.encode(
      framePaths: const ['/a/f000.png', '/a/f001.png'],
      outPath: out.path,
      width: 1080,
      height: 1920,
      fps: 10,
      loops: 2,
      bitRate: 8000000,
    );

    expect(file?.path, out.path);
    expect(seen?.method, 'encode');
    final args = seen!.arguments as Map;
    // Keys are read by name in MainActivity.kt — renaming one here alone
    // silently disables video and falls back to GIF.
    expect(args['frames'], ['/a/f000.png', '/a/f001.png']);
    expect(args['outPath'], out.path);
    expect(args['width'], 1080);
    expect(args['height'], 1920);
    expect(args['fps'], 10);
    expect(args['loops'], 2);
    expect(args['bitRate'], 8000000);
  });

  test('a failed encode resolves to null so the caller can fall back',
      () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'encode_failed', message: 'no codec');
    });

    expect(
      await WrappedVideo.encode(
        framePaths: const ['/a/f000.png'],
        outPath: '${tmp.path}/out.mp4',
        width: 1080,
        height: 1920,
        fps: 10,
      ),
      isNull,
    );
  });

  test('a path the platform never actually wrote resolves to null', () async {
    final missing = '${tmp.path}/never_written.mp4';
    messenger.setMockMethodCallHandler(channel, (call) async => missing);

    expect(
      await WrappedVideo.encode(
        framePaths: const ['/a/f000.png'],
        outPath: missing,
        width: 1080,
        height: 1920,
        fps: 10,
      ),
      isNull,
      reason: 'sharing a non-existent file would fail in the share sheet',
    );
  });

  test('an empty file resolves to null', () async {
    final empty = File('${tmp.path}/empty.mp4')..writeAsBytesSync([]);
    messenger.setMockMethodCallHandler(channel, (call) async => empty.path);

    expect(
      await WrappedVideo.encode(
        framePaths: const ['/a/f000.png'],
        outPath: empty.path,
        width: 1080,
        height: 1920,
        fps: 10,
      ),
      isNull,
    );
  });

  test('off Android it reports unsupported without touching the channel',
      () async {
    // Host test platform is not Android, which is the iOS path: no encoder, so
    // the screen must take the GIF branch.
    var called = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      called = true;
      return true;
    });

    expect(await WrappedVideo.isSupported(), isFalse);
    expect(called, isFalse);
  });
}
