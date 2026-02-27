class Community {
  const Community({
    required this.id,
    required this.name,
    required this.joinCode,
    required this.category,
    required this.isPrivate,
    required this.createdAt,
    this.description,
  });

  final String id;
  final String name;
  final String joinCode;
  final String category;
  final bool isPrivate;
  final String createdAt;
  final String? description;

  factory Community.fromMap(Map<String, dynamic> map) {
    return Community(
      id: map['id'] as String,
      name: map['name'] as String,
      joinCode: map['join_code'] as String,
      category: map['category'] as String,
      isPrivate: map['is_private'] as bool,
      createdAt: map['created_at'] as String,
      description: map['description'] as String?,
    );
  }
}

class SponsoredCommunityTemplate {
  const SponsoredCommunityTemplate({
    required this.id,
    required this.displayName,
    required this.category,
    required this.defaultTitle,
    required this.defaultIsPrivate,
    required this.rules,
    this.description,
    this.defaultDescription,
  });

  final String id;
  final String displayName;
  final String category;
  final String defaultTitle;
  final String? defaultDescription;
  final bool defaultIsPrivate;
  final String? description;
  final List<String> rules;

  factory SponsoredCommunityTemplate.fromMap(Map<String, dynamic> map) {
    return SponsoredCommunityTemplate(
      id: map['id'] as String,
      displayName: map['displayName'] as String? ?? '',
      category: map['category'] as String? ?? 'other',
      defaultTitle: map['defaultTitle'] as String? ?? '',
      defaultDescription: map['defaultDescription'] as String?,
      defaultIsPrivate: map['defaultIsPrivate'] as bool? ?? false,
      description: map['description'] as String?,
      rules: (map['rules'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<String>()
          .toList(growable: false),
    );
  }
}
