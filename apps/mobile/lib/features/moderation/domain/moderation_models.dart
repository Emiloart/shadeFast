class ReportContentInput {
  const ReportContentInput({
    required this.reason,
    this.details,
  });

  final String reason;
  final String? details;
}

class BlockUserResult {
  const BlockUserResult({
    required this.blockedUserId,
    required this.isBlocked,
  });

  final String blockedUserId;
  final bool isBlocked;
}
