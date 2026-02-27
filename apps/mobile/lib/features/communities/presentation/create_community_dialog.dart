import 'package:flutter/material.dart';

import '../domain/community.dart';

class CreateCommunityDialogResult {
  const CreateCommunityDialogResult({
    required this.name,
    required this.category,
    required this.isPrivate,
    this.templateId,
    this.description,
  });

  final String name;
  final String? description;
  final String category;
  final bool isPrivate;
  final String? templateId;
}

class CreateCommunityDialog extends StatefulWidget {
  const CreateCommunityDialog({
    this.templates = const <SponsoredCommunityTemplate>[],
    super.key,
  });

  final List<SponsoredCommunityTemplate> templates;

  @override
  State<CreateCommunityDialog> createState() => _CreateCommunityDialogState();
}

class _CreateCommunityDialogState extends State<CreateCommunityDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  static const _categories = <String>[
    'school',
    'workplace',
    'faith',
    'neighborhood',
    'other',
  ];

  String _category = _categories.last;
  bool _isPrivate = false;
  String? _selectedTemplateId;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final result = CreateCommunityDialogResult(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      category: _category,
      isPrivate: _isPrivate,
      templateId: _selectedTemplateId,
    );

    Navigator.of(context).pop(result);
  }

  SponsoredCommunityTemplate? _selectedTemplate() {
    final templateId = _selectedTemplateId;
    if (templateId == null || templateId.isEmpty) {
      return null;
    }

    for (final template in widget.templates) {
      if (template.id == templateId) {
        return template;
      }
    }

    return null;
  }

  void _applyTemplate(SponsoredCommunityTemplate template) {
    _nameController.text = template.defaultTitle;
    _descriptionController.text = template.defaultDescription ?? '';
    _category = template.category;
    _isPrivate = template.defaultIsPrivate;
  }

  @override
  Widget build(BuildContext context) {
    final selectedTemplate = _selectedTemplate();

    return AlertDialog(
      backgroundColor: const Color(0xFF111111),
      title: const Text('Create Community'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (widget.templates.isNotEmpty) ...<Widget>[
                DropdownButtonFormField<String?>(
                  initialValue: _selectedTemplateId,
                  decoration: const InputDecoration(
                    labelText: 'Starter template',
                  ),
                  items: <DropdownMenuItem<String?>>[
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Custom community'),
                    ),
                    ...widget.templates.map(
                      (SponsoredCommunityTemplate template) =>
                          DropdownMenuItem<String?>(
                        value: template.id,
                        child: Text(template.displayName),
                      ),
                    ),
                  ],
                  onChanged: (String? value) {
                    setState(() {
                      _selectedTemplateId = value;
                      final template = _selectedTemplate();
                      if (template != null) {
                        _applyTemplate(template);
                      }
                    });
                  },
                ),
                if (selectedTemplate != null) ...<Widget>[
                  const SizedBox(height: 8),
                  _TemplateInfoCard(template: selectedTemplate),
                ],
                const SizedBox(height: 8),
              ],
              TextFormField(
                controller: _nameController,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g. Midtown High Tea',
                ),
                validator: (String? value) {
                  final text = value?.trim() ?? '';
                  if (text.length < 2) {
                    return 'Name must be at least 2 characters.';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _descriptionController,
                maxLength: 300,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                ),
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _category,
                items: _categories
                    .map(
                      (String category) => DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),
                decoration: const InputDecoration(labelText: 'Category'),
                onChanged: (String? value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _category = value;
                  });
                },
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                value: _isPrivate,
                onChanged: (bool value) {
                  setState(() {
                    _isPrivate = value;
                  });
                },
                contentPadding: EdgeInsets.zero,
                title: const Text('Private community'),
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
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _TemplateInfoCard extends StatelessWidget {
  const _TemplateInfoCard({
    required this.template,
  });

  final SponsoredCommunityTemplate template;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (template.description != null && template.description!.isNotEmpty)
            Text(
              template.description!,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          if (template.rules.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            ...template.rules.take(3).map(
                  (String rule) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '- $rule',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}
