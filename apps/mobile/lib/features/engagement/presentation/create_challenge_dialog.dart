import 'package:flutter/material.dart';

class CreateChallengeDialogResult {
  const CreateChallengeDialogResult({
    required this.title,
    this.description,
    required this.durationDays,
  });

  final String title;
  final String? description;
  final int durationDays;
}

class CreateChallengeDialog extends StatefulWidget {
  const CreateChallengeDialog({super.key});

  @override
  State<CreateChallengeDialog> createState() => _CreateChallengeDialogState();
}

class _CreateChallengeDialogState extends State<CreateChallengeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  int _durationDays = 7;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF111111),
      title: const Text('Create Challenge'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                controller: _titleController,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'Post your worst boss story',
                ),
                validator: (String? value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.length < 3) {
                    return 'Title must be at least 3 characters.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLength: 1000,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: _durationDays,
                decoration: const InputDecoration(labelText: 'Duration'),
                items: const <DropdownMenuItem<int>>[
                  DropdownMenuItem(value: 1, child: Text('1 day')),
                  DropdownMenuItem(value: 3, child: Text('3 days')),
                  DropdownMenuItem(value: 7, child: Text('7 days')),
                  DropdownMenuItem(value: 14, child: Text('14 days')),
                ],
                onChanged: (int? value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _durationDays = value;
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
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) {
              return;
            }

            Navigator.of(context).pop(
              CreateChallengeDialogResult(
                title: _titleController.text.trim(),
                description: _descriptionController.text.trim().isEmpty
                    ? null
                    : _descriptionController.text.trim(),
                durationDays: _durationDays,
              ),
            );
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
