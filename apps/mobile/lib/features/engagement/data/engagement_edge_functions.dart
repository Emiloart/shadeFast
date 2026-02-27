import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/engagement_models.dart';

class EngagementApiException implements Exception {
  const EngagementApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class EngagementEdgeFunctions {
  const EngagementEdgeFunctions(this._client);

  final SupabaseClient _client;

  Future<List<TrendingPoll>> listTrendingPolls({
    int limit = 20,
    String? communityId,
  }) async {
    final response = await _client.functions.invoke(
      'list-trending-polls',
      body: <String, dynamic>{
        'limit': limit,
        'communityId': communityId,
      },
    );

    if (response.status >= 400) {
      throw EngagementApiException(
        _extractErrorMessage(response.data, 'Failed to load trending polls.'),
      );
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const EngagementApiException(
          'Invalid list-trending-polls response.');
    }

    final polls = data['polls'];
    if (polls is! List<dynamic>) {
      throw const EngagementApiException('Invalid polls payload.');
    }

    return polls
        .map((dynamic item) => Map<String, dynamic>.from(item as Map))
        .map(TrendingPoll.fromMap)
        .toList(growable: false);
  }

  Future<String> createPoll(CreatePollInput input) async {
    final response = await _client.functions.invoke(
      'create-poll',
      body: <String, dynamic>{
        'communityId': input.communityId,
        'content': input.content,
        'question': input.question,
        'options': input.options,
        'ttlHours': input.ttlHours,
        'challengeId': input.challengeId,
      },
    );

    if (response.status >= 400) {
      throw EngagementApiException(
        _extractErrorMessage(response.data, 'Failed to create poll.'),
      );
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const EngagementApiException('Invalid create-poll response.');
    }

    final poll = data['poll'];
    if (poll is! Map<String, dynamic>) {
      throw const EngagementApiException('Invalid create-poll payload.');
    }

    final pollId = poll['id'];
    if (pollId is! String || pollId.isEmpty) {
      throw const EngagementApiException('Missing poll id in response.');
    }

    return pollId;
  }

  Future<PollVoteResult> votePoll({
    required String pollId,
    required int optionIndex,
  }) async {
    final response = await _client.functions.invoke(
      'vote-poll',
      body: <String, dynamic>{
        'pollId': pollId,
        'optionIndex': optionIndex,
      },
    );

    if (response.status >= 400) {
      throw EngagementApiException(
        _extractErrorMessage(response.data, 'Failed to submit vote.'),
      );
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const EngagementApiException('Invalid vote-poll response.');
    }

    return PollVoteResult.fromMap(data);
  }

  Future<List<TrendingChallenge>> listTrendingChallenges({
    int limit = 20,
  }) async {
    final response = await _client.functions.invoke(
      'list-trending-challenges',
      body: <String, dynamic>{
        'limit': limit,
      },
    );

    if (response.status >= 400) {
      throw EngagementApiException(
        _extractErrorMessage(
          response.data,
          'Failed to load trending challenges.',
        ),
      );
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const EngagementApiException(
          'Invalid list-trending-challenges response.');
    }

    final challenges = data['challenges'];
    if (challenges is! List<dynamic>) {
      throw const EngagementApiException('Invalid challenges payload.');
    }

    return challenges
        .map((dynamic item) => Map<String, dynamic>.from(item as Map))
        .map(TrendingChallenge.fromMap)
        .toList(growable: false);
  }

  Future<TrendingChallenge> createChallenge(CreateChallengeInput input) async {
    final response = await _client.functions.invoke(
      'create-challenge',
      body: <String, dynamic>{
        'title': input.title,
        'description': input.description,
        'durationDays': input.durationDays,
      },
    );

    if (response.status >= 400) {
      throw EngagementApiException(
        _extractErrorMessage(response.data, 'Failed to create challenge.'),
      );
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const EngagementApiException('Invalid create-challenge response.');
    }

    final challenge = data['challenge'];
    if (challenge is! Map<String, dynamic>) {
      throw const EngagementApiException('Invalid create-challenge payload.');
    }

    return TrendingChallenge(
      id: challenge['id'] as String,
      title: challenge['title'] as String? ?? '',
      description: challenge['description'] as String?,
      createdAt: DateTime.parse(challenge['created_at'] as String),
      expiresAt: DateTime.parse(challenge['expires_at'] as String),
      entryCount: 0,
      recentEntryCount: 0,
      participantCount: 0,
      trendScore: 0,
    );
  }

  Future<List<ChallengeEntryPost>> listMyActivePosts({int limit = 40}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw const EngagementApiException('Anonymous session is not ready.');
    }

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final rows = await _client
        .from('posts')
        .select('id, content, community_id, created_at, expires_at')
        .eq('user_uuid', userId)
        .gt('expires_at', nowIso)
        .order('created_at', ascending: false)
        .limit(limit);

    return (rows as List<dynamic>)
        .map((dynamic item) => Map<String, dynamic>.from(item as Map))
        .map(ChallengeEntryPost.fromMap)
        .toList(growable: false);
  }

  Future<void> submitChallengeEntry({
    required String challengeId,
    required String postId,
  }) async {
    final response = await _client.functions.invoke(
      'submit-challenge-entry',
      body: <String, dynamic>{
        'challengeId': challengeId,
        'postId': postId,
      },
    );

    if (response.status >= 400) {
      throw EngagementApiException(
        _extractErrorMessage(
            response.data, 'Failed to submit challenge entry.'),
      );
    }
  }
}

final engagementEdgeFunctionsProvider =
    Provider<EngagementEdgeFunctions?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return null;
  }

  return EngagementEdgeFunctions(client);
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
