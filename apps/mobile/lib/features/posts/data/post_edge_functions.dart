import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_compress/video_compress.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/post.dart';

class PostApiException implements Exception {
  const PostApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PostEdgeFunctions {
  const PostEdgeFunctions(this._client);

  final SupabaseClient _client;
  static const _mediaUrlTtlSeconds = 48 * 60 * 60;
  static const _maxVideoUploadBytes = 10 * 1024 * 1024;

  Future<String> uploadPostImage(String filePath) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw const PostApiException('Anonymous session is not ready.');
    }

    final extension = _imageExtension(filePath);
    final objectPath =
        'posts/$userId/${DateTime.now().toUtc().microsecondsSinceEpoch}.$extension';

    try {
      await _client.storage.from('media').upload(
            objectPath,
            File(filePath),
            fileOptions: FileOptions(
              upsert: false,
              contentType: _imageContentType(extension),
              cacheControl: '172800',
            ),
          );
    } catch (error) {
      throw PostApiException('Image upload failed: $error');
    }

    try {
      await _runUploadPolicyCheck(
        objectPath: objectPath,
        mediaType: 'image',
      );
    } catch (error) {
      throw PostApiException('Image safety check failed: $error');
    }

    try {
      return await _client.storage
          .from('media')
          .createSignedUrl(objectPath, _mediaUrlTtlSeconds);
    } catch (error) {
      throw PostApiException('Image URL signing failed: $error');
    }
  }

  Future<String> uploadPostVideo(String filePath) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw const PostApiException('Anonymous session is not ready.');
    }

    final preparedVideo = await _prepareVideoFile(filePath);
    final extension = _videoExtension(preparedVideo.path);
    final objectPath =
        'videos/$userId/${DateTime.now().toUtc().microsecondsSinceEpoch}.$extension';

    try {
      await _client.storage.from('media').upload(
            objectPath,
            File(preparedVideo.path),
            fileOptions: FileOptions(
              upsert: false,
              contentType: _videoContentType(extension),
              cacheControl: '172800',
            ),
          );
    } catch (error) {
      throw PostApiException('Video upload failed: $error');
    } finally {
      await preparedVideo.dispose();
    }

    try {
      await _runUploadPolicyCheck(
        objectPath: objectPath,
        mediaType: 'video',
      );
    } catch (error) {
      throw PostApiException('Video safety check failed: $error');
    }

    try {
      return await _client.storage
          .from('media')
          .createSignedUrl(objectPath, _mediaUrlTtlSeconds);
    } catch (error) {
      throw PostApiException('Video URL signing failed: $error');
    }
  }

  Future<ShadePost> createPost(CreatePostInput input) async {
    final response = await _client.functions.invoke(
      'create-post',
      body: <String, dynamic>{
        'communityId': input.communityId,
        'content': input.content,
        'imageUrl': input.imageUrl,
        'videoUrl': input.videoUrl,
        'ttlHours': input.ttlHours,
      },
    );

    if (response.status >= 400) {
      throw PostApiException(
        _extractErrorMessage(response.data, 'Failed to create post.'),
      );
    }

    final data = response.data;
    if (data is! Map<String, dynamic> || data['post'] == null) {
      throw const PostApiException('Invalid create-post response.');
    }

    return ShadePost.fromMap(Map<String, dynamic>.from(data['post']));
  }

  Future<ReactionResult> reactToPost({
    required String postId,
    required bool removeReaction,
  }) async {
    final response = await _client.functions.invoke(
      'react-to-post',
      body: <String, dynamic>{
        'postId': postId,
        'action': removeReaction ? 'remove' : 'add',
      },
    );

    if (response.status >= 400) {
      throw PostApiException(
        _extractErrorMessage(response.data, 'Failed to react to post.'),
      );
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const PostApiException('Invalid react-to-post response.');
    }

    final likeCount = data['likeCount'];
    final liked = data['liked'];

    if (likeCount is! int || liked is! bool) {
      throw const PostApiException('Invalid reaction payload.');
    }

    return ReactionResult(
      postId: postId,
      likeCount: likeCount,
      liked: liked,
    );
  }

  Future<_PreparedUploadFile> _prepareVideoFile(String sourcePath) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw const PostApiException('Video file not found.');
    }

    final sourceSize = await sourceFile.length();
    if (sourceSize <= _maxVideoUploadBytes) {
      return _PreparedUploadFile(
        path: sourcePath,
        cleanupPaths: const <String>[],
      );
    }

    final cleanupPaths = <String>[];
    String? selectedPath;
    int? selectedSize;

    for (final quality in <VideoQuality>[
      VideoQuality.MediumQuality,
      VideoQuality.LowQuality,
    ]) {
      final info = await VideoCompress.compressVideo(
        sourcePath,
        quality: quality,
        deleteOrigin: false,
        includeAudio: true,
      );

      final compressedPath = info?.file?.path;
      if (compressedPath == null || compressedPath.isEmpty) {
        continue;
      }

      cleanupPaths.add(compressedPath);

      final compressedSize = await File(compressedPath).length();
      if (selectedSize == null || compressedSize < selectedSize) {
        selectedPath = compressedPath;
        selectedSize = compressedSize;
      }

      if (compressedSize <= _maxVideoUploadBytes) {
        break;
      }
    }

    if (selectedPath == null || selectedSize == null) {
      await _deletePaths(cleanupPaths);
      throw const PostApiException(
          'Video compression failed. Pick another video.');
    }

    if (selectedSize > _maxVideoUploadBytes) {
      await _deletePaths(cleanupPaths);
      throw const PostApiException(
        'Video is too large after compression. Please use a shorter clip.',
      );
    }

    return _PreparedUploadFile(
      path: selectedPath,
      cleanupPaths: cleanupPaths,
    );
  }

  Future<void> _runUploadPolicyCheck({
    required String objectPath,
    required String mediaType,
  }) async {
    final response = await _client.functions.invoke(
      'moderate-upload',
      body: <String, dynamic>{
        'objectPath': objectPath,
        'mediaType': mediaType,
      },
    );

    if (response.status >= 400) {
      throw PostApiException(
        _extractErrorMessage(
          response.data,
          'Upload blocked by safety policy. Please choose different media.',
        ),
      );
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const PostApiException('Invalid upload policy response.');
    }

    final verdict = data['verdict'];
    if (verdict is! Map<String, dynamic>) {
      throw const PostApiException('Invalid upload policy verdict.');
    }

    final status = verdict['status'];
    if (status is! String || status != 'approved') {
      throw const PostApiException('Upload was not approved by safety policy.');
    }
  }
}

