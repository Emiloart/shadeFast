import 'package:flutter/material.dart';

import '../domain/moderation_models.dart';

class ReportPostDialog extends StatefulWidget {
  const ReportPostDialog({super.key});

  @override
  State<ReportPostDialog> createState() => _ReportPostDialogState();
}

class _ReportPostDialogState extends State<ReportPostDialog> {
  final _formKey = GlobalKey<FormState>();
  final _detailsController = TextEditingController();

  static const _reasons = <String>[
    'spam',
    'harassment',
    'hate',
    'violence',
    'sexual',
    'self_harm',
    'misinformation',
    'other',
  ];

  String _reason = _reasons.first;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final details = _detailsController.text.trim();
    Navigator.of(context).pop(
      ReportContentInput(
        reason: _reason,
        details: details.isEmpty ? null : details,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF111111),
      title: const Text('Report Post'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DropdownButtonFormField<String>(
                initialValue: _reason,
                decoration: const InputDecoration(labelText: 'Reason'),
                items: _reasons
                    .map(
                      (String reason) => DropdownMenuItem<String>(
                        value: reason,
                        child: Text(reason),
                      ),
                    )
                    .toList(),
                onChanged: (String? value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _reason = value;
                  });
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _detailsController,
                maxLength: 1000,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Details (optional)',
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
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
