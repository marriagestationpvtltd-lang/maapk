import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../Auth/Screen/signupscreen10.dart';
import '../Calling/OutgoingCall.dart';
import '../Calling/videocall.dart';
import '../Calling/call_history_model.dart';
import '../Calling/call_history_service.dart';
import 'ChatdetailsScreen.dart';
import '../Models/masterdata.dart';
import '../otherenew/othernew.dart';
import '../utils/image_utils.dart';
import '../utils/time_utils.dart';

class AdminChatScreen extends StatefulWidget {
  final String senderID;
  final String userName;
  final bool isAdmin;
  final Map<String, dynamic>? initialProfileData; // Optional profile card data

  const AdminChatScreen({
    super.key,
    required this.senderID,
    required this.userName,
    this.isAdmin = false,
    this.initialProfileData, // Make it optional
  });

  @override
  State<AdminChatScreen> createState() => _AdminChatScreenState();
}

class _AdminChatScreenState extends State<AdminChatScreen>
    with WidgetsBindingObserver {
  static const String _adminUserId = '1';
  static const String _adminUserName = 'Admin';

  final TextEditingController _controller = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isSending = false;
  String? _replyToID;
  Map<String, dynamic>? _replyToMessage;
  final ScrollController _scrollController = ScrollController();
  final List<String> _suggestedMessages = [
    "How can I verify my profile?",
    "I need help with subscription plans",
    "How do I contact a potential match?",
    "I want to report a suspicious profile",
    "Can you help me with profile suggestions?",
    "How do I reset my password?",
    "I'm having technical issues with the app"
  ];
  bool _showSuggestedMessages = true;
  bool _isFirstLoad = true;
  bool _profileCardSent = false; // Track if profile card was sent
  String _currentUserImage = ''; // Store current user image

  static const int _messagePageSize = 30;

  // Pagination & cache
  List<DocumentSnapshot> _cachedMessages = [];
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;
  DocumentSnapshot? _lastDocument;
  StreamSubscription<QuerySnapshot>? _msgSubscription;
  bool _streamLoading = true;
  bool _streamHasError = false;

  // Admin online status
  bool _adminOnline = false;
  DateTime? _adminLastSeen;
  StreamSubscription<DocumentSnapshot>? _adminStatusSubscription;

  // Swipe-to-reply offsets (keyed by message ID)
  final Map<String, double> _swipeOffsets = {};

  // Call history
  List<CallHistory> _callHistory = [];
  bool _showCallHistory = false;
  bool _callHistoryLoaded = false;

  // Current user verification state (loaded for non-admin)
  String _currentUserDocStatus = '';
  String _currentUserType = '';

// Updated color scheme with gradients
  final LinearGradient _primaryGradient = const LinearGradient(
    colors: [Color(0xFF6B46C1), Color(0xFF9F7AEA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  final LinearGradient _secondaryGradient = const LinearGradient(
    colors: [Color(0xFFE9D5FF), Color(0xFFD6BCFA)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  final Color _accentColor = const Color(0xFFEC4899);
  final Color _backgroundColor = const Color(0xFFF8FAFC);
  final Color _textColor = const Color(0xFF1F2937);
  final Color _lightTextColor = const Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserImage();
    if (!widget.isAdmin) {
      _loadCurrentUserData();
    }
    _scrollController.addListener(_onScroll);
    _startAdminStatusListener();
    _msgSubscription = _messagesStream().listen(
      (snapshot) {
        if (!mounted) return;
        final streamDocs = snapshot.docs.reversed.toList(); // chronological
        final streamDocIds = streamDocs.map((d) => d.id).toSet();
        final paginatedDocs =
            _cachedMessages.where((d) => !streamDocIds.contains(d.id)).toList();
        final newCache = [...paginatedDocs, ...streamDocs];
        final firstLoad = _isFirstLoad;
        setState(() {
          _cachedMessages = newCache;
          _streamLoading = false;
          _hasMoreMessages = snapshot.docs.length >= _messagePageSize;
          if (_lastDocument == null && snapshot.docs.isNotEmpty) {
            _lastDocument = snapshot.docs.last; // oldest (desc query → last)
          }
          if (firstLoad && newCache.isNotEmpty) {
            _isFirstLoad = false;
          }
        });
        if (firstLoad && newCache.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
          });
        }
      },
      onError: (_) {
        if (mounted) setState(() { _streamHasError = true; _streamLoading = false; });
      },
    );
    // Call history is loaded lazily when the user taps the call history header

// Automatically send profile card if provided (optional)
    if (widget.initialProfileData != null && !_profileCardSent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendProfileCard();
      });
    }
  }

  Future<void> _loadCurrentUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');
      if (userDataString == null) return;
      final userData = jsonDecode(userDataString);
      final userId = userData['id']?.toString() ?? '';
      if (userId.isEmpty) return;

      final url = Uri.parse(
        'https://digitallami.com/Api2/masterdata.php?userid=$userId',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final res = jsonDecode(response.body);
        if (res['success'] == true) {
          final masterData = UserMasterData.fromJson(res['data']);
          if (mounted) {
            setState(() {
              _currentUserDocStatus = masterData.docStatus;
              _currentUserType = masterData.usertype;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading current user data: $e');
    }
  }

  Future<void> _handleProfileCardChat(BuildContext context, String userId, String displayName) async {
    if (_currentUserDocStatus.isEmpty || _currentUserType.isEmpty) {
      await _loadCurrentUserData();
    }
    if (!context.mounted) return;

    final docStatus = _currentUserDocStatus;
    final userType = _currentUserType;

    if (docStatus == 'approved' && userType == 'paid') {
      try {
        final prefs = await SharedPreferences.getInstance();
        final userDataString = prefs.getString('user_data');
        if (userDataString == null) return;
        final userData = jsonDecode(userDataString);
        final currentUserId = userData['id']?.toString() ?? '';
        final currentUserName = userData['firstName']?.toString() ?? '';

        final List<String> ids = [currentUserId, userId];
        ids.sort();
        final chatRoomId = ids.join('_');

        final chatRoomDoc = await FirebaseFirestore.instance
            .collection('chatRooms')
            .doc(chatRoomId)
            .get();

        if (!chatRoomDoc.exists) {
          await FirebaseFirestore.instance
              .collection('chatRooms')
              .doc(chatRoomId)
              .set({
            'chatRoomId': chatRoomId,
            'participants': [currentUserId, userId],
            'participantNames': {
              currentUserId: currentUserName,
              userId: displayName,
            },
            'participantImages': {
              currentUserId: resolveApiImageUrl(_currentUserImage),
              userId: '',
            },
            'unreadCount': {currentUserId: 0, userId: 0},
            'lastMessage': '',
            'lastMessageType': 'text',
            'lastMessageTime': DateTime.now(),
            'lastMessageSenderId': '',
            'createdAt': DateTime.now(),
            'updatedAt': DateTime.now(),
          });
        }

        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatDetailScreen(
              chatRoomId: chatRoomId,
              receiverId: userId,
              receiverName: displayName.isNotEmpty ? displayName : 'User $userId',
              receiverImage: '',
              currentUserId: currentUserId,
              currentUserName: currentUserName.isNotEmpty ? currentUserName : 'User $currentUserId',
              currentUserImage: resolveApiImageUrl(_currentUserImage),
            ),
          ),
        );
      } catch (e) {
        debugPrint('Error opening chat: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to open chat. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else if (docStatus == 'not_uploaded' && userType == 'free') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => IDVerificationScreen()));
    } else if (userType == 'free' && docStatus == 'approved') {
      _showUpgradeChatDialog(context);
    } else if (userType == 'paid' && docStatus != 'approved') {
      _showDocumentVerificationDialog(context);
    } else if (docStatus == 'pending') {
      _showDocumentPendingDialog(context);
    } else if (docStatus == 'rejected') {
      _showDocumentRejectedDialog(context);
    } else {
      _showUpgradeChatDialog(context);
    }
  }

  Future<void> _handleProfileCardViewProfile(BuildContext context, String userId) async {
    if (_currentUserDocStatus.isEmpty) {
      await _loadCurrentUserData();
    }
    if (!context.mounted) return;

    final docStatus = _currentUserDocStatus;
    if (docStatus == 'approved') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId)),
      );
    } else if (docStatus == 'pending') {
      _showDocumentPendingDialog(context);
    } else if (docStatus == 'rejected') {
      _showDocumentRejectedDialog(context);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => IDVerificationScreen()),
      );
    }
  }

  void _showUpgradeChatDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Premium Membership Required'),
        content: const Text(
          'You have not taken a premium membership, therefore you cannot chat. '
          'Please upgrade your plan to start chatting.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }

  void _showDocumentVerificationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Document Verification Pending'),
        content: const Text(
          'Your document verification is in progress. '
          'Please wait for approval before starting a chat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showDocumentPendingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Document Under Review'),
        content: const Text(
          'Your document is currently under review. '
          'You will be able to chat once it has been verified.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showDocumentRejectedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Document Rejected'),
        content: const Text(
          'Your document was rejected. '
          'Please upload a valid document to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => IDVerificationScreen()),
              );
            },
            child: const Text('Re-upload'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadUserImage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');
      if (userDataString != null) {
        final userData = jsonDecode(userDataString);
        setState(() {
          _currentUserImage = userData['image']?.toString() ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error loading user image: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _msgSubscription?.cancel();
    _adminStatusSubscription?.cancel();
    _scrollController.removeListener(_onScroll);
    _controller.dispose();
    _messageFocusNode.dispose();
    _audioPlayer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startAdminStatusListener();
    }
  }

  void _startAdminStatusListener() {
    _adminStatusSubscription?.cancel();
    _adminStatusSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(_adminUserId)
        .snapshots()
        .listen((doc) {
      if (!mounted) return;
      if (!doc.exists) {
        setState(() {
          _adminOnline = false;
          _adminLastSeen = null;
        });
        return;
      }
      final data = doc.data() as Map<String, dynamic>;
      final bool online = data['isOnline'] == true;
      final Timestamp? lastSeenTs = data['lastSeen'] as Timestamp?;
      final DateTime? lastSeen = lastSeenTs?.toDate();
      final bool recentlySeen = lastSeen != null &&
          DateTime.now().difference(lastSeen).inMinutes < 5;
      setState(() {
        _adminOnline = online || recentlySeen;
        _adminLastSeen = lastSeen;
      });
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

// FIXED: Correct Firestore query for chat between two users
  Stream<QuerySnapshot> _messagesStream() {
    return FirebaseFirestore.instance
        .collection('adminchat')
        .where('senderid', whereIn: [widget.senderID, _adminUserId])
        .where('receiverid', whereIn: [widget.senderID, _adminUserId])
        .orderBy('timestamp', descending: true)
        .limit(_messagePageSize)
        .snapshots();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels <=
        _scrollController.position.minScrollExtent + 200) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages || _lastDocument == null) return;
    setState(() => _isLoadingMore = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('adminchat')
          .where('senderid', whereIn: [widget.senderID, _adminUserId])
          .where('receiverid', whereIn: [widget.senderID, _adminUserId])
          .orderBy('timestamp', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_messagePageSize)
          .get();

      if (snap.docs.isEmpty) {
        setState(() { _isLoadingMore = false; _hasMoreMessages = false; });
        return;
      }

      final olderDocs = snap.docs.reversed.toList(); // chronological
      final prevOffset = _scrollController.hasClients
          ? _scrollController.position.pixels
          : 0.0;

      setState(() {
        final existingIds = _cachedMessages.map((d) => d.id).toSet();
        final newDocs = olderDocs.where((d) => !existingIds.contains(d.id)).toList();
        _cachedMessages = [...newDocs, ..._cachedMessages];
        _lastDocument = snap.docs.last;
        _hasMoreMessages = snap.docs.length >= _messagePageSize;
        _isLoadingMore = false;
      });

      // Restore scroll position so newly inserted older messages don't cause a visual jump.
      // We jump to the previous pixel offset so the user stays at the same apparent position.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients &&
            _scrollController.position.maxScrollExtent >= prevOffset) {
          _scrollController.jumpTo(prevOffset);
        }
      });
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadCallHistory() async {
    try {
      final all = await CallHistoryService.getCallHistoryPaginated(
          userId: widget.senderID, limit: 50);
      final filtered = all
          .where((c) =>
              (c.callerId == widget.senderID && c.recipientId == _adminUserId) ||
              (c.callerId == _adminUserId && c.recipientId == widget.senderID))
          .toList();
      if (mounted) setState(() {
        _callHistory = filtered;
        _callHistoryLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _callHistoryLoaded = true);
    }
  }

  String _formatDateForGrouping(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(dt.year, dt.month, dt.day);
    if (d == today) return 'Today';
    if (d == yesterday) return 'Yesterday';
    return DateFormat('MMM d, yyyy').format(dt);
  }

  String _formatCallDateTime(DateTime dt) {
    return DateFormat('MMM d, h:mm a').format(dt);
  }

// Method to send profile card
  Future<void> _sendProfileCard() async {
    if (widget.initialProfileData == null || _profileCardSent) return;

    setState(() {
      _profileCardSent = true;
    });

    final profileData = {
      'userId': widget.initialProfileData!['userId'] ?? '',
      'name': widget.initialProfileData!['name'] ?? 'Unknown User',
      'lastName': widget.initialProfileData!['lastName'] ?? '',
      'firstName': widget.initialProfileData!['userid'] ?? '',
      'profileImage': widget.initialProfileData!['profileImage'] ?? '',
      'bio': widget.initialProfileData!['bio'] ?? 'No bio available',
      'location':
          widget.initialProfileData!['location'] ?? 'Location not specified',
      'age': widget.initialProfileData!['age'] ?? 'N/A',
      'height': widget.initialProfileData!['height'] ?? 'N/A',
      'religion': widget.initialProfileData!['religion'] ?? 'N/A',
      'community': widget.initialProfileData!['community'] ?? 'N/A',
      'occupation': widget.initialProfileData!['occupation'] ?? 'N/A',
      'education': widget.initialProfileData!['education'] ?? 'N/A',
      'shouldBlurPhoto': widget.initialProfileData!['shouldBlurPhoto'] ?? true,
      'timestamp': DateTime.now().toIso8601String(),
    };

    await _sendMessage('profile_card', 'Profile Information',
        profileData: profileData);
  }

// FIXED: Correct sender/receiver logic
  Future<void> _sendMessage(String type, String content,
      {String? imageUrl, Map<String, dynamic>? profileData}) async {
// Determine sender and receiver based on user type
    final senderId = widget.senderID;
    final receiverId =
        widget.isAdmin ? "user_id_placeholder" : _adminUserId;

    final Map<String, dynamic> messageData = {
      'message': content,
      'liked': false,
      'replyto': _replyToID ?? '',
      'senderid': senderId,
      'receiverid': receiverId,
      'timestamp': FieldValue.serverTimestamp(),
      'type': type,
    };

// Add optional fields if provided
    if (imageUrl != null) {
      messageData['imageUrl'] = imageUrl;
    }
    if (profileData != null) {
      messageData['profileData'] = profileData;
    }

    await FirebaseFirestore.instance.collection('adminchat').add(messageData);
// ✅ UPDATE CONVERSATION (THIS FIXES MOVE TO TOP)
    String getConversationId(String a, String b) {
      return (a.compareTo(b) < 0) ? '${a}_$b' : '${b}_$a';
    }

    final senderIdStr = senderId.toString();
    final receiverIdStr = receiverId.toString();

    String conversationId = getConversationId(senderIdStr, receiverIdStr);

    await FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .set({
      'participants': [senderIdStr, receiverIdStr],
      'lastMessage': content,
      'lastTimestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    setState(() {
      _replyToID = null;
      _replyToMessage = null;
      if (_showSuggestedMessages) _showSuggestedMessages = false;
    });

    if (!widget.isAdmin) {
      _sendNotification(content);
    }

    _scrollToBottom();
  }

  Future<void> _sendText() async {
    if (_isSending) return;
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      _controller.clear();
      _messageFocusNode.requestFocus();
      setState(() { _isSending = true; });
      try {
        await _sendMessage('text', text);
      } finally {
        if (mounted) setState(() { _isSending = false; });
      }
    }
  }

  Future<void> _sendSuggestedMessage(String message) async {
    await _sendMessage('text', message);
  }

  Future<void> _sendDoc() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
    );
    if (result != null) {
      File file = File(result.files.single.path!);
      String fileName = result.files.single.name;
      UploadTask task = FirebaseStorage.instance
          .ref('adminchat/${widget.senderID}/docs/$fileName')
          .putFile(file);
      TaskSnapshot snap = await task;
      String url = await snap.ref.getDownloadURL();
      await _sendMessage('doc', jsonEncode({'url': url, 'name': fileName}));
    }
  }

  Future<void> _sendImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );
    if (result != null) {
      File file = File(result.files.single.path!);
      String fileName = result.files.single.name;
      UploadTask task = FirebaseStorage.instance
          .ref('adminchat/${widget.senderID}/images/$fileName')
          .putFile(file);
      TaskSnapshot snap = await task;
      String url = await snap.ref.getDownloadURL();
      await _sendMessage('image', 'Image', imageUrl: url);
    }
  }

