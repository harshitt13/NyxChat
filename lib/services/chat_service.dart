import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:convert/convert.dart' as convert;
import '../core/crypto/encryption_engine.dart';
import '../core/crypto/key_manager.dart';
import '../core/crypto/session_key_manager.dart';
import '../core/crypto/hybrid_key_exchange.dart';
import '../core/network/message_protocol.dart';
import '../core/network/p2p_client.dart';
import '../core/network/p2p_server.dart';
import '../core/network/file_transfer_manager.dart';
import '../core/storage/local_storage.dart';
import '../models/message.dart';
import '../models/chat_room.dart';

/// Manages chat messaging: sending, receiving, encrypting, and persisting.
/// Now supports group chats, reactions, file sharing, and forward secrecy.
class ChatService extends ChangeNotifier {
  final LocalStorage _storage;
  final P2PClient _client;
  final P2PServer _server;
  final KeyManager _keyManager;
  final EncryptionEngine _encryptionEngine = EncryptionEngine();
  final SessionKeyManager _sessionKeyManager = SessionKeyManager();
  final FileTransferManager _fileTransferManager = FileTransferManager();
  final HybridKeyExchange _hybridKex = HybridKeyExchange();
  final Uuid _uuid = const Uuid();

  // Stores metadata from fileTransfer message until chunks complete
  final Map<String, Map<String, dynamic>> _pendingFileMetadata = {};

  final Map<String, ChatRoom> _chatRooms = {};
  final Map<String, List<ChatMessage>> _messages = {};
  bool _initialized = false;

  final StreamController<ChatMessage> _incomingMessageController =
      StreamController<ChatMessage>.broadcast();
  final StreamController<String> _reactionController =
      StreamController<String>.broadcast();

  Stream<ChatMessage> get onIncomingMessage =>
      _incomingMessageController.stream;
  Stream<String> get onReaction => _reactionController.stream;

  ChatService({
    required LocalStorage storage,
    required P2PClient client,
    required P2PServer server,
    required KeyManager keyManager,
  })  : _storage = storage,
        _client = client,
        _server = server,
        _keyManager = keyManager;

  // ─── Initialization ────────────────────────────────────────────

  Future<void> init(String myNyxChatId) async {
    if (_initialized) return; // Guard: don't subscribe to listeners twice
    _initialized = true;

    final rooms = await _storage.getChatRooms();
    for (final room in rooms) {
      _chatRooms[room.id] = room;
      final msgs = await _storage.getMessagesForRoom(room.id);
      _messages[room.id] = msgs;
    }

    _server.onNewConnection.listen((connection) {
      _setupConnectionListener(connection, myNyxChatId);
    });

    notifyListeners();
  }

  void _setupConnectionListener(
    PeerConnection connection,
    String myNyxChatId,
  ) {
    connection.onMessage.listen((message) async {
      switch (message.type) {
        case ProtocolMessageType.message:
          await _handleIncomingMessage(message, connection, myNyxChatId);
          break;
        case ProtocolMessageType.groupMessage:
          await _handleGroupMessage(message, connection, myNyxChatId);
          break;
        case ProtocolMessageType.groupCreate:
          await _handleGroupCreate(message, connection, myNyxChatId);
          break;
        case ProtocolMessageType.groupInvite:
          await _handleGroupInvite(message, connection, myNyxChatId);
          break;
        case ProtocolMessageType.reaction:
          await _handleReaction(message, myNyxChatId);
          break;
        case ProtocolMessageType.fileTransfer:
          await _handleFileTransfer(message, connection, myNyxChatId);
          break;
        case ProtocolMessageType.fileChunk:
          await _handleFileChunk(message, connection, myNyxChatId);
          break;
        default:
          break;
      }
    });
  }

  // ─── Post-Quantum Hybrid Key Helpers ──────────────────────────

