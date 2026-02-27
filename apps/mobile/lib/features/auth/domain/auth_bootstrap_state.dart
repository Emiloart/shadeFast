enum AuthBootstrapStatus {
  ready,
  missingConfig,
  error,
}

class AuthBootstrapState {
  const AuthBootstrapState._({
    required this.status,
    this.userId,
    this.message,
  });

  final AuthBootstrapStatus status;
  final String? userId;
  final String? message;

  factory AuthBootstrapState.ready(String userId) {
    return AuthBootstrapState._(
      status: AuthBootstrapStatus.ready,
      userId: userId,
    );
  }

  const AuthBootstrapState.missingConfig()
      : this._(
          status: AuthBootstrapStatus.missingConfig,
          message:
              'Supabase env variables are missing. Set --dart-define values to enable live backend features.',
        );

  const AuthBootstrapState.error(String message)
      : this._(
          status: AuthBootstrapStatus.error,
          message: message,
        );

  bool get isReady => status == AuthBootstrapStatus.ready;
}