// FIXED: Updated like functionality
  Future<void> _toggleLike(String messageID, bool currentLiked) async {
    await FirebaseFirestore.instance
        .collection('adminchat')
        .doc(messageID)
        .update({'liked': !currentLiked});
  }

  Future<void> _setReplyTo(
      String messageID, Map<String, dynamic> messageData) async {
    setState(() {
      _replyToID = messageID;
      _replyToMessage = messageData;
    });
  }

  Future<void> _playVoice(String url) async {
    try {
      await _audioPlayer.play(UrlSource(url));
    } catch (e) {
      print('Error playing audio: $e');
    }
  }

  Future<void> _sendNotification(String message) async {
    String? adminToken = await _getAdminToken();
    if (adminToken != null && adminToken.isNotEmpty) {
      var data = {
        'to': adminToken,
        'priority': 'high',
        'notification': {
          'title': 'New Message from ${widget.userName}',
          'body':
              message.length > 50 ? '${message.substring(0, 50)}...' : message,
        },
        'data': {
          'type': 'chat',
          'senderId': widget.senderID,
          'click_action': 'FLUTTER_NOTIFICATION_CLICK'
        },
      };
      try {
        await http.post(
          Uri.parse('https://fcm.googleapis.com/fcm/send'),
          body: jsonEncode(data),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'key=YOUR_SERVER_KEY', // Replace with your FCM key
          },
        );
      } catch (e) {
        print('Error sending notification: $e');
      }
    }
  }

  Future<String?> _getAdminToken() async {
    try {
      DocumentSnapshot snap = await FirebaseFirestore.instance
          .collection('admin')
          .doc('config')
          .get();
      return snap.exists ? snap['fcmToken'] as String? : null;
    } catch (e) {
      print('Error getting admin token: $e');
      return null;
    }
  }

