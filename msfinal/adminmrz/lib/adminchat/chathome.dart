import 'package:adminmrz/adminchat/services/pushservice.dart';
import 'package:adminmrz/adminchat/video_call_page.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'OutgoingCall.dart';
import 'audiocall.dart';
import 'chat_screen.dart';
import 'chatprovider.dart';
import 'chatscreen.dart';
import 'constant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import 'chat_theme.dart';
import 'left.dart';
import 'dart:html' as html;
import 'dart:js' as js;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

class ChatWindow extends StatefulWidget {
  final String name;
  final bool isOnline;
  final dynamic receiverIdd;
  /// Called on mobile when the admin taps the back arrow to return to the list.
  final VoidCallback? onBack;

  const ChatWindow({super.key, required this.name, required this.isOnline, required this.receiverIdd, this.onBack});

  @override
  State<ChatWindow> createState() => _ChatWindowState();
}

class _ChatWindowState extends State<ChatWindow> {
  final int senderId = 1;
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  bool _isListening = false;
  bool _userStoppedListening = false;
  bool _isSearching = false;
  bool _showMatchInfo = false;
  File? _selectedImage;
  Uint8List? _selectedImageBytes;
  List<QueryDocumentSnapshot> _filteredMessages = [];
  js.JsObject? _webSpeechRecognition;
  FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final ScrollController _scrollController = ScrollController();
  QuerySnapshot? _lastSnapshot;
  String? _lastUploadedImageUrl;

  // Cached streams – recreated only when the selected receiver changes.
  int? _cachedReceiverId;
  Stream<QuerySnapshot>? _messagesStream;

  // Voice typing state
  String _selectedLanguage = 'en-US'; // 'en-US' or 'ne-NP'
  String _textBeforeVoice = ''; // text already in field before listening started

  // Pagination
  static const int _pageSize = 20;
  static const double _autoScrollThreshold = 120;
  int _currentLimit = 20;
  int? _cachedLimit;
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;
  bool _suppressNextAutoScroll = false;
  int? _prevUserId;

  // Floating date indicator (WhatsApp-style)
  final ValueNotifier<String?> _floatingDateNotifier = ValueNotifier(null);
  Timer? _floatingDateTimer;
  List<_ChatMessageDateGroup> _currentMessageGroups = [];

  // Match-related data
  Map<String, dynamic>? _matchDetails;
  bool _isLoadingMatchDetails = false;
  List<Map<String, dynamic>> _mutualMatches = [];

  // Active call overlay
  OverlayEntry? _callOverlayEntry;

  // Typing indicator state
  Timer? _typingTimer;
  StreamSubscription<DocumentSnapshot>? _typingSubscription;
  bool _userIsTyping = false;

  // Inline reply / edit state
  Map<String, dynamic>? _replyingTo; // {docId, message, senderid, senderName}
  String? _editingDocId;
  String _editingOriginalText = ''; // original message text before user edits it

  static const int _kMaxQuoteLength = 80; // max chars shown in reply/edit preview
  static const String _kDeletedMessageText = 'This message was deleted.';
  static const String _kUnsentMessageText = 'This message was unsent.';
  static const String _kDefaultMessageText = 'Message';
  // Approximate chat row height used for the initial jump before ensureVisible
  // performs the precise final alignment on the mounted target widget.
  static const double _kEstimatedMessageExtent = 112;
  static const double _kDateHeaderExtent = _ChatDateHeaderDelegate.kExtent;
  static const int _kMaxLoadAttempts = 20;
  static const int _kMaxContextFindAttempts = 6;
  static const Duration _kLoadRetryDelay = Duration(milliseconds: 250);
  static const Duration _kLoadMoreDelay = Duration(milliseconds: 450);
  static const Duration _kContextFindDelay = Duration(milliseconds: 80);
  static const Duration _kEnsureVisibleDuration = Duration(milliseconds: 420);
  static const int _kMinScrollDurationMs = 320;
  static const int _kMaxScrollDurationMs = 950;
  static const double _kScrollDurationMultiplier = 0.35;
  static const double _kMessageScrollAlignment = 0.45;
  static const double _kReplyPreviewSentBackgroundOpacity = 0.18;
  static const double _kReplyPreviewSentBorderOpacity = 0.78;
  static const double _kReplyPreviewSentTextOpacity = 0.85;
  static const double _kReplyPreviewSentIconOpacity = 0.88;

  final Map<String, GlobalKey> _messageKeys = <String, GlobalKey>{};
  final Map<String, int> _messageIndexMap = <String, int>{};
  Timer? _replyHighlightTimer;
  String? _highlightedMessageId;

