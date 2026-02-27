import 'package:flutter/material.dart';

class CreatePrivateChatLinkDialogResult {
  const CreatePrivateChatLinkDialogResult({
    required this.readOnce,
    required this.ttlMinutes,
  });

  final bool readOnce;
  final int ttlMinutes;
}

class CreatePrivateChatLinkDialog extends StatefulWidget {
  const CreatePrivateChatLinkDialog({super.key});

  @override
  State<CreatePrivateChatLinkDialog> createState() =>
      _CreatePrivateChatLinkDialogState();
}

class _CreatePrivateChatLinkDialogState
    extends State<CreatePrivateChatLinkDialog> {
  bool _readOnce = false;
  int _ttlMinutes = 60;

  void _submit() {
    Navigator.of(context).pop(
      CreatePrivateChatLinkDialogResult(
        readOnce: _readOnce,
        ttlMinutes: _ttlMinutes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF111111),
      title: const Text('Create Private Link'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          DropdownButtonFormField<int>(
            initialValue: _ttlMinutes,
            decoration: const InputDecoration(labelText: 'Expires in'),
            items: const <DropdownMenuItem<int>>[
              DropdownMenuItem<int>(
                value: 15,
                child: Text('15 minutes'),
              ),
              DropdownMenuItem<int>(
                value: 30,
                child: Text('30 minutes'),
              ),
              DropdownMenuItem<int>(
                value: 60,
                child: Text('60 minutes'),
              ),
            ],
            onChanged: (int? value) {
              if (value == null) {
                return;
              }
              setState(() {
                _ttlMinutes = value;
              });
            },
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            value: _readOnce,
            onChanged: (bool value) {
              setState(() {
                _readOnce = value;
              });
            },
            contentPadding: EdgeInsets.zero,
            title: const Text('Read-once mode'),
            subtitle: const Text(
              'Each message disappears after first read.',
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Create'),
        ),
      ],
    );
  }
}
