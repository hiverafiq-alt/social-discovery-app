import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../design/theme.dart';

// One mounted controller per visible card. Native AVPlayer/ExoPlayer owns ABR.
// Data saver uses tap to play, never a hand selected fixed rendition.
class LivingVideo extends StatefulWidget {
  const LivingVideo({
    super.key,
    required this.grant,
    this.posterUrl,
    this.paused = false,
    this.tapToPlay = false,
  });
  final Future<Uri> Function() grant;
  final String? posterUrl;
  final bool paused, tapToPlay;
  @override
  State<LivingVideo> createState() => _LivingVideoState();
}

class _LivingVideoState extends State<LivingVideo> with WidgetsBindingObserver {
  VideoPlayerController? player;
  bool failed = false, loading = false, muted = true, started = false;
  bool foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!widget.tapToPlay) load();
  }

  Future<void> load() async {
    if (loading || player != null) return;
    setState(() {
      loading = true;
      failed = false;
    });
    VideoPlayerController? created;
    try {
      final uri = await widget.grant();
      if (uri.scheme != 'https' || !uri.path.endsWith('.m3u8')) {
        throw StateError('Adaptive HTTPS master required');
      }
      if (!mounted) return;
      created = VideoPlayerController.networkUrl(
        uri,
        formatHint: VideoFormat.hls,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );
      await created.initialize().timeout(const Duration(seconds: 20));
      await created.setLooping(true);
      await created.setVolume(0);
      if (!mounted) {
        await created.dispose();
        return;
      }
      player = created;
      started = true;
      if (!widget.paused && foreground) await created.play();
      if (mounted && context.mounted) setState(() => loading = false);
    } catch (_) {
      await created?.dispose();
      if (mounted && context.mounted) {
        setState(() {
          player = null;
          loading = false;
          failed = true;
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant LivingVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.paused || !foreground) {
      player?.pause();
    } else if (started) {
      player?.play();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (!foreground) {
      player?.pause();
    } else if (!widget.paused && started) {
      player?.play();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF44344B), Color(0xFF1B1727), P.ink],
          ),
        ),
      ),
      if (widget.posterUrl != null)
        Image.network(
          widget.posterUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      if (player?.value.isInitialized == true)
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: player!.value.size.width,
            height: player!.value.size.height,
            child: VideoPlayer(player!),
          ),
        ),
      if (loading)
        const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: P.lilac),
        ),
      if (failed || (widget.tapToPlay && !started))
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton.filledTonal(
                onPressed: load,
                icon: Icon(failed ? Icons.refresh : Icons.play_arrow),
                tooltip: failed ? 'Retry introduction' : 'Play introduction',
              ),
              Text(
                failed
                    ? 'Introduction unavailable. Tap to retry.'
                    : 'Tap to play, Data Saver is on',
                style: const TextStyle(color: P.mist),
              ),
            ],
          ),
        ),
      Positioned(
        top: 16,
        right: 16,
        child: IconButton.filledTonal(
          onPressed: player == null
              ? null
              : () {
                  setState(() => muted = !muted);
                  player!.setVolume(muted ? 0 : 1);
                },
          icon: Icon(
            muted ? Icons.volume_off_outlined : Icons.volume_up_outlined,
          ),
          tooltip: muted ? 'Unmute introduction' : 'Mute introduction',
        ),
      ),
    ],
  );
}

class StudioPortrait extends StatelessWidget {
  const StudioPortrait({super.key, required this.name});
  final String name;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF69556E), Color(0xFF352A48), Color(0xFF17121E)],
      ),
    ),
    child: Stack(
      children: [
        Positioned(
          top: 60,
          right: -60,
          child: Container(
            width: 310,
            height: 310,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: P.lilac.withValues(alpha: .2),
                width: 1,
              ),
            ),
          ),
        ),
        const Center(child: Opacity(opacity: .15, child: Monogram(size: 220))),
        const Positioned(
          top: 28,
          left: 24,
          child: Eyebrow('Fictional studio profile', color: P.white),
        ),
        const Positioned(
          top: 52,
          left: 24,
          child: Text(
            'No introduction video attached',
            style: TextStyle(color: P.mist, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}
