import 'package:flutter/material.dart';

class JoinCommunityDialog extends StatefulWidget {
  const JoinCommunityDialog({super.key});

  @override
  State<JoinCommunityDialog> createState() => _JoinCommunityDialogState();
}

class _JoinCommunityDialogState extends State<JoinCommunityDialog> {
  final _formKey = GlobalKey<FormState>();
  final _joinCodeController = TextEditingController();

  @override
  void dispose() {
    _joinCodeController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(_joinCodeController.text.trim().toUpperCase());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF111111),
      title: const Text('Join Community'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _joinCodeController,
          maxLength: 8,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Join code',
            hintText: '8-character code',
          ),
          validator: (String? value) {
            final text = value?.trim() ?? '';
            if (text.length != 8) {
              return 'Join code must be exactly 8 characters.';
            }
            return null;
          },
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Join'),
        ),
      ],
    );
  }
}
