import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import '../../core/config.dart';
import '../../design/theme.dart';
import '../../domain/models.dart';
import 'upload.dart';

class RecorderScreen extends StatefulWidget {
  const RecorderScreen({super.key});
  @override
  State<RecorderScreen> createState() => _RecorderScreenState();
}

class _RecorderScreenState extends State<RecorderScreen>
    with WidgetsBindingObserver {
  CameraController? camera;
  VideoPlayerController? preview;
  List<CameraDescription> cameras = [];
  int lens = 0;
  Timer? timer;
  final clock = Stopwatch();
  File? recording;
  Duration duration = Duration.zero;
  String? error;
  bool recordingNow = false, uploading = false, stopping = false;
  double progress = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initialize();
  }

  Future<void> initialize() async {
    if (AppConfig.webPreview) {
      setState(
        () => error =
            'Camera-only recording is part of the iPhone build. This browser preview does not record or upload video.',
      );
      return;
    }
    try {
      cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('Camera unavailable');
      if (camera == null) {
        lens = cameras
            .indexWhere((c) => c.lensDirection == CameraLensDirection.front)
            .clamp(0, cameras.length - 1);
      }
      final next = CameraController(
        cameras[lens],
        ResolutionPreset.high,
        enableAudio: true,
        fps: 30,
      );
      await next.initialize();
      await next.lockCaptureOrientation(DeviceOrientation.portraitUp);
      if (!mounted) {
        await next.dispose();
        return;
      }
      setState(() {
        camera = next;
        error = null;
      });
    } catch (_) {
      if (mounted && context.mounted) {
        setState(
          () => error =
              'Camera and microphone access are needed. Check Settings, then try again.',
        );
      }
    }
  }

  Future<void> start() async {
    if (camera == null || recordingNow) return;
    try {
      await camera!.startVideoRecording();
      clock.reset();
      clock.start();
      setState(() {
        recordingNow = true;
        duration = Duration.zero;
      });
      timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
        if (!mounted) return;
        setState(() => duration = clock.elapsed);
        if (clock.elapsed >= const Duration(milliseconds: 9700)) stop();
      });
    } catch (_) {
      if (mounted && context.mounted) {
        notice(context, 'Recording could not start. Try again.');
      }
    }
  }

  Future<void> stop() async {
    if (!recordingNow || stopping) return;
    stopping = true;
    timer?.cancel();
    clock.stop();
    try {
      final file = await camera!.stopVideoRecording();
      final p = VideoPlayerController.file(File(file.path));
      await p.initialize();
      final actual = p.value.duration;
      if (!IntroPolicy.valid(actual)) {
        await p.dispose();
        await File(file.path).delete();
        if (mounted && context.mounted) {
          notice(
            context,
            'Keep your introduction between 5 and 10 seconds. Please retake.',
          );
          setState(() => recordingNow = false);
        }
      } else {
        await p.setLooping(true);
        await p.play();
        if (!mounted) {
          await p.dispose();
          return;
        }
        setState(() {
          recording = File(file.path);
          preview = p;
          duration = actual;
          recordingNow = false;
        });
        await camera?.dispose();
        camera = null;
      }
    } catch (_) {
      if (mounted && context.mounted) {
        setState(() => recordingNow = false);
        notice(context, 'Recording was interrupted. Please retake.');
      }
    }
    stopping = false;
  }

  Future<void> retake() async {
    await preview?.dispose();
    preview = null;
    if (recording != null && await recording!.exists()) {
      await recording!.delete();
    }
    recording = null;
    duration = Duration.zero;
    await initialize();
    if (mounted && context.mounted) setState(() {});
  }

  Future<void> upload() async {
    if (AppConfig.demo) {
      notice(
        context,
        'Recording is local in studio mode. Configure Supabase and Bunny to upload.',
      );
      return;
    }
    setState(() => uploading = true);
    await preview?.pause();
    try {
      final mediaId = await IntroUploader(Supabase.instance.client).upload(
        recording!,
        duration,
        (v) {
          if (mounted && context.mounted) setState(() => progress = v);
        },
      );
      await Supabase.instance.client.functions.invoke(
        'media-status',
        body: {'media_id': mediaId},
      );
      if (await recording!.exists()) await recording!.delete();
      if (mounted && context.mounted) {
        notice(
          context,
          'Uploaded privately. Processing and review come before publication.',
        );
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted && context.mounted) {
        notice(
          context,
          'Upload paused. Your recording is retained for retry in this session.',
        );
      }
    }
    if (mounted && context.mounted) setState(() => uploading = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (recordingNow) stop();
      preview?.pause();
      if (!recordingNow) {
        camera?.dispose();
        camera = null;
      }
    } else if (state == AppLifecycleState.resumed &&
        recording == null &&
        !recordingNow) {
      initialize();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    camera?.dispose();
    preview?.dispose();
    final file = recording;
    if (file != null) {
      file.exists().then((exists) {
        if (exists) file.delete();
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.webPreview) return _buildNative(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Your first hello')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Monogram(size: 80),
                  const SizedBox(height: 32),
                  const Eyebrow('Camera studio'),
                  const SizedBox(height: 16),
                  Text(
                    'Your first impression, alive.',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'A portrait introduction, recorded directly in the app. Keep it between 5 and 10 seconds. Good light. Face in frame. Just be you.',
                    style: TextStyle(color: P.mist),
                  ),
                  const SizedBox(height: 28),
                  const Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.videocam_outlined, size: 36, color: P.lilac),
                        SizedBox(height: 16),
                        Text(
                          'Camera-only recording is part of the iPhone build. This browser preview does not record or upload video.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Back to your profile'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNative(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Your first hello')),
    body: SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Good light. Face in frame. Just be you.\nRecord 5 to 10 seconds, directly here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: P.mist),
            ),
          ),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: preview != null
                      ? VideoPlayer(preview!)
                      : camera?.value.isInitialized == true
                      ? CameraPreview(camera!)
                      : Center(
                          child: error == null
                              ? const CircularProgressIndicator()
                              : Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(error!),
                                      TextButton(
                                        onPressed: initialize,
                                        child: const Text('Try again'),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  '${(duration.inMilliseconds / 1000).toStringAsFixed(1)} / 10 seconds',
                  style: const TextStyle(color: P.mist),
                ),
                const SizedBox(height: 12),
                if (uploading) LinearProgressIndicator(value: progress),
                if (recording != null)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: uploading ? null : retake,
                          child: const Text('Retake'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: uploading ? null : upload,
                          child: const Text('Use introduction'),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: recordingNow || cameras.length < 2
                            ? null
                            : () async {
                                await camera?.dispose();
                                lens = (lens + 1) % cameras.length;
                                await initialize();
                              },
                        icon: const Icon(Icons.cameraswitch_outlined),
                        tooltip: 'Switch camera',
                      ),
                      const SizedBox(width: 16),
                      FilledButton.icon(
                        onPressed: camera == null
                            ? null
                            : recordingNow
                            ? (clock.elapsed >= const Duration(seconds: 5)
                                  ? stop
                                  : null)
                            : start,
                        icon: Icon(
                          recordingNow ? Icons.stop : Icons.fiber_manual_record,
                        ),
                        label: Text(
                          recordingNow ? 'Finish' : 'Record introduction',
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
