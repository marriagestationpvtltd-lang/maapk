// lib/screens/ChatDetailScreen.dart
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:ms2026/Chat/screen_state_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

import '../service/socket_service.dart';
import '../Calling/videocall.dart';
import '../Calling/call_history_model.dart';
import '../Calling/call_history_service.dart';
import '../Calling/callmanager.dart';
import '../Calling/incommingcall.dart';
import '../Calling/incomingvideocall.dart';
import '../otherprofile/otherprofileview.dart';
import '../otherenew/othernew.dart';
import '../otherenew/service.dart';
import '../pushnotification/pushservice.dart';
import 'call_overlay_manager.dart';
import 'widgets/typing_indicator.dart';
import '../constant/constant.dart';
import '../utils/time_utils.dart';
import '../utils/image_utils.dart';
import '../utils/privacy_utils.dart';

class ChatDetailScreen extends StatefulWidget {
  final String chatRoomId;
  final String receiverId;
  final String receiverName;
  final String receiverImage;
  final String? receiverPrivacy;
  final String? receiverPhotoRequest;
  final String currentUserId;
  final String currentUserName;
  final String currentUserImage;

  const ChatDetailScreen({
    super.key,
    required this.chatRoomId,
    required this.receiverId,
    required this.receiverName,
    required this.receiverImage,
    this.receiverPrivacy,
    this.receiverPhotoRequest,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserImage,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final SocketService _socketService = SocketService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = Uuid();

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

  // Send guard to prevent duplicate messages
  bool _isSending = false;

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

  // Track whether the compose field has text (avoids per-keystroke full rebuild)
  bool _hasText = false;

  // Message-widget cache: rebuilt only when messages/highlight/loading state changes
  List<Widget>? _cachedMessageWidgets;
  int _messagesCacheVersion = 0;
  int _lastBuiltVersion = -1;
  String? _lastBuiltHighlightId;
  bool _lastBuiltIsLoadingMore = false;

  // Lazy loading variables
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;
  static const int _messagesPerPage = 20;
  // Pagination cursor – only updated on first load and during loadMore (never on stream updates)
  int _currentMessagePage = 1;

  // Call history variables
  List<CallHistory> _callHistory = [];
  bool _showCallHistory = false;
  StreamSubscription? _callHistorySubscription;

  // Backup incoming call listener (mirrors AdminChatScreen logic)
  StreamSubscription<Map<String, dynamic>>? _callListenerSubscription;

  // Messages stream subscription (replaces StreamBuilder to prevent rebuild-on-setState)
  StreamSubscription? _messagesSubscription;

  // Typing indicator
  Timer? _typingDebounce;
  bool _isReceiverTyping = false;
  StreamSubscription? _typingSubscription;
  bool _isMarkingMessagesAsRead = false;
  bool _isReceiverViewingThisChat = false;

  // Receiver online status
  bool _isOtherUserOnline = false;
  DateTime? _otherUserLastSeen;
  StreamSubscription? _otherUserStatusSub;
  StreamSubscription? _audioPlayerStateSubscription;
  StreamSubscription? _audioPlayerPositionSubscription;
  StreamSubscription? _audioPlayerDurationSubscription;
  // Track whether the next scroll-to-bottom should be forced (own message sent)
  bool _forceScrollToBottom = false;

  // Scroll-to-reply + highlight
  final Map<String, GlobalKey> _messageKeys = {};
  String? _highlightedMessageId;

  // Delivered status (hover for web)
  String? _hoveredMessageId;

  // Block / photo-privacy state
  bool _isBlocked = false;
  bool _isLoadingBlock = true;
  String _photoRequestStatus = 'not_sent';
  String _privacyStatus = 'private';

  // Timing constants
  static const int _kTypingTimeoutSeconds = 5;
  static const Duration _kTypingDebounceDelay = Duration(seconds: 3);
  static const Duration _kHighlightDuration = Duration(milliseconds: 700);
  static const Duration _kActiveChatPresenceWindow = Duration(seconds: 30);

  static const LinearGradient _primaryGradient = LinearGradient(
    colors: [Color(0xFFF90E18), Color(0xFFD00D15)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient _secondaryGradient = LinearGradient(
    colors: [Color(0xFFFFE4E6), Color(0xFFFFF1F2)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  static const Color _accentColor = Color(0xFFF90E18);
  static const Color _backgroundColor = Color(0xFFF8FAFC);
  static const Color _textColor = Color(0xFF1F2937);
  static const Color _lightTextColor = Color(0xFF6B7280);
  static const Color _inputFieldBackground = Color(0xFFF3F4F6);
  static const Color _sendButtonDisabled = Color(0xFFD1D5DB);

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

    // Defer heavy init work off the first frame so the screen opens instantly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markMessagesAsRead();
      _checkBlockStatus();
      _loadCallHistory();
      _fetchPhotoRequestStatus();
    });

    // Set chat as active when screen opens
    ScreenStateManager().onChatScreenOpened(
      widget.chatRoomId,
      widget.currentUserId,
      partnerUserId: widget.receiverId,
    );
    _updateActiveChatPresence(true);

    // Add observer for app lifecycle
    WidgetsBinding.instance.addObserver(this);

    // Audio player listeners
    _audioPlayerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
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
    _audioPlayerPositionSubscription = _audioPlayer.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _playbackPosition = pos);
    });
    _audioPlayerDurationSubscription = _audioPlayer.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _playbackDuration = dur);
    });

    // Update _hasText without a full rebuild on every keystroke
    _messageController.addListener(_onMessageTextChanged);

    // Add scroll listener for lazy loading
    _scrollController.addListener(_onScroll);

    // Start listening to messages (dedicated subscription to avoid merge running on every setState)
    _listenToMessages();

    // Start listening to receiver's typing status
    _listenToTypingStatus();

    // Start listening to receiver's online status
    _startReceiverStatusListener();

    // Backup incoming call listener so calls ring while typing on this screen.
    // The global CallOverlayWrapper is the primary handler; this ensures the
    // call UI still appears if the global handler's frame callback is delayed
    // (e.g. keyboard open with no pending frames).
    _setupCallListener();
  }

  void _onMessageTextChanged() {
    final hasText = _messageController.text.trim().isNotEmpty;
    if (hasText != _hasText && mounted) {
      setState(() => _hasText = hasText);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels <=
            _scrollController.position.minScrollExtent + 200 &&
        !_isLoadingMore &&
        _hasMoreMessages) {
      _loadMoreMessages();
    }
  }

  void _listenToMessages() {
    // Load initial page via Socket.IO request-response
    _socketService.joinRoom(widget.chatRoomId);
    _socketService.getMessages(widget.chatRoomId, page: 1, limit: _messagesPerPage).then((result) {
      if (!mounted) return;
      final messages = List<Map<String, dynamic>>.from(
        (result['messages'] as List? ?? []).map((m) => Map<String, dynamic>.from(m as Map)),
      );
      setState(() {
        _isFirstLoad = false;
        _cachedMessages = messages;
        _hasMoreMessages = result['hasMore'] == true;
        _currentMessagePage = 1;
        _messagesCacheVersion++;
      });
      _scrollToBottom(jump: true);
    }).catchError((e) {
      debugPrint('Error loading messages: $e');
      if (mounted) setState(() => _isFirstLoad = false);
    });

    // Real-time new messages
    _messagesSubscription = _socketService.onNewMessage.listen((data) {
      if (!mounted) return;
      if (data['chatRoomId']?.toString() != widget.chatRoomId) return;

      final newMsg = Map<String, dynamic>.from(data);
      // Normalise timestamp to DateTime for UI consistency
      final ts = SocketService.parseTimestamp(newMsg['timestamp']);
      if (ts != null) newMsg['timestamp'] = ts;

      final existingIdx = _cachedMessages.indexWhere(
        (m) => m['messageId']?.toString() == newMsg['messageId']?.toString(),
      );
      final shouldScroll = _forceScrollToBottom || _isNearBottom();

      setState(() {
        if (existingIdx >= 0) {
          _cachedMessages[existingIdx] = newMsg;
        } else {
          _cachedMessages.add(newMsg);
        }
        _messagesCacheVersion++;
        if (_forceScrollToBottom) _forceScrollToBottom = false;
      });

      _syncVisibleIncomingMessagesAsRead(_cachedMessages);
      if (shouldScroll) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    });

    // Listen for edits and deletes
    _socketService.onMessageEdited.listen((data) {
      if (!mounted) return;
      if (data['chatRoomId']?.toString() != widget.chatRoomId) return;
      final idx = _cachedMessages.indexWhere(
        (m) => m['messageId']?.toString() == data['messageId']?.toString(),
      );
      if (idx >= 0) {
        setState(() {
          _cachedMessages[idx] = {
            ..._cachedMessages[idx],
            'message':  data['newMessage'],
            'isEdited': true,
            'editedAt': data['editedAt'],
          };
          _messagesCacheVersion++;
        });
      }
    });

    _socketService.onMessageDeleted.listen((data) {
      if (!mounted) return;
      if (data['chatRoomId']?.toString() != widget.chatRoomId) return;
      final msgId = data['messageId']?.toString();
      if (data['deleteForEveryone'] == true) {
        setState(() {
          _cachedMessages.removeWhere((m) => m['messageId']?.toString() == msgId);
          _messagesCacheVersion++;
        });
      } else {
        final idx = _cachedMessages.indexWhere((m) => m['messageId']?.toString() == msgId);
        if (idx >= 0) {
          final isMine = data['userId']?.toString() == widget.currentUserId;
          setState(() {
            _cachedMessages[idx] = {
              ..._cachedMessages[idx],
              if (isMine) 'isDeletedForSender':   true,
              if (!isMine) 'isDeletedForReceiver': true,
            };
            _messagesCacheVersion++;
          });
        }
      }
    });
  }

  void _loadCallHistory() {
    // Use a live stream so the section updates whenever a call is made/ended
    _callHistorySubscription =
        CallHistoryService.getCallHistory(widget.currentUserId).listen(
      (allCalls) {
        // Filter calls for this specific chat partner
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
      },
      onError: (e) {
        print('Error loading call history: $e');
      },
    );
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

  Future<void> _fetchPhotoRequestStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');
      if (userDataString == null) return;

      final userData = jsonDecode(userDataString);
      final myId = userData["id"].toString();

      final service = ProfileService();
      final profileResponse = await service.fetchProfile(
        myId: myId,
        userId: widget.receiverId,
      );

      if (mounted) {
        setState(() {
          _photoRequestStatus = profileResponse.data.personalDetail.photoRequest;
          _privacyStatus = profileResponse.data.personalDetail.privacy;
        });
      }
    } catch (e) {
      debugPrint('Error fetching photo request status: $e');
    }
  }

  // ───────── TYPING INDICATOR ─────────

  void _listenToTypingStatus() {
    _typingSubscription = _socketService.onTypingStart.listen((data) {
      if (!mounted) return;
      if (data['chatRoomId']?.toString() != widget.chatRoomId) return;
      if (data['userId']?.toString() != widget.receiverId) return;
      if (!_isReceiverTyping) setState(() => _isReceiverTyping = true);
      // Reset auto-clear timeout
      _typingDebounce?.cancel();
      _typingDebounce = Timer(Duration(seconds: _kTypingTimeoutSeconds), () {
        if (mounted && _isReceiverTyping) setState(() => _isReceiverTyping = false);
      });
    });

    // Stop typing
    _socketService.onTypingStop.listen((data) {
      if (!mounted) return;
      if (data['chatRoomId']?.toString() != widget.chatRoomId) return;
      if (data['userId']?.toString() != widget.receiverId) return;
      _typingDebounce?.cancel();
      if (_isReceiverTyping) setState(() => _isReceiverTyping = false);
    });
  }

  void _startReceiverStatusListener() {
    _otherUserStatusSub?.cancel();
    _otherUserStatusSub = _socketService.onUserStatusChange.listen((data) {
      if (!mounted) return;
      if (data['userId']?.toString() != widget.receiverId) return;
      final bool online = data['isOnline'] == true;
      final DateTime? lastSeen = SocketService.parseTimestamp(data['lastSeen']);
      setState(() {
        _isOtherUserOnline = online;
        _otherUserLastSeen  = lastSeen;
      });
    });
  }

  /// Format lastSeen timestamp into a human-readable "last active" string.
  String _formatLastSeen(DateTime lastSeen) => formatLastSeen(lastSeen);


  void _onTypingChanged() {
    _typingDebounce?.cancel();
    _socketService.startTyping(widget.chatRoomId, widget.currentUserId);
    _typingDebounce = Timer(_kTypingDebounceDelay, _clearTyping);
  }

  void _clearTyping() {
    _socketService.stopTyping(widget.chatRoomId, widget.currentUserId);
  }

  // Backup incoming call listener so calls ring while the user is typing on
  // this screen.  The global CallOverlayWrapper is the primary handler; this
  // ensures the call UI still appears if its frame callback is delayed
  // (e.g. keyboard open with no frames being rendered).
  void _setupCallListener() {
    _callListenerSubscription?.cancel();
    _callListenerSubscription = NotificationService.incomingCalls.listen((data) {
      final isVideoCall =
          data['type'] == 'video_call' || data['isVideoCall'] == 'true';
      // Dismiss keyboard so it does not block the call screen.
      FocusManager.instance.primaryFocus?.unfocus();
      // Schedule a frame first so the postFrameCallback below fires immediately,
      // even when the app is idle (no frames being scheduled, e.g. keyboard open).
      WidgetsBinding.instance.scheduleFrame();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // isCallScreenShowing is set by whichever listener fires first (usually
        // CallOverlayWrapper).  Skip if the screen is already being shown.
        if (CallManager().isCallScreenShowing) return;
        CallManager().isCallScreenShowing = true;
        try {
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                  settings: const RouteSettings(name: activeCallRouteName),
                  fullscreenDialog: true,
                  builder: (_) => isVideoCall
                      ? IncomingVideoCallScreen(callData: data)
                      : IncomingCallScreen(callData: data),
                ),
              )
              .whenComplete(() {
            CallManager().isCallScreenShowing = false;
          });
        } catch (_) {
          // Reset the flag if push fails so future calls are not blocked.
          CallManager().isCallScreenShowing = false;
        }
      });
    });
  }

  Future<void> _setActiveChatPresence({required bool isActive}) async {
    _socketService.setActiveChat(widget.currentUserId, widget.chatRoomId, isActive: isActive);
  }

  void _updateActiveChatPresence(bool isActive) {
    unawaited(
      _setActiveChatPresence(isActive: isActive).catchError((Object error) {
        debugPrint('Error updating active chat presence: $error');
      }),
    );
  }

  void _syncVisibleIncomingMessagesAsRead(List<Map<String, dynamic>> messages) {
    if (_isMarkingMessagesAsRead) return;
    final hasUnreadIncoming = messages.any((message) =>
        message['receiverId'] == widget.currentUserId &&
        message['isRead'] != true);
    if (!hasUnreadIncoming) return;
    _markMessagesAsRead();
  }

  // ───────── SCROLL TO REPLIED MESSAGE ─────────

  /// Scroll to the message with [messageId] and briefly highlight it.
  void _scrollToMessage(String messageId) {
    final key = _messageKeys[messageId];
    if (key?.currentContext == null) {
      // Original message is not visible – inform the user
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Original message is not in view. Scroll up to find it.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    Scrollable.ensureVisible(
      key!.currentContext!,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      alignment: 0.3,
    );

    setState(() => _highlightedMessageId = messageId);
    Future.delayed(_kHighlightDuration, () {
      if (mounted) setState(() => _highlightedMessageId = null);
    });
  }
  @override
  void dispose() {
    // Clear chat active state when screen closes
    ScreenStateManager().onChatScreenClosed();
    _updateActiveChatPresence(false);
    WidgetsBinding.instance.removeObserver(this);
    _messageController.removeListener(_onMessageTextChanged);
    _messageController.dispose();
    _editController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _audioPlayerStateSubscription?.cancel();
    _audioPlayerPositionSubscription?.cancel();
    _audioPlayerDurationSubscription?.cancel();
    _audioPlayer.dispose();
    _swipeAnimationController?.dispose();
    _typingDebounce?.cancel();
    _typingSubscription?.cancel();
    _otherUserStatusSub?.cancel();
    _callHistorySubscription?.cancel();
    _callListenerSubscription?.cancel();
    _messagesSubscription?.cancel();
    _socketService.leaveRoom(widget.chatRoomId);
    _clearTyping(); // Remove our typing entry on exit
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
        _updateActiveChatPresence(true);
        _markMessagesAsRead();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      // App went to background, clear active state
        ScreenStateManager().onChatScreenClosed();
        _updateActiveChatPresence(false);
        break;
      case AppLifecycleState.detached:
      // App is closed
        ScreenStateManager().onChatScreenClosed();
        _updateActiveChatPresence(false);
        break;
      case AppLifecycleState.hidden:
      // App is hidden
        ScreenStateManager().onChatScreenClosed();
        _updateActiveChatPresence(false);
        break;
    }
  }

  // MARK MESSAGES AS READ
  Future<void> _markMessagesAsRead() async {
    if (_isMarkingMessagesAsRead) return;
    _isMarkingMessagesAsRead = true;
    try {
      await _markMessagesAsReadInternal();
    } finally {
      _isMarkingMessagesAsRead = false;
    }
  }

  Future<void> _markMessagesAsReadInternal() async {
    try {
      _socketService.markRead(widget.chatRoomId, widget.currentUserId);
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  // SEND MESSAGE (with reply support)
  Future<void> _sendMessage() async {
    if (_isBlocked) return;
    if (_isSending) return;
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    // Clear input immediately to prevent duplicate sends
    _messageController.clear();
    if (mounted) setState(() { _isSending = true; });

    try {
      final timestamp = DateTime.now();
      final messageId = _uuid.v4();
      final bool receiverViewingThisChat = _isReceiverViewingThisChat;

      // Prepare message data
      final messageData = {
        'messageId': messageId,
        'senderId': widget.currentUserId,
        'receiverId': widget.receiverId,
        'message': messageText,
        'messageType': 'text',
        'timestamp': timestamp,
        'isRead': receiverViewingThisChat,
        'isDelivered': receiverViewingThisChat,
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

      // Clear reply/edit states
      _cancelReply();
      _cancelEdit();

      // Force scroll to bottom after own message
      _forceScrollToBottom = true;
      _scrollToBottom();

      // Send via Socket.IO
      _socketService.sendMessage(
        chatRoomId:        widget.chatRoomId,
        senderId:          widget.currentUserId,
        receiverId:        widget.receiverId,
        message:           messageText,
        messageType:       'text',
        messageId:         messageId,
        repliedTo:         messageData['repliedTo'] as Map<String, dynamic>?,
        isReceiverViewing: receiverViewingThisChat,
        user1Name:         widget.currentUserName,
        user2Name:         widget.receiverName,
        user1Image:        widget.currentUserImage,
        user2Image:        widget.receiverImage,
      );

      if (!receiverViewingThisChat) {
        // Send notification after message is saved
        await NotificationService.sendChatNotification(
          recipientUserId: widget.receiverId.toString(),
          senderName: widget.currentUserName,
          senderId: widget.currentUserId.toString(),
          message: messageText,
        );
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() { _isSending = false; });
    }
  }

  bool _isSendingImage = false;

  Future<void> _pickAndSendImage() async {
    if (_isBlocked || _isSendingImage) return;
    final picker = ImagePicker();
    XFile? picked;
    try {
      picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to access gallery. Please check permissions.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    if (picked == null || !mounted) return;

    setState(() => _isSendingImage = true);
    try {
      final messageId = _uuid.v4();
      final file = File(picked.path);
      final bool receiverViewingThisChat = _isReceiverViewingThisChat;

      final imageUrl = await _socketService.uploadChatImage(
        imageFile: file,
        userId:    widget.currentUserId,
        chatRoomId: widget.chatRoomId,
      );

      _forceScrollToBottom = true;
      _scrollToBottom();

      _socketService.sendMessage(
        chatRoomId:        widget.chatRoomId,
        senderId:          widget.currentUserId,
        receiverId:        widget.receiverId,
        message:           imageUrl,
        messageType:       'image',
        messageId:         messageId,
        isReceiverViewing: receiverViewingThisChat,
        user1Name:         widget.currentUserName,
        user2Name:         widget.receiverName,
        user1Image:        widget.currentUserImage,
        user2Image:        widget.receiverImage,
      );

      if (!receiverViewingThisChat) {
        await NotificationService.sendChatNotification(
          recipientUserId: widget.receiverId.toString(),
          senderName: widget.currentUserName,
          senderId: widget.currentUserId.toString(),
          message: '📷 Photo',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingImage = false);
    }
  }

  Future<void> _editMessage() async {
    if (editingMessage == null || _editController.text.trim().isEmpty) return;

    try {
      final messageId = editingMessage!['messageId'];
      final newMessage = _editController.text.trim();

      _socketService.editMessage(widget.chatRoomId, messageId, newMessage);

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


  // MESSAGE ACTIONS
  Future<void> _deleteMessage(bool deleteForEveryone) async {
    if (selectedMessage == null) return;

    try {
      final messageId = selectedMessage!['messageId'];

      _socketService.deleteMessage(
        chatRoomId:        widget.chatRoomId,
        messageId:         messageId,
        userId:            widget.currentUserId,
        deleteForEveryone: deleteForEveryone,
      );

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

    _messageFocusNode.requestFocus();
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

    _messageFocusNode.requestFocus();
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

    final newOffset = _dragOffset + details.delta.dx;

    // Only accept leftward drag on own messages, rightward on others'
    if (isMine && newOffset > 0) return;
    if (!isMine && newOffset < 0) return;

    setState(() {
      _dragOffset = newOffset.clamp(-100.0, 100.0);
    });
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
  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && _scrollController.position.maxScrollExtent > 0) {
        if (jump) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        } else {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  /// Returns true when the user is within 150px of the bottom of the list.
  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    final pos = _scrollController.position;
    return pos.pixels >= pos.maxScrollExtent - 150;
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
        gradient: _secondaryGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: _accentColor,
            width: 4,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: _accentColor.withOpacity(0.10),
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
                  style: TextStyle(
                    fontSize: 12,
                    color: _accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                if (messageType == 'text')
                  Text(
                    message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: _lightTextColor),
                  )
                else if (messageType == 'image')
                  Row(
                    children: [
                      Icon(Icons.image, size: 15, color: _accentColor),
                      const SizedBox(width: 4),
                      Text('Photo',
                          style: TextStyle(fontSize: 13, color: _lightTextColor)),
                    ],
                  )
                else if (messageType == 'voice')
                  Row(
                    children: [
                      Icon(Icons.mic, size: 15, color: _accentColor),
                      const SizedBox(width: 4),
                      Text('Voice message',
                          style: TextStyle(fontSize: 13, color: _lightTextColor)),
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
        gradient: _secondaryGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: _accentColor, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: _accentColor.withOpacity(0.08),
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
                  'Editing message',
                  style: TextStyle(
                    fontSize: 12,
                    color: _accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  editingMessage!['message'],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: _lightTextColor),
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
    required bool isDelivered,
    required int? duration,
    required Map<String, dynamic> messageData,
    required Map<String, dynamic>? repliedTo,
    required bool isEdited,
  }) {
    final msgId = messageData['messageId'] as String? ?? '';
    // Assign a stable GlobalKey so we can scroll to this message
    final key = _messageKeys.putIfAbsent(msgId, () => GlobalKey());

    final time = _formatTime(timestamp);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isHighlighted = _highlightedMessageId == msgId;

    // Build the reply snippet widget (tappable to scroll to source)
    Widget? replyWidget;
    if (repliedTo != null) {
      replyWidget = GestureDetector(
        onTap: () {
          final replyId = repliedTo['messageId'] as String?;
          if (replyId != null) _scrollToMessage(replyId);
        },
        child: Container(
          width: 260,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            gradient: _secondaryGradient,
            borderRadius: BorderRadius.circular(10),
            border: Border(
              left: BorderSide(color: _accentColor, width: 3.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                repliedTo['senderName'] ?? 'User',
                style: TextStyle(
                  fontSize: 12,
                  color: _accentColor,
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
                style: TextStyle(fontSize: 13, color: _lightTextColor),
              ),
            ],
          ),
        ),
      );
    }

    // Choose tick icon based on delivery/read state
    Widget _buildTick() {
      if (isRead) {
        return Icon(Icons.done_all, size: 16, color: const Color(0xFF34B7F1));
      } else if (isDelivered) {
        return Icon(Icons.done_all, size: 16, color: Colors.grey.shade500);
      } else {
        return Icon(Icons.done, size: 16, color: Colors.grey.shade500);
      }
    }

    Widget messageContent = GestureDetector(
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
        key: key,
        margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
        decoration: BoxDecoration(
          color: isHighlighted ? _accentColor.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (replyWidget != null) replyWidget,

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  constraints: BoxConstraints(
                    maxWidth: screenWidth * 0.75,
                  ),
                  decoration: BoxDecoration(
                    gradient: isMine ? _primaryGradient : _secondaryGradient,
                    borderRadius: isMine
                        ? const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(4),
                    )
                        : const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(4),
                      bottomRight: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
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
                        Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            'Edited',
                            style: TextStyle(
                              fontSize: 10,
                              color: isMine ? Colors.white70 : _lightTextColor,
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
                        color: _lightTextColor,
                        fontSize: 12,
                      ),
                    ),
                    if (isMine) ...[
                      const SizedBox(width: 4),
                      _buildTick(),
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

    // Wrap with MouseRegion on web for hover quick-actions
    if (kIsWeb) {
      messageContent = MouseRegion(
        onEnter: (_) => setState(() => _hoveredMessageId = msgId),
        onExit: (_) => setState(() {
          if (_hoveredMessageId == msgId) _hoveredMessageId = null;
        }),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            messageContent,
            if (_hoveredMessageId == msgId)
              Positioned(
                top: 0,
                right: isMine ? null : -80,
                left: isMine ? -80 : null,
                child: _buildHoverActions(messageData, isMine),
              ),
          ],
        ),
      );
    }

    return _swipeableMessage(
      child: messageContent,
      messageData: messageData,
      isMine: isMine,
    );
  }

  /// Small row of quick-action buttons shown on hover (web only).
  Widget _buildHoverActions(Map<String, dynamic> msg, bool isMine) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _hoverActionBtn(Icons.reply, () => _setReplyMessage(msg)),
          if (isMine && msg['messageType'] == 'text')
            _hoverActionBtn(Icons.edit, () => _setEditMessage(msg)),
          _hoverActionBtn(Icons.delete, () {
            setState(() {
              selectedMessage = msg;
              selectedMine = isMine;
              showDeletePopup = true;
            });
          }, color: Colors.red),
        ],
      ),
    );
  }

  Widget _hoverActionBtn(IconData icon, VoidCallback onTap, {Color? color}) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 18, color: color ?? Colors.grey[700]),
      ),
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
        final bool shouldBlur = !isMine &&
            _privacyStatus.toLowerCase() != 'free' &&
            _photoRequestStatus.toLowerCase() != 'accepted';

        if (shouldBlur) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 200,
              height: 150,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Image.network(
                      text,
                      width: 200,
                      height: 150,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[300],
                      ),
                    ),
                  ),
                  Container(
                    color: Colors.black.withOpacity(0.4),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.red.shade600.withOpacity(0.9),
                            ),
                            child: const Icon(
                              Icons.lock,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Photo Protected',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => Dialog(
                backgroundColor: Colors.black,
                insetPadding: const EdgeInsets.all(8),
                child: Stack(
                  children: [
                    InteractiveViewer(
                      child: Image.network(
                        text,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
                        ),
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
                      ? Colors.white.withOpacity(0.20)
                      : _accentColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCurrentlyPlaying ? Icons.pause : Icons.play_arrow,
                    color: isMine ? Colors.white : _accentColor,
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
                            isMine ? Colors.white : _accentColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        displayTime,
                        style: TextStyle(
                          color: isMine ? Colors.white70 : _lightTextColor,
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
          style: TextStyle(
            color: isMine ? Colors.white : _textColor,
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
                // Reply is available for all message types
                if (selectedMessage != null)
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
    if (_isBlocked) {
      return Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).padding.bottom + 12,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.block, color: Colors.red.shade400, size: 18),
            const SizedBox(width: 8),
            Text(
              'You have blocked this user',
              style: TextStyle(
                color: Colors.red.shade400,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    final hasText = isEditing
        ? _editController.text.trim().isNotEmpty
        : _hasText;

    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isReplying) _buildReplyPreview(),
          if (isEditing) _buildEditPreview(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isEditing)
                Padding(
                  padding: const EdgeInsets.only(right: 6, bottom: 4),
                  child: _isSendingImage
                      ? const SizedBox(
                          width: 40,
                          height: 40,
                          child: Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(_accentColor),
                            ),
                          ),
                        )
                      : IconButton(
                          onPressed: _pickAndSendImage,
                          icon: const Icon(Icons.image_outlined, size: 24),
                          color: _accentColor,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        ),
                ),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 46),
                  decoration: BoxDecoration(
                    color: _inputFieldBackground,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: isEditing
                              ? _editController
                              : _messageController,
                          focusNode: _messageFocusNode,
                          minLines: 1,
                          maxLines: 5,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          style: const TextStyle(
                            fontSize: 15,
                            color: _textColor,
                            height: 1.4,
                          ),
                          decoration: InputDecoration(
                            hintText: isEditing
                                ? "Edit your message..."
                                : "Type a message...",
                            hintStyle: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 15,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 0,
                              vertical: 12,
                            ),
                          ),
                          onChanged: (value) {
                            // Fire typing indicator only when composing (not editing)
                            if (!isEditing && value.isNotEmpty) {
                              _onTypingChanged();
                            } else if (!isEditing && value.isEmpty) {
                              _clearTyping();
                            }
                          },
                          onSubmitted: (_) => isEditing ? _editMessage() : _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  gradient: hasText ? _primaryGradient : null,
                  color: hasText ? null : _sendButtonDisabled,
                  shape: BoxShape.circle,
                  boxShadow: hasText
                      ? [
                          BoxShadow(
                            color: _accentColor.withOpacity(0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [],
                ),
                child: IconButton(
                  onPressed: hasText ? (isEditing ? _editMessage : _sendMessage) : null,
                  icon: Icon(
                    isEditing ? Icons.check : Icons.send_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  padding: const EdgeInsets.all(13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bottomSection() => _bottomInputBar();

  Widget _buildMessagesList() {
    // Show skeleton on very first load before the stream delivers any data.
    if (_isFirstLoad) {
      return _buildSkeletonLoader();
    }

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

    return _buildMessagesFromCache();
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages) return;
    setState(() => _isLoadingMore = true);

    final double scrollExtentBefore = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent : 0.0;
    final double currentPixels = _scrollController.hasClients
        ? _scrollController.position.pixels : 0.0;

    try {
      final nextPage = _currentMessagePage + 1;
      final result = await _socketService.getMessages(
        widget.chatRoomId, page: nextPage, limit: _messagesPerPage,
      );
      if (!mounted) return;

      final newMessages = List<Map<String, dynamic>>.from(
        (result['messages'] as List? ?? []).map((m) => Map<String, dynamic>.from(m as Map)),
      );

      if (newMessages.isEmpty) {
        setState(() { _hasMoreMessages = false; _isLoadingMore = false; });
        return;
      }

      setState(() {
        _cachedMessages.insertAll(0, newMessages);
        _hasMoreMessages = result['hasMore'] == true;
        _currentMessagePage = nextPage;
        _isLoadingMore = false;
        _messagesCacheVersion++;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          final double scrollExtentAfter = _scrollController.position.maxScrollExtent;
          _scrollController.jumpTo(currentPixels + (scrollExtentAfter - scrollExtentBefore));
        }
      });
    } catch (e) {
      debugPrint('Error loading more messages: $e');
      if (mounted) setState(() => _isLoadingMore = false);
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
    // Reuse cached widget list when nothing relevant has changed.
    // Bypass cache while audio is actively playing so progress updates render correctly.
    final canUseCache = _cachedMessageWidgets != null &&
        _playingMessageId == null &&
        _lastBuiltVersion == _messagesCacheVersion &&
        _lastBuiltHighlightId == _highlightedMessageId &&
        _lastBuiltIsLoadingMore == _isLoadingMore;

    if (canUseCache) {
      return ListView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
        children: _cachedMessageWidgets!,
      );
    }

    final List<Widget> messageWidgets = [];

    // Add loading indicator at the top if loading more
    if (_isLoadingMore) {
      messageWidgets.add(
        Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(_accentColor),
              ),
            ),
          ),
        ),
      );
    }

    // Group messages by date
    final Map<String, List<Map<String, dynamic>>> groupedMessages = {};

    for (final data in _cachedMessages) {
      final isDeletedForSender = data['isDeletedForSender'] ?? false;
      final isDeletedForReceiver = data['isDeletedForReceiver'] ?? false;
      final isMine = data['senderId'] == widget.currentUserId;
      final isDeleted = isMine ? isDeletedForSender : isDeletedForReceiver;

      if (isDeleted) continue;

      final rawTs = data['timestamp'];
      if (rawTs == null) continue;
      final timestamp = rawTs is Timestamp
          ? rawTs.toDate()
          : rawTs is DateTime
              ? rawTs
              : null;
      if (timestamp == null) continue;
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
        final rawA = a['timestamp'];
        final rawB = b['timestamp'];
        if (rawA == null || rawB == null) return 0;
        final timeA = rawA is Timestamp
            ? rawA.toDate()
            : rawA is DateTime
                ? rawA
                : DateTime.now();
        final timeB = rawB is Timestamp
            ? rawB.toDate()
            : rawB is DateTime
                ? rawB
                : DateTime.now();
        return timeA.compareTo(timeB);
      });

      // Add date separator/label
      messageWidgets.add(_dateSeparator(dateKey));

      // Add all messages for this date
      for (final data in messagesForDate) {
        final rawTs = data['timestamp'];
        final timestamp = rawTs is Timestamp
            ? rawTs.toDate()
            : rawTs is DateTime
                ? rawTs
                : DateTime.now();

        if ((data['messageType'] ?? 'text') == 'call') {
          messageWidgets.add(_buildInlineCallBubble(
            callType: data['callType'] ?? 'audio',
            callStatus: data['callStatus'] ?? 'missed',
            duration: data['duration']?.toInt() ?? 0,
            callerId: data['senderId'] ?? '',
            timestamp: timestamp,
          ));
        } else {
          messageWidgets.add(_messageBubble(
            isMine: data['senderId'] == widget.currentUserId,
            text: data['message'],
            timestamp: timestamp,
            messageType: data['messageType'] ?? 'text',
            isRead: data['isRead'] ?? false,
            isDelivered: data['isDelivered'] ?? false,
            duration: data['duration']?.toInt(),
            messageData: data,
            repliedTo: data['repliedTo'],
            isEdited: data['isEdited'] ?? false,
          ));
        }
      }
    }

    // Cache for next rebuild
    _cachedMessageWidgets = messageWidgets;
    _lastBuiltVersion = _messagesCacheVersion;
    _lastBuiltHighlightId = _highlightedMessageId;
    _lastBuiltIsLoadingMore = _isLoadingMore;

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

  Widget _buildInlineCallBubble({
    required String callType,
    required String callStatus,
    required int duration,
    required String callerId,
    required DateTime timestamp,
  }) {
    final isVideo = callType == 'video';
    final isMissed = callStatus == 'missed' || callStatus == 'declined' || callStatus == 'cancelled';
    final isOutgoing = callerId == widget.currentUserId;

    Color iconColor;
    IconData directionIcon;
    if (isMissed) {
      iconColor = Colors.red;
      directionIcon = isVideo ? Icons.videocam_off : Icons.phone_missed;
    } else if (isOutgoing) {
      iconColor = const Color(0xFF25D366);
      directionIcon = isVideo ? Icons.videocam : Icons.call_made;
    } else {
      iconColor = const Color(0xFF25D366);
      directionIcon = isVideo ? Icons.videocam : Icons.call_received;
    }

    String label;
    if (isMissed) {
      label = isVideo ? 'Missed video call' : 'Missed voice call';
    } else if (isOutgoing) {
      label = isVideo ? 'Outgoing video call' : 'Outgoing voice call';
    } else {
      label = isVideo ? 'Incoming video call' : 'Incoming voice call';
    }

    String durationStr = '';
    if (!isMissed && duration > 0) {
      final m = duration ~/ 60;
      final s = duration % 60;
      durationStr = m > 0 ? '${m}m ${s}s' : '${s}s';
    }

    final timeStr = _formatTime(timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 260),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isMissed ? Colors.red.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isMissed ? Colors.red.withOpacity(0.3) : Colors.grey.withOpacity(0.25),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(directionIcon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isMissed ? Colors.red[700] : Colors.grey[800],
                      ),
                    ),
                    if (durationStr.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        durationStr,
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                timeStr,
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ),
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
                gradient: _primaryGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: _accentColor.withOpacity(0.30),
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
                      'Call History',
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
                gradient: _secondaryGradient,
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
                    '... and ${_callHistory.length - 10} more calls',
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
                        isIncoming ? 'Incoming Call' : 'Outgoing Call',
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
      return 'Today ${DateFormat('HH:mm').format(dateTime)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${DateFormat('HH:mm').format(dateTime)}';
    } else if (difference.inDays < 7) {
      final dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemStatusBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: _backgroundColor,
        body: Stack(
          children: [
            Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_backgroundColor, _backgroundColor.withOpacity(0.92)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
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
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final String resolvedReceiverImage =
        resolveApiImageUrl(widget.receiverImage);
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8, left: 6, right: 6, bottom: 12),
      decoration: BoxDecoration(
        gradient: _primaryGradient,
        boxShadow: [
          BoxShadow(
            color: _accentColor.withOpacity(0.25),
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
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(userId: widget.receiverId),
                ),
              );
            },
            child: PrivacyUtils.buildPrivacyAwareAvatar(
              imageUrl: resolvedReceiverImage,
              privacy: widget.receiverPrivacy,
              photoRequest: widget.receiverPhotoRequest,
              radius: 22,
              backgroundColor: Colors.grey[600],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(userId: widget.receiverId),
                  ),
                );
              },
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
                  if (_isReceiverTyping)
                    Row(
                      children: [
                        TypingIndicatorWidget(dotColor: Colors.white, dotSize: 6),
                        const SizedBox(width: 6),
                        const Text(
                          'is typing...',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    )
                  else if (_isOtherUserOnline)
                    const Text(
                      "online",
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    )
                  else if (_otherUserLastSeen != null)
                    Text(
                      _formatLastSeen(_otherUserLastSeen!),
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              // Prevent starting a new call if one is already active
              if (CallOverlayManager().isCallActive) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('You are already in a call'),
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }
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
                    chatRoomId: widget.chatRoomId,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.call, color: Colors.white),
          ),
          IconButton(
            onPressed: () {
              // Prevent starting a new call if one is already active
              if (CallOverlayManager().isCallActive) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('You are already in a call'),
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }
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
                    chatRoomId: widget.chatRoomId,
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
    String? selectedReason;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (_, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Icon(Icons.flag, color: Colors.orange, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Report Profile',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Select reason for report:',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...AppConstants.reportReasons.map((reason) => RadioListTile<String>(
                        value: reason,
                        groupValue: selectedReason,
                        onChanged: (value) =>
                            setSheetState(() => selectedReason = value),
                        title: Text(reason,
                            style: const TextStyle(fontSize: 14)),
                        activeColor: Colors.red,
                        dense: true,
                      )),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                Navigator.of(sheetContext).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: selectedReason == null
                                ? null
                                : () async {
                                    Navigator.of(sheetContext).pop();
                                    await _submitReport(
                                        context, selectedReason!);
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: const Text(
                              'Report',
                              style: TextStyle(color: Colors.white),
                            ),
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
      },
    );
  }

  Future<void> _submitReport(BuildContext context, String reason) async {
    try {
      final adminUserId = AppConstants.adminUserId;
      final reportMessage =
          'I have reported this profile.\n\nReason: $reason\n\nReported Profile ID: ${widget.receiverId}';
      final reportPayload = jsonEncode({
        'reportMessage': reportMessage,
        'reportedUserId': widget.receiverId,
        'reportedUserName': widget.receiverName,
        'reportReason': reason,
      });

      final List<String> ids = [widget.currentUserId, adminUserId]..sort();
      final adminChatRoomId = ids.join('_');
      _socketService.sendMessage(
        chatRoomId: adminChatRoomId,
        senderId: widget.currentUserId,
        receiverId: adminUserId,
        message: reportPayload,
        messageType: 'report',
        messageId: _uuid.v4(),
        user1Name: widget.currentUserName,
        user2Name: 'Admin',
        user1Image: widget.currentUserImage,
        user2Image: '',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile reported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to report: $e')),
        );
      }
    }
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
