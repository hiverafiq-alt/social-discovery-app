import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:social_discovery/features/requests/redaction.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'redaction is baked into output pixels, not a removable display overlay',
    () async {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 0, 10, 10),
        ui.Paint()..color = const ui.Color(0xFFFFFFFF),
      );
      final picture = recorder.endRecording();
      final original = await picture.toImage(10, 10);
      picture.dispose();
      final bytes = await flattenEvidence(original, [
        const ui.Rect.fromLTRB(0, 0, .5, .5),
      ]);
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final pixels = (await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      expect(pixels.getUint8(0), 0);
      expect(pixels.getUint8(1), 0);
      expect(pixels.getUint8(2), 0);
      final untouched = (9 * 10 + 9) * 4;
      expect(pixels.getUint8(untouched), 255);
      final originalPixels = (await original.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      expect(originalPixels.getUint8(0), 255);
      frame.image.dispose();
      codec.dispose();
      original.dispose();
    },
  );
}
