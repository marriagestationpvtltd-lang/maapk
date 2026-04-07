import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

/// URL of the Node.js Socket.IO server.
/// Change this to your deployed server's URL before building for production.
const String kSocketServerUrl = 'https://your-socket-server.com';

/// REST endpoint for uploading chat media (images / voice).
const String kChatUploadUrl = 'https://digitallami.com/Api2/chat_upload.php';

/// ---------------------------------------------------------------------------
/// SocketService — singleton that manages the Socket.IO connection and
/// exposes streams for all real-time chat events.
/// ---------------------------------------------------------------------------
class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  String? _connectedUserId;

  // ── Stream controllers ────────────────────────────────────────────────────

  final _newMessageCtrl      = StreamController<Map<String, dynamic>>.broadcast();
  final _messageEditedCtrl   = StreamController<Map<String, dynamic>>.broadcast();
  final _messageDeletedCtrl  = StreamController<Map<String, dynamic>>.broadcast();
  final _typingStartCtrl     = StreamController<Map<String, dynamic>>.broadcast();
  final _typingStopCtrl      = StreamController<Map<String, dynamic>>.broadcast();
  final _messagesReadCtrl    = StreamController<Map<String, dynamic>>.broadcast();
  final _userStatusCtrl      = StreamController<Map<String, dynamic>>.broadcast();
  final _chatRoomsUpdateCtrl = StreamController<List<dynamic>>.broadcast();
  final _connectionCtrl      = StreamController<bool>.broadcast();

  // ── Public streams ────────────────────────────────────────────────────────

  Stream<Map<String, dynamic>> get onNewMessage      => _newMessageCtrl.stream;
  Stream<Map<String, dynamic>> get onMessageEdited   => _messageEditedCtrl.stream;
  Stream<Map<String, dynamic>> get onMessageDeleted  => _messageDeletedCtrl.stream;
  Stream<Map<String, dynamic>> get onTypingStart     => _typingStartCtrl.stream;
  Stream<Map<String, dynamic>> get onTypingStop      => _typingStopCtrl.stream;
  Stream<Map<String, dynamic>> get onMessagesRead    => _messagesReadCtrl.stream;
  Stream<Map<String, dynamic>> get onUserStatusChange => _userStatusCtrl.stream;
  Stream<List<dynamic>>        get onChatRoomsUpdate => _chatRoomsUpdateCtrl.stream;
  Stream<bool>                 get onConnectionChange => _connectionCtrl.stream;

  bool get isConnected => _socket?.connected == true;

  // ── Connect / Disconnect ──────────────────────────────────────────────────

  void connect(String userId) {
    if (_socket != null && _socket!.connected) {
      if (_connectedUserId == userId) return;
      _socket!.disconnect();
    }

    _connectedUserId = userId;

    _socket = IO.io(
      kSocketServerUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(2000)
          .build(),
    );

    _socket!.onConnect((_) {
      print('✅ Socket connected');
      _connectionCtrl.add(true);
      // Authenticate immediately after connect / reconnect
      _socket!.emit('authenticate', {'userId': userId});
    });

    _socket!.onDisconnect((_) {
      print('⚡ Socket disconnected');
      _connectionCtrl.add(false);
    });

    _socket!.onConnectError((err) => print('❌ Socket connect error: $err'));

    // ── Register event listeners ────────────────────────────────────────────

    _socket!.on('new_message', (data) {
      _newMessageCtrl.add(_toMap(data));
    });

    _socket!.on('message_edited', (data) {
      _messageEditedCtrl.add(_toMap(data));
    });

    _socket!.on('message_deleted', (data) {
      _messageDeletedCtrl.add(_toMap(data));
    });

    _socket!.on('typing_start', (data) {
      _typingStartCtrl.add(_toMap(data));
    });

    _socket!.on('typing_stop', (data) {
      _typingStopCtrl.add(_toMap(data));
    });

    _socket!.on('messages_read', (data) {
      _messagesReadCtrl.add(_toMap(data));
    });

    _socket!.on('user_status_change', (data) {
      _userStatusCtrl.add(_toMap(data));
    });

    _socket!.on('chat_rooms_update', (data) {
      final map = _toMap(data);
      final rooms = map['chatRooms'];
      if (rooms is List) _chatRoomsUpdateCtrl.add(rooms);
    });

    _socket!.on('error', (data) {
      print('🔴 Socket error event: $data');
    });

    _socket!.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket    = null;
    _connectedUserId = null;
  }

  // ── Emit helpers ──────────────────────────────────────────────────────────

  /// Join a chat room socket channel.
  void joinRoom(String chatRoomId) {
    _socket?.emit('join_room', {'chatRoomId': chatRoomId});
  }

  /// Leave a chat room socket channel.
  void leaveRoom(String chatRoomId) {
    _socket?.emit('leave_room', {'chatRoomId': chatRoomId});
  }

  /// Tell the server which chat room is currently active (for read-receipt logic).
  void setActiveChat(String userId, String chatRoomId, {bool isActive = true}) {
    _socket?.emit('set_active_chat', {
      'userId':     userId,
      'chatRoomId': chatRoomId,
      'isActive':   isActive,
    });
  }

  /// Send a text or media message.
  void sendMessage({
    required String chatRoomId,
    required String senderId,
    required String receiverId,
    required String message,
    required String messageType,
    required String messageId,
    Map<String, dynamic>? repliedTo,
    bool isReceiverViewing = false,
    String user1Name = '',
    String user2Name = '',
    String user1Image = '',
    String user2Image = '',
  }) {
    _socket?.emit('send_message', {
      'chatRoomId':         chatRoomId,
      'senderId':           senderId,
      'receiverId':         receiverId,
      'message':            message,
      'messageType':        messageType,
      'messageId':          messageId,
      'repliedTo':          repliedTo,
      'isReceiverViewing':  isReceiverViewing,
      'user1Name':          user1Name,
      'user2Name':          user2Name,
      'user1Image':         user1Image,
      'user2Image':         user2Image,
    });
  }

  void startTyping(String chatRoomId, String userId) {
    _socket?.emit('typing_start', {'chatRoomId': chatRoomId, 'userId': userId});
  }

  void stopTyping(String chatRoomId, String userId) {
    _socket?.emit('typing_stop', {'chatRoomId': chatRoomId, 'userId': userId});
  }

  void markRead(String chatRoomId, String userId) {
    _socket?.emit('mark_read', {'chatRoomId': chatRoomId, 'userId': userId});
  }

  void editMessage(String chatRoomId, String messageId, String newMessage) {
    _socket?.emit('edit_message', {
      'chatRoomId': chatRoomId,
      'messageId':  messageId,
      'newMessage': newMessage,
    });
  }

  void deleteMessage({
    required String chatRoomId,
    required String messageId,
    required String userId,
    required bool deleteForEveryone,
  }) {
    _socket?.emit('delete_message', {
      'chatRoomId':       chatRoomId,
      'messageId':        messageId,
      'userId':           userId,
      'deleteForEveryone': deleteForEveryone,
    });
  }

  // ── Request-response helpers ──────────────────────────────────────────────

  /// Fetch a page of messages (request-response via Socket.IO ack).
  Future<Map<String, dynamic>> getMessages(String chatRoomId, {int page = 1, int limit = 20}) {
    final completer = Completer<Map<String, dynamic>>();
    _socket?.emitWithAck(
      'get_messages',
      {'chatRoomId': chatRoomId, 'page': page, 'limit': limit},
      ack: (response) {
        final map = _toMap(response);
        if (!completer.isCompleted) completer.complete(map);
      },
    );
    // Timeout fallback
    Future.delayed(const Duration(seconds: 15), () {
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('get_messages timed out'));
      }
    });
    return completer.future;
  }

  /// Fetch the user's chat room list (request-response via Socket.IO ack).
  Future<List<dynamic>> getChatRooms(String userId) async {
    final completer = Completer<List<dynamic>>();
    _socket?.emitWithAck(
      'get_chat_rooms',
      {'userId': userId},
      ack: (response) {
        final map = _toMap(response);
        final rooms = map['chatRooms'];
        if (!completer.isCompleted) {
          completer.complete(rooms is List ? rooms : []);
        }
      },
    );
    Future.delayed(const Duration(seconds: 15), () {
      if (!completer.isCompleted) completer.complete([]);
    });
    return completer.future;
  }

  // ── Media upload ──────────────────────────────────────────────────────────

  /// Upload a chat image via PHP REST API and return the public URL.
  Future<String> uploadChatImage({
    required File imageFile,
    required String userId,
    required String chatRoomId,
  }) async {
    return _uploadFile(
      file: imageFile,
      userId: userId,
      type: 'image',
      mimeType: MediaType('image', 'jpeg'),
    );
  }

  /// Upload a voice message via PHP REST API and return the public URL.
  Future<String> uploadVoiceMessage({
    required File voiceFile,
    required String userId,
    required String chatRoomId,
  }) async {
    return _uploadFile(
      file: voiceFile,
      userId: userId,
      type: 'voice',
      mimeType: MediaType('audio', 'mpeg'),
    );
  }

  Future<String> _uploadFile({
    required File file,
    required String userId,
    required String type,
    required MediaType mimeType,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse(kChatUploadUrl))
      ..fields['type']   = type
      ..fields['userId'] = userId
      ..files.add(await http.MultipartFile.fromPath(
        'file',
        file.path,
        contentType: mimeType,
      ));

    final streamed = await request.send();
    final body     = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200) {
      throw Exception('Upload failed: ${streamed.statusCode} $body');
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    if (json['success'] != true) {
      throw Exception('Upload error: ${json['error']}');
    }
    return json['url'] as String;
  }

  // ── Utility ───────────────────────────────────────────────────────────────

  /// Normalize data coming from socket events to Map<String, dynamic>.
  static Map<String, dynamic> _toMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) {
      try { return jsonDecode(data) as Map<String, dynamic>; } catch (_) {}
    }
    return {};
  }

  /// Parse a timestamp value (String ISO8601 or DateTime) to a DateTime.
  static DateTime? parseTimestamp(dynamic ts) {
    if (ts == null) return null;
    if (ts is DateTime) return ts;
    if (ts is String) return DateTime.tryParse(ts);
    return null;
  }

  void dispose() {
    disconnect();
    _newMessageCtrl.close();
    _messageEditedCtrl.close();
    _messageDeletedCtrl.close();
    _typingStartCtrl.close();
    _typingStopCtrl.close();
    _messagesReadCtrl.close();
    _userStatusCtrl.close();
    _chatRoomsUpdateCtrl.close();
    _connectionCtrl.close();
  }
}
