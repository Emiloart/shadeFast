class TrendingPoll {
  const TrendingPoll({
    required this.id,
    required this.question,
    required this.options,
    required this.counts,
    required this.totalVotes,
    required this.trendScore,
    required this.createdAt,
    required this.expiresAt,
    this.selectedOptionIndex,
    this.postId,
    this.postContent,
    this.communityId,
    this.likeCount = 0,
  });

  final String id;
  final String question;
  final List<String> options;
  final List<int> counts;
  final int totalVotes;
  final int trendScore;
  final int? selectedOptionIndex;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? postId;
  final String? postContent;
  final String? communityId;
  final int likeCount;

  factory TrendingPoll.fromMap(Map<String, dynamic> map) {
    final post = map['post'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(map['post'] as Map)
        : <String, dynamic>{};

    return TrendingPoll(
      id: map['id'] as String,
      question: map['question'] as String? ?? '',
      options: _asStringList(map['options']),
      counts: _asIntList(map['counts']),
      totalVotes: _asInt(map['totalVotes']),
      trendScore: _asInt(map['trendScore']),
      selectedOptionIndex: map['selectedOptionIndex'] is int
          ? map['selectedOptionIndex'] as int
          : null,
      createdAt: DateTime.parse(map['createdAt'] as String),
      expiresAt: DateTime.parse(post['expiresAt'] as String),
      postId: post['id'] as String?,
      postContent: post['content'] as String?,
      communityId: post['communityId'] as String?,
      likeCount: _asInt(post['likeCount']),
    );
  }
}

class PollVoteResult {
  const PollVoteResult({
    required this.pollId,
    required this.selectedOptionIndex,
    required this.totalVotes,
    required this.counts,
  });

  final String pollId;
  final int selectedOptionIndex;
  final int totalVotes;
  final List<int> counts;

  factory PollVoteResult.fromMap(Map<String, dynamic> map) {
    return PollVoteResult(
      pollId: map['pollId'] as String,
      selectedOptionIndex: _asInt(map['selectedOptionIndex']),
      totalVotes: _asInt(map['totalVotes']),
      counts: _asIntList(map['counts']),
    );
  }
}

class CreatePollInput {
  const CreatePollInput({
    required this.question,
    required this.options,
    this.content,
    this.communityId,
    this.ttlHours = 24,
    this.challengeId,
  });

  final String question;
  final List<String> options;
  final String? content;
  final String? communityId;
  final int ttlHours;
  final String? challengeId;
}

class TrendingChallenge {
  const TrendingChallenge({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.expiresAt,
    required this.entryCount,
    required this.recentEntryCount,
    required this.participantCount,
    required this.trendScore,
    this.description,
  });

  final String id;
  final String title;
  final String? description;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int entryCount;
  final int recentEntryCount;
  final int participantCount;
  final int trendScore;

  factory TrendingChallenge.fromMap(Map<String, dynamic> map) {
    return TrendingChallenge(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      description: map['description'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      expiresAt: DateTime.parse(map['expiresAt'] as String),
      entryCount: _asInt(map['entryCount']),
      recentEntryCount: _asInt(map['recentEntryCount']),
      participantCount: _asInt(map['participantCount']),
      trendScore: _asInt(map['trendScore']),
    );
  }
}

class CreateChallengeInput {
  const CreateChallengeInput({
    required this.title,
    this.description,
    this.durationDays = 7,
  });

  final String title;
  final String? description;
  final int durationDays;
}

class ChallengeEntryPost {
  const ChallengeEntryPost({
    required this.id,
    required this.createdAt,
    required this.expiresAt,
    this.content,
    this.communityId,
  });

  final String id;
  final String? content;
  final String? communityId;
  final DateTime createdAt;
  final DateTime expiresAt;

  factory ChallengeEntryPost.fromMap(Map<String, dynamic> map) {
    return ChallengeEntryPost(
      id: map['id'] as String,
      content: map['content'] as String?,
      communityId: map['community_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      expiresAt: DateTime.parse(map['expires_at'] as String),
    );
  }
}

List<String> _asStringList(dynamic value) {
  if (value is! List<dynamic>) {
    return const <String>[];
  }

  return value
      .map((dynamic item) => item is String ? item.trim() : '')
      .where((String item) => item.isNotEmpty)
      .toList(growable: false);
}

List<int> _asIntList(dynamic value) {
  if (value is! List<dynamic>) {
    return const <int>[];
  }

  return value.map((dynamic item) => _asInt(item)).toList(growable: false);
}

int _asInt(dynamic value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  if (value is String) {
    return int.tryParse(value) ?? 0;
  }

  return 0;
}
