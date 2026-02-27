import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class FeedPostContent extends StatelessWidget {
  const FeedPostContent({
    super.key,
    this.content,
    this.imageUrl,
    this.videoUrl,
  });

  final String? content;
  final String? imageUrl;
  final String? videoUrl;

  @override
  Widget build(BuildContext context) {
    final contentText = content?.trim() ?? '';
    final image = imageUrl?.trim() ?? '';
    final video = videoUrl?.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (contentText.isNotEmpty)
          Text(
            contentText,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        if (image.isNotEmpty) ...<Widget>[
          if (contentText.isNotEmpty) const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: CachedNetworkImage(
                imageUrl: image,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const Center(
                  child: Text(
                    'Image unavailable',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ),
          ),
        ],
        if (video.isNotEmpty) ...<Widget>[
          if (contentText.isNotEmpty || image.isNotEmpty)
            const SizedBox(height: 8),
          _VideoAttachment(videoUrl: video),
        ],
        if (contentText.isEmpty && image.isEmpty && video.isEmpty)
          const Text(
            '[media post]',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

class _VideoAttachment extends StatefulWidget {
  const _VideoAttachment({
    required this.videoUrl,
  });

  final String videoUrl;

  @override
  State<_VideoAttachment> createState() => _VideoAttachmentState();
}

class _VideoAttachmentState extends State<_VideoAttachment> {
  VideoPlayerController? _controller;
  Future<void>? _initializeFuture;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _initializeController() {
    final uri = Uri.tryParse(widget.videoUrl);
    if (uri == null) {
      setState(() {
        _hasError = true;
      });
      return;
    }

    final controller = VideoPlayerController.networkUrl(uri);
    _controller = controller;
    _initializeFuture = controller.initialize().then((_) {
      controller.setLooping(true);
    }).catchError((_) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    });
  }

  void _togglePlayback() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_hasError || controller == null) {
      return const _VideoErrorState();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        color: Colors.black,
        child: FutureBuilder<void>(
          future: _initializeFuture,
          builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError || !controller.value.isInitialized) {
              return const _VideoErrorState();
            }

            return Stack(
              alignment: Alignment.center,
              children: <Widget>[
                AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: VideoPlayer(controller),
                ),
                IconButton.filledTonal(
                  onPressed: _togglePlayback,
                  icon: Icon(
                    controller.value.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _VideoErrorState extends StatelessWidget {
  const _VideoErrorState();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 200,
      child: Center(
        child: Text(
          'Video unavailable',
          style: TextStyle(color: Colors.white70),
        ),
      ),
    );
  }
}