  /// Resolve the Kyber shared secret for a connection.
  /// - Responder: reads pre-computed secret from connection
  /// - Initiator: decapsulates ciphertext using our Kyber private key
  Future<Uint8List?> _resolveKyberSecret(PeerConnection connection) async {
    try {
      // Responder path: we already have the shared secret from encapsulation
      if (connection.kyberSharedSecretHex != null &&
          connection.kyberSharedSecretHex!.isNotEmpty) {
        return Uint8List.fromList(
            convert.hex.decode(connection.kyberSharedSecretHex!));
      }

      // Initiator path: decapsulate the ciphertext we received
      if (connection.kyberCiphertextHex != null &&
          connection.kyberCiphertextHex!.isNotEmpty &&
          _keyManager.kyberKeyPair != null) {
        final ciphertext = Uint8List.fromList(
            convert.hex.decode(connection.kyberCiphertextHex!));
        final secret = await _hybridKex.decapsulate(
          ciphertext,
          _keyManager.kyberKeyPair!.privateKey,
        );
        // Cache the result so we don't decapsulate again
        connection.kyberSharedSecretHex = convert.hex.encode(secret);
        return secret;
      }
    } catch (e) {
      debugPrint('[PQC] Failed to resolve Kyber secret: $e');
    }
    return null; // Fallback: no PQC available, use ECDH only
  }

  // ─── Direct Message Handling ───────────────────────────────────

  Future<void> _handleIncomingMessage(
    ProtocolMessage protocol,
    PeerConnection connection,
    String myNyxChatId,
  ) async {
    try {
      final encryptedContent =
          protocol.payload['encryptedContent'] as String;
      final msgType = protocol.payload['messageType'] as String? ?? 'text';

      String content;
      try {
        final peerPublicKeyHex = connection.peerPublicKeyHex;
        if (peerPublicKeyHex != null &&
            _keyManager.keyExchangeKeyPair != null) {
          
          if (!_sessionKeyManager.hasSession(protocol.senderId)) {
            final kyberSecret = await _resolveKyberSecret(connection);
            await _sessionKeyManager.establishSession(
              peerId: protocol.senderId,
              peerPublicKeyHex: peerPublicKeyHex,
              ourIdentityKeyPair: _keyManager.keyExchangeKeyPair!,
              kyberSharedSecret: kyberSecret,
            );
          }

          final messageKey = await _sessionKeyManager.getNextReceivingKeyAndStep(
            peerId: protocol.senderId,
            incomingDhPubKeyHex: protocol.dhPubKey ?? peerPublicKeyHex,
          );

          content = await _encryptionEngine.decryptMessage(
            encryptedData: encryptedContent,
            sharedSecret: messageKey,
          );
        } else {
          content = encryptedContent;
        }
      } catch (e) {
        debugPrint('Decryption failed, using raw content: $e');
        content = encryptedContent;
      }

      final senderId = protocol.senderId;
      var room = await _getOrCreateRoom(
        peerId: senderId,
        peerDisplayName: connection.peerDisplayName ?? 'Unknown',
        peerPublicKeyHex: connection.peerPublicKeyHex ?? '',
      );

      final msg = ChatMessage(
        id: protocol.messageId ?? _uuid.v4(),
        senderId: senderId,
        receiverId: myNyxChatId,
        content: content,
        timestamp: protocol.timestamp,
        status: MessageStatus.delivered,
        roomId: room.id,
        messageType: MessageType.values.firstWhere(
          (e) => e.name == msgType,
          orElse: () => MessageType.text,
        ),
      );

      await _storage.saveMessage(msg);
      _messages[room.id] = [...(_messages[room.id] ?? []), msg];

      room = room.copyWith(
        lastMessageAt: msg.timestamp,
        unreadCount: room.unreadCount + 1,
      );
      _chatRooms[room.id] = room;
      await _storage.saveChatRoom(room);

      _incomingMessageController.add(msg);
      notifyListeners();

      connection.send(ProtocolMessage.ack(
        senderId: myNyxChatId,
        messageId: msg.id,
      ));
    } catch (e) {
      debugPrint('Error handling incoming message: $e');
    }
  }

  // ─── Send Message ──────────────────────────────────────────────

