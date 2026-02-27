import 'package:flutter/material.dart';

class CreatePollDialogResult {
  const CreatePollDialogResult({
    required this.question,
    required this.options,
    this.content,
  });

  final String question;
  final List<String> options;
  final String? content;
}

class CreatePollDialog extends StatefulWidget {
  const CreatePollDialog({super.key});

  @override
  State<CreatePollDialog> createState() => _CreatePollDialogState();
}

class _CreatePollDialogState extends State<CreatePollDialog> {
  final _formKey = GlobalKey<FormState>();
  final _questionController = TextEditingController();
  final _contentController = TextEditingController();
  final _optionControllers = List<TextEditingController>.generate(
    4,
    (_) => TextEditingController(),
  );

  @override
  void dispose() {
    _questionController.dispose();
    _contentController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF111111),
      title: const Text('Create Poll'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                controller: _questionController,
                maxLength: 280,
                decoration: const InputDecoration(
                  labelText: 'Question',
                  hintText: 'What is your hot take?',
                ),
                validator: (String? value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.length < 3) {
                    return 'Question must be at least 3 characters.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _contentController,
                maxLength: 4000,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Context (optional)',
                ),
              ),
              const SizedBox(height: 8),
              for (var index = 0; index < _optionControllers.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextFormField(
                    controller: _optionControllers[index],
                    maxLength: 80,
                    decoration: InputDecoration(
                      labelText: 'Option ${index + 1}',
                    ),
                    validator: (String? value) {
                      if (index < 2) {
                        final trimmed = value?.trim() ?? '';
                        if (trimmed.isEmpty) {
                          return 'At least two options are required.';
                        }
                      }

                      return null;
                    },
                  ),
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

            final options = _optionControllers
                .map((controller) => controller.text.trim())
                .where((option) => option.isNotEmpty)
                .toList(growable: false);

            if (options.length < 2) {
              return;
            }

            Navigator.of(context).pop(
              CreatePollDialogResult(
                question: _questionController.text.trim(),
                options: options,
                content: _contentController.text.trim().isEmpty
                    ? null
                    : _contentController.text.trim(),
              ),
            );
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