// FIXED: Updated message builder with swipe-to-reply
  Widget _buildMessageItem(DocumentSnapshot msg) {
    var data = msg.data() as Map<String, dynamic>;
    bool isMe = data['senderid'] == widget.senderID;
    String msgID = msg.id;
    Timestamp? ts = data['timestamp'];
    String formattedTime =
        ts != null ? DateFormat('HH:mm').format(ts.toDate()) : '';

    // Render call events inline (WhatsApp-style)
    if (data['type'] == 'call') {
      return _buildInlineCallBubble(data, ts);
    }

    // Render report messages as a special card
    if (data['type'] == 'report') {
      return _buildReportMessageCard(data, isMe, formattedTime);
    }

// Determine if message is from admin
    bool isFromAdmin = data['senderid'] == _adminUserId;
    String senderName =
        isFromAdmin ? "Admin Support" : (isMe ? "You" : widget.userName);

    double _swipeOffset = _swipeOffsets[msgID] ?? 0.0;

    return StatefulBuilder(
      builder: (context, setItemState) {
        _swipeOffset = _swipeOffsets[msgID] ?? 0.0;
        return GestureDetector(
          onDoubleTap: () => _toggleLike(msgID, data['liked'] ?? false),
          onLongPress: () => _setReplyTo(msgID, data),
          onHorizontalDragUpdate: (details) {
            if (details.delta.dx > 0) {
              setItemState(() {
                final newOffset = (_swipeOffset + details.delta.dx).clamp(0.0, 70.0);
                _swipeOffsets[msgID] = newOffset;
                _swipeOffset = newOffset;
              });
            }
          },
          onHorizontalDragEnd: (details) {
            if (_swipeOffset > 50) {
              _setReplyTo(msgID, data);
            }
            setItemState(() {
              _swipeOffsets[msgID] = 0.0;
              _swipeOffset = 0.0;
            });
          },
          child: Stack(
            children: [
              if (_swipeOffset > 10)
                Positioned(
                  left: isMe ? null : 16,
                  right: isMe ? 16 : null,
                  top: 0, bottom: 0,
                  child: Center(
                    child: AnimatedOpacity(
                      opacity: (_swipeOffset / 50).clamp(0.0, 1.0),
                      duration: const Duration(milliseconds: 100),
                      child: Icon(Icons.reply,
                          color: _primaryGradient.colors[0], size: 24),
                    ),
                  ),
                ),
              Transform.translate(
                offset: Offset(isMe ? -_swipeOffset : _swipeOffset, 0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Row(
                    mainAxisAlignment:
                        isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
            if (!isMe)
              CircleAvatar(
                backgroundColor: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient:
                        isFromAdmin ? _primaryGradient : _secondaryGradient,
                  ),
                  child: Icon(
                    isFromAdmin ? Icons.support_agent : Icons.person,
                    color: Colors.white,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 6),
                      child: Text(
                        senderName,
                        style: TextStyle(
                          fontSize: 14,
                          color: _lightTextColor,
                          fontWeight: FontWeight.w600,
                         ),
                      ),
                    ),
                  // Profile card: render directly without gradient bubble
                  if (data['type'] == 'profile_card') ...[
                    _buildProfileCardMessage(data['profileData'], isMe),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisAlignment:
                            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                        children: [
                          Text(
                            formattedTime,
                            style: TextStyle(
                              fontSize: 12,
                              color: _lightTextColor,
                            ),
                          ),
                          if (data['liked'] ?? false)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Icon(Icons.favorite,
                                  size: 16, color: _accentColor),
                            ),
                        ],
                      ),
                    ),
                  ] else
                  Container(
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: isMe ? _primaryGradient : _secondaryGradient,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: isMe
                            ? const Radius.circular(20)
                            : const Radius.circular(4),
                        bottomRight: isMe
                            ? const Radius.circular(4)
                            : const Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (data['replyto'] != null &&
                            data['replyto'].toString().isNotEmpty) ...[
                          _buildReplyPreview(data['replyto'], isMe),
                          const SizedBox(height: 8),
                        ],
                        if (data['type'] == 'text')
                          Text(
                            data['message'],
                            style: TextStyle(
                              color: isMe ? Colors.white : _textColor,
                              fontSize: 17,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        if (data['type'] == 'voice')
                          _buildVoiceMessage(data['message'], isMe),
                        if (data['type'] == 'doc')
                          _buildDocumentMessage(data['message'], isMe),
                        if (data['type'] == 'image')
                          _buildImageMessage(data['imageUrl'], isMe),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              formattedTime,
                              style: TextStyle(
                                fontSize: 12,
                                color: isMe ? Colors.white70 : _lightTextColor,
                              ),
                            ),
                            if (data['liked'] ?? false)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Icon(Icons.favorite,
                                    size: 16,
                                    color: isMe ? Colors.white : _accentColor),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (isMe) const SizedBox(width: 8),
            if (isMe)
              CircleAvatar(
                backgroundColor: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient:
                        widget.isAdmin ? _primaryGradient : _secondaryGradient,
                  ),
                  child: Icon(
                    widget.isAdmin ? Icons.support_agent : Icons.person,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
              ),
            ),
            ],
          ),
        );
      },
    );
  }

  Widget _dateSeparator(String date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: _lightTextColor.withOpacity(0.3))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              date,
              style: TextStyle(
                  fontSize: 12,
                  color: _lightTextColor,
                  fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Divider(color: _lightTextColor.withOpacity(0.3))),
        ],
      ),
    );
  }

  List<Widget> _buildMessagesFromCache() {
    final items = <Widget>[];

    String? lastDateLabel;
    for (final doc in _cachedMessages) {
      final data = doc.data() as Map<String, dynamic>;
      final ts = data['timestamp'];
      if (ts != null) {
        final dt = (ts as Timestamp).toDate();
        final label = _formatDateForGrouping(dt);
        if (label != lastDateLabel) {
          items.add(_dateSeparator(label));
          lastDateLabel = label;
        }
      }
      items.add(_buildMessageItem(doc));
    }
    return items;
  }

  Widget _buildReportMessageCard(
      Map<String, dynamic> data, bool isMe, String formattedTime) {
    final reportReason = data['reportReason'] ?? '';
    final reportedUserName = data['reportedUserName'] ?? '';
    final reportedUserId = data['reportedUserId'] ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.80),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            border: Border.all(color: Colors.orange.shade300, width: 1.2),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft:
                  isMe ? const Radius.circular(16) : const Radius.circular(4),
              bottomRight:
                  isMe ? const Radius.circular(4) : const Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.12),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade400,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flag, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'प्रोफाइल रिपोर्ट',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (reportedUserName.isNotEmpty)
                      Text(
                        'रिपोर्ट गरिएको: $reportedUserName (ID: $reportedUserId)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    if (reportedUserName.isNotEmpty) const SizedBox(height: 4),
                    Text(
                      'कारण: $reportReason',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF4A3000),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        formattedTime,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInlineCallBubble(Map<String, dynamic> data, Timestamp? ts) {
    final isVideo = (data['callType'] ?? 'audio') == 'video';
    final callStatus = data['callStatus'] ?? 'missed';
    final isMissed = callStatus == 'missed' || callStatus == 'declined' || callStatus == 'cancelled';
    final isOutgoing = (data['callerId'] ?? '') == widget.senderID;
    final duration = (data['duration'] as num?)?.toInt() ?? 0;
    final timeStr = ts != null ? DateFormat('HH:mm').format(ts.toDate()) : '';

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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              if (!_callHistoryLoaded) {
                _loadCallHistory();
              }
              setState(() => _showCallHistory = !_showCallHistory);
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.history, color: _primaryGradient.colors[0], size: 20),
                  const SizedBox(width: 10),
                  Text('Call History (${_callHistory.length})',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _textColor,
                          fontSize: 14)),
                  const Spacer(),
                  Icon(
                    _showCallHistory
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: _lightTextColor,
                  ),
                ],
              ),
            ),
          ),
          if (_showCallHistory)
            _callHistoryLoaded
                ? (_callHistory.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('No call history',
                            style: TextStyle(
                                color: _lightTextColor, fontSize: 13)),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _callHistory.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: Colors.grey.shade100),
                        itemBuilder: (context, i) =>
                            _buildCallHistoryItem(_callHistory[i]),
                      ))
                : const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
        ],
      ),
    );
  }

  Widget _buildCallHistoryItem(CallHistory call) {
    final isVideo = call.callType == CallType.video;
    final outgoing = call.callerId == widget.senderID;
    final missed = call.status == CallStatus.missed ||
        call.status == CallStatus.declined ||
        call.status == CallStatus.cancelled;

    Color iconColor;
    IconData directionIcon;
    if (missed) {
      iconColor = Colors.red;
      directionIcon = isVideo ? Icons.videocam_off : Icons.phone_missed;
    } else if (outgoing) {
      iconColor = Colors.blue;
      directionIcon = isVideo ? Icons.videocam : Icons.call_made;
    } else {
      iconColor = Colors.green;
      directionIcon = isVideo ? Icons.videocam : Icons.call_received;
    }

    String durationStr = '';
    if (!missed && call.duration > 0) {
      final m = call.duration ~/ 60;
      final s = call.duration % 60;
      durationStr = '${m}m ${s}s';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(directionIcon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  missed
                      ? 'Missed ${isVideo ? 'video' : 'voice'} call'
                      : outgoing
                          ? 'Outgoing ${isVideo ? 'video' : 'voice'} call'
                          : 'Incoming ${isVideo ? 'video' : 'voice'} call',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _textColor),
                ),
                if (durationStr.isNotEmpty)
                  Text(durationStr,
                      style: TextStyle(fontSize: 11, color: _lightTextColor)),
              ],
            ),
          ),
          Text(
            _formatCallDateTime(call.startTime),
            style: TextStyle(fontSize: 11, color: _lightTextColor),
          ),
        ],
      ),
    );
  }

