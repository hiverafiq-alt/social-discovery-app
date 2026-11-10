import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import '../../core/config.dart';
import '../../design/theme.dart';
import 'upload.dart';
import 'player.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});
  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  bool busy = false;
  double progress = 0;
  String status = '';
  Future<List<Map<String, dynamic>>> library() async {
    if (AppConfig.demo) return [];
    final client = Supabase.instance.client;
    return await client
        .from('profile_media')
        .select('id,kind,state,moderation,created_at')
        .eq('owner_id', client.auth.currentUser!.id)
        .order('created_at', ascending: false);
  }

  late Future<List<Map<String, dynamic>>> items = library();
  Future<void> add(bool video) async {
    if (AppConfig.webPreview) {
      notice(
        context,
        'Supporting media uploads are available in the mobile build. This preview uses sample data.',
      );
      return;
    }
    if (busy) return;
    try {
      final picker = ImagePicker();
      final picked = video
          ? await picker.pickVideo(
              source: ImageSource.gallery,
              maxDuration: const Duration(seconds: 60),
            )
          : await picker.pickImage(
              source: ImageSource.gallery,
              imageQuality: 85,
              maxWidth: 1600,
              maxHeight: 1600,
              requestFullMetadata: false,
            );
      if (picked == null || !mounted) return;
      if (AppConfig.demo) {
        notice(
          context,
          'Studio preview does not upload supporting media. Configure your services to continue.',
        );
        return;
      }
      setState(() {
        busy = true;
        progress = 0;
        status = 'Uploading privately';
      });
      final client = Supabase.instance.client;
      if (video) {
        final controller = VideoPlayerController.file(File(picked.path));
        await controller.initialize();
        final duration = controller.value.duration;
        final size = controller.value.size;
        await controller.dispose();
        if (duration > const Duration(seconds: 60) ||
            duration < const Duration(seconds: 1) ||
            size.width >= size.height) {
          throw StateError('Choose a portrait video of 1 to 60 seconds');
        }
        final id = await IntroUploader(client).upload(
          File(picked.path),
          duration,
          (v) {
            if (mounted) setState(() => progress = v);
          },
          kind: 'secondary_video',
          origin: 'import',
        );
        await client.functions.invoke('media-status', body: {'media_id': id});
      } else {
        final bytes = await picked.readAsBytes();
        if (bytes.length > 5 * 1024 * 1024) {
          throw StateError('Choose a photo smaller than 5 MB');
        }
        final response = await client.functions.invoke(
          'photo-upload',
          body: bytes,
          headers: {'Content-Type': 'image/jpeg'},
        );
        if (response.status != 200) {
          throw StateError('Photo upload unavailable');
        }
      }
      if (mounted) {
        setState(() {
          items = library();
          status =
              'Private upload received. Review is required before sharing.';
        });
      }
    } catch (_) {
      if (mounted) {
        notice(
          context,
          'Upload could not finish. Use a JPEG photo or a portrait video of 1 to 60 seconds, then retry.',
        );
      }
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> refresh() async {
    if (AppConfig.demo) return;
    final client = Supabase.instance.client;
    final rows = await library();
    for (final media in rows.where(
      (m) =>
          m['kind'] != 'photo' &&
          ['uploading', 'processing'].contains(m['state']),
    )) {
      await client.functions.invoke(
        'media-status',
        body: {'media_id': media['id']},
      );
    }
    if (mounted) setState(() => items = library());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Your supporting moments'),
      actions: [
        IconButton(
          onPressed: busy
              ? null
              : () async {
                  try {
                    await refresh();
                  } catch (_) {
                    if (context.mounted) {
                      notice(
                        context,
                        'Processing status is unavailable. Try again.',
                      );
                    }
                  }
                },
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh processing',
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Eyebrow('More of your world'),
        const SizedBox(height: 16),
        Text(
          'Life beyond\nthe first hello.',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 20),
        const Text(
          'Your primary introduction is always recorded in the camera studio. Add supporting photos or portrait videos here. Every upload stays private until reviewed.',
          style: TextStyle(color: P.mist),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: busy ? null : () => add(false),
          icon: const Icon(Icons.photo_outlined),
          label: const Text('Add supporting photo'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: busy ? null : () => add(true),
          icon: const Icon(Icons.video_library_outlined),
          label: const Text('Add secondary video'),
        ),
        if (busy) ...[
          const SizedBox(height: 24),
          LinearProgressIndicator(value: progress > 0 ? progress : null),
        ],
        if (status.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(status, style: const TextStyle(color: P.mist)),
        ],
        const SizedBox(height: 24),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: items,
          builder: (context, s) => Column(
            children: [
              if (s.hasError)
                const Text(
                  'Media library is unavailable. Pull a fresh status to retry.',
                ),
              if (s.data?.isEmpty == true)
                const Panel(
                  child: Text('Your supporting moments will live here.'),
                ),
              ...(s.data ?? []).map(
                (m) => ListTile(
                  leading: Icon(
                    m['kind'] == 'photo'
                        ? Icons.photo_outlined
                        : Icons.play_circle_outline,
                  ),
                  title: Text(
                    m['kind'] == 'intro'
                        ? 'Camera introduction'
                        : m['kind'] == 'photo'
                        ? 'Supporting photo'
                        : 'Secondary video',
                  ),
                  subtitle: Text('${m['state']} · ${m['moderation']}'),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class SupportingMoments extends StatefulWidget {
  const SupportingMoments({super.key, required this.load, required this.grant});
  final Future<List<Map<String, dynamic>>> Function() load;
  final Future<Uri> Function(String) grant;
  @override
  State<SupportingMoments> createState() => _SupportingMomentsState();
}

class _SupportingMomentsState extends State<SupportingMoments> {
  late final future = widget.load();
  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, s) => Column(
          children: [
            if (s.hasError)
              const Text(
                'Supporting moments could not load.',
                style: TextStyle(color: P.mist),
              ),
            ...(s.data ?? []).map(
              (m) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: m['kind'] == 'photo'
                    ? FutureBuilder<Uri>(
                        future: widget.grant(m['id']),
                        builder: (context, url) => url.hasData
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Image.network(
                                  url.data.toString(),
                                  height: 240,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Text('Photo unavailable'),
                                ),
                              )
                            : const SizedBox(height: 80),
                      )
                    : OutlinedButton.icon(
                        onPressed: () => showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            child: AspectRatio(
                              aspectRatio: 9 / 16,
                              child: LivingVideo(
                                grant: () => widget.grant(m['id']),
                              ),
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.play_circle_outline),
                        label: const Text('Play a supporting moment'),
                      ),
              ),
            ),
          ],
        ),
      );
}
