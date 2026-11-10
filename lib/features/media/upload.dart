import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class IntroUploader {
  IntroUploader(this.client);
  final SupabaseClient client;
  Future<String> upload(
    File file,
    Duration duration,
    void Function(double) progress, {
    String kind = 'intro',
    String origin = 'camera',
  }) async {
    final hash = await sha256.bind(file.openRead()).first;
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'upload-${client.auth.currentUser!.id}-$hash';
    final sessionResponse = await client.functions.invoke(
      'media-session',
      body: {
        'sha256': hash.toString(),
        'duration_ms': duration.inMilliseconds,
        'kind': kind,
        'origin': origin,
      },
    );
    if (sessionResponse.status != 200) {
      throw StateError('Upload session unavailable');
    }
    final session = Map<String, dynamic>.from(sessionResponse.data);
    final headers = Map<String, String>.from(session['headers']);
    headers['Tus-Resumable'] = '1.0.0';
    final endpoint = Uri.parse(session['endpoint']);
    Uri? uploadUri;
    final saved = prefs.getString(cacheKey);
    // Cached resources are server-issued Bunny TUS URLs, scoped to this account and file hash.
    if (saved != null) {
      final uri = Uri.parse(saved);
      if (uri.scheme == 'https' && uri.host == endpoint.host) uploadUri = uri;
    }
    final length = await file.length();
    var offset = 0;
    if (uploadUri != null) {
      final head = await http
          .head(uploadUri, headers: headers)
          .timeout(const Duration(seconds: 20));
      if (head.statusCode == 200 || head.statusCode == 204) {
        offset = int.parse(head.headers['upload-offset'] ?? '0');
      } else {
        uploadUri = null;
      }
    }
    if (uploadUri == null) {
      final metadata = {
        'filetype': 'video/mp4',
        'title': 'Introduction',
        'collection': session['collection'] ?? '',
      };
      final created = await http
          .post(
            endpoint,
            headers: {
              ...headers,
              'Upload-Length': '$length',
              'Upload-Metadata': metadata.entries
                  .map((e) => '${e.key} ${base64Encode(utf8.encode(e.value))}')
                  .join(','),
            },
          )
          .timeout(const Duration(seconds: 30));
      if (created.statusCode != 201) {
        throw StateError('Could not begin resumable upload');
      }
      uploadUri = endpoint.resolve(created.headers['location']!);
      if (uploadUri.host != endpoint.host || uploadUri.scheme != 'https') {
        throw StateError('Unexpected upload location');
      }
      await prefs.setString(cacheKey, uploadUri.toString());
    }
    final input = await file.open();
    try {
      while (offset < length) {
        await input.setPosition(offset);
        final chunk = await input.read(min(1024 * 1024, length - offset));
        final result = await http
            .patch(
              uploadUri,
              headers: {
                ...headers,
                'Upload-Offset': '$offset',
                'Content-Type': 'application/offset+octet-stream',
              },
              body: chunk,
            )
            .timeout(const Duration(seconds: 45));
        if (result.statusCode != 204) {
          throw StateError('Upload interrupted. Retry to resume.');
        }
        offset = int.parse(
          result.headers['upload-offset'] ?? '${offset + chunk.length}',
        );
        progress(offset / length);
      }
    } finally {
      await input.close();
    }
    await prefs.remove(cacheKey);
    return session['media_id'];
  }
}