// FIXED: Reply preview uses cache (no async fetch)
  Widget _buildReplyPreview(String replyToID, bool isMe) {
    // Look up from cache first
    DocumentSnapshot? cached;
    try {
      cached = _cachedMessages.firstWhere((d) => d.id == replyToID);
    } catch (_) {}

    Map<String, dynamic>? replyData;
    if (cached != null) {
      replyData = cached.data() as Map<String, dynamic>?;
    }

    if (replyData == null) {
      // Minimal placeholder – no network call
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.white.withOpacity(0.2)
              : _primaryGradient.colors[0].withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.reply, size: 14,
                color: isMe ? Colors.white70 : _primaryGradient.colors[0]),
            const SizedBox(width: 6),
            Text('Replied message',
                style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: isMe ? Colors.white70 : _lightTextColor)),
          ],
        ),
      );
    }

    bool isReplyFromMe = replyData['senderid'] == widget.senderID;
    bool isReplyFromAdmin = replyData['senderid'] == _adminUserId;
    String senderName = isReplyFromAdmin
        ? "Admin"
        : (isReplyFromMe ? "You" : widget.userName);
    String content = replyData['type'] == 'text'
        ? (replyData['message'] ?? '')
        : '${replyData['type']} message';

    return Container(
      constraints: BoxConstraints(
        minWidth: 100,
        maxWidth: MediaQuery.of(context).size.width * 0.6,
      ),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.white.withOpacity(0.2)
            : _primaryGradient.colors[0].withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe
              ? Colors.white.withOpacity(0.4)
              : _primaryGradient.colors[0].withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.reply, size: 16,
                  color: isMe ? Colors.white70 : _primaryGradient.colors[0]),
              const SizedBox(width: 6),
              Text(senderName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isMe ? Colors.white70 : _primaryGradient.colors[0],
                  )),
            ],
          ),
          const SizedBox(height: 6),
          Text(content,
              style: TextStyle(
                fontSize: 13,
                color: isMe ? Colors.white : _textColor,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildVoiceMessage(String content, bool isMe) {
    try {
      Map<String, dynamic> voiceData = jsonDecode(content);
      return GestureDetector(
        onTap: () => _playVoice(voiceData['url']),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: isMe ? _primaryGradient : _secondaryGradient,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.play_circle_filled,
                color: isMe ? Colors.white : _primaryGradient.colors[0],
                size: 28,
              ),
              const SizedBox(width: 10),
              Text(voiceData['duration'] ?? '0:15',
                  style: TextStyle(
                    color: isMe ? Colors.white : _textColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  )),
              const SizedBox(width: 6),
              Text('•',
                  style: TextStyle(
                    color: isMe ? Colors.white70 : _lightTextColor,
                  )),
              const SizedBox(width: 6),
              Text('Voice message',
                  style: TextStyle(
                    color: isMe ? Colors.white70 : _lightTextColor,
                    fontSize: 13,
                  )),
            ],
          ),
        ),
      );
    } catch (e) {
      return Text('Voice message',
          style: TextStyle(
            color: isMe ? Colors.white : _textColor,
          ));
    }
  }

  Widget _buildDocumentMessage(String content, bool isMe) {
    try {
      Map<String, dynamic> docData = jsonDecode(content);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: isMe ? _primaryGradient : _secondaryGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file,
                color: isMe ? Colors.white : _primaryGradient.colors[0],
                size: 28),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Document',
                    style: TextStyle(
                      color: isMe ? Colors.white : _textColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    docData['name'] ?? 'Unknown file',
                    style: TextStyle(
                      color: isMe ? Colors.white70 : _lightTextColor,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      return Text('Document',
          style: TextStyle(
            color: isMe ? Colors.white : _textColor,
          ));
    }
  }

  Widget _buildImageMessage(String? imageUrl, bool isMe) {
    if (imageUrl == null) {
      return Text('Image',
          style: TextStyle(
            color: isMe ? Colors.white : _textColor,
          ));
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Image.network(
          imageUrl,
          width: 220,
          height: 160,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 220,
              height: 160,
              decoration: BoxDecoration(
                gradient: _secondaryGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                  color: _accentColor,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 220,
              height: 160,
              decoration: BoxDecoration(
                gradient: _secondaryGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.broken_image, color: _lightTextColor, size: 40),
            );
          },
        ),
      ),
    );
  }

