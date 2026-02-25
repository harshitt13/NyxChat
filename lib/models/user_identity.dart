import 'dart:convert';

class UserIdentity {
  final String nyxChatId;
  final String displayName;
  final String publicKeyHex;
  final String signingPublicKeyHex;
  final DateTime createdAt;

  UserIdentity({
    required this.nyxChatId,
    required this.displayName,
    required this.publicKeyHex,
    required this.signingPublicKeyHex,
    required this.createdAt,
  });

  /// Generate a short NyxChat ID from the public key
  static String generateNyxChatId(String publicKeyHex) {
    final prefix = publicKeyHex.substring(0, 4).toUpperCase();
    final suffix = publicKeyHex
        .substring(publicKeyHex.length - 4)
        .toUpperCase();
    return 'NC-$prefix...$suffix';
  }

  /// Generate an avatar color from the public key
  int get avatarColorIndex {
    int hash = 0;
    for (int i = 0; i < publicKeyHex.length; i++) {
      hash = publicKeyHex.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return hash.abs() % 8;
  }

  /// Get initials for avatar
  String get initials {
    if (displayName.isEmpty) return '??';
    final parts = displayName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return displayName.substring(0, displayName.length >= 2 ? 2 : 1).toUpperCase();
  }

  UserIdentity copyWith({
    String? nyxChatId,
    String? displayName,
    String? publicKeyHex,
    String? signingPublicKeyHex,
    DateTime? createdAt,
  }) {
    return UserIdentity(
      nyxChatId: nyxChatId ?? this.nyxChatId,
      displayName: displayName ?? this.displayName,
      publicKeyHex: publicKeyHex ?? this.publicKeyHex,
      signingPublicKeyHex: signingPublicKeyHex ?? this.signingPublicKeyHex,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'nyxChatId': nyxChatId,
    'displayName': displayName,
    'publicKeyHex': publicKeyHex,
    'signingPublicKeyHex': signingPublicKeyHex,
    'createdAt': createdAt.toIso8601String(),
  };

  factory UserIdentity.fromJson(Map<String, dynamic> json) => UserIdentity(
    nyxChatId: json['nyxChatId'] as String,
    displayName: json['displayName'] as String,
    publicKeyHex: json['publicKeyHex'] as String,
    signingPublicKeyHex: json['signingPublicKeyHex'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  String encode() => jsonEncode(toJson());

  factory UserIdentity.decode(String data) =>
      UserIdentity.fromJson(jsonDecode(data) as Map<String, dynamic>);

  @override
  String toString() => 'UserIdentity($nyxChatId, $displayName)';
}
