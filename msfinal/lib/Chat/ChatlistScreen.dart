import 'dart:async';
import 'dart:convert';

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
import '../purposal/Purposalmodel.dart';
import '../purposal/purposalservice.dart';
import '../Calling/call_history_screen.dart';
import 'ChatdetailsScreen.dart';
import 'adminchat.dart';

class ChatListScreen extends StatefulWidget {
  ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
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
  String _userCity = '';
  static const String _adminUserId = '1';
  static const String _adminDisplayName = 'Admin Support';
  final LinearGradient _adminGradient = const LinearGradient(
    colors: [Color(0xFF0F172A), Color(0xFF1D4ED8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    _loadUserData();
    OnlineStatusService().start();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _adminChatSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
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
      final detectedCity = (userData['city'] ??
              userData['current_city'] ??
              userData['address'] ??
              '')
          .toString();

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
          _userCity = detectedCity;
        });
      }

      print('=== USER DATA LOADED ===');
      print('userId: $userId');
      print('name: $name');

      await _loadPendingChatRequests(user.id?.toString() ?? userIdString);
      _startAdminChatListener(user.id?.toString() ?? userIdString);

    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<UserMasterData> fetchUserMasterData(String userId) async {
    final url = Uri.parse(
      "https://digitallami.com/Api2/masterdata.php?userid=$userId",
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

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    return DateFormat('hh:mm a').format(time);
  }

  Widget _buildLocationChip(String label, {bool highlight = false}) {
    final bool hasLabel = label.trim().isNotEmpty;
    final String display = hasLabel ? label : 'Location not shared';
    final Color baseColor =
        highlight ? const Color(0xFF1D4ED8) : const Color(0xFF6B7280);
    final Color background =
        highlight ? const Color(0xFFE0E7FF) : const Color(0xFFF3F4F6);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: baseColor.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on_rounded, size: 14, color: baseColor),
          const SizedBox(width: 6),
          Text(
            display,
            style: TextStyle(
              color: baseColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinnedAdminCard() {
    final String subtitle = _adminLoading
        ? 'Loading admin updates...'
        : (_adminLastMessage.isNotEmpty
            ? _adminLastMessage
            : 'Message us anytime for account help');
    final String timeLabel = _formatTime(_adminLastMessageTime);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          await _markAdminChatSeen();
          if (!mounted) return;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AdminChatScreen(
                senderID: userId,
                userName: name,
                isAdmin: false,
              ),
            ),
          );
          await _markAdminChatSeen();
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: _adminGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white.withOpacity(0.18),
                    child: const Icon(Icons.support_agent,
                        color: Colors.white, size: 28),
                  ),
                  Positioned(
                    bottom: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.push_pin,
                              size: 12, color: Color(0xFF1D4ED8)),
                          SizedBox(width: 4),
                          Text(
                            'Pinned',
                            style: TextStyle(
                              color: Color(0xFF1D4ED8),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
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
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (_adminUnreadCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$_adminUnreadCount new',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        const Spacer(),
                        if (timeLabel.isNotEmpty)
                          Text(
                            timeLabel,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildLocationChip(
                          _userCity.isNotEmpty ? _userCity : 'Set your city',
                          highlight: true,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.shield_moon_outlined,
                                  size: 14, color: Colors.white),
                              SizedBox(width: 6),
                              Text(
                                'Admin support',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
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
          height: 130,
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

    return Container(
      width: 200,
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
              CircleAvatar(
                radius: 22,
                backgroundImage: NetworkImage(imageUrl),
                onBackgroundImageError: (_, __) {},
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
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF90E18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text(
                        'Accept',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
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
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text(
                        'Reject',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
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
              tooltip: 'कल हिस्ट्री',
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
        floatingActionButton: FloatingActionButton(
          onPressed: _debugFirebaseData,
          child: const Icon(Icons.bug_report),
        ),
    );
  }

  Widget _buildChatListWithDebug() {
    final FirebaseService _firebaseService = FirebaseService();

    return StreamBuilder<QuerySnapshot>(
      stream: _firebaseService.getUserChatRooms(userId),
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

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFF90E18)));
        }

        final chatRooms = snapshot.data!.docs;

        // Calculate total unread count and conversations
        int totalUnread = 0;
        int unreadConversations = 0;
        for (var chatRoom in chatRooms) {
          final data = chatRoom.data() as Map<String, dynamic>;
          final unreadCount = Map<String, int>.from(data['unreadCount'] ?? {});
          final myUnread = unreadCount[userId] ?? 0;
          totalUnread += myUnread;
          if (myUnread > 0) unreadConversations++;
        }

        // Update state if changed
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              (_totalUnreadCount != totalUnread ||
                  _totalUnreadConversations != unreadConversations ||
                  _cachedTotalRooms != chatRooms.length)) {
            setState(() {
              _totalUnreadCount = totalUnread;
              _totalUnreadConversations = unreadConversations;
              _cachedTotalRooms = chatRooms.length;
            });
          }
        });

        if (chatRooms.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No conversations yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final displayedRooms = chatRooms.sublist(0, _displayCount.clamp(0, chatRooms.length));

        // Build the chat list with pagination
        return Container(
          color: Colors.white,
          child: ListView.separated(
            controller: _scrollController,
            itemCount: displayedRooms.length + (_isLoadingMore ? 1 : 0),
            separatorBuilder: (_, __) => const Divider(indent: 72, height: 1, color: Color(0xFFE0E0E0)),
            itemBuilder: (context, index) {
            // Loading indicator at the bottom
            if (index == displayedRooms.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(color: Color(0xFFF90E18))),
              );
            }

            final chatRoom = displayedRooms[index];
            final data = chatRoom.data() as Map<String, dynamic>;

            final participants = List<String>.from(data['participants'] ?? []);
            final participantNames = Map<String, String>.from(data['participantNames'] ?? {});
            final participantImages = Map<String, String>.from(data['participantImages'] ?? {});
            final unreadCount = Map<String, int>.from(data['unreadCount'] ?? {});
            final lastMessage = data['lastMessage'] ?? '';
            final Timestamp? lastMessageTimestamp =
                data['lastMessageTime'] as Timestamp?;
            final DateTime? lastMessageTime = lastMessageTimestamp?.toDate();
            final lastMessageType = data['lastMessageType'] ?? 'text';
            final lastMessageSenderId = data['lastMessageSenderId'] ?? '';
            final participantLocations = data['participantLocations'] != null
                ? Map<String, dynamic>.from(data['participantLocations'])
                : <String, dynamic>{};
            final int unreadForMe = unreadCount[userId] ?? 0;

            print('\n=== Building Chat Item $index ===');
            print('Participants: $participants');
            print('Participant Names: $participantNames');
            print('My userId: $userId');
            print('My name from master data: $name');

            // Find the OTHER participant (not me)
            String otherParticipantId = '';
            String otherPersonName = '';
            dynamic rawLocation;
            String locationLabel = 'Location not shared';
            bool hasLocation = false;

            for (var participantId in participants) {
              if (participantId.trim() != userId.trim()) {
                otherParticipantId = participantId;

                // Get name from Firebase data
                otherPersonName = participantNames[otherParticipantId] ?? 'Unknown';
                rawLocation = participantLocations[otherParticipantId];
                if ((rawLocation?.toString().trim().isNotEmpty ?? false)) {
                  locationLabel = rawLocation.toString().trim();
                  hasLocation = true;
                }

                // DEBUG: Check if the name matches what we expect
                print('Found other participant: ID=$otherParticipantId, Name from Firebase=$otherPersonName');

                break;
              }
            }

            // If no other participant found, show error
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
            final isLastMessageFromMe = lastMessageSenderId == userId;

            // Prepare message preview
            String messagePreview = '';

            if (lastMessageType == 'image') {
              messagePreview = isLastMessageFromMe ? 'You: 📷 Photo' : '📷 Photo';
            } else if (lastMessageType == 'voice') {
              messagePreview = isLastMessageFromMe ? 'You: 🎤 Voice message' : '🎤 Voice message';
            } else {
              messagePreview = isLastMessageFromMe ? 'You: $lastMessage' : lastMessage;
            }

            // Format time
            String formattedTime = _formatTime(lastMessageTime);

            return InkWell(
              onTap: () {
                print('\n=== NAVIGATING TO CHAT ===');
                print('My ID: $userId, My Name: $name');
                print('Other Person ID: $otherParticipantId, Other Person Name: $otherPersonName');
                if (docstatus == "approved" && usertye == "paid") {   Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatDetailScreen(
                      chatRoomId: data['chatRoomId'] ?? chatRoom.id,
                      receiverId: otherParticipantId,
                      receiverName: otherPersonName, // Use name from Firebase
                      receiverImage: participantImages[otherParticipantId] ??
                          'https://via.placeholder.com/150',
                      currentUserId: userId,
                      currentUserName: name, // Your name from master data
                      currentUserImage: userimage,
                    ),
                  ),
                );}
                if (docstatus == "not_uploaded" && usertye == 'free') {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => IDVerificationScreen()));
                }
                if (usertye == "free" && docstatus == 'approved') {
                  showUpgradeDialog(context);
                }


              },
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                    // Profile Image with online status
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: NetworkImage(
                            participantImages[otherParticipantId] ??
                            "https://static.vecteezy.com/system/resources/previews/022/997/791/non_2x/contact-person-icon-transparent-blur-glass-effect-icon-free-vector.jpg"
                          ),
                        ),
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
                              // Other Person's Name
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

                              // Time
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

                          const SizedBox(height: 5),

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
                          // Removed location chip and "Tap to continue chat" message as per user request
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
      },
    );
  }

  // Debug function to check Firebase data
  Future<void> _debugFirebaseData() async {
    print('\n=== DEBUG FIREBASE DATA ===');
    print('Current User ID: $userId');
    print('Current User Name: $name');

    try {
      final chatRooms = await FirebaseFirestore.instance
          .collection('chatRooms')
          .where('participants', arrayContains: userId)
          .get();

      print('Total chat rooms found: ${chatRooms.docs.length}');

      for (var doc in chatRooms.docs) {
        final data = doc.data();
        print('\n--- Chat Room: ${doc.id} ---');
        print('Participants: ${data['participants']}');
        print('Participant Names: ${data['participantNames']}');
        print('Last Message: "${data['lastMessage']}"');
        print('Last Message Type: ${data['lastMessageType']}');
        print('Last Message Sender ID: "${data['lastMessageSenderId']}"');
        print('Unread Count: ${data['unreadCount']}');

        // Check who is who
        final participants = List<String>.from(data['participants'] ?? []);
        for (var participant in participants) {
          print('  Participant $participant: ${data['participantNames']?[participant]}');
        }
      }
    } catch (e) {
      print('Error debugging: $e');
    }
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