// Updated Profile Card Message with Pro-Level Design
  Widget _buildProfileCardMessage(
      Map<String, dynamic>? profileData, bool isMe) {
    if (profileData == null) {
      return Text('Profile Card',
          style: TextStyle(
            color: isMe ? Colors.white : _textColor,
          ));
    }

    final bool shouldBlurPhoto = profileData['shouldBlurPhoto'] ?? true;
    final String userId = profileData['userId']?.toString() ?? '';
    final String firstName = profileData['firstName']?.toString() ?? '';
    final String lastName = profileData['lastName']?.toString() ?? '';
    final String fullName = '$firstName $lastName'.trim();
    final String displayName =
        fullName.isNotEmpty ? fullName : (profileData['name']?.toString() ?? 'Unknown');
    final String? photoUrl = profileData['profileImage']?.toString();
    final bool hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primaryGradient.colors[0].withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Gradient header banner ──
            Container(
              height: 60,
              decoration: BoxDecoration(
                gradient: _primaryGradient,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.favorite, color: Colors.white.withOpacity(0.7), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Profile Card',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'MS-$userId',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Profile photo + name (Centered layout) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
              child: Column(
                children: [
                  Transform.translate(
                    offset: const Offset(0, -30),
                    child: Column(
                      children: [
                        // Profile photo - centered
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: shouldBlurPhoto
                                ? ImageFiltered(
                                    imageFilter: ImageFilter.blur(
                                      sigmaX: 6.0,
                                      sigmaY: 6.0,
                                    ),
                                    child: Container(
                                      width: 80,
                                      height: 80,
                                      color: Colors.grey.shade200,
                                      child: hasPhoto
                                          ? Image.network(
                                              photoUrl!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  Icon(Icons.person, size: 40, color: Colors.grey.shade400),
                                            )
                                          : Icon(Icons.person, size: 40, color: Colors.grey.shade400),
                                    ),
                                  )
                                : Container(
                                    width: 80,
                                    height: 80,
                                    color: Colors.grey.shade200,
                                    child: hasPhoto
                                        ? Image.network(
                                            photoUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Icon(Icons.person, size: 40, color: Colors.grey.shade400),
                                          )
                                        : Icon(Icons.person, size: 40, color: Colors.grey.shade400),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Name + meta - centered below
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    displayName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: _textColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Photo lock/unlock badge
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: shouldBlurPhoto ? Colors.orange.shade100 : Colors.green.shade100,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    shouldBlurPhoto ? Icons.lock_outline : Icons.lock_open_outlined,
                                    size: 12,
                                    color: shouldBlurPhoto ? Colors.orange.shade700 : Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (profileData['age'] != null && profileData['age'] != 'N/A')
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.cake_outlined, size: 13, color: _lightTextColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${profileData['age']} years',
                                    style: TextStyle(fontSize: 13, color: _lightTextColor, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            if (profileData['location'] != null &&
                                profileData['location'].toString().isNotEmpty &&
                                profileData['location'] != 'Location not specified')
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.location_on_outlined, size: 13, color: _lightTextColor),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        profileData['location'],
                                        style: TextStyle(fontSize: 12, color: _lightTextColor),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ── Info chips ──
                  Transform.translate(
                    offset: const Offset(0, -22),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (profileData['religion'] != null && profileData['religion'] != 'N/A')
                          _buildInfoChip(Icons.menu_book_outlined, profileData['religion']),
                        if (profileData['community'] != null && profileData['community'] != 'N/A')
                          _buildInfoChip(Icons.groups_outlined, profileData['community']),
                        if (profileData['occupation'] != null && profileData['occupation'] != 'N/A')
                          _buildInfoChip(Icons.work_outline, profileData['occupation']),
                        if (profileData['education'] != null && profileData['education'] != 'N/A')
                          _buildInfoChip(Icons.school_outlined, profileData['education']),
                        if (profileData['height'] != null && profileData['height'] != 'N/A')
                          _buildInfoChip(Icons.height, profileData['height']),
                      ],
                    ),
                  ),

                  // ── Bio ──
                  if (profileData['bio'] != null &&
                      profileData['bio'].toString().isNotEmpty &&
                      profileData['bio'] != 'No bio available')
                    Transform.translate(
                      offset: const Offset(0, -14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: _primaryGradient.colors[0].withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '"${profileData['bio']}"',
                          style: TextStyle(
                            fontSize: 11,
                            color: _lightTextColor,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Divider ──
            Divider(height: 1, color: Colors.grey.shade200),

            // ── Action buttons ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () {
                        if (userId.isNotEmpty) {
                          if (widget.isAdmin) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AdminChatScreen(
                                  senderID: userId,
                                  userName: displayName,
                                  isAdmin: widget.isAdmin,
                                ),
                              ),
                            );
                          } else {
                            _handleProfileCardChat(context, userId, displayName);
                          }
                        }
                      },
                      icon: Icon(Icons.chat_bubble_outline,
                          size: 16, color: _primaryGradient.colors[0]),
                      label: Text(
                        'Chat',
                        style: TextStyle(
                          color: _primaryGradient.colors[0],
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  Container(width: 1, height: 28, color: Colors.grey.shade200),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () {
                        if (userId.isNotEmpty) {
                          if (widget.isAdmin) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProfileScreen(userId: userId),
                              ),
                            );
                          } else {
                            _handleProfileCardViewProfile(context, userId);
                          }
                        }
                      },
                      icon: Icon(Icons.person_outline,
                          size: 16, color: _primaryGradient.colors[0]),
                      label: Text(
                        'View Profile',
                        style: TextStyle(
                          color: _primaryGradient.colors[0],
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _primaryGradient.colors[0].withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _primaryGradient.colors[0].withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: _primaryGradient.colors[0]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: _primaryGradient.colors[0],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showOfficeHoursDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.schedule, color: _primaryGradient.colors[0]),
            const SizedBox(width: 8),
            const Text('Office Hours'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _officeHoursDialogRow(Icons.calendar_today, 'Sunday – Friday'),
            const SizedBox(height: 6),
            _officeHoursDialogRow(Icons.access_time, '10:00 AM – 5:00 PM'),
            const Divider(height: 20),
            _officeHoursDialogRow(Icons.block, 'Saturday: Closed',
                color: Colors.red.shade700),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _officeHoursDialogRow(IconData icon, String text, {Color? color}) {
    final Color iconColor = color ?? _primaryGradient.colors[0];
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Text(text,
            style: TextStyle(
                fontSize: 14,
                color: color ?? _textColor)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: _primaryGradient,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white.withOpacity(0.25),
              child: const Icon(Icons.support_agent,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Admin Support',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 17)),
                  if (_adminOnline)
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 5),
                          decoration: const BoxDecoration(
                            color: Color(0xFF22C55E),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Text(
                          'Online',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.9)),
                        ),
                      ],
                    )
                  else if (_adminLastSeen != null)
                    Text(
                      formatLastSeen(_adminLastSeen!),
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.85)),
                    )
                  else if (!widget.isAdmin)
                    Text(
                      'Replies within 10 minutes',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.9)),
                    )
                  else
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 5),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade400,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Text(
                          'Offline',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.9)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.phone, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CallScreen(
                    currentUserId: widget.senderID,
                    currentUserName: widget.userName,
                    currentUserImage: _currentUserImage,
                    otherUserId: _adminUserId,
                    otherUserName: _adminUserName,
                    otherUserImage: '',
                    isOutgoingCall: true,
                    isAdminChat: true,
                    adminChatReceiverId: _adminUserId,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VideoCallScreen(
                    currentUserId: widget.senderID,
                    currentUserName: widget.userName,
                    currentUserImage: _currentUserImage,
                    otherUserId: _adminUserId,
                    otherUserName: _adminUserName,
                    otherUserImage: '',
                    isOutgoingCall: true,
                    isAdminChat: true,
                    adminChatReceiverId: _adminUserId,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            tooltip: 'Office Hours',
            onPressed: _showOfficeHoursDialog,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_backgroundColor, _backgroundColor.withOpacity(0.9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: _buildMessageList(),
            ),
            if (_replyToMessage != null) _buildReplyBar(),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    if (_streamHasError) {
      return Center(
          child: Text('Error loading messages',
              style: TextStyle(color: _textColor)));
    }

    if (_streamLoading && _cachedMessages.isEmpty) {
      return Center(child: CircularProgressIndicator(color: _accentColor));
    }

    if (_cachedMessages.isEmpty && _showSuggestedMessages && !widget.isAdmin) {
      return Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(gradient: _primaryGradient),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.support_agent,
                        size: 72,
                        color: Colors.white.withOpacity(0.9)),
                    const SizedBox(height: 20),
                    Text('How can we help you?',
                        style: const TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                          'Start a conversation or choose from common questions below',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 15,
                              color: Colors.white.withOpacity(0.8))),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildSuggestedMessages(),
        ],
      );
    }

    final messageWidgets = _buildMessagesFromCache();

    return Container(
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.only(top: 16, bottom: 12),
        children: [
          if (_isLoadingMore)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _accentColor),
                ),
              ),
            ),
          ...messageWidgets,
        ],
      ),
    );
  }

  Widget _buildSuggestedMessages() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, -3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Suggested questions',
              style: TextStyle(
                  fontSize: 15,
                  color: _textColor,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _suggestedMessages.map((message) {
              return InkWell(
                onTap: () => _sendSuggestedMessage(message),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: _secondaryGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(message,
                      style: TextStyle(
                          fontSize: 13,
                          color: _primaryGradient.colors[0],
                          fontWeight: FontWeight.w500)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: _secondaryGradient,
        border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          Icon(Icons.reply, color: _primaryGradient.colors[0], size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Replying to',
                    style: TextStyle(
                        fontSize: 13,
                        color: _lightTextColor,
                        fontWeight: FontWeight.w500)),
                Text(
                  _replyToMessage!['type'] == 'text'
                      ? _replyToMessage!['message']
                      : '${_replyToMessage!['type']} message',
                  style: TextStyle(
                      fontSize: 15,
                      color: _textColor,
                      fontWeight: FontWeight.w400),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 22, color: _lightTextColor),
            onPressed: () => setState(() {
              _replyToID = null;
              _replyToMessage = null;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E8FF),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, -3),
          )
        ],
      ),
      child: Row(
        children: [
          if (!widget.isAdmin)
            PopupMenuButton(
              icon: Icon(Icons.add_circle_outlined,
                  color: _primaryGradient.colors[0]),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'document',
                  child: ListTile(
                    leading: Icon(Icons.insert_drive_file,
                        color: _primaryGradient.colors[0]),
                    title: Text('Document',
                        style: TextStyle(
                            color: _textColor, fontWeight: FontWeight.w500)),
                  ),
                ),
                PopupMenuItem(
                  value: 'image',
                  child: ListTile(
                    leading:
                        Icon(Icons.image, color: _primaryGradient.colors[0]),
                    title: Text('Image',
                        style: TextStyle(
                            color: _textColor, fontWeight: FontWeight.w500)),
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'document') _sendDoc();
                if (value == 'image') _sendImage();
              },
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: _secondaryGradient,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _controller,
                focusNode: _messageFocusNode,
                maxLines: null,
                minLines: 1,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  hintStyle: TextStyle(
                      color: _lightTextColor.withOpacity(0.7), fontSize: 15),
                ),
                style: TextStyle(color: _textColor, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 22),
              onPressed: _sendText,
            ),
          ),
        ],
      ),
    );
  }
}
