import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/community.dart';

class CommunityApiException implements Exception {
  const CommunityApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CommunityEdgeFunctions {
  const CommunityEdgeFunctions(this._client);

  final SupabaseClient _client;

  Future<Community> createCommunity({
    required String name,
    String? description,
    String category = 'other',
    bool isPrivate = false,
    String? templateId,
  }) async {
    final response = await _client.functions.invoke(
      'create-community',
      body: <String, dynamic>{
        'name': name,
        'description': description,
        'category': category,
        'isPrivate': isPrivate,
        'templateId': templateId,
      },
    );

    if (response.status >= 400) {
      throw CommunityApiException(
        _extractErrorMessage(response.data, 'Failed to create community.'),
      );
    }

    final data = response.data;
    if (data is! Map<String, dynamic> || data['community'] == null) {
      throw const CommunityApiException('Invalid create-community response.');
    }

    return Community.fromMap(Map<String, dynamic>.from(data['community']));
  }

  Future<List<SponsoredCommunityTemplate>> listSponsoredCommunityTemplates({
    String? category,
    int limit = 20,
  }) async {
    final response = await _client.functions.invoke(
      'list-sponsored-community-templates',
      body: <String, dynamic>{
        'category': category,
        'limit': limit,
      },
    );

    if (response.status >= 400) {
      throw CommunityApiException(
        _extractErrorMessage(
          response.data,
          'Failed to load sponsored community templates.',
        ),
      );
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const CommunityApiException(
        'Invalid list-sponsored-community-templates response.',
      );
    }

    final templates = data['templates'];
    if (templates is! List<dynamic>) {
      throw const CommunityApiException('Invalid sponsored templates payload.');
    }

    return templates
        .map((dynamic item) => Map<String, dynamic>.from(item as Map))
        .map(SponsoredCommunityTemplate.fromMap)
        .toList(growable: false);
  }

  Future<Community> joinCommunity({
    required String joinCode,
  }) async {
    final response = await _client.functions.invoke(
      'join-community',
      body: <String, dynamic>{
        'joinCode': joinCode,
      },
    );

    if (response.status >= 400) {
      throw CommunityApiException(
        _extractErrorMessage(response.data, 'Failed to join community.'),
      );
    }

    final data = response.data;
    if (data is! Map<String, dynamic> || data['community'] == null) {
      throw const CommunityApiException('Invalid join-community response.');
    }

    return Community.fromMap(Map<String, dynamic>.from(data['community']));
  }
}

final communityEdgeFunctionsProvider = Provider<CommunityEdgeFunctions?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return null;
  }
  return CommunityEdgeFunctions(client);
});

final joinCommunityByCodeProvider =
    FutureProvider.family<Community, String>((ref, String joinCode) async {
  final api = ref.watch(communityEdgeFunctionsProvider);
  if (api == null) {
    throw const CommunityApiException('Supabase is not configured.');
  }

  return api.joinCommunity(joinCode: joinCode);
});

String _extractErrorMessage(dynamic data, String fallback) {
  if (data is Map<String, dynamic>) {
    final error = data['error'];
    if (error is Map<String, dynamic>) {
      final message = error['message'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
    }
  }

  return fallback;
}
