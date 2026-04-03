// lib/screens/ChatDetailScreen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:ms2026/Chat/screen_state_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:record/record.dart';
import 'dart:async';

import '../Calling/OutgoingCall.dart';
import '../Calling/videocall.dart';
import '../otherenew/othernew.dart';
import '../otherenew/service.dart';
import '../pushnotification/pushservice.dart';
import '../webrtc/webrtc.dart';

class ChatDetailScreen extends StatefulWidget {
  final String chatRoomId;
  final String receiverId;
  final String receiverName;
  final String receiverImage;
  final String currentUserId;
  final String currentUserName;
  final String currentUserImage;

  const ChatDetailScreen({
    super.key,
    required this.chatRoomId,
    required this.receiverId,
    required this.receiverName,
    required this.receiverImage,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserImage,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = Uuid();
  final AudioRecorder _audioRecorder = AudioRecorder();

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String myImage = "";
  String otherUserImage = "";

  // Overlay
  bool showActionOverlay = false;
  bool showDeletePopup = false;
  Map<String, dynamic>? selectedMessage;
  bool selectedMine = false;

  // Reply functionality
  Map<String, dynamic>? repliedMessage;
  bool isReplying = false;

  // Edit functionality
  Map<String, dynamic>? editingMessage;
  bool isEditing = false;
  final TextEditingController _editController = TextEditingController();

  // Audio recording
  bool _isRecording = false;
  String? _currentRecordingPath;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;

  // Swipe reply variables
  Map<String, dynamic>? _swipedMessage;
  double _dragOffset = 0.0;
  bool _isDragging = false;
  bool _showSwipeIndicator = false;
  AnimationController? _swipeAnimationController;
  Animation<double>? _swipeAnimation;

  // Cached messages to prevent blinking
  List<Map<String, dynamic>> _cachedMessages = [];
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    myImage = widget.currentUserImage;
    otherUserImage = widget.receiverImage;

    _swipeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _swipeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _swipeAnimationController!,
        curve: Curves.easeOut,
      ),
    );

    _markMessagesAsRead();

    // Set chat as active when screen opens
    ScreenStateManager().onChatScreenOpened(widget.chatRoomId, widget.currentUserId);

