import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CreatePostDialogResult {
  const CreatePostDialogResult({
    required this.content,
    required this.ttlHours,
    this.imagePath,
    this.videoPath,
  });

  final String content;
  final int ttlHours;
  final String? imagePath;
  final String? videoPath;
}

class CreatePostDialog extends StatefulWidget {
  const CreatePostDialog({super.key});

  @override
  State<CreatePostDialog> createState() => _CreatePostDialogState();
}

class _CreatePostDialogState extends State<CreatePostDialog> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  final _imagePicker = ImagePicker();

  int _ttlHours = 24;
  XFile? _selectedImage;
  XFile? _selectedVideo;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      CreatePostDialogResult(
        content: _contentController.text.trim(),
        ttlHours: _ttlHours,
        imagePath: _selectedImage?.path,
        videoPath: _selectedVideo?.path,
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final selected = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 2048,
      );

      if (selected == null || !mounted) {
        return;
      }

      setState(() {
        _selectedImage = selected;
        _selectedVideo = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image pick failed: $error')),
      );
    }
  }

  Future<void> _pickVideo() async {
    try {
      final selected = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 60),
      );

      if (selected == null || !mounted) {
        return;
      }

      setState(() {
        _selectedVideo = selected;
        _selectedImage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Video pick failed: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF111111),
      title: const Text('Create Post'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                controller: _contentController,
                minLines: 4,
                maxLines: 8,
                maxLength: 4000,
                decoration: const InputDecoration(
                  hintText: 'Say what you want to say...',
                ),
                validator: (String? value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty &&
                      _selectedImage == null &&
                      _selectedVideo == null) {
                    return 'Add text, image, or video.';
                  }
                  return null;
                },
              ),
              if (_selectedImage != null) ...<Widget>[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 170,
                    child: Image.file(
                      File(_selectedImage!.path),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ],
              if (_selectedVideo != null) ...<Widget>[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161616),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x33FFFFFF)),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.videocam_outlined,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _selectedVideo!.name,
                          style: const TextStyle(color: Colors.white70),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Videos are compressed before upload (target <10 MB).',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(
                      _selectedImage == null ? 'Add Image' : 'Change Image',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pickVideo,
                    icon: const Icon(Icons.video_library_outlined),
                    label: Text(
                      _selectedVideo == null ? 'Add Video' : 'Change Video',
                    ),
                  ),
                  if (_selectedImage != null || _selectedVideo != null)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedImage = null;
                          _selectedVideo = null;
                        });
                      },
                      child: const Text('Remove Media'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: _ttlHours,
                decoration: const InputDecoration(labelText: 'Expires in'),
                items: const <DropdownMenuItem<int>>[
                  DropdownMenuItem<int>(
                    value: 24,
                    child: Text('24 hours'),
                  ),
                  DropdownMenuItem<int>(
                    value: 48,
                    child: Text('48 hours'),
                  ),
                ],
                onChanged: (int? value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _ttlHours = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Post'),
        ),
      ],
    );
  }
}
