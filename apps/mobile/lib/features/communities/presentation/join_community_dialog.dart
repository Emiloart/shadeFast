import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
            TextInputFormatter.withFunction(
              (TextEditingValue oldValue, TextEditingValue newValue) {
                return newValue.copyWith(
                  text: newValue.text.toUpperCase(),
                  selection: newValue.selection,
                );
              },
            ),
          ],
          decoration: const InputDecoration(
            labelText: 'Join code',
            hintText: '8-character code',
          ),
          validator: (String? value) {
            final text = value?.trim() ?? '';
            if (!RegExp(r'^[A-Z0-9]{8}$').hasMatch(text)) {
              return 'Use 8 letters/numbers only.';
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