    // Add observer for app lifecycle
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    _checkBlockStatus(); // Add this line

  }
  Future<void> _checkBlockStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    if (userDataString == null) return;

    final userData = jsonDecode(userDataString);
    final myId = userData["id"].toString();

    final service = ProfileService();
    final isBlocked = await service.isUserBlocked(
      myId: myId,
      userId: widget.receiverId,
    );

    if (mounted) {
      setState(() {
        _isBlocked = isBlocked;
      });
    }
  }
  @override
  void dispose() {
    // Clear chat active state when screen closes
    ScreenStateManager().onChatScreenClosed();
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _editController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    _recordingTimer?.cancel();
    _swipeAnimationController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Handle app lifecycle changes
    switch (state) {
      case AppLifecycleState.resumed:
      // App came back to foreground, set chat as active
        ScreenStateManager().onChatScreenOpened(widget.chatRoomId, widget.currentUserId);
        _markMessagesAsRead();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      // App went to background, clear active state
        ScreenStateManager().onChatScreenClosed();
        break;
      case AppLifecycleState.detached:
      // App is closed
        ScreenStateManager().onChatScreenClosed();
        break;
      case AppLifecycleState.hidden:
      // App is hidden
        ScreenStateManager().onChatScreenClosed();
        break;
    }
  }

  // MARK MESSAGES AS READ
  Future<void> _markMessagesAsRead() async {
    try {
      await _firestore.collection('chatRooms').doc(widget.chatRoomId).update({
        'unreadCount.${widget.currentUserId}': 0,
      });

      final unreadMessages = await _firestore
          .collection('chatRooms')
          .doc(widget.chatRoomId)
          .collection('messages')
          .where('receiverId', isEqualTo: widget.currentUserId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  // SEND MESSAGE (with reply support)
// SEND MESSAGE (with reply support)
  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    try {
      final timestamp = DateTime.now();
      final messageId = _uuid.v4();

      // Prepare message data
      final messageData = {
        'messageId': messageId,
        'senderId': widget.currentUserId,
        'receiverId': widget.receiverId,
        'message': messageText,
        'messageType': 'text',
        'timestamp': timestamp,
        'isRead': false,
        'isDeletedForSender': false,
        'isDeletedForReceiver': false,
      };
      await NotificationService.sendChatNotification(
        recipientUserId: widget.receiverId.toString(),
        senderName: "MS:${widget.currentUserId} ${widget.currentUserName}".trim(),
        senderId: widget.currentUserId.toString(),
        message: messageText,
      );

      // Add reply data if replying to a message
      if (isReplying && repliedMessage != null) {
        messageData['repliedTo'] = {
          'messageId': repliedMessage!['messageId'],
          'message': repliedMessage!['message'],
          'senderId': repliedMessage!['senderId'],
          'senderName': repliedMessage!['senderId'] == widget.currentUserId
              ? widget.currentUserName
              : widget.receiverName,
          'messageType': repliedMessage!['messageType'] ?? 'text',
        };
      }

      // Clear text field IMMEDIATELY
      _messageController.clear();

      // Clear reply/edit states
      _cancelReply();
      _cancelEdit();

      // Scroll to bottom
      _scrollToBottom();

      // Create message document (do this after UI updates)
      await _firestore
          .collection('chatRooms')
          .doc(widget.chatRoomId)
          .collection('messages')
          .doc(messageId)
          .set(messageData);

      // Update chat room last message
      await _firestore.collection('chatRooms').doc(widget.chatRoomId).update({
        'lastMessage': messageText,
        'lastMessageType': 'text',
        'lastMessageTime': timestamp,
        'lastMessageSenderId': widget.currentUserId,
        'unreadCount.${widget.receiverId}': FieldValue.increment(1),
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  // EDIT MESSAGE
  Future<void> _editMessage() async {
    if (editingMessage == null || _editController.text.trim().isEmpty) return;

    try {
      final messageId = editingMessage!['messageId'];
      final newMessage = _editController.text.trim();

      // Update message in Firestore
      await _firestore
          .collection('chatRooms')
          .doc(widget.chatRoomId)
          .collection('messages')
          .doc(messageId)
          .update({
        'message': newMessage,
        'isEdited': true,
        'editedAt': DateTime.now(),
      });

      // Update chat room last message if this was the last message
      await _firestore.collection('chatRooms').doc(widget.chatRoomId).update({
        'lastMessage': newMessage,
      });

      _cancelEdit();
      _scrollToBottom();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message edited'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to edit message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }



  // VOICE RECORDING METHODS



  Future<void> _stopRecording() async {
    try {
      _recordingTimer?.cancel();

      if (!_isRecording) return;

      final recordingPath = await _audioRecorder.stop();

      if (mounted) {
        setState(() {
          _isRecording = false;
        });
      }

      if (recordingPath != null && _recordingSeconds >= 1) {
        await _sendVoiceMessage(recordingPath);
      } else {
        await _cancelRecording();
        if (_recordingSeconds < 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recording too short'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('Error stopping recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to stop recording: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _recordingSeconds = 0;
        });
      }
    }
  }

  Future<void> _cancelRecording() async {
    _recordingTimer?.cancel();

    if (_isRecording) {
      await _audioRecorder.stop();
      if (mounted) {
        setState(() {
          _isRecording = false;
        });
      }

      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    }

    if (mounted) {
      setState(() {
        _recordingSeconds = 0;
      });
    }
  }

  // SEND VOICE MESSAGE (with reply support)
  Future<void> _sendVoiceMessage(String audioPath) async {
    try {
      final timestamp = DateTime.now();
      final messageId = _uuid.v4();
      final fileName = 'voice_messages/${widget.chatRoomId}/$messageId.m4a';

      // Upload audio to Firebase Storage
      final ref = _storage.ref().child(fileName);
      await ref.putFile(File(audioPath));
      final audioUrl = await ref.getDownloadURL();

      // Prepare message data
      final messageData = {
        'messageId': messageId,
        'senderId': widget.currentUserId,
        'receiverId': widget.receiverId,
        'message': audioUrl,
        'messageType': 'voice',
        'duration': _recordingSeconds,
        'timestamp': timestamp,
        'isRead': false,
        'isDeletedForSender': false,
        'isDeletedForReceiver': false,
      };

      // Add reply data if replying to a message
      if (isReplying && repliedMessage != null) {
        messageData['repliedTo'] = {
          'messageId': repliedMessage!['messageId'],
          'message': repliedMessage!['message'],
          'senderId': repliedMessage!['senderId'],
          'senderName': repliedMessage!['senderId'] == widget.currentUserId
              ? widget.currentUserName
              : widget.receiverName,
          'messageType': repliedMessage!['messageType'] ?? 'text',
        };
      }

      // Create message document
      await _firestore
          .collection('chatRooms')
          .doc(widget.chatRoomId)
          .collection('messages')
          .doc(messageId)
          .set(messageData);

      // Update chat room
      await _firestore.collection('chatRooms').doc(widget.chatRoomId).update({
        'lastMessage': '🎤 Voice message',
        'lastMessageType': 'voice',
        'lastMessageTime': timestamp,
        'lastMessageSenderId': widget.currentUserId,
        'unreadCount.${widget.receiverId}': FieldValue.increment(1),
      });

      // Delete local recording file
      final file = File(audioPath);
      if (await file.exists()) {
        await file.delete();
      }

      _cancelReply();
      _cancelEdit();
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send voice message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _recordingSeconds = 0;
        });
      }
    }
  }

  // MESSAGE ACTIONS
  Future<void> _deleteMessage(bool deleteForEveryone) async {
    if (selectedMessage == null) return;

    try {
      final messageId = selectedMessage!['messageId'];

      if (deleteForEveryone) {
        await _firestore
            .collection('chatRooms')
            .doc(widget.chatRoomId)
            .collection('messages')
            .doc(messageId)
            .delete();
      } else {
        final isMine = selectedMessage!['senderId'] == widget.currentUserId;
        final updateData = isMine
            ? {'isDeletedForSender': true}
            : {'isDeletedForReceiver': true};

        await _firestore
            .collection('chatRooms')
            .doc(widget.chatRoomId)
            .collection('messages')
            .doc(messageId)
            .update(updateData);
      }

      if (mounted) {
        setState(() {
          showDeletePopup = false;
          showActionOverlay = false;
          selectedMessage = null;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message deleted'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error deleting message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _copyMessage() {
    if (selectedMessage != null && selectedMessage!['messageType'] == 'text') {
      Clipboard.setData(ClipboardData(text: selectedMessage!['message']));
      if (mounted) {
        setState(() {
          showActionOverlay = false;
          selectedMessage = null;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message copied to clipboard'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // REPLY FUNCTIONALITY
  void _setReplyMessage(Map<String, dynamic> message) {
    if (mounted) {
      setState(() {
        repliedMessage = message;
        isReplying = true;
        showActionOverlay = false;
      });
    }

    FocusScope.of(context).requestFocus(FocusNode());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(FocusNode());
    });
  }

  void _cancelReply() {
    if (mounted) {
      setState(() {
        repliedMessage = null;
        isReplying = false;
      });
    }
  }

  // EDIT FUNCTIONALITY
  void _setEditMessage(Map<String, dynamic> message) {
    if (mounted) {
      setState(() {
        editingMessage = message;
        isEditing = true;
        _editController.text = message['message'];
        showActionOverlay = false;
      });
    }

    FocusScope.of(context).requestFocus(FocusNode());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(FocusNode());
    });
  }

  void _cancelEdit() {
    if (mounted) {
      setState(() {
        editingMessage = null;
        isEditing = false;
        _editController.clear();
      });
    }
  }

  // SWIPE HANDLING
  void _onHorizontalDragStart(
      DragStartDetails details, Map<String, dynamic> messageData, bool isMine) {
    _swipedMessage = messageData;
    _dragOffset = 0.0;
    _isDragging = true;
    _showSwipeIndicator = true;
    _swipeAnimationController?.forward();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details, bool isMine) {
    if (!_isDragging) return;

    _dragOffset += details.delta.dx;

    if (isMine && _dragOffset > 0) return;
    if (!isMine && _dragOffset < 0) return;

    _dragOffset = _dragOffset.clamp(-100.0, 100.0);
  }

  void _onHorizontalDragEnd(DragEndDetails details, bool isMine) {
    if (!_isDragging) return;

    final threshold = 60.0;
    final shouldReply = isMine
        ? _dragOffset < -threshold
        : _dragOffset > threshold;

    if (shouldReply && _swipedMessage != null) {
      _setReplyMessage(_swipedMessage!);
    }

    _swipeAnimationController?.reverse().then((value) {
      if (mounted) {
        setState(() {
          _swipedMessage = null;
          _dragOffset = 0.0;
          _isDragging = false;
          _showSwipeIndicator = false;
        });
      }
    });
  }

  // FORMATTING HELPERS
  String _formatTime(DateTime timestamp) {
    return DateFormat('hh:mm a').format(timestamp);
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && _scrollController.position.maxScrollExtent > 0) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatRecordingTime() {
    return _formatDuration(_recordingSeconds);
  }

  // REPLY PREVIEW WIDGET
  Widget _buildReplyPreview() {
    if (!isReplying || repliedMessage == null) return const SizedBox.shrink();

    final isMyMessage = repliedMessage!['senderId'] == widget.currentUserId;
    final senderName = isMyMessage ? 'You' : widget.receiverName;
    final messageType = repliedMessage!['messageType'] ?? 'text';
    final message = repliedMessage!['message'];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: Colors.red.withOpacity(0.8),
            width: 4,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to $senderName',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                if (messageType == 'text')
                  Text(
                    message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  )
                else if (messageType == 'image')
                  Row(
                    children: [
                      const Icon(Icons.image, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        'Image',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  )
                else if (messageType == 'voice')
                    Row(
                      children: [
                        const Icon(Icons.mic, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          'Voice message',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
              ],
            ),
          ),
          IconButton(
            onPressed: _cancelReply,
            icon: const Icon(Icons.close, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // EDIT PREVIEW WIDGET
  Widget _buildEditPreview() {
    if (!isEditing || editingMessage == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: Colors.blue.withOpacity(0.8),
            width: 4,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Editing message',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Original: ${editingMessage!['message']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _cancelEdit,
            icon: const Icon(Icons.close, size: 20, color: Colors.blue),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // SWIPEABLE MESSAGE WIDGET
  Widget _swipeableMessage({
    required Widget child,
    required Map<String, dynamic> messageData,
    required bool isMine,
  }) {
    final messageId = messageData['messageId'];
    final isSwiped = _swipedMessage?['messageId'] == messageId;

    return GestureDetector(
      onHorizontalDragStart: (details) =>
          _onHorizontalDragStart(details, messageData, isMine),
      onHorizontalDragUpdate: (details) => _onHorizontalDragUpdate(details, isMine),
      onHorizontalDragEnd: (details) => _onHorizontalDragEnd(details, isMine),
      child: Stack(
        children: [
          if (isSwiped && _showSwipeIndicator)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _swipeAnimation!,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_dragOffset * _swipeAnimation!.value, 0),
                    child: Container(
                      color: Colors.grey.withOpacity(0.1),
                      child: Row(
                        mainAxisAlignment: isMine
                            ? MainAxisAlignment.start
                            : MainAxisAlignment.end,
                        children: [
                          if (isMine)
                            Padding(
                              padding: const EdgeInsets.only(left: 20),
                              child: Icon(
                                Icons.reply,
                                color: Colors.grey.withOpacity(_swipeAnimation!.value),
                              ),
                            ),
                          if (!isMine)
                            Padding(
                              padding: const EdgeInsets.only(right: 20),
                              child: Icon(
                                Icons.reply,
                                color: Colors.grey.withOpacity(_swipeAnimation!.value),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          Transform.translate(
            offset: Offset(isSwiped ? _dragOffset : 0.0, 0.0),
            child: child,
          ),
        ],
      ),
    );
  }

  // Message bubble with swipe reply
  Widget _messageBubble({
    required bool isMine,
    required String text,
    required DateTime timestamp,
    required String messageType,
    required bool isRead,
    required int? duration,
    required Map<String, dynamic> messageData,
    required Map<String, dynamic>? repliedTo,
    required bool isEdited,
  }) {
    final time = _formatTime(timestamp);
    final userName = isMine ? widget.currentUserName : widget.receiverName;

    final messageContent = GestureDetector(
      onLongPress: () {
        if (mounted) {
          setState(() {
            selectedMessage = messageData;
            selectedMine = isMine;
            showActionOverlay = true;
          });
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMine) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
                    child: Text(
                      userName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],

                if (repliedTo != null) ...[
                  Container(
                    width: 260,
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border(
                        left: BorderSide(
                          color: Colors.grey.withOpacity(0.5),
                          width: 3,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          repliedTo['senderName'] ?? 'User',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          repliedTo['messageType'] == 'text'
                              ? repliedTo['message']
                              : repliedTo['messageType'] == 'image'
                              ? '📷 Image'
                              : '🎤 Voice message',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  constraints: const BoxConstraints(maxWidth: 260),
                  decoration: BoxDecoration(
                    color: isMine ? null : const Color(0xFFF2F2F2),
                    gradient: isMine
                        ? const LinearGradient(
                      colors: [Color(0xFFE53935), Color(0xFFEC407A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                        : null,
                    borderRadius: isMine
                        ? const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    )
                        : const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMessageContent(
                        text: text,
                        messageType: messageType,
                        isMine: isMine,
                        duration: duration,
                      ),
                      if (isEdited)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            'Edited',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      time,
                      style: const TextStyle(color: Colors.black45, fontSize: 11),
                    ),
                    if (isMine) ...[
                      const SizedBox(width: 4),
                      Icon(
                        isRead ? Icons.done_all : Icons.done,
                        size: 17,
                        color: isRead ? Colors.lightGreen : Colors.grey,
                      ),
                    ]
                  ],
                ),
              ],
            ),
            if (isMine) ...[
              const SizedBox(width: 10),
            ],
          ],
        ),
      ),
    );

    return _swipeableMessage(
      child: messageContent,
      messageData: messageData,
      isMine: isMine,
    );
  }

  Widget _buildMessageContent({
    required String text,
    required String messageType,
    required bool isMine,
    required int? duration,
  }) {
    switch (messageType) {
      case 'image':
        return GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => Dialog(
                backgroundColor: Colors.transparent,
                child: Stack(
                  children: [
                    InteractiveViewer(
                      child: Image.network(
                        text,
                        fit: BoxFit.contain,
                      ),
                    ),
                    Positioned(
                      top: 16,
                      right: 16,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              text,
              width: 200,
              height: 150,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  width: 200,
                  height: 150,
                  color: Colors.grey[200],
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      case 'voice':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.mic,
                color: isMine ? Colors.white : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Voice: ${_formatDuration(duration ?? 0)}',
                style: TextStyle(
                  color: isMine ? Colors.white : Colors.black87,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      default:
        return Text(
          text,
          style: TextStyle(
            color: isMine ? Colors.white : Colors.black87,
            fontSize: 14,
            height: 1.25,
          ),
        );
    }
  }

  // FULLSCREEN OVERLAY MENU
  Widget _fullScreenActionOverlay() {
    return GestureDetector(
      onTap: () {
        if (mounted) {
          setState(() => showActionOverlay = false);
        }
      },
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black.withOpacity(0.55),
        child: Center(
          child: Container(
            width: 320,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(22),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selectedMessage != null &&
                    selectedMessage!['messageType'] == 'text')
                  _menuItem(Icons.reply, "Reply", () {
                    _setReplyMessage(selectedMessage!);
                  }),
                if (selectedMessage != null &&
                    selectedMessage!['messageType'] == 'text')
                  _menuItem(Icons.copy, "Copy", _copyMessage),
                if (selectedMessage != null &&
                    selectedMine &&
                    selectedMessage!['messageType'] == 'text')
                  _menuItem(Icons.edit, "Edit", () {
                    _setEditMessage(selectedMessage!);
                  }),
                _menuItem(Icons.delete, "Delete", () {
                  if (mounted) {
                    setState(() {
                      showActionOverlay = false;
                      showDeletePopup = true;
                    });
                  }
                }, isDelete: true),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _deletePopupOverlay() {
    return GestureDetector(
      onTap: () {
        if (mounted) {
          setState(() => showDeletePopup = false);
        }
      },
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black.withOpacity(0.55),
        child: Center(
          child: Container(
            width: 300,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(22),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _menuItem(Icons.delete_outline, "Delete only for you", () {
                  _deleteMessage(false);
                }, isDelete: true),
                if (selectedMine)
                  _menuItem(Icons.delete, "Delete for everyone", () {
                    _deleteMessage(true);
                  }, isDelete: true),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _menuItem(IconData icon, String text, VoidCallback onTap,
      {bool isDelete = false}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
        child: Row(
          children: [
            Icon(icon, color: isDelete ? Colors.red : Colors.white, size: 20),
            const SizedBox(width: 14),
            Text(
              text,
              style: TextStyle(
                color: isDelete ? Colors.red : Colors.white,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomInputBar() {
    final hasText = isEditing
        ? _editController.text.trim().isNotEmpty
        : _messageController.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 14, top: 6),
      child: Column(
        children: [
          if (isReplying) _buildReplyPreview(),
          if (isEditing) _buildEditPreview(),
          Row(
            children: [

              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F1F1),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: isEditing
                              ? _editController
                              : _messageController,
                          decoration: InputDecoration(
                            hintText: isEditing
                                ? "Edit your message..."
                                : "Type your message...",
                            border: InputBorder.none,
                          ),
                          onChanged: (value) {
                            if (mounted) {
                              setState(() {});
                            }
                          },
                          onSubmitted: (_) => isEditing ? _editMessage() : _sendMessage(),
                        ),
                      ),
                      if (hasText)
                        IconButton(
                          onPressed: isEditing ? _editMessage : _sendMessage,
                          icon: const Icon(
                            Icons.send,
                            color: Color(0xFFE53935),
                          ),
                          padding: const EdgeInsets.all(6),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (isEditing)
                IconButton(
                  onPressed: _editMessage,
                  icon: const Icon(Icons.check, color: Color(0xFFE53935)),
                ),

            ],
          ),
        ],
      ),
    );
  }

  Widget _bottomSection() => _isRecording ? _voiceRecorderBar() : _bottomInputBar();

  Widget _voiceRecorderBar() {
    return Container(
      padding: const EdgeInsets.only(left: 14, right: 14, bottom: 14, top: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: _cancelRecording,
              child: const CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white,
                child: Icon(Icons.delete_outline, color: Colors.black54),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _formatRecordingTime(),
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Container(
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            const SizedBox(width: 14),
            GestureDetector(
              onTap: _stopRecording,
              child: const CircleAvatar(
                radius: 20,
                backgroundColor: Color(0xFFE53935),
                child: Icon(Icons.stop, color: Colors.white),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('chatRooms')
          .doc(widget.chatRoomId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          if (_isFirstLoad) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFE53935)),
            );
          } else {
            return _buildMessagesFromCache();
          }
        }

        final messages = snapshot.data!.docs;
        _isFirstLoad = false;

        // Convert to list and REVERSE to get ascending order (oldest first)
        _cachedMessages = messages.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data;
        }).toList().reversed.toList(); // REVERSE the list

        if (_cachedMessages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat, size: 60, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'Start a conversation!',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        // Scroll to bottom when messages are first loaded
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });

        return _buildMessagesFromCache();
      },
    );
  }
  Widget _buildMessagesFromCache() {
    final List<Widget> messageWidgets = [];

    // Group messages by date
    final Map<String, List<Map<String, dynamic>>> groupedMessages = {};

    for (final data in _cachedMessages) {
      final isDeletedForSender = data['isDeletedForSender'] ?? false;
      final isDeletedForReceiver = data['isDeletedForReceiver'] ?? false;
      final isMine = data['senderId'] == widget.currentUserId;
      final isDeleted = isMine ? isDeletedForSender : isDeletedForReceiver;

      if (isDeleted) continue;

      final timestamp = (data['timestamp'] as Timestamp).toDate();
      final dateKey = _formatDateForGrouping(timestamp);

      groupedMessages.putIfAbsent(dateKey, () => []);
      groupedMessages[dateKey]!.add(data);
    }

    // Sort date keys in chronological order (oldest first)
    final sortedDateKeys = _sortDateKeysChronologically(groupedMessages.keys.toList());

    // Build widgets for each date group
    for (final dateKey in sortedDateKeys) {
      final messagesForDate = groupedMessages[dateKey]!;

      // Sort messages within each date group by timestamp (oldest first)
      messagesForDate.sort((a, b) {
        final timeA = (a['timestamp'] as Timestamp).toDate();
        final timeB = (b['timestamp'] as Timestamp).toDate();
        return timeA.compareTo(timeB);
      });

      // Add date separator/label
      messageWidgets.add(_dateSeparator(dateKey));

      // Add all messages for this date
      for (final data in messagesForDate) {
        final timestamp = (data['timestamp'] as Timestamp).toDate();

        messageWidgets.add(_messageBubble(
          isMine: data['senderId'] == widget.currentUserId,
          text: data['message'],
          timestamp: timestamp,
          messageType: data['messageType'] ?? 'text',
          isRead: data['isRead'] ?? false,
          duration: data['duration']?.toInt(),
          messageData: data,
          repliedTo: data['repliedTo'],
          isEdited: data['isEdited'] ?? false,
        ));
      }
    }

    return ListView.builder(
      reverse: false, // Keep as false for natural order
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      itemCount: messageWidgets.length,
      itemBuilder: (context, index) {
        return messageWidgets[index];
      },
    );
  }

// Helper method to sort date keys chronologically with Today at the bottom
  List<String> _sortDateKeysChronologically(List<String> dateKeys) {
    final uniqueKeys = dateKeys.toSet().toList();

    uniqueKeys.sort((a, b) {
      // Convert date strings to DateTime for comparison
      DateTime? dateA, dateB;

      if (a == 'Today') {
        dateA = DateTime.now();
      } else if (a == 'Yesterday') {
        dateA = DateTime.now().subtract(const Duration(days: 1));
      } else {
        try {
          dateA = DateFormat('MMM dd, yyyy').parse(a);
        } catch (e) {
          dateA = DateTime.now();
        }
      }

      if (b == 'Today') {
        dateB = DateTime.now();
      } else if (b == 'Yesterday') {
        dateB = DateTime.now().subtract(const Duration(days: 1));
      } else {
        try {
          dateB = DateFormat('MMM dd, yyyy').parse(b);
        } catch (e) {
          dateB = DateTime.now();
        }
      }

      // Sort chronologically (oldest first)
      return dateA.compareTo(dateB);
    });

    return uniqueKeys;
  }

// Format date for grouping
  String _formatDateForGrouping(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM dd, yyyy').format(date);
    }
  }

// Helper method to sort date keys in correct order: Today → Yesterday → Older dates


// Format date for grouping

// Enhanced date separator widget
  Widget _dateSeparator(String date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            date,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

// Update scrollToBottom method for correct scroll direction




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(60),
                  ),
                  child: Container(
                    color: Colors.white,
                    child: _buildMessagesList(),
                  ),
                ),
              ),
              _bottomSection(),
            ],
          ),

          if (showActionOverlay) _fullScreenActionOverlay(),
          if (showDeletePopup) _deletePopupOverlay(),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 45, left: 10, right: 10, bottom: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE53935), Color(0xFFEC407A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
          ),
          GestureDetector(
            onTap: (){
              Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen(userId: widget.receiverId,),));
            },
            child: CircleAvatar(
              radius: 22,
              backgroundImage: NetworkImage(
                  widget.receiverImage),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "${widget.receiverName}",
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 17),
            ),
          ),
          GestureDetector(
            onTap: () {
              print('tapped on call button');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CallScreen(
                    currentUserId: widget.currentUserId,
                    currentUserName: widget.currentUserName,
                    otherUserId: widget.receiverId,
                    otherUserName: widget.receiverName,
                  ),
                ),
              );
            },
            child: Container(
              child: const Icon(Icons.call, color: Colors.white),
            ),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VideoCallScreen(
                    currentUserId: widget.currentUserId,
                    currentUserName: widget.currentUserName,
                    otherUserId: widget.receiverId,
                    otherUserName: widget.receiverName,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.videocam, color: Colors.white),
          ),
          PopupMenuButton<String>(
            onSelected: (String result) {
              if (result == 'block') {
                _showBlockProfileDialog(context);
              } else if (result == 'report') {
                _showReportDialog(context);
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'block',
                child: Row(
                  children: [
                    Icon(
                      _isBlocked ? Icons.check_circle : Icons.block,
                      color: _isBlocked ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(_isBlocked ? 'Unblock Profile' : 'Block Profile'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.flag, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Text('Report'),
                  ],
                ),
              ),
            ],
            icon: const Icon(Icons.more_vert, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Report Profile'),
          content: const Text(
              'Are you sure you want to report this profile? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () {
                debugPrint('Profile reported!');
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Profile reported successfully!')),
                );
              },
              child: Text('REPORT',
                  style: TextStyle(color: Theme.of(context).primaryColor)),
            ),
          ],
        );
      },
    );
  }


  void _showBlockProfileDialog(BuildContext context) async {
    if (_isBlocked) {
      // Show unblock confirmation
      showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Unblock Profile'),
            content: const Text('Are you sure you want to unblock this profile? They will be able to contact you again.'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () => _unblockUser(dialogContext),
                child: Text(
                  'UNBLOCK',
                  style: TextStyle(color: Theme.of(context).primaryColor),
                ),
              ),
            ],
          );
        },
      );
    } else {
      // Show block confirmation
      showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Block Profile'),
            content: const Text('Are you sure you want to block this profile? They will not be able to contact you or see your profile.'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () => _blockUser(dialogContext),
                child: Text(
                  'BLOCK',
                  style: TextStyle(color: Theme.of(context).primaryColor),
                ),
              ),
            ],
          );
        },
      );
    }
  }

bool  _isBlocked = false;
 bool  _isLoadingBlock = true;
  Future<void> _blockUser(BuildContext dialogContext) async {
    setState(() {
      _isLoadingBlock = true;
    });

    Navigator.of(dialogContext).pop(); // Close dialog

    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');
      final userData = jsonDecode(userDataString!);
      final myId = userData["id"].toString();

      final service = ProfileService();
      final result = await service.blockUser(
        myId: myId,
        userId: widget.receiverId,
      );

      if (mounted) {
        if (result['status'] == 'success') {
          setState(() {
            _isBlocked = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile blocked successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to block user'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingBlock = false;
        });
      }
    }
  }

  Future<void> _unblockUser(BuildContext dialogContext) async {
    setState(() {
      _isLoadingBlock = true;
    });

    Navigator.of(dialogContext).pop(); // Close dialog

    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');
      final userData = jsonDecode(userDataString!);
      final myId = userData["id"].toString();

      final service = ProfileService();
      final result = await service.unblockUser(
        myId: myId,
        userId: widget.receiverId,
      );

      if (mounted) {
        if (result['status'] == 'success') {
          setState(() {
            _isBlocked = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile unblocked successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to unblock user'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingBlock = false;
        });
      }
    }
  }

}
