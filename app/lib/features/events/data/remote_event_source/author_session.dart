class AuthorLoginSession {
  AuthorLoginSession({
    required this.accessToken,
    required this.refreshToken,
    required this.accessExpiresAt,
    required this.refreshExpiresAt,
    required this.authorId,
    required this.username,
    required this.isAdmin,
    required this.requiresPasswordChange,
    this.layerGrantIds = const <int>[],
    this.topicGrantIds = const <int>[],
  });

  final String accessToken;
  final String refreshToken;
  final String accessExpiresAt;
  final String refreshExpiresAt;
  final int authorId;
  final String username;
  final bool isAdmin;
  final bool requiresPasswordChange;
  final List<int> layerGrantIds;
  final List<int> topicGrantIds;
}

class AuthorSessionState {
  AuthorSessionState({
    required this.requiresPasswordChange,
    required this.isAdmin,
    this.layerGrantIds = const <int>[],
    this.topicGrantIds = const <int>[],
  });

  final bool requiresPasswordChange;
  final bool isAdmin;
  final List<int> layerGrantIds;
  final List<int> topicGrantIds;
}
