import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../design/theme.dart';

class RedactionEditor extends StatefulWidget {
  const RedactionEditor({super.key, required this.source});
  final File source;
  @override
  State<RedactionEditor> createState() => _RedactionEditorState();
}

class _RedactionEditorState extends State<RedactionEditor> {
  ui.Image? image;
  final boxes = <Rect>[];
  Offset? start, end;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    decode();
  }

  Future<void> decode() async {
    try {
      final codec = await ui.instantiateImageCodec(
        await widget.source.readAsBytes(),
        targetWidth: 1600,
        allowUpscaling: false,
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() => image = frame.image);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'This image could not be opened. Choose a different file.',
        );
      }
    }
  }

  Rect? get current =>
      start == null || end == null ? null : Rect.fromPoints(start!, end!);
  Future<void> save() async {
    if (image == null || busy) return;
    setState(() => busy = true);
    try {
      final bytes = await flattenEvidence(image!, boxes);
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/social_discovery-redacted-${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);
      if (mounted) Navigator.pop(context, file);
    } catch (_) {
      if (mounted) {
        setState(() => busy = false);
        notice(context, 'Could not save the redacted copy. Please retry.');
      }
    }
  }

  @override
  void dispose() {
    image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Protect your details'),
      actions: [
        TextButton(
          onPressed: busy ? null : save,
          child: const Text('Use copy'),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Drag over addresses, account numbers, card details and QR codes. Only the flattened copy will be uploaded.',
              style: TextStyle(color: P.mist),
            ),
          ),
          Expanded(
            child: image == null
                ? Center(
                    child: error == null
                        ? const CircularProgressIndicator()
                        : Text(error!),
                  )
                : Center(
                    child: AspectRatio(
                      aspectRatio: image!.width / image!.height,
                      child: LayoutBuilder(
                        builder: (context, c) => GestureDetector(
                          onPanStart: (d) => setState(() {
                            start = Offset(
                              (d.localPosition.dx / c.maxWidth).clamp(0, 1),
                              (d.localPosition.dy / c.maxHeight).clamp(0, 1),
                            );
                            end = start;
                          }),
                          onPanUpdate: (d) => setState(
                            () => end = Offset(
                              (d.localPosition.dx / c.maxWidth).clamp(0, 1),
                              (d.localPosition.dy / c.maxHeight).clamp(0, 1),
                            ),
                          ),
                          onPanEnd: (_) => setState(() {
                            if (current != null) boxes.add(current!);
                            start = null;
                            end = null;
                          }),
                          child: CustomPaint(
                            painter: _EvidencePainter(image!, [
                              ...boxes,
                              if (current != null) current!,
                            ]),
                            size: Size.infinite,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: boxes.isEmpty
                        ? null
                        : () => setState(() => boxes.removeLast()),
                    child: const Text('Undo'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : save,
                    child: Text(busy ? 'Preparing…' : 'Use private copy'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _EvidencePainter extends CustomPainter {
  _EvidencePainter(this.image, this.boxes);
  final ui.Image image;
  final List<Rect> boxes;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      Paint(),
    );
    for (final r in boxes) {
      canvas.drawRect(
        Rect.fromLTRB(
          r.left * size.width,
          r.top * size.height,
          r.right * size.width,
          r.bottom * size.height,
        ),
        Paint()..color = Colors.black,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EvidencePainter oldDelegate) => true;
}

Future<Uint8List> flattenEvidence(ui.Image image, List<Rect> boxes) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawImage(image, Offset.zero, Paint());
  for (final rect in boxes) {
    canvas.drawRect(
      Rect.fromLTRB(
        rect.left * image.width,
        rect.top * image.height,
        rect.right * image.width,
        rect.bottom * image.height,
      ),
      Paint()..color = Colors.black,
    );
  }
  final picture = recorder.endRecording();
  final flattened = await picture.toImage(image.width, image.height);
  picture.dispose();
  final bytes = await flattened.toByteData(format: ui.ImageByteFormat.png);
  flattened.dispose();
  return bytes!.buffer.asUint8List();
}