  @override
  void initState() {
    super.initState();
    _initializeWebSpeech();
    _initializeRecorder();
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    if (chatProvider.id != null) {
      _fetchMatchDetails();
    }
    _scrollController.addListener(_onScrollForPagination);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_messageFocusNode);
      // Set up typing listener for the initially selected user.
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      if (chatProvider.id != null) _setupTypingListener(chatProvider.id!);
    });
  }

  Future<void> _fetchMatchDetails() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    if (chatProvider.id == null) {
      setState(() {
        _isLoadingMatchDetails = false;
        _matchDetails = null;
        _mutualMatches = [];
      });
      return;
    }

    setState(() {
      _isLoadingMatchDetails = true;
      _matchDetails = null;
      _mutualMatches = [];
    });

    try {
      final response = await http.get(
          Uri.parse('https://digitallami.com/get_match_details.php?user_id=${chatProvider.id}')
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _matchDetails = data['match_details'];
            _mutualMatches = List<Map<String, dynamic>>.from(data['mutual_matches'] ?? []);
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching match details: $e');
    } finally {
      setState(() {
        _isLoadingMatchDetails = false;
      });
    }
  }

  // ── TYPING INDICATOR ────────────────────────────────────────────────────

  /// Subscribe to the selected user's typing status in Firestore.
  void _setupTypingListener(int userId) {
    _typingSubscription?.cancel();
    _typingSubscription = _firestore
        .collection('typing_status')
        .doc(userId.toString())
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      if (!snap.exists) {
        setState(() => _userIsTyping = false);
        return;
      }
      final data = snap.data() as Map<String, dynamic>;
      final bool isTyping = data['isTyping'] == true;
      final String? typingTo = data['typingTo']?.toString();
      // Only show if user is typing TO admin ('1').
      setState(() => _userIsTyping = isTyping && typingTo == senderId.toString());
    });
  }

  /// Update admin's typing status in Firestore.
  void _updateAdminTypingStatus(String text, String receiverId) {
    _typingTimer?.cancel();
    final isTyping = text.isNotEmpty;
    _firestore.collection('typing_status').doc(senderId.toString()).set({
      'isTyping': isTyping,
      'typingTo': receiverId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (isTyping) {
      // Auto-clear after 3 seconds of no new keystrokes.
      _typingTimer = Timer(const Duration(seconds: 3), () {
        _clearAdminTypingStatus();
      });
    }
  }

  /// Clear admin's typing status (on send, user switch, or dispose).
  void _clearAdminTypingStatus() {
    _typingTimer?.cancel();
    _firestore.collection('typing_status').doc(senderId.toString()).set({
      'isTyping': false,
      'typingTo': '',
      'updatedAt': FieldValue.serverTimestamp(),
    }).catchError((_) {});
  }

  // ── SEEN STATUS ─────────────────────────────────────────────────────────

  /// Batch-mark all unread incoming messages as seen by admin.
  void _markIncomingMessagesAsSeen(List<QueryDocumentSnapshot> messages) {
    final batch = _firestore.batch();
    bool hasPending = false;
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    if (chatProvider.id == null) return;
    final String userId = chatProvider.id.toString();
    for (final doc in messages) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['senderid'] == userId &&
          data['receiverid'] == senderId.toString() &&
          data['seen'] != true) {
        batch.update(doc.reference, {
          'seen': true,
          'seenAt': FieldValue.serverTimestamp(),
        });
        hasPending = true;
      }
    }
    if (hasPending) batch.commit().catchError((_) {});
  }

  // ── CALL HISTORY ─────────────────────────────────────────────────────────

  /// Save a call history message to the `adminchat` collection.
  Future<void> _saveCallHistory(
      String receiverId, String callType, String status, int durationSeconds) async {
    try {
      final String label = _callLabel(callType, status, durationSeconds);
      await _firestore.collection('adminchat').add({
        'message': label,
        'senderid': senderId.toString(),
        'receiverid': receiverId,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'call',
        'callType': callType,
        'callStatus': status,
        'callDuration': durationSeconds,
        'seen': false,
      });

      final String conversationId =
          getConversationId(senderId.toString(), receiverId);
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .set({
        'participants': [senderId.toString(), receiverId],
        'lastMessage': label,
        'lastTimestamp': FieldValue.serverTimestamp(),
        'lastSenderId': senderId.toString(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  String _callLabel(String callType, String status, int seconds) {
    final bool isVideo = callType == 'video';
    if (status == 'missed') {
      return isVideo ? '📹 Missed Video Call' : '📞 Missed Call';
    }
    final String dur = _formatCallDuration(seconds);
    return isVideo ? '📹 Video Call • $dur' : '📞 Audio Call • $dur';
  }

  String _messagePreviewText(Map<String, dynamic> data) {
    if (data['deleted'] == true) return _kDeletedMessageText;
    if (data['unsent'] == true) return _kUnsentMessageText;

    switch (data['type']?.toString()) {
      case 'image':
        return '📷 Image';
      case 'profile_card':
        return '👤 Profile shared';
      case 'call':
        return _callLabel(
          data['callType']?.toString() ?? 'audio',
          data['callStatus']?.toString() ?? 'missed',
          (data['callDuration'] as num?)?.toInt() ?? 0,
        );
      case 'text':
      case null:
        final text = data['message']?.toString().trim() ?? '';
        return text.isEmpty ? _kDefaultMessageText : text;
      default:
        return data['message']?.toString() ?? _kDefaultMessageText;
    }
  }

  Map<String, dynamic> _buildReplyPayload({
    required String docId,
    required Map<String, dynamic> data,
    required String senderId,
    required String senderName,
  }) {
    return {
      'docId': docId,
      'message': _messagePreviewText(data),
      'senderid': senderId,
      'senderName': senderName,
      'type': data['type']?.toString() ?? 'text',
      'edited': data['edited'] == true,
      'deleted': data['deleted'] == true,
      'unsent': data['unsent'] == true,
    };
  }

  Map<String, dynamic> _buildFallbackReplyPayload({
    required String docId,
    required String message,
    required String senderId,
    required String senderName,
  }) {
    return _buildReplyPayload(
      docId: docId,
      data: {
        'message': message,
        'type': 'text',
        'edited': false,
        'deleted': false,
        'unsent': false,
      },
      senderId: senderId,
      senderName: senderName,
    );
  }

  bool _canEditMessage(Map<String, dynamic> data, bool isSentByMe) {
    if (!isSentByMe) return false;
    if (data['deleted'] == true || data['unsent'] == true) return false;
    final type = data['type']?.toString();
    return type == null || type == 'text';
  }

  bool _canMutateMessage(Map<String, dynamic> data, bool isSentByMe) {
    return isSentByMe && data['deleted'] != true && data['unsent'] != true;
  }

  Future<void> _syncReplySnapshots(
    String sourceDocId,
    Map<String, dynamic> replyData,
  ) async {
    final snapshot = await _firestore
        .collection('adminchat')
        .where('replyto.docId', isEqualTo: sourceDocId)
        .get();

    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'replyto': replyData});
    }
    await batch.commit();
  }

  Future<void> _updateConversationPreviewIfLatest({
    required String docId,
    required String receiverId,
    required String lastMessage,
  }) async {
    final latestSnapshot = await _firestore
        .collection('adminchat')
        .where('senderid', whereIn: [senderId.toString(), receiverId])
        .where('receiverid', whereIn: [senderId.toString(), receiverId])
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (latestSnapshot.docs.isEmpty || latestSnapshot.docs.first.id != docId) {
      return;
    }

    await _firestore
        .collection('conversations')
        .doc(getConversationId(senderId.toString(), receiverId))
        .set({
      'lastMessage': lastMessage,
      'lastTimestamp': FieldValue.serverTimestamp(),
      'lastSenderId': senderId.toString(),
    }, SetOptions(merge: true));
  }

  Future<void> _applyMessageMutation({
    required String docId,
    required Map<String, dynamic> updates,
  }) async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final receiverId = chatProvider.id?.toString();
    if (receiverId == null) return;

    final docRef = _firestore.collection('adminchat').doc(docId);
    await docRef.update(updates);
    final latestSnapshot = await docRef.get();
    if (!latestSnapshot.exists) return;

    final latestData = {
      ...latestSnapshot.data() ?? <String, dynamic>{},
      ...updates,
    };

    final replyData = {
      'docId': docId,
      'message': _messagePreviewText(latestData),
      'senderid': latestData['senderid']?.toString() ?? senderId.toString(),
      'senderName': latestData['senderid']?.toString() == senderId.toString()
          ? 'You'
          : (chatProvider.namee ?? 'User'),
      'type': latestData['type']?.toString() ?? 'text',
      'edited': latestData['edited'] == true,
      'deleted': latestData['deleted'] == true,
      'unsent': latestData['unsent'] == true,
    };

    await Future.wait([
      _syncReplySnapshots(docId, replyData),
      _updateConversationPreviewIfLatest(
        docId: docId,
        receiverId: receiverId,
        lastMessage: replyData['message'] as String,
      ),
    ]);
  }

  String _formatCallDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _initializeWebSpeech() {
    // Prefer the unprefixed SpeechRecognition (Firefox/Edge) with a fallback to
    // the webkit-prefixed version used by Chrome.
    final dynamic speechClass = js.context.hasProperty('SpeechRecognition')
        ? js.context['SpeechRecognition']
        : js.context.hasProperty('webkitSpeechRecognition')
            ? js.context['webkitSpeechRecognition']
            : null;

    if (speechClass == null) return;

    _webSpeechRecognition = js.JsObject(speechClass as js.JsFunction);
    _webSpeechRecognition!['continuous'] = true;
    _webSpeechRecognition!['interimResults'] = true;
    _webSpeechRecognition!['lang'] = _selectedLanguage;

    _webSpeechRecognition!['onresult'] = js.allowInterop((dynamic event) {
      final eventObj = js.JsObject.fromBrowserObject(event);
      final results = eventObj['results'];
      if (results == null) return;

      final resultList = js.JsObject.fromBrowserObject(results);
      // Use safe num→int cast; JS numbers come through as num, not int.
      final int length = (resultList['length'] as num).toInt();
      // Only process new results starting at resultIndex to avoid double-counting
      // previous finals every time onresult fires.
      final int resultIndex = (eventObj['resultIndex'] as num).toInt();

      String interimTranscript = '';
      String finalTranscript = '';

      for (int i = resultIndex; i < length; i++) {
        final result = js.JsObject.fromBrowserObject(
            resultList.callMethod('item', [i]));
        final transcript =
            js.JsObject.fromBrowserObject(result.callMethod('item', [0]))['transcript'] as String;
        // Use == true instead of `as bool` — JS booleans may not cast to Dart bool directly.
        final isFinal = result['isFinal'] == true;
        if (isFinal) {
          finalTranscript += transcript;
        } else {
          interimTranscript += transcript;
        }
      }

      if (finalTranscript.isNotEmpty) {
        _textBeforeVoice = _textBeforeVoice + finalTranscript;
      }

      final displayText = interimTranscript.isNotEmpty
          ? _textBeforeVoice + interimTranscript
          : _textBeforeVoice;

      setState(() {
        _messageController.text = displayText;
        _messageController.selection = TextSelection.fromPosition(
          TextPosition(offset: displayText.length),
        );
      });
    });

    _webSpeechRecognition!['onend'] = js.allowInterop((dynamic _) {
      // With continuous=true the browser may still fire onend after silence.
      // Restart automatically unless the user explicitly stopped listening.
      if (!_userStoppedListening && _isListening && mounted) {
        try {
          _webSpeechRecognition!.callMethod('start');
        } catch (e) {
          setState(() => _isListening = false);
        }
      } else {
        if (mounted) setState(() => _isListening = false);
      }
    });

    _webSpeechRecognition!['onerror'] = js.allowInterop((dynamic event) {
      final error =
          js.JsObject.fromBrowserObject(event)['error'] as String? ?? '';
      if (error == 'aborted') return; // user-initiated stop, onend handles state

      // Prevent auto-restart only for unrecoverable errors (permission denied).
      if (error == 'not-allowed' || error == 'service-not-allowed') {
        _userStoppedListening = true;
      }

      final resetText = _textBeforeVoice.trimRight();
      setState(() {
        _isListening = false;
        _messageController.text = resetText;
        _messageController.selection = TextSelection.fromPosition(
          TextPosition(offset: resetText.length),
        );
      });

      String errorMsg;
      switch (error) {
        case 'not-allowed':
        case 'service-not-allowed':
          errorMsg =
              'Microphone access denied. Please allow microphone permission in your browser settings.';
          break;
        case 'no-speech':
          errorMsg = 'No speech detected. Please try again.';
          break;
        default:
          errorMsg = 'Speech error: $error';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg)),
      );
    });
  }

  Future<void> _initializeRecorder() async {
    try {
      await _recorder.openRecorder();
    } catch (e) {
    }
  }

  void _startListening() {
    if (_webSpeechRecognition != null && !_isListening) {
      _textBeforeVoice = _messageController.text;
      if (_textBeforeVoice.isNotEmpty && !_textBeforeVoice.endsWith(' ')) {
        _textBeforeVoice += ' ';
      }
      _webSpeechRecognition!['lang'] = _selectedLanguage;
      _userStoppedListening = false;
      _webSpeechRecognition!.callMethod('start');
      setState(() => _isListening = true);
    }
  }

  void _stopListening() {
    if (_isListening && _webSpeechRecognition != null) {
      _userStoppedListening = true;
      _webSpeechRecognition!.callMethod('stop');
      setState(() => _isListening = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      final maxScrollExtent = _scrollController.position.maxScrollExtent;
      if (maxScrollExtent > 0) {
        _scrollController.jumpTo(maxScrollExtent);
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollToBottom();
        });
      }
    } else {
      Future.delayed(Duration(milliseconds: 100), _scrollToBottom);
    }
  }

  void _onScrollForPagination() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels <= 200 && !_isLoadingMore && _hasMoreMessages) {
      _loadMoreMessages();
    }
  }

  void _loadMoreMessages() {
    if (_isLoadingMore || !_hasMoreMessages) return;
    setState(() {
      _isLoadingMore = true;
      _suppressNextAutoScroll = true;
      _currentLimit += _pageSize;
    });
    // _isLoadingMore is cleared in the StreamBuilder once the new snapshot arrives
    // (via the _hasMoreMessages/noMore logic). As a safety fallback, clear it after
    // a short delay so the UI never gets stuck.
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _isLoadingMore) setState(() => _isLoadingMore = false);
    });
  }

  GlobalKey _messageKeyFor(String messageId) {
    return _messageKeys.putIfAbsent(messageId, () => GlobalKey(debugLabel: 'message-$messageId'));
  }

  void _highlightMessage(String messageId) {
    _replyHighlightTimer?.cancel();
    if (!mounted) return;

    setState(() {
      _highlightedMessageId = messageId;
    });

    _replyHighlightTimer = Timer(const Duration(milliseconds: 1600), () {
      if (!mounted || _highlightedMessageId != messageId) return;
      setState(() {
        _highlightedMessageId = null;
      });
    });
  }

  Future<bool> _ensureMessageLoaded(String messageId) async {
    for (int attempt = 0; attempt < _kMaxLoadAttempts; attempt++) {
      final docs = _lastSnapshot?.docs ?? const <QueryDocumentSnapshot>[];
      final bool found = docs.any((doc) => doc.id == messageId);
      if (found) return true;
      if (!_hasMoreMessages || _isLoadingMore) {
        await Future.delayed(_kLoadRetryDelay);
        continue;
      }
      _loadMoreMessages();
      await Future.delayed(_kLoadMoreDelay);
    }

    final docs = _lastSnapshot?.docs ?? const <QueryDocumentSnapshot>[];
    return docs.any((doc) => doc.id == messageId);
  }

  Duration _navigationDurationForDistance(double distance) {
    final int millis = (_kMinScrollDurationMs + (distance * _kScrollDurationMultiplier))
        .round()
        .clamp(_kMinScrollDurationMs, _kMaxScrollDurationMs);
    return Duration(milliseconds: millis);
  }

  Future<void> _scrollToMessage(String messageId) async {
    if (messageId.isEmpty) return;

    final bool isLoaded = await _ensureMessageLoaded(messageId);
    if (!mounted) return;

    if (!isLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Original message could not be found.')),
      );
      return;
    }

    if (_scrollController.hasClients) {
      final int? targetIndex = _messageIndexMap[messageId];
      if (targetIndex != null) {
        final position = _scrollController.position;
        final double estimatedOffset =
            (targetIndex * _kEstimatedMessageExtent).clamp(0.0, position.maxScrollExtent);
        final double distance = (position.pixels - estimatedOffset).abs();
        await _scrollController.animateTo(
          estimatedOffset,
          duration: _navigationDurationForDistance(distance),
          curve: Curves.easeInOutCubic,
        );
      }
    }

    for (int attempt = 0; attempt < _kMaxContextFindAttempts; attempt++) {
      // Wait for the post-scroll frame so the lazily built target row can mount.
      await SchedulerBinding.instance.endOfFrame;
      final BuildContext? targetContext = _messageKeys[messageId]?.currentContext;
      if (targetContext == null) {
        await Future.delayed(_kContextFindDelay);
        continue;
      }

      await Scrollable.ensureVisible(
        targetContext,
        duration: _kEnsureVisibleDuration,
        curve: Curves.easeInOutCubic,
        alignment: _kMessageScrollAlignment,
      );
      _highlightMessage(messageId);
      return;
    }

    _highlightMessage(messageId);
  }

  Future<void> _handleReplyPreviewTap(Map<String, dynamic>? replyTo) async {
    final String messageId = replyTo?['docId']?.toString() ?? '';
    if (messageId.isEmpty) return;
    await _scrollToMessage(messageId);
  }

  Future<void> _sendMatchProfile(Map<String, dynamic> profileData) async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    try {
      await _firestore.collection('adminchat').add({
        'message': 'Match Profile',
        'liked': false,
        'replyto': '',
        'senderid': senderId.toString(),
        'receiverid': chatProvider.id.toString(),
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'profile_card',
        'profileData': profileData,
      });

      String conversationId = getConversationId(
        senderId.toString(),
        chatProvider.id.toString(),
      );

      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .set({
        'participants': [senderId.toString(), chatProvider.id.toString()],
        'lastMessage': 'Sent a match profile',
        'lastTimestamp': FieldValue.serverTimestamp(),
        'lastSenderId': senderId.toString(),
      }, SetOptions(merge: true));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to send match profile")),
      );
    }
  }

  // ── CALL OVERLAY HELPERS ─────────────────────────────────────────────────

  /// Remove the active call overlay and clean up.
  void _removeCallOverlay() {
    _callOverlayEntry?.remove();
    _callOverlayEntry = null;
  }

  /// Launch a call (video or audio) in a floating overlay so the admin can
  /// minimize it and continue browsing other conversations without ending it.
  void _launchCall(ChatProvider chatProvider, {required bool isVideo}) {
    if (_callOverlayEntry != null) return; // call already active

    final userId = chatProvider.id.toString();
    final userName = chatProvider.namee.toString();
    final isMinimizedNotifier = ValueNotifier<bool>(false);

    void onCallEnded(String callType, String status, int durationSeconds) {
      _removeCallOverlay();
      _saveCallHistory(userId, callType, status, durationSeconds);
    }

    _callOverlayEntry = OverlayEntry(
      builder: (ctx) => ValueListenableBuilder<bool>(
        valueListenable: isMinimizedNotifier,
        builder: (_, isMin, __) {
          final callWidget = isVideo
              ? VideoCallScreen(
                  currentUserId: '1',
                  currentUserName: 'Admin',
                  otherUserId: userId,
                  otherUserName: userName,
                  onMinimize: () => isMinimizedNotifier.value = true,
                  onEnd: _removeCallOverlay,
                  onCallEnded: onCallEnded,
                )
              : CallScreen(
                  currentUserId: '1',
                  currentUserName: 'Admin',
                  otherUserId: userId,
                  otherUserName: userName,
                  onMinimize: () => isMinimizedNotifier.value = true,
                  onEnd: _removeCallOverlay,
                  onCallEnded: onCallEnded,
                );

          return Stack(
            children: [
              // Full-screen call – kept alive via Offstage while minimized
              Offstage(offstage: isMin, child: callWidget),
              // Floating mini-bar shown when minimized
              if (isMin)
                _buildMiniCallBar(
                  userName: userName,
                  isVideo: isVideo,
                  onMaximize: () => isMinimizedNotifier.value = false,
                  onEnd: _removeCallOverlay,
                ),
            ],
          );
        },
      ),
    );
    Overlay.of(context).insert(_callOverlayEntry!);
  }

  void _launchVideoCall(ChatProvider chatProvider) =>
      _launchCall(chatProvider, isVideo: true);

  void _launchAudioCall(ChatProvider chatProvider) =>
      _launchCall(chatProvider, isVideo: false);

  /// A compact floating bar shown at the bottom-right when the call is
  /// minimized.  The admin can tap it to expand back or end the call.
  Widget _buildMiniCallBar({
    required String userName,
    required bool isVideo,
    required VoidCallback onMaximize,
    required VoidCallback onEnd,
  }) {
    return Positioned(
      bottom: 24,
      right: 24,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: onMaximize,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF22C55E),
                    shape: BoxShape.circle,
                  ),
                ),
                Icon(
                  isVideo ? Icons.videocam : Icons.call,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: onEnd,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.call_end, color: Colors.white, size: 14),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onMaximize,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.open_in_full, color: Colors.white, size: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── ICON BUTTON HELPER ────────────────────────────────────────────
  Widget _iconBtn({
    required IconData icon,
    required VoidCallback onTap,
    bool active = false,
    Color? iconColor,
  }) {
    final c = ChatColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: active ? c.primaryLight : c.searchFill,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 18,
          color: iconColor ?? (active ? c.primary : c.muted),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = ChatColors.of(context);

    final chatProvider = Provider.of<ChatProvider>(context);

    // Rebuild the Firestore stream only when the selected user changes so that
    // StreamBuilder keeps its existing subscription and never flashes a loading
    // spinner while switching conversations.
    final bool userChanged = chatProvider.id != _cachedReceiverId;
    final bool limitChanged = _currentLimit != _cachedLimit;
    if (userChanged) {
      _cachedReceiverId = chatProvider.id;
      _currentLimit = _pageSize;
      _hasMoreMessages = true;
      _suppressNextAutoScroll = false;
      _lastSnapshot = null; // clear stale messages from the previous user
      _messageKeys.clear();
      _messageIndexMap.clear();
      _replyHighlightTimer?.cancel();
      _highlightedMessageId = null;
      // Re-fetch match details for the newly selected user
      if (chatProvider.id != null) Future.microtask(_fetchMatchDetails);
      // Reset user-typing state and subscribe to new user's typing status.
      _userIsTyping = false;
      if (chatProvider.id != null) Future.microtask(() => _setupTypingListener(chatProvider.id!));
      // Clear admin typing status for the previous user.
      Future.microtask(_clearAdminTypingStatus);
      // Auto-focus the message input so the admin can type immediately.
      Future.microtask(() {
        if (mounted) FocusScope.of(context).requestFocus(_messageFocusNode);
      });
    }
    if (userChanged || limitChanged) {
      _cachedLimit = _currentLimit;
      _messagesStream = chatProvider.id == null
          ? null
          : _firestore
              .collection('adminchat')
              .where('senderid', whereIn: [senderId.toString(), chatProvider.id.toString()])
              .where('receiverid', whereIn: [senderId.toString(), chatProvider.id.toString()])
              .orderBy('timestamp', descending: true)
              .limit(_currentLimit)
              .snapshots();
    }

    return Scaffold(
      backgroundColor: c.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: c.header,
            border: Border(bottom: BorderSide(color: c.border, width: 1)),
          ),
          child: Row(
            children: [
              // Back button (mobile only — shown when onBack callback is provided)
              if (widget.onBack != null) ...[
                SizedBox(
                  width: 32,
                  height: 32,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onBack,
                      borderRadius: BorderRadius.circular(8),
                      child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: c.muted),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              // Avatar + paid badge
              Stack(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFF1F5F9),
                    backgroundImage: chatProvider.profilePicture != null &&
                            chatProvider.profilePicture!.isNotEmpty
                        ? NetworkImage(chatProvider.profilePicture!)
                        : null,
                    child: chatProvider.profilePicture == null ||
                            chatProvider.profilePicture!.isEmpty
                        ? Icon(Icons.person, size: 18, color: Colors.grey[400])
                        : null,
                  ),
                  if (chatProvider.ispaid)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(Icons.star, size: 8, color: Colors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),

              // Name + status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            chatProvider.namee.toString(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: chatProvider.ispaid ? c.primary : c.text,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (chatProvider.matchesCount != null && chatProvider.matchesCount! > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: c.primaryLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.favorite, color: c.primary, size: 10),
                                const SizedBox(width: 2),
                                Text(
                                  '${chatProvider.matchesCount}',
                                  style: TextStyle(
                                    color: c.primary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _userIsTyping ? c.primary : (chatProvider.online ? c.online : c.muted),
                          ),
                        ),
                        Text(
                          _userIsTyping
                              ? "typing..."
                              : (chatProvider.online ? "Online" : "Offline"),
                          style: TextStyle(
                            fontSize: 11,
                            color: _userIsTyping
                                ? c.primary
                                : (chatProvider.online ? c.online : c.muted),
                          ),
                        ),
                        if (chatProvider.id != null)
                          Row(
                            children: [
                              Icon(Icons.tag, size: 10, color: c.muted),
                              const SizedBox(width: 2),
                              Text(
                                '${chatProvider.id}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: c.muted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action buttons
              _iconBtn(
                icon: _showMatchInfo ? Icons.favorite : Icons.favorite_border,
                active: _showMatchInfo,
                iconColor: _showMatchInfo ? c.primary : c.muted,
                onTap: () => setState(() => _showMatchInfo = !_showMatchInfo),
              ),
              const SizedBox(width: 6),
              _iconBtn(
                icon: Icons.video_call_outlined,
                iconColor: c.primary,
                onTap: () => _launchVideoCall(chatProvider),
              ),
              const SizedBox(width: 6),
              _iconBtn(
                icon: Icons.call_outlined,
                iconColor: const Color(0xFF334155),
                onTap: () => _launchAudioCall(chatProvider),
              ),
              const SizedBox(width: 6),
              _iconBtn(
                icon: _isSearching ? Icons.close : Icons.search,
                active: _isSearching,
                onTap: () {
                  setState(() {
                    _isSearching = !_isSearching;
                    if (!_isSearching) {
                      _searchController.clear();
                      _filteredMessages.clear();
                    }
                  });
                },
              ),
              const SizedBox(width: 6),
              _iconBtn(
                icon: Icons.notifications_outlined,
                iconColor: c.muted,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          if (_isSearching)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: SizedBox(
                height: 38,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "Search messages...",
                    hintStyle: TextStyle(fontSize: 12, color: c.muted),
                    prefixIcon: Icon(Icons.search, size: 16, color: c.muted),
                    filled: true,
                    fillColor: c.searchFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: c.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: c.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: c.primary),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    isDense: true,
                  ),
                  onChanged: _searchMessages,
                ),
              ),
            ),

          // Match info panel
          if (_showMatchInfo)
            _buildMatchInfoPanel(chatProvider),

          Expanded(
            child: Stack(
              children: [
                StreamBuilder<QuerySnapshot>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 40),
                        const SizedBox(height: 12),
                        const Text(
                          "Firebase Error",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.red),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            snapshot.error.toString(),
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, color: c.muted),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: c.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _handleIndexError(snapshot.error.toString()),
                          child: const Text("Create Index", style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting && _lastSnapshot == null) {
                  return Center(child: CircularProgressIndicator(color: c.primary));
                }

                final rawMessages = snapshot.hasData
                    ? snapshot.data!.docs
                    : _lastSnapshot?.docs ?? <QueryDocumentSnapshot>[];
                final isActiveSearch = _isSearching && _searchController.text.isNotEmpty;
                final messages = isActiveSearch ? _filteredMessages : rawMessages;
                final previousSnapshot = _lastSnapshot;
                final previousCount = previousSnapshot?.docs.length ?? 0;

                if (snapshot.hasData) {
                  _lastSnapshot = snapshot.data;
                  // If we received fewer docs than requested, there are no older messages.
                  final bool noMore = snapshot.data!.docs.length < _currentLimit;
                  if (noMore != !_hasMoreMessages || _isLoadingMore) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() {
                        _hasMoreMessages = !noMore;
                        _isLoadingMore = false;
                        _suppressNextAutoScroll = false;
                      });
                    });
                  }
                  // Mark incoming messages as seen by admin.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _markIncomingMessagesAsSeen(snapshot.data!.docs);
                  });
                }

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 40, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                          isActiveSearch ? "No matching messages" : "No messages yet",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.muted),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isActiveSearch ? "Try a different keyword" : "Start a conversation!",
                          style: TextStyle(fontSize: 11, color: c.muted),
                        ),
                      ],
                    ),
                  );
                }

                final itemCount = messages.length;
                final activeMessageIds = messages.map((doc) => doc.id).toSet();
                for (final messageId in _messageKeys.keys.toList()) {
                  if (!activeMessageIds.contains(messageId)) {
                    _messageKeys.remove(messageId);
                  }
                }
                _messageIndexMap
                  ..clear()
                  ..addEntries(
                    List.generate(
                      itemCount,
                      (index) => MapEntry(messages[index].id, index),
                    ),
                  );
                final messageGroups = _groupMessagesByDate(messages);
                // Keep a reference so the floating date overlay can use it.
                // Direct assignment — no setState needed since the overlay
                // is driven by _floatingDateNotifier (ValueListenableBuilder).
                _currentMessageGroups = messageGroups;
                final shouldAutoScroll = _shouldAutoScrollToBottom(
                  hasSnapshotData: snapshot.hasData,
                  isSearching: isActiveSearch,
                  previousCount: previousCount,
                  currentCount: itemCount,
                );

                if (shouldAutoScroll) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _scrollToBottom();
                  });
                }

                return NotificationListener<ScrollUpdateNotification>(
                  onNotification: (notification) {
                    final offset = _scrollController.hasClients
                        ? _scrollController.offset
                        : 0.0;
                    final label = _dateGroupAtScrollOffset(
                        offset, _currentMessageGroups);
                    if (label != null) _showFloatingDateLabel(label);
                    return false;
                  },
                  child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    if (_hasMoreMessages || _isLoadingMore)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                          child: Center(
                            child: _isLoadingMore
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: c.primary,
                                    ),
                                  )
                                : TextButton.icon(
                                    onPressed: _loadMoreMessages,
                                    icon: Icon(Icons.history, size: 14, color: c.primary),
                                    label: Text(
                                      'Load older messages',
                                      style: TextStyle(fontSize: 12, color: c.primary),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    for (final group in messageGroups) ...[
                      SliverPersistentHeader(
                        pinned: false,
                        delegate: _ChatDateHeaderDelegate(
                          label: group.headerLabel,
                          backgroundColor: c.bg,
                          chipColor: c.primaryLight,
                          textColor: c.text,
                          borderColor: c.border,
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final doc = group.messages[index];
                              final data = doc.data() as Map<String, dynamic>;
                              final isSentByMe = data['senderid'] == senderId.toString();
                              final timestamp = _messageTimestampFromData(data);
                              final replyPayload = _buildReplyPayload(
                                docId: doc.id,
                                data: data,
                                senderId: isSentByMe
                                    ? senderId.toString()
                                    : (chatProvider.id?.toString() ?? ''),
                                senderName:
                                    isSentByMe ? 'You' : (chatProvider.namee ?? 'User'),
                              );
                              final canEdit = _canEditMessage(data, isSentByMe);
                              final canMutate = _canMutateMessage(data, isSentByMe);

                              return GestureDetector(
                                key: ValueKey(doc.id),
                                onLongPress: () {
                                  _showMessageOptions(
                                    context,
                                    doc.id,
                                    replyPayload,
                                    isSentByMe,
                                    canEdit: canEdit,
                                    canMutate: canMutate,
                                  );
                                },
                                child: _HighlightableMessageContainer(
                                  key: _messageKeyFor(doc.id),
                                  isHighlighted: _highlightedMessageId == doc.id,
                                  child: _buildChatBubble(
                                    data['message'],
                                    isSentByMe,
                                    timestamp,
                                    data['type'],
                                    data.containsKey('profileData')
                                        ? data['profileData']
                                        : null,
                                    data.containsKey('imageUrl') ? data['imageUrl'] : null,
                                    data['seen'] == true,
                                    data['callType']?.toString(),
                                    data['callStatus']?.toString(),
                                    (data['callDuration'] as num?)?.toInt() ?? 0,
                                    doc.id,
                                    data['replyto'] is Map<String, dynamic>
                                        ? data['replyto'] as Map<String, dynamic>
                                        : null,
                                    data['edited'] == true,
                                    data['deleted'] == true,
                                    data['unsent'] == true,
                                    canEdit,
                                    canMutate,
                                    replyPayload,
                                  ),
                                ),
                              );
                            },
                            childCount: group.messages.length,
                          ),
                        ),
                      ),
                    ],
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  ],
                  ),
                );
              },
            ),
            // WhatsApp-style floating date indicator
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: ValueListenableBuilder<String?>(
                valueListenable: _floatingDateNotifier,
                builder: (context, label, _) {
                  if (label == null) return const SizedBox.shrink();
                  return Center(
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: c.primaryLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: c.border, width: 0.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: c.text,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
          ),
          _buildMessageInput(chatProvider),
        ],
      ),
    );
  }

  Widget _buildMatchInfoPanel(ChatProvider chatProvider) {
    final c = ChatColors.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.selectedRow,
        border: Border(bottom: BorderSide(color: c.primaryLight, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.favorite, color: c.primary, size: 16),
              const SizedBox(width: 6),
              Text(
                'Match Information',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: c.primary,
                ),
              ),
              const Spacer(),
              if (_isLoadingMatchDetails)
                SizedBox(
                  height: 14,
                  width: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: c.primary),
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (_matchDetails != null && _matchDetails!['percentage'] != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: c.cardBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Match Score: ', style: TextStyle(fontSize: 12, color: c.muted)),
                  Text(
                    '${_matchDetails!['percentage']}%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: c.primary,
                    ),
                  ),
                ],
              ),
            ),

          if (_matchDetails != null && _matchDetails!['commonInterests'] != null)
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: (_matchDetails!['commonInterests'] as List).map((interest) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: c.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    interest,
                    style: TextStyle(fontSize: 10, color: c.primary),
                  ),
                );
              }).toList(),
            ),

          if (_mutualMatches.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Mutual Matches:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.muted),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _mutualMatches.length,
                itemBuilder: (context, index) {
                  final match = _mutualMatches[index];
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFFF1F5F9),
                          backgroundImage: match['profile_picture'] != null &&
                                  match['profile_picture'].toString().isNotEmpty
                              ? NetworkImage(match['profile_picture'])
                              : null,
                          child: match['profile_picture'] == null ||
                                  match['profile_picture'].toString().isEmpty
                              ? Icon(Icons.person, size: 16, color: Colors.grey[400])
                              : null,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          match['name'] ?? '',
                          style: TextStyle(fontSize: 8, color: c.muted),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],

          if (chatProvider.matchesCount != null && chatProvider.matchesCount! > 0)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _showMatchSelectionDialog(chatProvider),
                icon: const Icon(Icons.send, size: 12),
                label: const Text('Send Match Profile', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  backgroundColor: c.primaryLight,
                  foregroundColor: c.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: const Size(0, 28),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showMatchSelectionDialog(ChatProvider chatProvider) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Select Match Profile', style: TextStyle(fontSize: 16)),
          content: Container(
            width: double.maxFinite,
            height: 300,
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('matches')
                  .where('userId', isEqualTo: chatProvider.id.toString())
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                final matches = snapshot.data!.docs;

                if (matches.isEmpty) {
                  return Center(child: Text('No matches found'));
                }

                return ListView.builder(
                  itemCount: matches.length,
                  itemBuilder: (context, index) {
                    final match = matches[index].data() as Map<String, dynamic>;
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: match['profile_picture'] != null &&
                            match['profile_picture'].toString().isNotEmpty
                            ? NetworkImage(match['profile_picture'])
                            : null,
                        child: match['profile_picture'] == null ||
                            match['profile_picture'].toString().isEmpty
                            ? Icon(Icons.person, color: Colors.grey[700])
                            : null,
                      ),
                      title: Text(match['name'] ?? 'Unknown'),
                      subtitle: Text('Match: ${match['percentage'] ?? 'N/A'}%'),
                      onTap: () {
                        Navigator.pop(context);
                        _sendMatchProfile(match);
                      },
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _handleIndexError(String error) {
    final regex = RegExp(r'https://console\.firebase\.google\.com[^\s]+');
    final match = regex.firstMatch(error);

    if (match != null) {
      String indexUrl = match.group(0)!;

      if (kIsWeb) {
        html.window.open(indexUrl, '_blank');
      } else {
        launchUrl(Uri.parse(indexUrl));
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening Firebase Console to create index...'),
          duration: Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please check Firebase Console for index creation'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void openUrl(String url) {
    html.window.open(url, '_blank');
  }

  DateTime _dateOnly(DateTime dateTime) =>
      DateTime(dateTime.year, dateTime.month, dateTime.day);

  DateTime _messageTimestampFromData(
    Map<String, dynamic> data, {
    DateTime? fallback,
  }) {
    return (data['timestamp'] as Timestamp?)?.toDate() ??
        fallback ??
        DateTime.now();
  }

  bool _isToday(DateTime dateTime, [DateTime? reference]) {
    final now = reference ?? DateTime.now();
    return _dateOnly(dateTime) == _dateOnly(now);
  }

  bool _isYesterday(DateTime dateTime, [DateTime? reference]) {
    final yesterday =
        _dateOnly(reference ?? DateTime.now()).subtract(const Duration(days: 1));
    return _dateOnly(dateTime) == yesterday;
  }

  String _formatDateHeader(DateTime dateTime, [DateTime? reference]) {
    final now = reference ?? DateTime.now();
    if (_isToday(dateTime, now)) return 'Today';
    if (_isYesterday(dateTime, now)) return 'Yesterday';
    return DateFormat('MMM d, y').format(dateTime);
  }

  List<QueryDocumentSnapshot> _sortMessagesChronologically(
    List<QueryDocumentSnapshot> messages,
  ) {
    final sorted = List<QueryDocumentSnapshot>.from(messages);
    final fallbackTimestamp = DateTime.now();
    sorted.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      final aTimestamp =
          _messageTimestampFromData(aData, fallback: fallbackTimestamp);
      final bTimestamp =
          _messageTimestampFromData(bData, fallback: fallbackTimestamp);
      return aTimestamp.compareTo(bTimestamp);
    });
    return sorted;
  }

  List<_ChatMessageDateGroup> _groupMessagesByDate(
    List<QueryDocumentSnapshot> messages,
  ) {
    final groups = <_ChatMessageDateGroup>[];
    final fallbackTimestamp = DateTime.now();
    final referenceNow = DateTime.now();

    for (final doc in _sortMessagesChronologically(messages)) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp =
          _messageTimestampFromData(data, fallback: fallbackTimestamp);
      final date = _dateOnly(timestamp);

      if (groups.isEmpty || groups.last.date != date) {
        groups.add(
          _ChatMessageDateGroup(
            date: date,
            headerLabel: _formatDateHeader(timestamp, referenceNow),
            messages: [doc],
          ),
        );
      } else {
        groups.last.messages.add(doc);
      }
    }

    return groups;
  }

  /// Returns the headerLabel of the date group that is visible near the top of
  /// the viewport given the current [offset] and the rendered [groups].
  String? _dateGroupAtScrollOffset(
      double offset, List<_ChatMessageDateGroup> groups) {
    if (groups.isEmpty) return null;
    const double msgH = _kEstimatedMessageExtent;
    double pos = 0;
    for (final group in groups) {
      final groupH = _kDateHeaderExtent + group.messages.length * msgH;
      if (offset < pos + groupH) return group.headerLabel;
      pos += groupH;
    }
    return groups.last.headerLabel;
  }

  void _showFloatingDateLabel(String label) {
    _floatingDateTimer?.cancel();
    _floatingDateNotifier.value = label;
    _floatingDateTimer = Timer(const Duration(seconds: 2), () {
      _floatingDateNotifier.value = null;
    });
  }

  bool _shouldAutoScrollToBottom({
    required bool hasSnapshotData,
    required bool isSearching,
    required int previousCount,
    required int currentCount,
  }) {
    if (isSearching || _isLoadingMore || !hasSnapshotData) {
      return false;
    }

    if (_suppressNextAutoScroll) {
      return false;
    }

    if (!_scrollController.hasClients) {
      // The first layout pass has not attached the controller yet; schedule a
      // deferred scroll so the view still lands on the latest messages.
      return true;
    }

    if (previousCount != currentCount) {
      return true;
    }

    final distanceFromBottom =
        _scrollController.position.maxScrollExtent - _scrollController.offset;
    return distanceFromBottom <= _autoScrollThreshold;
  }

  Widget _buildChatBubble(String message, bool isSentByMe, DateTime timestamp,
      [String? type,
      Map<String, dynamic>? profileData,
      String? imageUrl,
      bool seen = false,
      String? callType,
      String? callStatus,
      int callDuration = 0,
      String? docId,
      Map<String, dynamic>? replyTo,
      bool edited = false,
      bool deleted = false,
      bool unsent = false,
      bool canEdit = false,
      bool canMutate = false,
      Map<String, dynamic>? replyPayload]) {
    const kPrimary = Color(0xFFD81B60);
    const kText = Color(0xFF1E293B);
    const kMuted = Color(0xFF64748B);
    final replyPreview = _buildReplyPreview(
      replyTo: replyTo,
      isSentByMe: isSentByMe,
      mutedColor: kMuted,
      primaryColor: kPrimary,
    );

    final statusMessage = deleted
        ? _kDeletedMessageText
        : (unsent ? _kUnsentMessageText : null);
    final displayedMessage = statusMessage ?? message;
    final showEditedLabel = edited && statusMessage == null;

    Widget footer({bool includeSeen = true}) {
      return Padding(
        padding: const EdgeInsets.only(right: 8, left: 8, bottom: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showEditedLabel) ...[
              const Text(
                'Edited',
                style: TextStyle(fontSize: 10, color: kMuted, fontStyle: FontStyle.italic),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              DateFormat('hh:mm a').format(timestamp),
              style: const TextStyle(fontSize: 10, color: kMuted),
            ),
            if (includeSeen && isSentByMe) ...[
              const SizedBox(width: 3),
              _buildSeenTick(seen),
            ],
          ],
        ),
      );
    }

    if (type == 'call') {
      final callBubble = statusMessage != null
          ? Align(
              alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (replyPreview != null) replyPreview,
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
                    decoration: BoxDecoration(
                      color: isSentByMe ? kPrimary : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      displayedMessage,
                      style: TextStyle(
                        color: isSentByMe ? Colors.white : kText,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  footer(),
                ],
              ),
            )
          : _buildCallBubble(
              callType ?? 'audio',
              callStatus ?? 'missed',
              callDuration,
              isSentByMe,
              timestamp,
              replyPreview: replyPreview,
            );
      return _buildMessageWithActions(
        bubble: callBubble,
        isSentByMe: isSentByMe,
        canEdit: false,
        canMutate: canMutate,
        docId: docId,
        replyPayload: replyPayload,
      );
    }

    if (type == 'image' && imageUrl != null) {
      final bubble = Align(
        alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (replyPreview != null) replyPreview,
            if (statusMessage != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
                decoration: BoxDecoration(
                  color: isSentByMe ? kPrimary : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  displayedMessage,
                  style: TextStyle(
                    color: isSentByMe ? Colors.white : kText,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else
              Container(
                margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 1))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    width: MediaQuery.of(context).size.width * 0.24,
                    fit: BoxFit.cover,
                    cacheWidth: (MediaQuery.of(context).size.width * 0.24).toInt(),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: CircularProgressIndicator(color: kPrimary));
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Column(
                        children: [
                          const Text('Error loading image'),
                          Text('Details: $error', style: const TextStyle(fontSize: 10)),
                          ElevatedButton(
                            onPressed: () => setState(() {}),
                            child: const Text("Retry"),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            footer(),
          ],
        ),
      );

      return _buildMessageWithActions(
        bubble: bubble,
        isSentByMe: isSentByMe,
        canEdit: false,
        canMutate: canMutate,
        docId: docId,
        replyPayload: replyPayload,
      );
    }

    if (type == 'profile_card' && profileData != null) {
      const kCardPrimary = Color(0xFFD81B60);
      const kCardSurface = Color(0xFFFCFCFE);
      const kCardBorder = Color(0xFFEDE7F6);
      const kInfoLabel = Color(0xFF78909C);
      const kInfoValue = Color(0xFF1A2340);

      final bool isPaid = profileData['is_paid'] == true;
      final String bioText = profileData['bio'] ?? '';
      final matchRegex = RegExp(r'(\d+(?:\.\d+)?)%');
      final matchMatch = matchRegex.firstMatch(bioText);
      final double matchPct = matchMatch != null ? double.tryParse(matchMatch.group(1)!) ?? 0 : 0;

      Color matchColor;
      if (matchPct >= 70) {
        matchColor = const Color(0xFF43A047);
      } else if (matchPct >= 50) {
        matchColor = const Color(0xFFFB8C00);
      } else {
        matchColor = const Color(0xFF78909C);
      }

      final bubble = Align(
        alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (replyPreview != null) replyPreview,
            if (statusMessage != null)
              Container(
                width: MediaQuery.of(context).size.width * 0.22,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                decoration: BoxDecoration(
                  color: isSentByMe ? kPrimary : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  displayedMessage,
                  style: TextStyle(
                    color: isSentByMe ? Colors.white : kText,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else
              Container(
                width: MediaQuery.of(context).size.width * 0.22,
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                decoration: BoxDecoration(
                  color: kCardSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kCardBorder, width: 1),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFD81B60).withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 4)),
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(15),
                        topRight: Radius.circular(15),
                      ),
                      child: Container(
                        height: 72,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFD81B60), Color(0xFFAD1457), Color(0xFF880E4F)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              top: -10,
                              right: -10,
                              child: Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.06),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: -8,
                              left: -8,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.06),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              left: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.person_pin_rounded, size: 9, color: Colors.white),
                                    SizedBox(width: 3),
                                    Text('Profile Shared', style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w600, letterSpacing: 0.2)),
                                  ],
                                ),
                              ),
                            ),
                            if (isPaid)
                              Positioned(
                                top: 8,
                                right: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(colors: [Color(0xFFFFD54F), Color(0xFFFFA000)]),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.workspace_premium, size: 8, color: Colors.white),
                                      SizedBox(width: 2),
                                      Text('Premium', style: TextStyle(color: Colors.white, fontSize: 7.5, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Transform.translate(
                      offset: const Offset(0, -28),
                      child: Column(
                        children: [
                          Center(
                            child: Stack(
                              alignment: Alignment.center,
                              clipBehavior: Clip.none,
                              children: [
                                if (matchPct > 0)
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: matchColor, width: 2.5),
                                    ),
                                  ),
                                Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2.5),
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 3))],
                                  ),
                                  child: ClipOval(
                                    child: profileData['profileImage'] != null &&
                                            profileData['profileImage'].toString().isNotEmpty
                                        ? Image.network(
                                            profileData['profileImage'],
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(
                                              color: const Color(0xFFF8BBD9),
                                              child: const Icon(Icons.person_rounded, size: 28, color: Color(0xFFD81B60)),
                                            ),
                                          )
                                        : Container(
                                            color: const Color(0xFFF8BBD9),
                                            child: const Icon(Icons.person_rounded, size: 28, color: Color(0xFFD81B60)),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              profileData['name'] ?? 'Unknown',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: kInfoValue,
                                letterSpacing: 0.1,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (matchPct > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: matchColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: matchColor.withOpacity(0.35), width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.favorite_rounded, size: 9, color: matchColor),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${matchPct.toStringAsFixed(0)}% Match',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: matchColor),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    Transform.translate(
                      offset: const Offset(0, -18),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: kCardPrimary.withOpacity(0.07),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: kCardPrimary.withOpacity(0.25), width: 0.8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.tag_rounded, size: 10, color: kCardPrimary),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'User ID',
                                    style: TextStyle(fontSize: 9.5, color: kCardPrimary, fontWeight: FontWeight.w600),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '#${profileData['id']}',
                                    style: const TextStyle(fontSize: 9.5, color: kCardPrimary, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                            _buildInfoRow(Icons.badge_rounded, 'Member ID', profileData['Member ID'], kInfoLabel, kInfoValue),
                            _buildInfoRow(Icons.wc_rounded, 'Gender', profileData['gender'], kInfoLabel, kInfoValue),
                            _buildInfoRow(Icons.location_on_rounded, 'Country', profileData['country'], kInfoLabel, kInfoValue),
                            _buildInfoRow(Icons.work_rounded, 'Occupation', profileData['occupation'], kInfoLabel, kInfoValue),
                            _buildInfoRow(Icons.school_rounded, 'Education', profileData['education'], kInfoLabel, kInfoValue),
                            _buildInfoRow(Icons.favorite_border_rounded, 'Marital', profileData['marit'], kInfoLabel, kInfoValue),
                            _buildInfoRow(Icons.cake_rounded, 'Age', profileData['age']?.toString(), kInfoLabel, kInfoValue),
                          ],
                        ),
                      ),
                    ),
                    Transform.translate(
                      offset: const Offset(0, -12),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => openUrl("https://digitallami.com/profile.php?id=${profileData['id']}"),
                                child: Container(
                                  height: 32,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: kCardPrimary, width: 1.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.open_in_new_rounded, size: 12, color: kCardPrimary),
                                      SizedBox(width: 4),
                                      Text('Profile', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kCardPrimary)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    Provider.of<ChatProvider>(context, listen: false)
                                        .updateName("${profileData['last']}  ${profileData['first']}");
                                    Provider.of<ChatProvider>(context, listen: false)
                                        .updateidd(profileData['id']);
                                  });
                                },
                                child: Container(
                                  height: 32,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFD81B60), Color(0xFFAD1457)],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [BoxShadow(color: const Color(0xFFD81B60).withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))],
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.chat_bubble_rounded, size: 12, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text('Chat', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            footer(),
          ],
        ),
      );

      return _buildMessageWithActions(
        bubble: bubble,
        isSentByMe: isSentByMe,
        canEdit: false,
        canMutate: canMutate,
        docId: docId,
        replyPayload: replyPayload,
      );
    }

    final bubble = Align(
      alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.24),
        child: Column(
          crossAxisAlignment: isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
              decoration: BoxDecoration(
                color: isSentByMe ? kPrimary : Colors.white,
                borderRadius: isSentByMe
                    ? const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
                        bottomLeft: Radius.circular(18),
                        bottomRight: Radius.circular(4),
                      )
                    : const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(18),
                        bottomLeft: Radius.circular(18),
                        bottomRight: Radius.circular(18),
                      ),
                boxShadow: isSentByMe
                    ? null
                    : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (replyPreview != null) replyPreview,
                  Text(
                    displayedMessage,
                    style: TextStyle(
                      color: isSentByMe ? Colors.white : kText,
                      fontSize: 13,
                      fontStyle: statusMessage != null ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ],
              ),
            ),
            footer(),
          ],
        ),
      ),
    );

    return _buildMessageWithActions(
      bubble: bubble,
      isSentByMe: isSentByMe,
      canEdit: canEdit,
      canMutate: canMutate,
      docId: docId,
      replyPayload: replyPayload,
    );
  }

  Widget _buildMessageWithActions({
    required Widget bubble,
    required bool isSentByMe,
    required bool canEdit,
    required bool canMutate,
    required String? docId,
    required Map<String, dynamic>? replyPayload,
  }) {
    if (docId == null || replyPayload == null) return bubble;

    return _HoverableMessageBubble(
      bubble: bubble,
      isSentByMe: isSentByMe,
      canEdit: canEdit,
      canDelete: canMutate,
      canUnsend: canMutate,
      onReply: () => _startReply(
        docId,
        replyPayload['message']?.toString() ?? '',
        replyPayload['senderid']?.toString() ?? '',
        replyPayload['senderName']?.toString() ?? 'User',
        replyPayload,
      ),
      onEdit: canEdit ? () => _startEdit(docId, replyPayload['message']?.toString() ?? '') : null,
      onDelete: canMutate ? () => _deleteMessage(docId) : null,
      onUnsend: canMutate ? () => _unsendMessage(docId) : null,
    );
  }

  Widget? _buildReplyPreview({
    required Map<String, dynamic>? replyTo,
    required bool isSentByMe,
    required Color mutedColor,
    required Color primaryColor,
  }) {
    if (replyTo == null || replyTo['message'] == null) return null;

    final String quotedMsg = replyTo['message'] as String;
    final String quotedSender = replyTo['senderName'] as String? ?? 'User';
    final bool canNavigate = (replyTo['docId']?.toString() ?? '').isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 6, right: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canNavigate ? () => _handleReplyPreviewTap(replyTo) : null,
          splashColor: canNavigate ? null : Colors.transparent,
          highlightColor: canNavigate ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isSentByMe
                  ? Colors.white.withOpacity(_kReplyPreviewSentBackgroundOpacity)
                  : primaryColor.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border(
                left: BorderSide(
                  color: isSentByMe
                      ? Colors.white.withOpacity(_kReplyPreviewSentBorderOpacity)
                      : primaryColor,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quotedSender,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isSentByMe ? Colors.white : primaryColor,
                        ),
                      ),
                      if (replyTo['edited'] == true &&
                          replyTo['deleted'] != true &&
                          replyTo['unsent'] != true) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Edited',
                          style: TextStyle(
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                            color: isSentByMe
                                ? Colors.white.withOpacity(_kReplyPreviewSentTextOpacity)
                                : mutedColor,
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        quotedMsg.length > _kMaxQuoteLength
                            ? '${quotedMsg.substring(0, _kMaxQuoteLength)}…'
                            : quotedMsg,
                        style: TextStyle(
                          fontSize: 11,
                          color: isSentByMe
                              ? Colors.white.withOpacity(_kReplyPreviewSentTextOpacity)
                              : mutedColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (canNavigate) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.subdirectory_arrow_left_rounded,
                    size: 16,
                    color: isSentByMe
                        ? Colors.white.withOpacity(_kReplyPreviewSentIconOpacity)
                        : primaryColor,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// WhatsApp-style read receipt tick for admin-sent messages.
  /// Double grey ticks = delivered (not yet read by user).
  /// Double blue ticks = read by user.
  Widget _buildSeenTick(bool seen) {
    // WhatsApp blue (#34B7F1) for read, slate-grey for delivered-not-read.
    const kReadBlue = Color(0xFF34B7F1);
    const kDelivered = Color(0xFF94A3B8);
    return Icon(
      Icons.done_all,
      size: 14,
      color: seen ? kReadBlue : kDelivered,
    );
  }

  /// Call history message bubble.
  Widget _buildCallBubble(
      String callType, String status, int durationSeconds, bool isSentByMe, DateTime timestamp,
      {Widget? replyPreview}) {
    const kPrimary = Color(0xFFD81B60);
    const kMuted = Color(0xFF64748B);
    final bool isMissed = status == 'missed';
    final bool isVideo = callType == 'video';
    final Color color = isMissed ? Colors.red : kPrimary;
    final String label = isMissed
        ? (isVideo ? 'Missed Video Call' : 'Missed Call')
        : (isVideo ? 'Video Call' : 'Audio Call');
    final IconData icon = isMissed
        ? (isVideo ? Icons.videocam_off_outlined : Icons.phone_missed)
        : (isVideo ? Icons.videocam_outlined : Icons.phone_outlined);
    final String dur = durationSeconds > 0 ? ' • ${_formatCallDuration(durationSeconds)}' : '';

    return Align(
      alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (replyPreview != null) replyPreview,
          Container(
            margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isMissed ? Colors.red.shade50 : const Color(0xFFFCE4EC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isMissed ? Colors.red.shade200 : const Color(0xFFFFCDD2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$label$dur',
                      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      DateFormat('hh:mm a').format(timestamp),
                      style: const TextStyle(fontSize: 10, color: kMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String? value, Color labelColor, Color valueColor) {
    if (value == null || value.isEmpty || value == 'null') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 11, color: labelColor),
          const SizedBox(width: 5),
          SizedBox(
            width: 58,
            child: Text(
              label,
              style: TextStyle(fontSize: 9.5, color: labelColor, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 9.5, color: valueColor, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String text, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onPressed,
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  void _playAudio(String url) async {
    final AudioPlayer _audioPlayer = AudioPlayer();
    try {
      await _audioPlayer.setUrl(url);
      await _audioPlayer.play();
    } catch (e) {
    }
  }

  /// Inline reply/edit banner shown above the message input.
  Widget _buildActionBanner(ChatColors colors) {
    const kPrimary = Color(0xFFD81B60);
    final bool isEditing = _editingDocId != null;
    final bool replyingToEdited = _replyingTo?['edited'] == true &&
        _replyingTo?['deleted'] != true &&
        _replyingTo?['unsent'] != true;
    final String label = isEditing
        ? 'Editing'
        : 'Replying to ${_replyingTo?['senderName'] ?? 'User'}${replyingToEdited ? ' • edited' : ''}';
    final String preview = isEditing
        ? (_editingOriginalText.length > _kMaxQuoteLength
            ? '${_editingOriginalText.substring(0, _kMaxQuoteLength)}…'
            : _editingOriginalText)
        : (() {
            final String msg = (_replyingTo?['message'] as String?) ?? '';
            return msg.length > _kMaxQuoteLength ? '${msg.substring(0, _kMaxQuoteLength)}…' : msg;
          }());
    final IconData leadIcon = isEditing ? Icons.edit_outlined : Icons.reply_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: kPrimary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kPrimary.withOpacity(0.25), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 36,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: kPrimary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Icon(leadIcon, size: 15, color: kPrimary),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: kPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: colors.muted),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _cancelAction,
            child: Icon(Icons.close, size: 16, color: colors.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput(ChatProvider chatProvider) {
    const kPrimary = Color(0xFFD81B60);
    // Dark-mode tints for the language-selector chip
    const kLangNepaliDarkBg     = Color(0xFF4A1A1A);
    const kLangEnglishDarkBg    = Color(0xFF1A2A40);
    const kLangNepaliDarkBorder = Color(0xFFCC4444);
    const kLangEnglishDarkBorder= Color(0xFF4488CC);
    const kLangNepaliDarkText   = Color(0xFFFF6B6B);
    const kLangEnglishDarkText  = Color(0xFF64B5F6);
    final colors = ChatColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.inputBg,
        border: Border(top: BorderSide(color: colors.border, width: 1)),
      ),
      child: Column(
        children: [
          // ── Inline reply / edit banner ──────────────────────────────────
          if (_replyingTo != null || _editingDocId != null)
            _buildActionBanner(colors),
          if (_selectedImage != null || _selectedImageBytes != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: kIsWeb
                            ? MemoryImage(_selectedImageBytes!) as ImageProvider
                            : FileImage(_selectedImage!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _sendImageMessage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: const Text("Send", style: TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.close, color: colors.muted, size: 18),
                    onPressed: () {
                      setState(() {
                        _selectedImage = null;
                        _selectedImageBytes = null;
                      });
                    },
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.emoji_emotions, color: colors.muted, size: 20),
                onPressed: _showEmojiPicker,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(width: 2),
              IconButton(
                icon: Icon(Icons.attach_file, color: colors.muted, size: 20),
                onPressed: _pickImage,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
              // Language selector button
              Tooltip(
                message: _selectedLanguage == 'en-US' ? 'Switch to Nepali' : 'Switch to English',
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedLanguage = _selectedLanguage == 'en-US' ? 'ne-NP' : 'en-US';
                      if (_webSpeechRecognition != null) {
                        _webSpeechRecognition!['lang'] = _selectedLanguage;
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: _isListening
                          ? (_selectedLanguage == 'ne-NP'
                              ? (colors.isDark ? kLangNepaliDarkBg : Colors.red.shade50)
                              : (colors.isDark ? kLangEnglishDarkBg : Colors.blue.shade50))
                          : colors.cardBg,
                      border: Border.all(
                        color: _selectedLanguage == 'ne-NP'
                            ? (colors.isDark ? kLangNepaliDarkBorder : Colors.red.shade300)
                            : (colors.isDark ? kLangEnglishDarkBorder : Colors.blue.shade300),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _selectedLanguage == 'en-US' ? 'EN' : 'ने',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _selectedLanguage == 'ne-NP'
                            ? (colors.isDark ? kLangNepaliDarkText : Colors.red.shade700)
                            : (colors.isDark ? kLangEnglishDarkText : Colors.blue.shade700),
                      ),
                    ),
                  ),
                ),
              ),
              // Mic button
              IconButton(
                tooltip: _isListening ? 'Stop voice typing' : 'Start voice typing',
                icon: Icon(
                  _isListening ? Icons.mic_off : Icons.mic,
                  color: _isListening ? kPrimary : colors.muted,
                  size: 20,
                ),
                onPressed: _isListening ? _stopListening : _startListening,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: CallbackShortcuts(
                  bindings: <ShortcutActivator, VoidCallback>{
                    const SingleActivator(LogicalKeyboardKey.enter): () {
                      final keys = HardwareKeyboard.instance.logicalKeysPressed;
                      final bool hasModifier = keys.contains(LogicalKeyboardKey.shiftLeft) ||
                          keys.contains(LogicalKeyboardKey.shiftRight) ||
                          keys.contains(LogicalKeyboardKey.controlLeft) ||
                          keys.contains(LogicalKeyboardKey.controlRight) ||
                          keys.contains(LogicalKeyboardKey.altLeft) ||
                          keys.contains(LogicalKeyboardKey.altRight) ||
                          keys.contains(LogicalKeyboardKey.metaLeft) ||
                          keys.contains(LogicalKeyboardKey.metaRight);

                      final int lineCount = _estimateLineCount(_messageController.text);
                      final String trimmed = _messageController.text.trim();

                      if (!hasModifier && lineCount <= 2 && trimmed.isNotEmpty) {
                        _sendMessage();
                        return;
                      }

                      final selection = _messageController.selection;
                      final start = selection.start >= 0 ? selection.start : _messageController.text.length;
                      final end = selection.end >= 0 ? selection.end : _messageController.text.length;
                      final String newText = _messageController.text.replaceRange(start, end, '\n');
                      _messageController.value = TextEditingValue(
                        text: newText,
                        selection: TextSelection.collapsed(offset: start + 1),
                      );
                    },
                  },
                  child: TextField(
                    controller: _messageController,
                    focusNode: _messageFocusNode,
                    textInputAction: TextInputAction.newline,
                    minLines: 1,
                    maxLines: 6,
                    onChanged: (text) {
                      if (chatProvider.id != null) {
                        _updateAdminTypingStatus(text, chatProvider.id.toString());
                      }
                    },
                    style: TextStyle(color: colors.text, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: _selectedLanguage == 'ne-NP'
                          ? "सन्देश टाइप गर्नुहोस्"
                          : "Type a message",
                      hintStyle: TextStyle(color: colors.muted, fontSize: 14),
                      filled: true,
                      fillColor: colors.searchFill,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: colors.border, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: kPrimary, width: 1.5),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: colors.border, width: 1),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _messageController,
                builder: (context, value, child) {
                  final hasText = value.text.trim().isNotEmpty;
                  return GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: hasText ? kPrimary : colors.border,
                        borderRadius: BorderRadius.circular(19),
                      ),
                      child: Icon(
                        Icons.send_rounded,
                        color: hasText ? Colors.white : colors.muted,
                        size: 18,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null) {
        if (kIsWeb) {
          setState(() {
            _selectedImageBytes = result.files.single.bytes;
            _selectedImage = null;
          });
        } else {
          if (result.files.single.path != null) {
            setState(() {
              _selectedImage = File(result.files.single.path!);
              _selectedImageBytes = null;
            });
          }
        }
      } else {
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error picking image: $e")),
      );
    }
  }

  void _sendImageMessage() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    if (_selectedImage == null && _selectedImageBytes == null) return;

    // Capture data and clear UI immediately (background processing)
    final File? imageToSend = _selectedImage;
    final Uint8List? imageBytesToSend = _selectedImageBytes;
    final String receiverId = chatProvider.id.toString();

    setState(() {
      _selectedImage = null;
      _selectedImageBytes = null;
    });

    // Upload and send in background without blocking the UI
    _uploadImageInBackground(imageToSend, imageBytesToSend, receiverId);
  }

  Future<void> _uploadImageInBackground(
    File? image,
    Uint8List? imageBytes,
    String receiverId,
  ) async {
    try {
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference storageRef = _storage.ref().child('chat_images/$fileName');
      UploadTask uploadTask;

      if (kIsWeb) {
        uploadTask = storageRef.putData(imageBytes!);
      } else {
        uploadTask = storageRef.putFile(image!);
      }

      TaskSnapshot snapshot = await uploadTask;
      String imageUrl = await snapshot.ref.getDownloadURL();

      await _firestore.collection('adminchat').add({
        'message': 'Image',
        'liked': false,
        'replyto': '',
        'senderid': senderId.toString(),
        'receiverid': receiverId,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'image',
        'imageUrl': imageUrl,
        'seen': false,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Failed to send image: $e")));
      }
    }
  }

  int _estimateLineCount(String text) {
    if (text.isEmpty) return 1;
    return text.split('\n').length;
  }

  Future<void> _sendMessage() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    if (_messageController.text.trim().isEmpty) return;

    String messageText = _messageController.text.trim();

    // --- Inline Edit Mode ---
    if (_editingDocId != null) {
      final docId = _editingDocId!;
      _messageController.clear();
      _textBeforeVoice = '';
      setState(() {
        _editingDocId = null;
        _editingOriginalText = '';
      });
      FocusScope.of(context).requestFocus(_messageFocusNode);
      _clearAdminTypingStatus();
      try {
        await _applyMessageMutation(
          docId: docId,
          updates: {
            'message': messageText,
            'edited': true,
            'deleted': false,
            'unsent': false,
          },
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text("Failed to edit message: $e")));
        }
      }
      return;
    }

    // Clear immediately so the UI feels instant
    _messageController.clear();
    _textBeforeVoice = '';
    final replySnapshot = _replyingTo;
    setState(() => _replyingTo = null);
    FocusScope.of(context).requestFocus(_messageFocusNode);

    // Clear typing indicator immediately on send.
    _clearAdminTypingStatus();

    try {
      await _firestore.collection('adminchat').add({
        'message': messageText,
        'liked': false,
        'replyto': replySnapshot,
        'senderid': senderId.toString(),
        'receiverid': chatProvider.id.toString(),
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'text',
        'seen': false,
      });

      await NotificationService.sendChatNotification(
        recipientUserId: chatProvider.id.toString(),
        senderName: "Admin",
        senderId: '1',
        message: messageText,
        extraData: {
          'chatId': chatProvider.id.toString(),
          'screen': 'chat',
        },
      );

      String conversationId = getConversationId(
        senderId.toString(),
        chatProvider.id.toString(),
      );

      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .set({
        'participants': [senderId.toString(), chatProvider.id.toString()],
        'lastMessage': messageText,
        'lastTimestamp': FieldValue.serverTimestamp(),
        'lastSenderId': senderId.toString(),
      }, SetOptions(merge: true));

    } catch (e) {
      // Restore message text so user doesn't lose their content
      if (_messageController.text.isEmpty) {
        _messageController.text = messageText;
        _messageController.selection = TextSelection.fromPosition(
          TextPosition(offset: messageText.length),
        );
        _textBeforeVoice = messageText;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to send message")),
      );
    }
  }

  String getConversationId(String a, String b) {
    return (a.compareTo(b) < 0) ? '${a}_$b' : '${b}_$a';
  }

  void _showMessageOptions(
    BuildContext context,
    String docId,
    Map<String, dynamic> replyPayload,
    bool isSentByMe, {
    required bool canEdit,
    required bool canMutate,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.reply_rounded, size: 20, color: Color(0xFFD81B60)),
              title: const Text("Reply", style: TextStyle(fontSize: 14)),
              onTap: () {
                Navigator.pop(context);
                _startReply(
                  docId,
                  replyPayload['message']?.toString() ?? '',
                  replyPayload['senderid']?.toString() ?? '',
                  replyPayload['senderName']?.toString() ?? 'User',
                  replyPayload,
                );
              },
            ),
            if (isSentByMe && canEdit) ...[
              ListTile(
                leading: const Icon(Icons.edit, size: 20, color: Color(0xFF0EA5E9)),
                title: const Text("Edit", style: TextStyle(fontSize: 14)),
                onTap: () {
                  Navigator.pop(context);
                  _startEdit(docId, replyPayload['message']?.toString() ?? '');
                },
              ),
            ],
            if (isSentByMe && canMutate) ...[
              ListTile(
                leading: const Icon(Icons.delete, size: 20, color: Color(0xFFEF4444)),
                title: const Text("Delete", style: TextStyle(fontSize: 14)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(docId);
                },
              ),
              ListTile(
                leading: const Icon(Icons.remove_circle_outline_rounded, size: 20, color: Color(0xFFF59E0B)),
                title: const Text("Unsend", style: TextStyle(fontSize: 14)),
                onTap: () {
                  _unsendMessage(docId);
                  Navigator.pop(context);
                },
              ),
            ],
          ],
        );
      },
    );
  }

  void _editMessage(String docId, String currentMessage) {
    _startEdit(docId, currentMessage);
  }

  void _replyToMessage(String originalMessage, String docId, String senderid, String senderName) {
    _startReply(docId, originalMessage, senderid, senderName);
  }

  void _deleteMessage(String docId) {
    _applyMessageMutation(
      docId: docId,
      updates: {
        'message': _kDeletedMessageText,
        'deleted': true,
        'unsent': false,
        'edited': false,
      },
    ).catchError((error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete message: $error')),
        );
      }
    });
  }

  void _unsendMessage(String docId) {
    _applyMessageMutation(
      docId: docId,
      updates: {
        'message': _kUnsentMessageText,
        'unsent': true,
        'deleted': false,
        'edited': false,
      },
    ).catchError((error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unsend message: $error')),
        );
      }
    });
  }

  // ── INLINE REPLY / EDIT ─────────────────────────────────────────────────

  void _startReply(
    String docId,
    String message,
    String senderid,
    String senderName, [
    Map<String, dynamic>? payload,
  ]) {
    setState(() {
      _replyingTo = payload ??
          _buildFallbackReplyPayload(
            docId: docId,
            message: message,
            senderId: senderid,
            senderName: senderName,
          );
      _editingDocId = null;
    });
    FocusScope.of(context).requestFocus(_messageFocusNode);
  }

  void _startEdit(String docId, String message) {
    setState(() {
      _editingDocId = docId;
      _editingOriginalText = message;
      _replyingTo = null;
      _messageController.text = message;
      _messageController.selection =
          TextSelection.fromPosition(TextPosition(offset: message.length));
    });
    FocusScope.of(context).requestFocus(_messageFocusNode);
  }

  void _cancelAction() {
    setState(() {
      _replyingTo = null;
      if (_editingDocId != null) {
        _editingDocId = null;
        _editingOriginalText = '';
        _messageController.clear();
      }
    });
    FocusScope.of(context).requestFocus(_messageFocusNode);
  }

  void _showEmojiPicker() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: SizedBox(
            height: 240,
            width: 240,
            child: EmojiPicker(
              onEmojiSelected: (category, emoji) {
                setState(() {
                  _messageController.text += emoji.emoji;
                });
              },
              config: Config(),
            ),
          ),
        );
      },
    );
  }

  void _searchMessages(String query) {
    if (_lastSnapshot == null) return;

    setState(() {
      if (query.isEmpty) {
        _filteredMessages.clear();
      } else {
        _filteredMessages = _lastSnapshot!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          String message = data['message']?.toString().toLowerCase() ?? '';
          return message.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _removeCallOverlay();
    _typingTimer?.cancel();
    _replyHighlightTimer?.cancel();
    _floatingDateTimer?.cancel();
    _floatingDateNotifier.dispose();
    _typingSubscription?.cancel();
    _clearAdminTypingStatus();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _messageController.dispose();
    _searchController.dispose();
    _recorder.closeRecorder();
    super.dispose();
  }
}

class _HighlightableMessageContainer extends StatelessWidget {
  static const double _kHighlightOpacity = 0.9;

  const _HighlightableMessageContainer({
    super.key,
    required this.child,
    required this.isHighlighted,
  });

  final Widget child;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final colors = ChatColors.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
      decoration: BoxDecoration(
        color: isHighlighted
            ? colors.primaryLight.withOpacity(_kHighlightOpacity)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

class _HoverableMessageBubble extends StatefulWidget {
  const _HoverableMessageBubble({
    required this.bubble,
    required this.isSentByMe,
    required this.onReply,
    this.onEdit,
    this.onDelete,
    this.onUnsend,
    this.canEdit = false,
    this.canDelete = false,
    this.canUnsend = false,
  });

  final Widget bubble;
  final bool isSentByMe;
  final VoidCallback onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onUnsend;
  final bool canEdit;
  final bool canDelete;
  final bool canUnsend;

  @override
  State<_HoverableMessageBubble> createState() => _HoverableMessageBubbleState();
}

class _HoverableMessageBubbleState extends State<_HoverableMessageBubble>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _onEnter(_) {
    setState(() => _isHovered = true);
    _fadeController.forward();
  }

  void _onExit(_) {
    setState(() => _isHovered = false);
    _fadeController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final actionMenu = _MessageActionMenu(
      onReply: widget.onReply,
      onEdit: widget.onEdit,
      onDelete: widget.onDelete,
      onUnsend: widget.onUnsend,
      canEdit: widget.canEdit,
      canDelete: widget.canDelete,
      canUnsend: widget.canUnsend,
    );

    return MouseRegion(
      onEnter: _onEnter,
      onExit: _onExit,
      child: Row(
        mainAxisAlignment:
            widget.isSentByMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.isSentByMe)
            FadeTransition(
              opacity: _fadeAnimation,
              child: IgnorePointer(
                ignoring: !_isHovered,
                child: actionMenu,
              ),
            ),
          widget.bubble,
          FadeTransition(
            opacity: _fadeAnimation,
            child: IgnorePointer(
              ignoring: !_isHovered,
              child: widget.isSentByMe ? const SizedBox.shrink() : actionMenu,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small dropdown icon button that opens the WhatsApp-style popup menu.
class _MessageActionMenu extends StatelessWidget {
  const _MessageActionMenu({
    required this.onReply,
    this.onEdit,
    this.onDelete,
    this.onUnsend,
    this.canEdit = false,
    this.canDelete = false,
    this.canUnsend = false,
  });

  final VoidCallback onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onUnsend;
  final bool canEdit;
  final bool canDelete;
  final bool canUnsend;

  @override
  Widget build(BuildContext context) {
    const kPrimary = Color(0xFFD81B60);

    return PopupMenuButton<_MsgAction>(
      padding: EdgeInsets.zero,
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        size: 17,
        color: Color(0xFF94A3B8),
      ),
      iconSize: 17,
      splashRadius: 14,
      tooltip: '',
      offset: const Offset(0, 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 6,
      color: Colors.white,
      onSelected: (action) {
        switch (action) {
          case _MsgAction.reply:
            onReply();
            break;
          case _MsgAction.edit:
            onEdit?.call();
            break;
          case _MsgAction.delete:
            onDelete?.call();
            break;
          case _MsgAction.unsend:
            onUnsend?.call();
            break;
        }
      },
      itemBuilder: (context) => [
        _menuItem(_MsgAction.reply, Icons.reply_rounded, 'Reply', kPrimary),
        if (canEdit)
          _menuItem(_MsgAction.edit, Icons.edit_outlined, 'Edit', const Color(0xFF0EA5E9)),
        if (canDelete)
          _menuItem(_MsgAction.delete, Icons.delete_outline_rounded, 'Delete', const Color(0xFFEF4444)),
        if (canUnsend)
          _menuItem(_MsgAction.unsend, Icons.remove_circle_outline_rounded, 'Unsend', const Color(0xFFF59E0B)),
      ],
    );
  }

  PopupMenuItem<_MsgAction> _menuItem(
      _MsgAction value, IconData icon, String label, Color color) {
    return PopupMenuItem<_MsgAction>(
      value: value,
      height: 38,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

enum _MsgAction { reply, edit, delete, unsend }

// ---------------------------------------------------------------------------
// Data class grouping chat messages by calendar date.
// ---------------------------------------------------------------------------
class _ChatMessageDateGroup {
  final DateTime date;
  final String headerLabel;
  final List<QueryDocumentSnapshot> messages;

  _ChatMessageDateGroup({
    required this.date,
    required this.headerLabel,
    required List<QueryDocumentSnapshot> messages,
  }) : messages = List<QueryDocumentSnapshot>.from(messages);
}

// ---------------------------------------------------------------------------
// Inline (non-pinned) sliver header that shows the date chip between message groups.
// ---------------------------------------------------------------------------
class _ChatDateHeaderDelegate extends SliverPersistentHeaderDelegate {
  static const double kExtent = 36.0;

  final String label;
  final Color backgroundColor;
  final Color chipColor;
  final Color textColor;
  final Color borderColor;

  const _ChatDateHeaderDelegate({
    required this.label,
    required this.backgroundColor,
    required this.chipColor,
    required this.textColor,
    required this.borderColor,
  });

  @override
  double get minExtent => kExtent;

  @override
  double get maxExtent => kExtent;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: backgroundColor,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: chipColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: textColor,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_ChatDateHeaderDelegate oldDelegate) {
    return oldDelegate.label != label ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.chipColor != chipColor ||
        oldDelegate.textColor != textColor ||
        oldDelegate.borderColor != borderColor;
  }
}