  Future<ChatMessage?> sendMessage({
    required String roomId,
    required String peerId,
    required String content,
    required String myNyxChatId,
    required String peerPublicKeyHex,
    MessageType messageType = MessageType.text,
  }) async {
    try {
      final messageId = _uuid.v4();
      final room = _chatRooms[roomId];
      final isGroup = room?.isGroup ?? false;

      String encryptedContent;
      String? dhPubKey;
      try {
        if (_keyManager.keyExchangeKeyPair != null &&
            peerPublicKeyHex.isNotEmpty) {
          
          if (isGroup) {
            // Group messages use static ECDH (matching _handleGroupMessage decryption)
            final sharedSecret =
                await _encryptionEngine.deriveSharedSecretFromHex(
              ourKeyPair: _keyManager.keyExchangeKeyPair!,
              theirPublicKeyHex: peerPublicKeyHex,
            );
            encryptedContent = await _encryptionEngine.encryptMessage(
              plaintext: content,
              sharedSecret: sharedSecret,
            );
          } else {
            // DM messages use Double Ratchet for forward secrecy
            if (!_sessionKeyManager.hasSession(peerId)) {
              final conn = _client.getConnection(peerId);
              final kyberSecret = conn != null
                  ? await _resolveKyberSecret(conn)
                  : null;
              await _sessionKeyManager.establishSession(
                peerId: peerId,
                peerPublicKeyHex: peerPublicKeyHex,
                ourIdentityKeyPair: _keyManager.keyExchangeKeyPair!,
                kyberSharedSecret: kyberSecret,
              );
            }

            final ratchetStep = await _sessionKeyManager.getNextSendingKeyAndStep(peerId);
            encryptedContent = await _encryptionEngine.encryptMessage(
              plaintext: content,
              sharedSecret: ratchetStep.messageKey,
            );
            dhPubKey = ratchetStep.dhPubKeyHex;
          }
        } else {
          debugPrint('[Security] No encryption keys available — message will be unencrypted');
          encryptedContent = content;
        }
      } catch (e) {
        debugPrint('[Security] Encryption FAILED: $e — aborting send');
        return null;
      }

      // Create protocol message
      final protocol = isGroup
          ? ProtocolMessage.groupMessage(
              senderId: myNyxChatId,
              groupId: roomId,
              encryptedContent: encryptedContent,
              messageId: messageId,
              messageType: messageType.name,
            )
          : ProtocolMessage.chatMessage(
              senderId: myNyxChatId,
              receiverId: peerId,
              encryptedContent: encryptedContent,
              messageId: messageId,
              messageType: messageType.name,
              dhPubKey: dhPubKey,
            );

      final msg = ChatMessage(
        id: messageId,
        senderId: myNyxChatId,
        receiverId: peerId,
        content: content,
        timestamp: DateTime.now(),
        status: MessageStatus.sending,
        roomId: roomId,
        messageType: messageType,
      );

      await _storage.saveMessage(msg);
      _messages[roomId] = [...(_messages[roomId] ?? []), msg];

      if (room != null) {
        final updatedRoom = room.copyWith(lastMessageAt: msg.timestamp);
        _chatRooms[roomId] = updatedRoom;
        await _storage.saveChatRoom(updatedRoom);
      }

      notifyListeners();

      // Send to peer(s)
      bool sent = false;
      if (isGroup && room != null) {
        // Send to all group members
        for (final member in room.members) {
          if (member.nyxChatId != myNyxChatId &&
              _client.isPeerConnected(member.nyxChatId)) {
            _client.sendToPeer(member.nyxChatId, protocol);
            sent = true;
          }
        }
      } else if (_client.isPeerConnected(peerId)) {
        _client.sendToPeer(peerId, protocol);
        sent = true;
      }

      final updatedMsg = msg.copyWith(
        status: sent ? MessageStatus.sent : MessageStatus.failed,
      );
      await _storage.saveMessage(updatedMsg);
      _messages[roomId] = _messages[roomId]!
          .map((m) => m.id == msg.id ? updatedMsg : m)
          .toList();
      notifyListeners();
      return updatedMsg;
    } catch (e) {
      debugPrint('Failed to send message: $e');
      return null;
    }
  }

