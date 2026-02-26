import 'dart:convert';

enum PeerStatus { discovered, connecting, connected, disconnected }

class Peer {
  final String nyxChatId;
  final String displayName;
  final String publicKeyHex;
  final String kyberPublicKeyHex;
  final String ipAddress;
  final int port;
  final PeerStatus status;
  final DateTime lastSeen;
  final DateTime? firstSeen;
  final String transport; // 'wifi' or 'ble'

  Peer({
    required this.nyxChatId,
    required this.displayName,
    required this.publicKeyHex,
    this.kyberPublicKeyHex = '',
    required this.ipAddress,
    required this.port,
    this.status = PeerStatus.discovered,
    required this.lastSeen,
    this.firstSeen,
    this.transport = 'wifi',
  });

  Peer copyWith({
    String? nyxChatId,
    String? displayName,
    String? publicKeyHex,
    String? kyberPublicKeyHex,
    String? ipAddress,
    int? port,
    PeerStatus? status,
    DateTime? lastSeen,
    DateTime? firstSeen,
    String? transport,
  }) {
    return Peer(
      nyxChatId: nyxChatId ?? this.nyxChatId,
      displayName: displayName ?? this.displayName,
      publicKeyHex: publicKeyHex ?? this.publicKeyHex,
      kyberPublicKeyHex: kyberPublicKeyHex ?? this.kyberPublicKeyHex,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      status: status ?? this.status,
      lastSeen: lastSeen ?? this.lastSeen,
      firstSeen: firstSeen ?? this.firstSeen,
      transport: transport ?? this.transport,
    );
  }

  bool get isOnline =>
      status == PeerStatus.connected ||
      DateTime.now().difference(lastSeen).inMinutes < 2;

  Map<String, dynamic> toJson() => {
    'nyxChatId': nyxChatId,
    'displayName': displayName,
    'publicKeyHex': publicKeyHex,
    'kyberPublicKeyHex': kyberPublicKeyHex,
    'ipAddress': ipAddress,
    'port': port,
    'status': status.name,
    'lastSeen': lastSeen.toIso8601String(),
    'firstSeen': firstSeen?.toIso8601String(),
    'transport': transport,
  };

  factory Peer.fromJson(Map<String, dynamic> json) => Peer(
    nyxChatId: json['nyxChatId'] as String,
    displayName: json['displayName'] as String,
    publicKeyHex: json['publicKeyHex'] as String,
    kyberPublicKeyHex: (json['kyberPublicKeyHex'] as String?) ?? '',
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
    transport: (json['transport'] as String?) ?? 'wifi',
  );

  String encode() => jsonEncode(toJson());

  factory Peer.decode(String data) =>
      Peer.fromJson(jsonDecode(data) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Peer &&
          runtimeType == other.runtimeType &&
          nyxChatId == other.nyxChatId;

  @override
  int get hashCode => nyxChatId.hashCode;
}
