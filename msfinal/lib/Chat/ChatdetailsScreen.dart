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
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';

import '../Calling/OutgoingCall.dart';
import '../Calling/videocall.dart';
import '../Calling/call_history_model.dart';
import '../Calling/call_history_service.dart';
import '../otherenew/othernew.dart';
import '../otherenew/service.dart';
import '../pushnotification/pushservice.dart';
import '../webrtc/webrtc.dart';
import 'call_overlay_manager.dart';

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
  final FocusNode _messageFocusNode = FocusNode();

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

  // Audio playback
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _playingMessageId;
  bool _isPlaying = false;
  Duration _playbackPosition = Duration.zero;
  Duration _playbackDuration = Duration.zero;

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

  // Lazy loading variables
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;
  static const int _messagesPerPage = 20;
  DocumentSnapshot? _lastDocument;

  // Call history variables
  List<CallHistory> _callHistory = [];
  bool _showCallHistory = false;

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
    ScreenStateManager().onChatScreenOpened(
      widget.chatRoomId,
      widget.currentUserId,
      partnerUserId: widget.receiverId,
    );

    // Add observer for app lifecycle
    WidgetsBinding.instance.addObserver(this);

    // Audio player listeners
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          if (state == PlayerState.completed) {
            _playingMessageId = null;
            _playbackPosition = Duration.zero;
          }
        });
      }
    });
    _audioPlayer.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _playbackPosition = pos);
    });
    _audioPlayer.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _playbackDuration = dur);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
      // Auto-focus keyboard when chat opens
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _messageFocusNode.requestFocus();
        }
      });
    });

    _checkBlockStatus(); // Add this line
    _loadCallHistory(); // Load call history

    // Add scroll listener for lazy loading
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels <=
            _scrollController.position.minScrollExtent + 200 &&
        !_isLoadingMore &&
        _hasMoreMessages) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadCallHistory() async {
    try {
      // Get call history between current user and receiver
      final allCalls = await CallHistoryService.getCallHistoryPaginated(
        userId: widget.currentUserId,
        limit: 100,
      );

      // Filter calls for this specific chat
      final filteredCalls = allCalls.where((call) {
        return (call.callerId == widget.currentUserId &&
                call.recipientId == widget.receiverId) ||
            (call.recipientId == widget.currentUserId &&
                call.callerId == widget.receiverId);
      }).toList();

      if (mounted) {
        setState(() {
          _callHistory = filteredCalls;
        });
      }
    } catch (e) {
      print('Error loading call history: $e');
    }

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
    _messageFocusNode.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
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
        ScreenStateManager().onChatScreenOpened(
          widget.chatRoomId,
          widget.currentUserId,
          partnerUserId: widget.receiverId,
        );
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

  Future<void> _startRecording() async {
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Microphone permission required'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000, sampleRate: 44100),
        path: path,
      );

      _recordingSeconds = 0;
      _currentRecordingPath = path;
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() => _recordingSeconds++);
        }
      });

      if (mounted) setState(() => _isRecording = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start recording: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

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

  // VOICE PLAYBACK
  Future<void> _toggleVoicePlayback(String messageId, String audioUrl) async {
    if (_playingMessageId == messageId && _isPlaying) {
      await _audioPlayer.pause();
    } else if (_playingMessageId == messageId && !_isPlaying) {
      await _audioPlayer.resume();
    } else {
      _playbackPosition = Duration.zero;
      _playbackDuration = Duration.zero;
      if (mounted) setState(() => _playingMessageId = messageId);
      await _audioPlayer.play(UrlSource(audioUrl));
    }
  }


  Widget _buildReplyPreview() {
    if (!isReplying || repliedMessage == null) return const SizedBox.shrink();

    final isMyMessage = repliedMessage!['senderId'] == widget.currentUserId;
    final senderName = isMyMessage ? 'You' : widget.receiverName;
    final messageType = repliedMessage!['messageType'] ?? 'text';
    final message = repliedMessage!['message'];

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: const Color(0xFFF90E18),
            width: 4,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF90E18).withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
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
                    color: Color(0xFFF90E18),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                if (messageType == 'text')
                  Text(
                    message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  )
                else if (messageType == 'image')
                  Row(
                    children: [
                      const Icon(Icons.image, size: 15, color: Color(0xFFF90E18)),
                      const SizedBox(width: 4),
                      Text('Photo', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                    ],
                  )
                else if (messageType == 'voice')
                  Row(
                    children: [
                      const Icon(Icons.mic, size: 15, color: Color(0xFFF90E18)),
                      const SizedBox(width: 4),
                      Text('Voice message', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                    ],
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _cancelReply,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 16, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  // EDIT PREVIEW WIDGET
  Widget _buildEditPreview() {
    if (!isEditing || editingMessage == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: Color(0xFF2196F3), width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2196F3).withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
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
                    color: Color(0xFF2196F3),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  editingMessage!['message'],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _cancelEdit,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 16, color: Colors.grey),
            ),
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
        margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
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
                        fontSize: 13,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],

                if (repliedTo != null) ...[
                  Container(
                    width: 260,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: isMine
                          ? const Color(0xFFF90E18).withOpacity(0.10)
                          : const Color(0xFFF90E18).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border(
                        left: BorderSide(
                          color: const Color(0xFFF90E18),
                          width: 3.5,
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
                            color: Color(0xFFF90E18),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          repliedTo['messageType'] == 'text'
                              ? repliedTo['message']
                              : repliedTo['messageType'] == 'image'
                              ? '📷 Photo'
                              : '🎤 Voice message',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  constraints: const BoxConstraints(maxWidth: 320),
                  decoration: BoxDecoration(
                    color: isMine
                      ? const Color(0xFFDCF8C6)  // WhatsApp-like light green for sent messages
                      : Colors.white,
                    borderRadius: isMine
                        ? const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(2),
                    )
                        : const BorderRadius.only(
                      topLeft: Radius.circular(2),
                      topRight: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMessageContent(
                        text: text,
                        messageType: messageType,
                        isMine: isMine,
                        duration: duration,
                        messageId: messageData['messageId'] ?? '',
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
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      time,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    if (isMine) ...[
                      const SizedBox(width: 4),
                      Icon(
                        isRead ? Icons.done_all : Icons.done,
                        size: 16,
                        color: isRead ? const Color(0xFF34B7F1) : Colors.grey.shade500,
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
    required String messageId,
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
        final isCurrentlyPlaying = _playingMessageId == messageId && _isPlaying;
        final isCurrentMessage = _playingMessageId == messageId;
        final totalSecs = duration ?? 0;
        final progressValue = isCurrentMessage && _playbackDuration.inSeconds > 0
            ? (_playbackPosition.inMilliseconds / _playbackDuration.inMilliseconds).clamp(0.0, 1.0)
            : 0.0;
        final displayTime = isCurrentMessage && _playbackDuration.inSeconds > 0
            ? _formatDuration(_playbackPosition.inSeconds)
            : _formatDuration(totalSecs);
        return GestureDetector(
          onTap: () => _toggleVoicePlayback(messageId, text),
          child: SizedBox(
            width: 200,
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isMine
                      ? const Color(0xFF128C7E)  // Dark green for sent voice messages
                      : const Color(0xFFF90E18).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCurrentlyPlaying ? Icons.pause : Icons.play_arrow,
                    color: isMine ? Colors.white : const Color(0xFFF90E18),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progressValue,
                          minHeight: 3,
                          backgroundColor: Colors.grey.withOpacity(0.25),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isMine ? const Color(0xFF128C7E) : const Color(0xFFF90E18),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        displayTime,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      default:
        return Text(
          text,
          style: const TextStyle(
            color: Color(0xFF303030),
            fontSize: 16,
            height: 1.4,
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
      padding: const EdgeInsets.only(left: 10, right: 10, bottom: 16, top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          if (isReplying) _buildReplyPreview(),
          if (isEditing) _buildEditPreview(),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  constraints: const BoxConstraints(minHeight: 48),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.25),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: isEditing
                              ? _editController
                              : _messageController,
                          focusNode: _messageFocusNode,
                          minLines: 1,
                          maxLines: 5,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                          decoration: InputDecoration(
                            hintText: isEditing
                                ? "Edit your message..."
                                : "Type a message",
                            hintStyle: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 15,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 0,
                              vertical: 10,
                            ),
                          ),
                          onChanged: (value) {
                            if (mounted) {
                              setState(() {});
                            }
                          },
                          onSubmitted: (_) => isEditing ? _editMessage() : _sendMessage(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFF90E18), Color(0xFFD00D15)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: hasText
                      ? (isEditing ? _editMessage : _sendMessage)
                      : _startRecording,
                  icon: Icon(
                    hasText ? Icons.send : Icons.mic,
                    color: Colors.white,
                    size: 22,
                  ),
                  padding: const EdgeInsets.all(10),
                ),
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
      padding: const EdgeInsets.only(left: 10, right: 10, bottom: 16, top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0F0),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFFF90E18).withOpacity(0.2)),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: _cancelRecording,
              child: const CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white,
                child: Icon(Icons.delete_outline, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.mic, color: Color(0xFFF90E18), size: 18),
            const SizedBox(width: 6),
            Text(
              _formatRecordingTime(),
              style: const TextStyle(
                color: Color(0xFFF90E18),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Container(
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Text(
                    'Recording...',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            GestureDetector(
              onTap: _stopRecording,
              child: const CircleAvatar(
                radius: 20,
                backgroundColor: Color(0xFFF90E18),
                child: Icon(Icons.send, color: Colors.white, size: 18),
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
          .limit(_messagesPerPage)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          if (_isFirstLoad) {
            return _buildSkeletonLoader();
          } else {
            return _buildMessagesFromCache();
          }
        }

        final messages = snapshot.data!.docs;
        _isFirstLoad = false;

        // Update last document for pagination
        if (messages.isNotEmpty) {
          _lastDocument = messages.last;
        }

        // Convert to list and REVERSE to get ascending order (oldest first)
        _cachedMessages = messages.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data;
        }).toList().reversed.toList(); // REVERSE the list

        if (_cachedMessages.isEmpty && _callHistory.isEmpty) {
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

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages || _lastDocument == null) return;

    setState(() => _isLoadingMore = true);

    try {
      final moreMessages = await _firestore
          .collection('chatRooms')
          .doc(widget.chatRoomId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_messagesPerPage)
          .get();

      if (moreMessages.docs.isEmpty) {
        setState(() {
          _hasMoreMessages = false;
          _isLoadingMore = false;
        });
        return;
      }

      _lastDocument = moreMessages.docs.last;

      final newMessages = moreMessages.docs.map((doc) {
        return doc.data() as Map<String, dynamic>;
      }).toList();

      setState(() {
        // Add new messages at the beginning (they are older)
        _cachedMessages.insertAll(0, newMessages.reversed);
        _isLoadingMore = false;
      });
    } catch (e) {
      print('Error loading more messages: $e');
      setState(() => _isLoadingMore = false);
    }
  }

  Widget _buildSkeletonLoader() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      itemCount: 8,
      itemBuilder: (context, index) {
        final isLeft = index % 2 == 0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment:
                isLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
            children: [
              Container(
                constraints: BoxConstraints(maxWidth: 280),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 150 + (index * 20.0) % 80,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 100,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  Widget _buildMessagesFromCache() {
    final List<Widget> messageWidgets = [];

    // Add loading indicator at the top if loading more
    if (_isLoadingMore) {
      messageWidgets.add(
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF90E18)),
              ),
            ),
          ),
        ),
      );
    }

    // Add call history section at the top if there are calls
    if (_callHistory.isNotEmpty) {
      messageWidgets.add(_buildCallHistorySection());
    }

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

  Widget _buildCallHistorySection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20, top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with toggle button
          GestureDetector(
            onTap: () {
              setState(() {
                _showCallHistory = !_showCallHistory;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF90E18), Color(0xFFD00D15)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF90E18).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.history, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'कल हिस्ट्री',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_callHistory.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _showCallHistory
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
          // Call history list
          if (_showCallHistory) ...[
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: _callHistory.take(10).map((call) {
                  return _buildCallHistoryItem(call);
                }).toList(),
              ),
            ),
            if (_callHistory.length > 10)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: Text(
                    '... र ${_callHistory.length - 10} थप कलहरू',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildCallHistoryItem(CallHistory call) {
    final isIncoming = call.isIncoming(widget.currentUserId);

    // Status icon based on call type and direction
    IconData statusIcon;
    Color statusColor;

    if (call.status == CallStatus.missed && isIncoming) {
      statusIcon = Icons.call_missed;
      statusColor = Colors.red;
    } else if (call.status == CallStatus.declined) {
      statusIcon = Icons.call_end;
      statusColor = Colors.red;
    } else if (call.status == CallStatus.cancelled) {
      statusIcon = Icons.call_missed_outgoing;
      statusColor = Colors.orange;
    } else if (isIncoming) {
      statusIcon = Icons.call_received;
      statusColor = Colors.green;
    } else {
      statusIcon = Icons.call_made;
      statusColor = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Call type icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              call.callType == CallType.video ? Icons.videocam : Icons.call,
              color: statusColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          // Call details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        isIncoming ? 'आगमन कल' : 'बहिर्गमन कल',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  _formatCallDateTime(call.startTime),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          // Duration or status
          if (call.status == CallStatus.completed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                call.getFormattedDuration(),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                call.getStatusText(widget.currentUserId),
                style: TextStyle(
                  fontSize: 11,
                  color: statusColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatCallDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return 'आज ${DateFormat('HH:mm').format(dateTime)}';
    } else if (difference.inDays == 1) {
      return 'हिजो ${DateFormat('HH:mm').format(dateTime)}';
    } else if (difference.inDays < 7) {
      final dayNames = ['आइत', 'सोम', 'मंगल', 'बुध', 'बिहि', 'शुक्र', 'शनि'];
      return '${dayNames[dateTime.weekday % 7]} ${DateFormat('HH:mm').format(dateTime)}';
    } else {
      return DateFormat('yyyy/MM/dd HH:mm').format(dateTime);
    }
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
      backgroundColor: const Color(0xFFECE5DD),  // WhatsApp-like beige background
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: Container(
                  color: const Color(0xFFFAF0F0),
                  child: _buildMessagesList(),
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
      padding: const EdgeInsets.only(top: 45, left: 6, right: 6, bottom: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF90E18), Color(0xFFD00D15)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x33F90E18),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${widget.receiverName}",
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 17),
                ),
                const Text(
                  "online",
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              print('tapped on call button');
              Navigator.push(
                context,
                MaterialPageRoute(
                  settings: const RouteSettings(name: activeCallRouteName),
                  builder: (context) => CallScreen(
                    currentUserId: widget.currentUserId,
                    currentUserName: widget.currentUserName,
                    currentUserImage: widget.currentUserImage,
                    otherUserId: widget.receiverId,
                    otherUserName: widget.receiverName,
                    otherUserImage: widget.receiverImage,
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
                  settings: const RouteSettings(name: activeCallRouteName),
                  builder: (context) => VideoCallScreen(
                    currentUserId: widget.currentUserId,
                    currentUserName: widget.currentUserName,
                    currentUserImage: widget.currentUserImage,
                    otherUserId: widget.receiverId,
                    otherUserName: widget.receiverName,
                    otherUserImage: widget.receiverImage,
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
            icon: const Icon(Icons.more_vert, color: Colors.white),
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