  // ─── Group Chat ────────────────────────────────────────────────

  /// Create a new group chat
  Future<ChatRoom> createGroupChat({
    required String groupName,
    required List<GroupMember> members,
    required String myNyxChatId,
    String? description,
  }) async {
    final groupId = _uuid.v4();
    final room = ChatRoom(
      id: groupId,
      peerId: groupId,
      peerDisplayName: groupName,
      peerPublicKeyHex: '',
      createdAt: DateTime.now(),
      roomType: ChatRoomType.group,
      members: members,
      groupDescription: description,
    );

    _chatRooms[room.id] = room;
    _messages[room.id] = [];
    await _storage.saveChatRoom(room);

    // Add system message
    final systemMsg = ChatMessage(
      id: _uuid.v4(),
      senderId: myNyxChatId,
      receiverId: groupId,
      content: 'Group "$groupName" created',
      timestamp: DateTime.now(),
      status: MessageStatus.sent,
      roomId: groupId,
      messageType: MessageType.system,
    );
    await _storage.saveMessage(systemMsg);
    _messages[groupId] = [systemMsg];

    // Notify all members
    for (final member in members) {
      if (member.nyxChatId != myNyxChatId &&
          _client.isPeerConnected(member.nyxChatId)) {
        _client.sendToPeer(
          member.nyxChatId,
          ProtocolMessage.groupInvite(
            senderId: myNyxChatId,
            groupId: groupId,
            groupName: groupName,
            members: members.map((m) => m.toJson()).toList(),
          ),
        );
      }
    }

    notifyListeners();
    return room;
  }

  Future<void> _handleGroupCreate(
    ProtocolMessage msg,
    PeerConnection connection,
    String myNyxChatId,
  ) async {
    await _handleGroupInvite(msg, connection, myNyxChatId);
  }

