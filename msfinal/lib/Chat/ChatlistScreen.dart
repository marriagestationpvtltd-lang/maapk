import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Auth/Screen/signupscreen10.dart';
import '../Models/chatservice.dart';
import '../Models/masterdata.dart';
import '../Package/PackageScreen.dart';
import '../online/onlineservice.dart';
import '../utils/time_utils.dart';
import '../utils/image_utils.dart';
import '../utils/privacy_utils.dart';
import '../purposal/Purposalmodel.dart';
import '../purposal/purposalservice.dart';
import '../pushnotification/pushservice.dart';
import '../Calling/call_history_screen.dart';
import 'ChatdetailsScreen.dart';
import 'adminchat.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with WidgetsBindingObserver {
  String usertye = '';
  String userimage = '';
  var pageno;
  String userId = '';
  String name = '';
  bool isLoading = true;
  String docstatus = '';

  List<ProposalModel> _pendingChatRequests = [];
  bool _requestsLoading = true;
  int _totalUnreadCount = 0;
  int _totalUnreadConversations = 0;

  int _displayCount = 10;
  bool _isLoadingMore = false;
  int _cachedTotalRooms = 0;
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<QuerySnapshot>? _adminChatSubscription;
  String _adminLastMessage = '';
  DateTime? _adminLastMessageTime;
  int _adminUnreadCount = 0;
  bool _adminLoading = true;
  static const String _adminUserId = '1';
  static const String _adminDisplayName = 'Admin Support';

  // Chat rooms stream stored once to prevent blinking on rebuilds
  Stream<QuerySnapshot>? _chatRoomsStream;
  List<QueryDocumentSnapshot> _cachedRooms = [];

  // Online status for chat participants
  final Map<String, bool> _onlineStatuses = {};
  final Map<String, DateTime?> _lastSeenTimes = {};
  _CompositeSubscription? _onlineStatusSubscription;

  // Admin online status
  bool _adminOnline = false;
  StreamSubscription<DocumentSnapshot>? _adminStatusSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserData();
    OnlineStatusService().start();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _adminChatSubscription?.cancel();
    _onlineStatusSubscription?.cancel();
    _adminStatusSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      OnlineStatusService().setOffline();
    } else if (state == AppLifecycleState.resumed) {
      OnlineStatusService().start();
      // Restart online status listeners so they are fresh after resume
      _startAdminStatusListener();
      if (_cachedRooms.isNotEmpty) {
        final participantIds = <String>{};
        for (final doc in _cachedRooms) {
          final data = doc.data() as Map<String, dynamic>;
          final participants =
              List<String>.from(data['participants'] ?? []);
          for (final p in participants) {
            if (p.trim() != userId.trim()) participantIds.add(p.trim());
          }
        }
        if (participantIds.isNotEmpty) {
          _startOnlineStatusListeners(participantIds.toList());
        }
      }
    }
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _displayCount < _cachedTotalRooms) {
      setState(() {
        _isLoadingMore = true;
        _displayCount += 10;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');

      if (userDataString == null) {
        setState(() => isLoading = false);
        return;
      }

      final userData = jsonDecode(userDataString);
      final rawId = userData["id"];
      final userIdString = rawId.toString().trim();

      UserMasterData user = await fetchUserMasterData(userIdString);

      if (mounted) {
        setState(() {
          usertye = user.usertype;
          userimage = user.profilePicture;
          pageno = user.pageno;
          userId = user.id?.toString() ?? userIdString;
          name = user.firstName;
          isLoading = false;
          docstatus = user.docStatus;
        });
      }

      print('=== USER DATA LOADED ===');
      print('userId: $userId');
      print('name: $name');

      await _loadPendingChatRequests(user.id?.toString() ?? userIdString);
      _startAdminChatListener(user.id?.toString() ?? userIdString);
      _initChatRoomsStream();
      _startAdminStatusListener();

    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<UserMasterData> fetchUserMasterData(String userId) async {
    final url = Uri.parse(
      "http://192.168.1.9/Api2/masterdata.php?userid=$userId",
    );

    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception("Failed: ${response.statusCode}");
    }

    final res = json.decode(response.body);

    if (res['success'] != true) {
      throw Exception(res['message'] ?? "API error");
    }

    return UserMasterData.fromJson(res['data']);
  }

  Future<void> _loadPendingChatRequests(String uid) async {
    try {
      if (mounted) setState(() => _requestsLoading = true);
      final all = await ProposalService.fetchProposals(uid, 'received');
      final pending = all
          .where((p) =>
              p.requestType?.toLowerCase() == 'chat' &&
              p.status?.toLowerCase() == 'pending')
          .toList();
      if (mounted) {
        setState(() {
          _pendingChatRequests = pending;
          _requestsLoading = false;
        });
      }
    } catch (e) {
      print('Error loading chat requests: $e');
      if (mounted) setState(() => _requestsLoading = false);
    }
  }

  Future<void> _startAdminChatListener(String uid) async {
    _adminChatSubscription?.cancel();

    if (mounted) {
      setState(() {
        _adminLoading = true;
      });
    }

    final prefs = await SharedPreferences.getInstance();
    final lastSeenString = prefs.getString('admin_chat_last_seen_$uid');
    final DateTime? lastSeen = lastSeenString != null
        ? DateTime.tryParse(lastSeenString)
        : null;

    _adminChatSubscription = FirebaseFirestore.instance
        .collection('adminchat')
        .where('senderid', whereIn: [uid, _adminUserId])
        .where('receiverid', whereIn: [uid, _adminUserId])
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      if (snapshot.docs.isEmpty) {
        setState(() {
          _adminLastMessage = '';
          _adminLastMessageTime = null;
          _adminUnreadCount = 0;
          _adminLoading = false;
        });
        return;
      }

      final Map<String, dynamic> latestData =
          snapshot.docs.first.data() as Map<String, dynamic>;
      final Timestamp? ts = latestData['timestamp'] as Timestamp?;
      final DateTime? latestTime = ts?.toDate();
      final String type = latestData['type']?.toString() ?? 'text';

      String preview;
      if (type == 'image') {
        preview = '📷 Image';
      } else if (type == 'voice') {
        preview = '🎤 Voice note';
      } else if (type == 'doc') {
        preview = '📄 Document';
      } else {
        preview = latestData['message']?.toString() ?? '';
      }

      int unread = 0;
      if (lastSeen != null) {
        unread = snapshot.docs.where((doc) {
          final Map<String, dynamic> data =
              doc.data() as Map<String, dynamic>;
          final Timestamp? timestamp = data['timestamp'] as Timestamp?;
          final DateTime? time = timestamp?.toDate();
          final String receiverId = data['receiverid']?.toString() ?? '';
          return receiverId == uid &&
              time != null &&
              time.isAfter(lastSeen);
        }).length;
      } else {
        unread = snapshot.docs
            .where((doc) =>
                (doc.data() as Map<String, dynamic>)['receiverid']
                    ?.toString() ==
                uid)
            .length;
      }

      setState(() {
        _adminLastMessage = preview;
        _adminLastMessageTime = latestTime;
        _adminUnreadCount = unread;
        _adminLoading = false;
      });
    });
  }

  Future<void> _markAdminChatSeen() async {
    if (userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'admin_chat_last_seen_$userId', DateTime.now().toIso8601String());
    if (mounted) {
      setState(() {
        _adminUnreadCount = 0;
      });
    }
  }

  /// Initialise the chat rooms stream once so rebuilds don't create a new
  /// stream (which causes a brief CircularProgressIndicator blink).
  void _initChatRoomsStream() {
    if (userId.isEmpty) return;
    final FirebaseService firebaseService = FirebaseService();
    setState(() {
      _chatRoomsStream = firebaseService.getUserChatRooms(userId);
    });
  }

  /// Listen to admin's Firestore users document for real-time online status.
  void _startAdminStatusListener() {
    _adminStatusSubscription?.cancel();
    _adminStatusSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(_adminUserId)
        .snapshots()
        .listen((doc) {
      if (!mounted) return;
      if (!doc.exists) return;
      final data = doc.data() as Map<String, dynamic>;
      final bool online = data['isOnline'] == true;
      final Timestamp? lastSeenTs = data['lastSeen'] as Timestamp?;
      final DateTime? lastSeen = lastSeenTs?.toDate();
      final bool recentlySeen = lastSeen != null &&
          DateTime.now().difference(lastSeen).inMinutes < 5;
      setState(() {
        _adminOnline = online || recentlySeen;
      });
    });
  }

  /// Listen to Firestore for online status of all chat participants.
  /// Handles batching for participants exceeding Firestore's 30-item whereIn limit.
  void _startOnlineStatusListeners(List<String> participantIds) {
    if (participantIds.isEmpty) return;
    _onlineStatusSubscription?.cancel();

    // Split into batches of 30 (Firestore whereIn limit).
    const int batchSize = 30;
    final batches = <List<String>>[];
    for (int i = 0; i < participantIds.length; i += batchSize) {
      batches.add(participantIds.sublist(
          i, (i + batchSize).clamp(0, participantIds.length)));
    }

    // Merge results from all batches using a StreamGroup-like approach with
    // manual merge into _onlineStatuses.
    final merged = <String, bool>{};
    final mergedLastSeen = <String, DateTime?>{};
    int pendingBatches = batches.length;
    final subscriptions = <StreamSubscription<QuerySnapshot>>[];

    for (final batch in batches) {
      final sub = FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: batch)
          .snapshots()
          .listen((snapshot) {
        if (!mounted) return;
        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final bool online = data['isOnline'] == true;
          final Timestamp? lastSeenTs = data['lastSeen'] as Timestamp?;
          final DateTime? lastSeen = lastSeenTs?.toDate();
          final bool recentlySeen = lastSeen != null &&
              DateTime.now().difference(lastSeen).inMinutes < 5;
          merged[doc.id] = online || recentlySeen;
          mergedLastSeen[doc.id] = lastSeen;
        }
        setState(() {
          _onlineStatuses
            ..clear()
            ..addAll(merged);
          _lastSeenTimes
            ..clear()
            ..addAll(mergedLastSeen);
        });
      });
      subscriptions.add(sub);
    }

    // Replace the single subscription with a composite cancel.
    _onlineStatusSubscription = _CompositeSubscription(subscriptions);
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    return DateFormat('hh:mm a').format(time);
  }

  /// Format a lastSeen timestamp into a human-readable "last active" string.
  String _formatLastSeen(DateTime lastSeen) => formatLastSeen(lastSeen);

  Widget _buildPinnedAdminCard() {
    final String subtitle = _adminLoading
        ? 'Loading...'
        : (_adminLastMessage.isNotEmpty
            ? _adminLastMessage
            : 'Message us anytime for help');
    final String timeLabel = _formatTime(_adminLastMessageTime);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await _markAdminChatSeen();
          if (!mounted) return;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AdminChatScreen(
                senderID: userId,
                userName: 'Admin',
                isAdmin: false,
              ),
            ),
          );
          await _markAdminChatSeen();
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF90E18), Color(0xFFD00D15)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF90E18).withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: const Icon(Icons.support_agent,
                        color: Colors.white, size: 24),
                  ),
                  Positioned(
                    bottom: 1,
                    right: 1,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _adminOnline
                            ? const Color(0xFF22C55E)
                            : Colors.grey.shade400,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          _adminDisplayName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (_adminUnreadCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$_adminUnreadCount',
                              style: const TextStyle(
                                color: Color(0xFFF90E18),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        const Spacer(),
                        if (timeLabel.isNotEmpty)
                          Text(
                            timeLabel,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(right: 5),
                          decoration: BoxDecoration(
                            color: _adminOnline
                                ? const Color(0xFF22C55E)
                                : Colors.grey.shade400,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Text(
                          _adminOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (!_adminLoading && subtitle.isNotEmpty) ...[
                          Text(
                            ' · ',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ],
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

  Future<void> _handleAcceptChatRequest(ProposalModel proposal) async {
    // Step 1: Check document status
    if (docstatus != 'approved') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => IDVerificationScreen()),
      );
      return;
    }

    // Step 2: Check payment / subscription
    if (usertye != 'paid') {
      showUpgradeDialog(context);
      return;
    }

    // Step 3: Confirm and accept
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Accept Chat Request"),
        content: Text(
          "${proposal.firstName ?? ''} ${proposal.lastName ?? ''} wants to chat with you. Accept?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Accept"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final success = await ProposalService.acceptProposal(
        proposal.proposalId.toString(),
        userId,
      );
      if (mounted) Navigator.pop(context);

      if (success) {
        // Create chat room and send "Ok Let's Talk" message
        try {
          final firebaseService = FirebaseService();
          final senderId = proposal.senderId ?? '';
          final senderName =
              '${proposal.firstName ?? ''} ${proposal.lastName ?? ''}'.trim();
          final senderImage =
              resolveApiImageUrl(proposal.profilePicture ?? '');

          if (senderId.isNotEmpty) {
            final chatRoomId = await firebaseService.getOrCreateChatRoom(
              user1Id: userId,
              user2Id: senderId,
              user1Name: name,
              user2Name: senderName,
              user1Image: resolveApiImageUrl(userimage),
              user2Image: senderImage,
            );

            await firebaseService.sendMessage(
              chatRoomId: chatRoomId,
              senderId: userId,
              receiverId: senderId,
              message: "Ok Let's Talk",
              messageType: 'text',
            );

            // Send notification to the request sender
            await NotificationService.sendChatNotification(
              recipientUserId: senderId,
              senderName: name,
              senderId: userId,
              message: "Ok Let's Talk",
            );
          }
        } catch (e) {
          print('Error creating chat room or sending initial message: $e');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Chat request accepted"),
            backgroundColor: Colors.green,
          ),
        );
        await _loadPendingChatRequests(userId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to accept request"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleRejectChatRequest(ProposalModel proposal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reject Chat Request"),
        content: const Text("Are you sure you want to reject this request?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Reject"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final success = await ProposalService.rejectProposal(
        proposal.proposalId.toString(),
        userId,
      );
      if (mounted) Navigator.pop(context);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Chat request rejected"),
            backgroundColor: Colors.orange,
          ),
        );
        await _loadPendingChatRequests(userId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to reject request"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildChatRequestsSection() {
    if (_requestsLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: LinearProgressIndicator(),
      );
    }

    if (_pendingChatRequests.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Chat Requests (${_pendingChatRequests.length})',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        SizedBox(
          height: 148,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _pendingChatRequests.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final req = _pendingChatRequests[index];
              return _buildChatRequestCard(req);
            },
          ),
        ),
        const Divider(height: 16),
      ],
    );
  }

  Widget _buildChatRequestCard(ProposalModel req) {
    final imageUrl = req.profilePicture?.isNotEmpty == true
        ? req.profilePicture!
        : 'https://static.vecteezy.com/system/resources/previews/022/997/791/non_2x/contact-person-icon-transparent-blur-glass-effect-icon-free-vector.jpg';
    final displayName =
        '${req.firstName ?? ''} ${req.lastName ?? ''}'.trim();

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth =
            (MediaQuery.sizeOf(context).width * 0.55).clamp(180.0, 240.0);
        return Container(
          width: cardWidth,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: const [
              BoxShadow(blurRadius: 4, color: Colors.black12, offset: Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  PrivacyUtils.buildPrivacyAwareAvatar(
                    imageUrl: imageUrl,
                    privacy: req.privacy,
                    photoRequest: req.photoRequest,
                    radius: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName.isEmpty ? 'User' : displayName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          req.city ?? '',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.black54),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Wants to chat with you',
                style: TextStyle(fontSize: 11, color: Colors.black54),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _handleAcceptChatRequest(req),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF90E18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text(
                            'Accept',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _handleRejectChatRequest(req),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text(
                            'Reject',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }


  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text('Chat', style: TextStyle(color: Colors.black87)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (userId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text('Chat', style: TextStyle(color: Colors.black87)),
        ),
        body: const Center(
          child: Text('Unable to load user data'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF90E18), Color(0xFFD00D15)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            const Text('Chats', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
            if (_totalUnreadConversations > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_totalUnreadConversations',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.call),
              tooltip: 'Call History',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CallHistoryScreen(),
                  ),
                );
              },
            ),
          ],
        ),
        body: Container(
          color: const Color(0xFFFAF0F0),
          child: Column(
            children: [
              _buildChatRequestsSection(),
              _buildPinnedAdminCard(),
              if (_totalUnreadCount > 0)
                Container(
                  color: const Color(0xFFF90E18).withOpacity(0.08),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.message, color: Color(0xFFF90E18), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '$_totalUnreadCount unread messages in $_totalUnreadConversations conversations',
                        style: const TextStyle(
                          color: Color(0xFFF90E18),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: _buildChatListWithDebug(),
              ),
            ],
          ),
        ),
        floatingActionButton: null,
    );
  }

  Widget _buildChatListWithDebug() {
    // Use the pre-initialised stream so rebuilds don't create a new connection.
    if (_chatRoomsStream == null) {
      return _cachedRooms.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFF90E18)))
          : _buildRoomsList(_cachedRooms);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _chatRoomsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
              ],
            ),
          );
        }

        // While waiting: show cached rooms if available to avoid blinking.
        if (snapshot.connectionState == ConnectionState.waiting) {
          if (_cachedRooms.isNotEmpty) {
            return _buildRoomsList(_cachedRooms);
          }
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFFF90E18)));
        }

        final chatRooms = snapshot.data!.docs;

        // Cache rooms and start/refresh online-status listener.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final participantIds = <String>{};
          for (final doc in chatRooms) {
            final data = doc.data() as Map<String, dynamic>;
            final participants =
                List<String>.from(data['participants'] ?? []);
            for (final p in participants) {
              if (p.trim() != userId.trim()) participantIds.add(p.trim());
            }
          }
          // Calculate unread counts
          int totalUnread = 0;
          int unreadConversations = 0;
          for (final doc in chatRooms) {
            final data = doc.data() as Map<String, dynamic>;
            final unreadCount =
                Map<String, int>.from(data['unreadCount'] ?? {});
            final myUnread = unreadCount[userId] ?? 0;
            totalUnread += myUnread;
            if (myUnread > 0) unreadConversations++;
          }
          if (_totalUnreadCount != totalUnread ||
              _totalUnreadConversations != unreadConversations ||
              _cachedTotalRooms != chatRooms.length ||
              _cachedRooms.length != chatRooms.length) {
            setState(() {
              _cachedRooms = chatRooms;
              _totalUnreadCount = totalUnread;
              _totalUnreadConversations = unreadConversations;
              _cachedTotalRooms = chatRooms.length;
            });
            if (participantIds.isNotEmpty) {
              _startOnlineStatusListeners(participantIds.toList());
            }
          }
        });

        if (chatRooms.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline,
                    size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No conversations yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return _buildRoomsList(chatRooms);
      },
    );
  }

  Widget _buildRoomsList(List<QueryDocumentSnapshot> chatRooms) {
    final displayedRooms =
        chatRooms.sublist(0, _displayCount.clamp(0, chatRooms.length));

    return Container(
      color: Colors.white,
      child: ListView.separated(
        controller: _scrollController,
        itemCount: displayedRooms.length + (_isLoadingMore ? 1 : 0),
        separatorBuilder: (_, __) =>
            const Divider(indent: 72, height: 1, color: Color(0xFFE0E0E0)),
        itemBuilder: (context, index) {
          // Loading indicator at the bottom
          if (index == displayedRooms.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                  child:
                      CircularProgressIndicator(color: Color(0xFFF90E18))),
            );
          }

          final chatRoom = displayedRooms[index];
          final data = chatRoom.data() as Map<String, dynamic>;

          final participants =
              List<String>.from(data['participants'] ?? []);
          final participantNames =
              Map<String, String>.from(data['participantNames'] ?? {});
          final participantImages =
              Map<String, String>.from(data['participantImages'] ?? {});
          final participantPrivacy =
              Map<String, String>.from(data['participantPrivacy'] ?? {});
          final participantPhotoRequests =
              Map<String, String>.from(data['participantPhotoRequests'] ?? {});
          final unreadCount =
              Map<String, int>.from(data['unreadCount'] ?? {});
          final lastMessage = data['lastMessage'] ?? '';
          final Timestamp? lastMessageTimestamp =
              data['lastMessageTime'] as Timestamp?;
          final DateTime? lastMessageTime = lastMessageTimestamp?.toDate();
          final lastMessageType = data['lastMessageType'] ?? 'text';
          final lastMessageSenderId =
              data['lastMessageSenderId'] ?? '';
          final int unreadForMe = unreadCount[userId] ?? 0;

          // Find the OTHER participant (not me)
          String otherParticipantId = '';
          String otherPersonName = '';

          for (var participantId in participants) {
            if (participantId.trim() != userId.trim()) {
              otherParticipantId = participantId;
              otherPersonName =
                  participantNames[otherParticipantId] ?? 'Unknown';
              break;
            }
          }

          if (otherParticipantId.isEmpty) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: const Text(
                'Error: Could not find other participant',
                style: TextStyle(color: Colors.red),
              ),
            );
          }

          // Determine if last message was sent by me
          final isLastMessageFromMe =
              lastMessageSenderId == userId;

          // Prepare message preview
          String messagePreview = '';
          if (lastMessageType == 'image') {
            messagePreview =
                isLastMessageFromMe ? 'You: 📷 Photo' : '📷 Photo';
          } else if (lastMessageType == 'voice') {
            messagePreview = isLastMessageFromMe
                ? 'You: 🎤 Voice message'
                : '🎤 Voice message';
          } else {
            messagePreview =
                isLastMessageFromMe ? 'You: $lastMessage' : lastMessage;
          }

          final String formattedTime = _formatTime(lastMessageTime);

          // Online status for this participant
          final bool isOnline =
              _onlineStatuses[otherParticipantId] ?? false;
          final DateTime? participantLastSeen =
              _lastSeenTimes[otherParticipantId];
          final String resolvedOtherImage = resolveApiImageUrl(
              participantImages[otherParticipantId] ?? '');

          // Extract privacy data for the other participant
          final String? otherParticipantPrivacy =
              participantPrivacy[otherParticipantId];
          final String? otherParticipantPhotoRequest =
              participantPhotoRequests[otherParticipantId];

          return InkWell(
            onTap: () {
              if (docstatus == "approved" && usertye == "paid") {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatDetailScreen(
                      chatRoomId: data['chatRoomId'] ?? chatRoom.id,
                      receiverId: otherParticipantId,
                      receiverName: otherPersonName,
                      receiverImage: resolvedOtherImage,
                      receiverPrivacy: otherParticipantPrivacy,
                      receiverPhotoRequest: otherParticipantPhotoRequest,
                      currentUserId: userId,
                      currentUserName: name,
                      currentUserImage: resolveApiImageUrl(userimage),
                    ),
                  ),
                );
              }
              if (docstatus == "not_uploaded" && usertye == 'free') {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => IDVerificationScreen()));
              }
              if (usertye == "free" && docstatus == 'approved') {
                showUpgradeDialog(context);
              }
            },
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.white, Color(0xFFF8FAFC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: unreadForMe > 0
                      ? const Color(0xFFFFE4E6)
                      : const Color(0xFFE5E7EB),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Image with online status indicator
                  Stack(
                    children: [
                      PrivacyUtils.buildPrivacyAwareAvatar(
                        imageUrl: resolvedOtherImage,
                        privacy: otherParticipantPrivacy,
                        photoRequest: otherParticipantPhotoRequest,
                        radius: 28,
                        backgroundColor: Colors.grey[200],
                      ),
                      // Green online dot (top-right)
                      if (isOnline)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            width: 13,
                            height: 13,
                            decoration: BoxDecoration(
                              color: const Color(0xFF22C55E),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      // Unread count badge (bottom-right)
                      if (unreadForMe > 0)
                        Positioned(
                          bottom: -2,
                          right: -2,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF90E18),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$unreadForMe',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(width: 12),

                  // Chat Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                otherPersonName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: unreadForMe > 0
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: const Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (formattedTime.isNotEmpty)
                              Text(
                                formattedTime,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: unreadForMe > 0
                                      ? const Color(0xFFF90E18)
                                      : Colors.grey[600],
                                  fontWeight: unreadForMe > 0
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        if (isOnline)
                          const Row(
                            children: [
                              Icon(Icons.circle,
                                  size: 8, color: Color(0xFF22C55E)),
                              SizedBox(width: 4),
                              Text(
                                'Online',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF22C55E),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          )
                        else if (participantLastSeen != null)
                          Row(
                            children: [
                              const Icon(Icons.access_time,
                                  size: 10, color: Colors.grey),
                              const SizedBox(width: 3),
                              Text(
                                _formatLastSeen(participantLastSeen),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 3),
                        Text(
                          messagePreview,
                          style: TextStyle(
                            fontSize: 14,
                            color: unreadForMe > 0
                                ? const Color(0xFF0F172A)
                                : Colors.grey[700],
                            fontWeight: unreadForMe > 0
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }


  void showUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFff0000),
                  Color(0xFF2575FC),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chat_bubble_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),

                const SizedBox(height: 20),

                // Title
                const Text(
                  "Upgrade to Chat",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                // Description
                const Text(
                  "Unlock unlimited messaging and premium chat features by upgrading your plan.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 28),

                // Buttons
                Row(
                  children: [
                    // Skip Button
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          "Skip",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Upgrade Button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (context) => SubscriptionPage(),));
                          // Navigate to upgrade screen
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          "Upgrade",
                          style: TextStyle(
                            color: Color(0xFFff0000),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

}

/// Helper to group multiple [StreamSubscription]s and cancel them all at once.
class _CompositeSubscription {
  final List<StreamSubscription> _subscriptions;

  _CompositeSubscription(this._subscriptions);

  void cancel() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }
}
