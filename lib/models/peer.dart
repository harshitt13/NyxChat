import 'dart:convert';

enum PeerStatus { discovered, connecting, connected, disconnected }

class Peer {
  final String bitChatId;
  final String displayName;
  final String publicKeyHex;
  final String ipAddress;
  final int port;
  final PeerStatus status;
  final DateTime lastSeen;
  final DateTime? firstSeen;

  Peer({
    required this.bitChatId,
    required this.displayName,
    required this.publicKeyHex,
    required this.ipAddress,
    required this.port,
    this.status = PeerStatus.discovered,
    required this.lastSeen,
    this.firstSeen,
  });

  Peer copyWith({
    String? bitChatId,
    String? displayName,
    String? publicKeyHex,
    String? ipAddress,
    int? port,
    PeerStatus? status,
    DateTime? lastSeen,
    DateTime? firstSeen,
  }) {
    return Peer(
      bitChatId: bitChatId ?? this.bitChatId,
      displayName: displayName ?? this.displayName,
      publicKeyHex: publicKeyHex ?? this.publicKeyHex,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      status: status ?? this.status,
      lastSeen: lastSeen ?? this.lastSeen,
      firstSeen: firstSeen ?? this.firstSeen,
    );
  }

  bool get isOnline =>
      status == PeerStatus.connected ||
      DateTime.now().difference(lastSeen).inMinutes < 2;

  Map<String, dynamic> toJson() => {
    'bitChatId': bitChatId,
    'displayName': displayName,
    'publicKeyHex': publicKeyHex,
    'ipAddress': ipAddress,
    'port': port,
    'status': status.name,
    'lastSeen': lastSeen.toIso8601String(),
    'firstSeen': firstSeen?.toIso8601String(),
  };

  factory Peer.fromJson(Map<String, dynamic> json) => Peer(
    bitChatId: json['bitChatId'] as String,
    displayName: json['displayName'] as String,
    publicKeyHex: json['publicKeyHex'] as String,
    ipAddress: json['ipAddress'] as String,
    port: json['port'] as int,
    status: PeerStatus.values.firstWhere(
      (e) => e.name == json['status'],
      orElse: () => PeerStatus.discovered,
    ),
    lastSeen: DateTime.parse(json['lastSeen'] as String),
    firstSeen: json['firstSeen'] != null
        ? DateTime.parse(json['firstSeen'] as String)
        : null,
  );

  String encode() => jsonEncode(toJson());

  factory Peer.decode(String data) =>
      Peer.fromJson(jsonDecode(data) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Peer &&
          runtimeType == other.runtimeType &&
          bitChatId == other.bitChatId;

  @override
  int get hashCode => bitChatId.hashCode;
}