  Future<void> _handleGroupInvite(
    ProtocolMessage msg,
    PeerConnection connection,
    String myNyxChatId,
  ) async {
    try {
      final groupId = msg.payload['groupId'] as String;
      final groupName = msg.payload['groupName'] as String;
      final membersJson = msg.payload['members'] as List<dynamic>;
      final members = membersJson
          .map((m) => GroupMember.fromJson(m as Map<String, dynamic>))
          .toList();

      if (!_chatRooms.containsKey(groupId)) {
        final room = ChatRoom(
          id: groupId,
          peerId: groupId,
          peerDisplayName: groupName,
          peerPublicKeyHex: '',
          createdAt: DateTime.now(),
          roomType: ChatRoomType.group,
          members: members,
        );

        _chatRooms[groupId] = room;
        _messages[groupId] = [];
        await _storage.saveChatRoom(room);

        // System message
        final systemMsg = ChatMessage(
          id: _uuid.v4(),
          senderId: msg.senderId,
          receiverId: groupId,
          content: 'You were added to "$groupName"',
          timestamp: DateTime.now(),
          status: MessageStatus.delivered,
          roomId: groupId,
          messageType: MessageType.system,
        );
        await _storage.saveMessage(systemMsg);
        _messages[groupId] = [systemMsg];

        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error handling group invite: $e');
    }
  }

  Future<void> _handleGroupMessage(
    ProtocolMessage protocol,
    PeerConnection connection,
    String myNyxChatId,
  ) async {
    try {
      final groupId = protocol.payload['groupId'] as String;
      final encryptedContent =
          protocol.payload['encryptedContent'] as String;
      final msgType =
          protocol.payload['messageType'] as String? ?? 'text';

      String content;
      try {
        final peerPublicKeyHex = connection.peerPublicKeyHex;
        if (peerPublicKeyHex != null &&
            _keyManager.keyExchangeKeyPair != null) {
          final sharedSecret =
              await _encryptionEngine.deriveSharedSecretFromHex(
            ourKeyPair: _keyManager.keyExchangeKeyPair!,
            theirPublicKeyHex: peerPublicKeyHex,
          );
          content = await _encryptionEngine.decryptMessage(
            encryptedData: encryptedContent,
            sharedSecret: sharedSecret,
          );
        } else {
          content = encryptedContent;
        }
      } catch (e) {
        content = encryptedContent;
      }

      final room = _chatRooms[groupId];
      if (room == null) return;

      final msg = ChatMessage(
        id: protocol.messageId ?? _uuid.v4(),
        senderId: protocol.senderId,
        receiverId: groupId,
        content: content,
        timestamp: protocol.timestamp,
        status: MessageStatus.delivered,
        roomId: groupId,
        messageType: MessageType.values.firstWhere(
          (e) => e.name == msgType,
          orElse: () => MessageType.text,
        ),
      );

      await _storage.saveMessage(msg);
      _messages[groupId] = [...(_messages[groupId] ?? []), msg];

      final updatedRoom = room.copyWith(
        lastMessageAt: msg.timestamp,
        unreadCount: room.unreadCount + 1,
      );
      _chatRooms[groupId] = updatedRoom;
      await _storage.saveChatRoom(updatedRoom);

      _incomingMessageController.add(msg);
      notifyListeners();
    } catch (e) {
      debugPrint('Error handling group message: $e');
    }
  }

  // ─── Reactions ─────────────────────────────────────────────────

  /// Add or remove a reaction on a message
  Future<void> toggleReaction({
    required String roomId,
    required String messageId,
    required String emoji,
    required String myNyxChatId,
  }) async {
    final msgs = _messages[roomId];
    if (msgs == null) return;

    final idx = msgs.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;

    final msg = msgs[idx];
    final existing = msg.reactions.where((r) => r.userId == myNyxChatId);
    final hasReaction =
        existing.isNotEmpty && existing.first.emoji == emoji;

    ChatMessage updatedMsg;
    if (hasReaction) {
      updatedMsg = msg.removeReaction(myNyxChatId);
    } else {
      updatedMsg = msg.addReaction(MessageReaction(
        userId: myNyxChatId,
        emoji: emoji,
        timestamp: DateTime.now(),
      ));
    }

    _messages[roomId]![idx] = updatedMsg;
    await _storage.saveMessage(updatedMsg);
    notifyListeners();

    // Send reaction to peer(s)
    final room = _chatRooms[roomId];
    if (room == null) return;

    final protocol = ProtocolMessage.reaction(
      senderId: myNyxChatId,
      targetMessageId: messageId,
      emoji: emoji,
      roomId: roomId,
      remove: hasReaction,
    );

    if (room.isGroup) {
      for (final member in room.members) {
        if (member.nyxChatId != myNyxChatId &&
            _client.isPeerConnected(member.nyxChatId)) {
          _client.sendToPeer(member.nyxChatId, protocol);
        }
      }
    } else if (_client.isPeerConnected(room.peerId)) {
      _client.sendToPeer(room.peerId, protocol);
    }
  }

  Future<void> _handleReaction(
      ProtocolMessage protocol, String myNyxChatId) async {
    try {
      final targetId = protocol.messageId ?? '';
      final emoji = protocol.payload['emoji'] as String;
      final roomId = protocol.payload['roomId'] as String;
      final remove = protocol.payload['remove'] as bool? ?? false;

      final msgs = _messages[roomId];
      if (msgs == null) return;

      final idx = msgs.indexWhere((m) => m.id == targetId);
      if (idx == -1) return;

      final msg = msgs[idx];
      ChatMessage updatedMsg;
      if (remove) {
        updatedMsg = msg.removeReaction(protocol.senderId);
      } else {
        updatedMsg = msg.addReaction(MessageReaction(
          userId: protocol.senderId,
          emoji: emoji,
          timestamp: DateTime.now(),
        ));
      }

      _messages[roomId]![idx] = updatedMsg;
      await _storage.saveMessage(updatedMsg);
      _reactionController.add(roomId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error handling reaction: $e');
    }
  }

  // ─── File Transfer ─────────────────────────────────────────────

  /// Send a file to a peer
  Future<ChatMessage?> sendFile({
    required String roomId,
    required String peerId,
    required String filePath,
    required String myNyxChatId,
    required String peerPublicKeyHex,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      final fileName = file.path.split(Platform.pathSeparator).last;
      final mimeType = _getMimeType(fileName);
      final fileSize = bytes.length;

      // Enforce max file size (100MB for chunks!)
      if (fileSize > 100 * 1024 * 1024) {
        debugPrint('File too large: $fileSize bytes');
        return null;
      }

      // Encrypt file data
      String encryptedDataB64;
      String? dhPubKey;
      final fileDataB64 = base64Encode(bytes);
      try {
        if (_keyManager.keyExchangeKeyPair != null &&
            peerPublicKeyHex.isNotEmpty) {
            
          if (!_sessionKeyManager.hasSession(peerId)) {
            final conn = _client.getConnection(peerId);
            final kyberSecret = conn != null
                ? await _resolveKyberSecret(conn)
                : null;
            await _sessionKeyManager.establishSession(
              peerId: peerId,
              peerPublicKeyHex: peerPublicKeyHex,
              ourIdentityKeyPair: _keyManager.keyExchangeKeyPair!,
              kyberSharedSecret: kyberSecret,
            );
          }

          final ratchetStep = await _sessionKeyManager.getNextSendingKeyAndStep(peerId);
          encryptedDataB64 = await _encryptionEngine.encryptMessage(
            plaintext: fileDataB64,
            sharedSecret: ratchetStep.messageKey,
          );
          dhPubKey = ratchetStep.dhPubKeyHex;
        } else {
          debugPrint('[Security] No encryption keys for file — sending unencrypted');
          encryptedDataB64 = fileDataB64;
        }
      } catch (e) {
        debugPrint('[Security] File encryption FAILED: $e — aborting send');
        return null;
      }

      final messageId = _uuid.v4();
      final attachment = FileAttachment(
        fileName: fileName,
        mimeType: mimeType,
        fileSize: fileSize,
        filePath: filePath,
      );

      final msg = ChatMessage(
        id: messageId,
        senderId: myNyxChatId,
        receiverId: peerId,
        content: '📎 $fileName',
        timestamp: DateTime.now(),
        status: MessageStatus.sending,
        roomId: roomId,
        messageType: mimeType.startsWith('image/')
            ? MessageType.image
            : MessageType.file,
        attachment: attachment,
      );

      await _storage.saveMessage(msg);
      _messages[roomId] = [...(_messages[roomId] ?? []), msg];
      notifyListeners();

      final protocol = ProtocolMessage.fileTransfer(
        senderId: myNyxChatId,
        receiverId: peerId,
        messageId: messageId,
        fileName: fileName,
        mimeType: mimeType,
        fileSize: fileSize,
        encryptedDataB64: "", // Metadata only
        groupId: _chatRooms[roomId]?.isGroup == true ? roomId : null,
        dhPubKey: dhPubKey,
      );

      bool sent = false;
      if (_client.isPeerConnected(peerId)) {
        _client.sendToPeer(peerId, protocol);
        sent = true;
        
        // Chunk and stream the large payload
        final payloadBytes = Uint8List.fromList(utf8.encode(encryptedDataB64));
        final chunks = _fileTransferManager.sliceFile(messageId, payloadBytes);
        for (final chunk in chunks) {
            final chunkMsg = ProtocolMessage.fileChunk(
                senderId: myNyxChatId,
                receiverId: peerId,
                chunkDataJson: chunk.toJson(),
            );
            _client.sendToPeer(peerId, chunkMsg);
        }
      }

      final updatedMsg = msg.copyWith(
        status: sent ? MessageStatus.sent : MessageStatus.failed,
      );
      await _storage.saveMessage(updatedMsg);
      _messages[roomId] = _messages[roomId]!
          .map((m) => m.id == msg.id ? updatedMsg : m)
          .toList();

      final room = _chatRooms[roomId];
      if (room != null) {
        _chatRooms[roomId] =
            room.copyWith(lastMessageAt: msg.timestamp);
        await _storage.saveChatRoom(_chatRooms[roomId]!);
      }

      notifyListeners();
      return updatedMsg;
    } catch (e) {
      debugPrint('Failed to send file: $e');
      return null;
    }
  }

  Future<void> _handleFileTransfer(
    ProtocolMessage protocol,
    PeerConnection connection,
    String myNyxChatId,
  ) async {
    try {
      final fileName = protocol.payload['fileName'] as String;
      final mimeType = protocol.payload['mimeType'] as String;
      final fileSize = protocol.payload['fileSize'] as int;
      final messageId = protocol.messageId ?? '';

      debugPrint('[FileTransfer] Receiving metadata for $fileName ($fileSize bytes). Awaiting chunks...');
      
      // Store metadata keyed by messageId so _handleFileChunk can retrieve it
      _pendingFileMetadata[messageId] = {
        'fileName': fileName,
        'mimeType': mimeType,
        'fileSize': fileSize,
        'dhPubKey': protocol.dhPubKey,
        'senderId': protocol.senderId,
        'groupId': protocol.payload['groupId'],
      };
      
      connection.send(ProtocolMessage.ack(
        senderId: myNyxChatId,
        messageId: messageId,
      ));
    } catch (e) {
      debugPrint('Error handling file transfer metadata: $e');
    }
  }

  Future<void> _handleFileChunk(
    ProtocolMessage protocol,
    PeerConnection connection,
    String myNyxChatId,
  ) async {
    try {
      final chunkJson = protocol.payload['chunk'] as Map<String, dynamic>;
      final chunk = FileChunk.fromJson(chunkJson);
      
      final assembledBytes = _fileTransferManager.receiveChunk(chunk);
      if (assembledBytes == null) return; // Still tracking...

      // Transfer complete!
      debugPrint('[FileTransfer] Chunk stream complete for file ${chunk.fileId}!');
      final encryptedDataB64 = utf8.decode(assembledBytes);

      // Retrieve metadata stored from the initial fileTransfer message
      final metadata = _pendingFileMetadata.remove(chunk.fileId);
      final fileName = (metadata?['fileName'] as String?) ?? 
          'nyxchat_${DateTime.now().millisecondsSinceEpoch}.bin';
      final mimeType = (metadata?['mimeType'] as String?) ?? 
          'application/octet-stream';
      final storedDhPubKey = metadata?['dhPubKey'] as String?;

      // Decrypt file data
      String fileDataB64;
      try {
        final peerPublicKeyHex = connection.peerPublicKeyHex;
        if (peerPublicKeyHex != null &&
            _keyManager.keyExchangeKeyPair != null) {
          
          if (!_sessionKeyManager.hasSession(protocol.senderId)) {
            final kyberSecret = await _resolveKyberSecret(connection);
            await _sessionKeyManager.establishSession(
              peerId: protocol.senderId,
              peerPublicKeyHex: peerPublicKeyHex,
              ourIdentityKeyPair: _keyManager.keyExchangeKeyPair!,
              kyberSharedSecret: kyberSecret,
            );
          }

          final messageKey = await _sessionKeyManager.getNextReceivingKeyAndStep(
            peerId: protocol.senderId,
            incomingDhPubKeyHex: storedDhPubKey ?? peerPublicKeyHex,
          );

          fileDataB64 = await _encryptionEngine.decryptMessage(
            encryptedData: encryptedDataB64,
            sharedSecret: messageKey,
          );
        } else {
          fileDataB64 = encryptedDataB64;
        }
      } catch (e) {
        debugPrint('[FileTransfer] Decryption failed, using raw data: $e');
        fileDataB64 = encryptedDataB64;
      }

      // Save file locally
      final dir = await getApplicationDocumentsDirectory();
      final savePath = '${dir.path}/nyxchat_files/$fileName';
      final saveDir = Directory('${dir.path}/nyxchat_files');
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }
      await File(savePath).writeAsBytes(base64Decode(fileDataB64));

      // Determine room
      final roomId = (await _getOrCreateRoom(
        peerId: protocol.senderId,
        peerDisplayName: connection.peerDisplayName ?? 'Unknown',
        peerPublicKeyHex: connection.peerPublicKeyHex ?? '',
      )).id;

      final attachment = FileAttachment(
        fileName: fileName,
        mimeType: mimeType,
        fileSize: assembledBytes.length,
        filePath: savePath,
      );

      final msg = ChatMessage(
        id: chunk.fileId,
        senderId: protocol.senderId,
        receiverId: myNyxChatId,
        content: '📎 $fileName',
        timestamp: DateTime.now(),
        status: MessageStatus.delivered,
        roomId: roomId,
        messageType: MessageType.file,
        attachment: attachment,
      );

      await _storage.saveMessage(msg);
      _messages[roomId] = [...(_messages[roomId] ?? []), msg];

      final room = _chatRooms[roomId];
      if (room != null) {
        final updatedRoom = room.copyWith(
          lastMessageAt: msg.timestamp,
          unreadCount: room.unreadCount + 1,
        );
        _chatRooms[roomId] = updatedRoom;
        await _storage.saveChatRoom(updatedRoom);
      }

      _incomingMessageController.add(msg);
      notifyListeners();

    } catch (e) {
      debugPrint('Error handling file chunk: $e');
    }
  }

  // ─── Forward Secrecy: Key Rotation ─────────────────────────────

  /// Establish forward secrecy session with a peer
  Future<void> establishSession({
    required String peerId,
    required String peerPublicKeyHex,
  }) async {
    if (_keyManager.keyExchangeKeyPair != null) {
      final conn = _client.getConnection(peerId);
      final kyberSecret = conn != null
          ? await _resolveKyberSecret(conn)
          : null;
      await _sessionKeyManager.establishSession(
        peerId: peerId,
        peerPublicKeyHex: peerPublicKeyHex,
        ourIdentityKeyPair: _keyManager.keyExchangeKeyPair!,
        kyberSharedSecret: kyberSecret,
      );
    }
  }

  // ─── Room Management ──────────────────────────────────────────

  Future<ChatRoom> _getOrCreateRoom({
    required String peerId,
    required String peerDisplayName,
    required String peerPublicKeyHex,
  }) async {
    for (final room in _chatRooms.values) {
      if (room.peerId == peerId && !room.isGroup) return room;
    }

    final room = ChatRoom(
      id: _uuid.v4(),
      peerId: peerId,
      peerDisplayName: peerDisplayName,
      peerPublicKeyHex: peerPublicKeyHex,
      createdAt: DateTime.now(),
    );

    _chatRooms[room.id] = room;
    _messages[room.id] = [];
    await _storage.saveChatRoom(room);
    notifyListeners();

    return room;
  }

  Future<ChatRoom> getOrCreateRoom({
    required String peerId,
    required String peerDisplayName,
    required String peerPublicKeyHex,
  }) {
    return _getOrCreateRoom(
      peerId: peerId,
      peerDisplayName: peerDisplayName,
      peerPublicKeyHex: peerPublicKeyHex,
    );
  }

  List<ChatMessage> getMessages(String roomId) =>
      List.unmodifiable(_messages[roomId] ?? []);

  List<ChatRoom> get chatRooms {
    final rooms = _chatRooms.values.toList();
    rooms.sort((a, b) {
      final aTime = a.lastMessageAt ?? a.createdAt;
      final bTime = b.lastMessageAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });
    return rooms;
  }

  Future<void> markRoomAsRead(String roomId) async {
    final room = _chatRooms[roomId];
    if (room != null) {
      final updated = room.copyWith(unreadCount: 0);
      _chatRooms[roomId] = updated;
      await _storage.saveChatRoom(updated);
      notifyListeners();
    }
  }

  void listenToConnection(PeerConnection connection, String myNyxChatId) {
    _setupConnectionListener(connection, myNyxChatId);
  }

  // ─── Helpers ──────────────────────────────────────────────────

  String _getMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    const mimeTypes = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'mp4': 'video/mp4',
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'txt': 'text/plain',
      'zip': 'application/zip',
    };
    return mimeTypes[ext] ?? 'application/octet-stream';
  }

  @override
  void dispose() {
    _incomingMessageController.close();
    _reactionController.close();
    super.dispose();
  }
}