final postEdgeFunctionsProvider = Provider<PostEdgeFunctions?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return null;
  }

  return PostEdgeFunctions(client);
});

final likedPostIdsProvider = StateProvider<Set<String>>((ref) {
  return <String>{};
});

String _extractErrorMessage(dynamic data, String fallback) {
  if (data is Map<String, dynamic>) {
    final error = data['error'];
    if (error is Map<String, dynamic>) {
      final message = error['message'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
    }
  }

  return fallback;
}

String _imageExtension(String filePath) {
  final value = filePath.toLowerCase();
  if (value.endsWith('.png')) {
    return 'png';
  }
  if (value.endsWith('.webp')) {
    return 'webp';
  }
  if (value.endsWith('.gif')) {
    return 'gif';
  }

  return 'jpg';
}

String _imageContentType(String extension) {
  switch (extension) {
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'gif':
      return 'image/gif';
    default:
      return 'image/jpeg';
  }
}

String _videoExtension(String filePath) {
  final value = filePath.toLowerCase();
  if (value.endsWith('.mov')) {
    return 'mov';
  }
  if (value.endsWith('.webm')) {
    return 'webm';
  }

  return 'mp4';
}

String _videoContentType(String extension) {
  switch (extension) {
    case 'mov':
      return 'video/quicktime';
    case 'webm':
      return 'video/webm';
    default:
      return 'video/mp4';
  }
}

class ReactionResult {
  const ReactionResult({
    required this.postId,
    required this.likeCount,
    required this.liked,
  });

  final String postId;
  final int likeCount;
  final bool liked;
}

class _PreparedUploadFile {
  const _PreparedUploadFile({
    required this.path,
    required this.cleanupPaths,
  });

  final String path;
  final List<String> cleanupPaths;

  Future<void> dispose() async {
    await _deletePaths(cleanupPaths);
  }
}

Future<void> _deletePaths(List<String> paths) async {
  for (final path in paths.toSet()) {
    if (path.isEmpty) {
      continue;
    }

    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Ignore best-effort temp cleanup errors.
    }
  }
}
