import 'dart:async';
import 'dart:convert';


import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_theme.dart';
import 'chatprovider.dart';
import 'chatscreen.dart';
import 'constant.dart';
import 'services/web_notification_service.dart';

class ChatSidebar extends StatefulWidget {
  /// Called on mobile when the user taps a conversation so the parent can
  /// switch from the list panel to the chat panel.
  final VoidCallback? onUserTap;

  const ChatSidebar({super.key, this.onUserTap});

  @override
  _ChatSidebarState createState() => _ChatSidebarState();
}

class _ChatSidebarState extends State<ChatSidebar> {
  Map<String, Map<String, dynamic>> conversationMap = {};

  List<dynamic> _users = [];
  List<dynamic> _filteredUsers = [];
  String _searchQuery = "";

  static const int _maxUnreadBadge = 99;

  // Filter options
  bool _showOnlyPaid = false;
  bool _showOnlyOnline = false;
  bool _showWithMatches = false;
  bool _showOnlyUnread = false;
  String _sortBy = 'recent'; // 'recent', 'name', 'matches', 'online'

  // Unread message counts: userId -> count of unseen messages from that user
  Map<String, int> _unreadCounts = {};

  Map<String, dynamic>? _selectedChat;
  final int senderId = 1;
  StreamSubscription? _conversationSub;
  StreamSubscription<QuerySnapshot>? _presenceSub;
  StreamSubscription<QuerySnapshot>? _unreadSub;

  // Tracks the last known message timestamp per conversation so we can
  // detect truly NEW incoming messages (from users, not the admin).
  final Map<String, Timestamp?> _prevLastTimestamps = {};
  bool _isFirstConversationSnapshot = true;

  // Pagination
  int _page = 1;
  static const int _pageSize = 30;
  int _totalUsers = 0;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _isInitialLoading = true;
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;
  Timer? _onlineStatusTimer;
  ChatProvider? _chatProvider;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    fetchUsers(reset: true);
    // Poll online status every 10 seconds so the list updates live
    _onlineStatusTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _refreshOnlineStatus(),
    );
    // Real-time Firestore listener for immediate offline/online status updates
    _startPresenceListener();
    // Real-time listener for per-user unread message counts
    _startUnreadListener();

    // Sync selection when navigating from other modules (e.g., Members -> Chat)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatProvider = context.read<ChatProvider>();
      _chatProvider?.addListener(_handleExternalSelection);
      _handleExternalSelection();
    });
  }

  @override
  void dispose() {
    _conversationSub?.cancel();
    _presenceSub?.cancel();
    _unreadSub?.cancel();
    _scrollController.dispose();
    _searchDebounce?.cancel();
    _onlineStatusTimer?.cancel();
    _chatProvider?.removeListener(_handleExternalSelection);
    super.dispose();
  }

  static const _kLastChatUserKey = 'last_selected_chat_user_id';

  Future<void> _saveLastSelectedUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastChatUserKey, userId);
  }

  Future<String?> _loadLastSelectedUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kLastChatUserKey);
  }

  Future<void> fetchUsers({bool reset = false}) async {
    if (_isLoadingMore && !reset) return;

    if (reset) {
      _page = 1;
      _hasMore = true;
      _users = [];
      _filteredUsers = [];
      _isInitialLoading = true;
      _conversationSub?.cancel();
      _conversationSub = null;
    }

    if (!_hasMore && !reset) return;

    if (mounted) setState(() => _isLoadingMore = true);

    try {
      final Map<String, String> queryParams = {
        'page': _page.toString(),
        'limit': _pageSize.toString(),
      };
      if (_searchQuery.isNotEmpty) {
        queryParams['search'] = _searchQuery;
      }

      final uri = Uri.parse('https://digitallami.com/get.php')
          .replace(queryParameters: queryParams);
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final List<dynamic> newUsers = (jsonResponse["data"] as List?) ?? [];

        // Support totalRecords / total fields from the server
        int? serverTotal = jsonResponse["totalRecords"] is int
            ? jsonResponse["totalRecords"] as int
            : jsonResponse["total"] is int
                ? jsonResponse["total"] as int
                : null;
        serverTotal ??= int.tryParse(
                jsonResponse["totalRecords"]?.toString() ?? '') ??
            int.tryParse(jsonResponse["total"]?.toString() ?? '');

        if (reset) {
          _users = newUsers;
          _totalUsers = serverTotal ?? newUsers.length;
        } else {
          // Deduplicate by userId to prevent the same user appearing twice when
          // pages overlap or are re-fetched.
          final existingIds = _users
              .map((u) => u['id']?.toString())
              .whereType<String>()
              .toSet();
          final dedupedNew = newUsers
              .where((u) => !existingIds.contains(u['id']?.toString()))
              .toList();
          _users = [..._users, ...dedupedNew];
          if (serverTotal != null) _totalUsers = serverTotal;
        }

        // Determine if more pages exist
        if (serverTotal != null) {
          _hasMore = _users.length < serverTotal;
        } else {
          _hasMore = newUsers.length >= _pageSize;
        }
        _page++;

        if (reset) {
          // Try to restore the last selected user from persistent storage.
          final savedId = await _loadLastSelectedUserId();
          final chatProvider =
              Provider.of<ChatProvider>(context, listen: false);

          if (_users.isNotEmpty) {
            // Priority: external selection (chatProvider.id) > saved prefs ID > first user
            final targetId = chatProvider.id?.toString() ?? savedId;
            if (targetId != null) {
              _selectedChat = _users.firstWhere(
                (user) => user['id']?.toString() == targetId,
                orElse: () => _users[0],
              );
            } else {
              _selectedChat = _users[0];
            }
            // Sync ChatProvider so the ChatWindow shows the selected user immediately.
            _updateSelectedChat();
          }
          listenToConversationChanges();
          // Restart the Firestore presence listener now that _users is populated.
          // The initial snapshot will immediately apply any pending online/offline
          // changes that occurred before this page was opened.
          _startPresenceListener();
        }

        _applyFilters();
        _handleExternalSelection();
      }
    } catch (error) {
      debugPrint('Error fetching users: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _isInitialLoading = false;
        });
      }
    }
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      fetchUsers();
    }
  }

  // Firestore real-time presence listener — fires the instant a user's isOnline
  // field changes in the 'users' collection (written by the user-side app).
  // This gives immediate offline detection without waiting for the REST poll.
  // The listener covers the full 'users' collection; only changes for users
  // already in _users are applied, so extra documents are a no-op.
  void _startPresenceListener() {
    _presenceSub = FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      bool changed = false;
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.removed) continue;
        final data = change.doc.data();
        if (data == null) continue;

        final userId = change.doc.id;
        final isOnline = data['isOnline'] as bool? ?? false;
        final lastSeenText = data['lastSeen']?.toString() ?? '';

        // Update sidebar user list
        final idx = _users.indexWhere(
            (u) => u['id']?.toString() == userId);
        if (idx != -1) {
          final prev = _users[idx]['is_online'];
          if (prev != isOnline) {
            _users[idx] = {
              ..._users[idx] as Map<String, dynamic>,
              'is_online': isOnline,
              'last_seen_text': isOnline ? 'Online' : lastSeenText,
            };
            changed = true;
            if (_selectedChat?['id']?.toString() == userId) {
              _selectedChat = _users[idx];
              _updateSelectedChat();
            }
          }
        }

        // Keep ChatProvider in sync so the dashboard live count stays accurate
        chatProvider.updateUserOnlineStatus(userId, isOnline, lastSeenText);
      }

      if (changed && mounted) {
        _applyFilters();
      }
    }, onError: (e) {
      debugPrint('Presence listener error: $e');
    });
  }

  // Firestore real-time listener for unread message counts.
  // Watches all messages sent TO the admin (receiverid == "1") that have not
  // been seen yet.  Groups them by senderid to get per-user counts.
  void _startUnreadListener() {
    _unreadSub = FirebaseFirestore.instance
        .collection('adminchat')
        .where('receiverid', isEqualTo: senderId.toString())
        .where('seen', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      final Map<String, int> counts = {};
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final uid = data['senderid']?.toString() ?? '';
        if (uid.isNotEmpty) {
          counts[uid] = (counts[uid] ?? 0) + 1;
        }
      }
      // Update counts then re-apply filters in a single rebuild
      _unreadCounts = counts;
      if (mounted) _applyFilters();
    }, onError: (e) {
      debugPrint('Unread listener error: $e');
    });
  }

  // Lightweight poll: fetch a large page and update only is_online / last_seen_text
  Future<void> _refreshOnlineStatus() async {
    if (_users.isEmpty || !mounted) return;
    try {
      final uri = Uri.parse('https://digitallami.com/get.php').replace(
        queryParameters: {
          'page': '1',
          'limit': _users.length.toString(),
        },
      );
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final List<dynamic> freshList =
            (jsonResponse["data"] as List?) ?? [];

        // Build lookup: id -> {is_online, last_seen_text}
        final Map<String, Map<String, dynamic>> freshMap = {
          for (var u in freshList)
            u['id'].toString(): {
              'is_online': u['is_online'] ?? false,
              'last_seen_text': u['last_seen_text']?.toString() ?? '',
            },
        };

        bool changed = false;
        bool selectedChatStatusChanged = false;
        final String? selectedId = _selectedChat?['id']?.toString();
        for (int i = 0; i < _users.length; i++) {
          final userId = _users[i]['id']?.toString();
          if (userId == null) continue;
          final fresh = freshMap[userId];
          if (fresh == null) continue;
          if (_users[i]['is_online'] != fresh['is_online'] ||
              _users[i]['last_seen_text'] != fresh['last_seen_text']) {
            _users[i] = {
              ..._users[i] as Map<String, dynamic>,
              'is_online': fresh['is_online'],
              'last_seen_text': fresh['last_seen_text'],
            };
            changed = true;
            // If this user is the currently selected chat, update the reference
            if (userId == selectedId) {
              _selectedChat = _users[i];
              selectedChatStatusChanged = true;
            }
          }
        }

        if (changed && mounted) {
          _applyFilters();
          // Sync ChatProvider so the chat header reflects the updated online status
          if (selectedChatStatusChanged) {
            _updateSelectedChat();
          }
        }
      }
    } catch (e) {
      debugPrint('Error refreshing online status: $e');
    }
  }

  // Handle external chat selection (e.g., from Members page)
  void _handleExternalSelection() {
    final targetId = _chatProvider?.id?.toString();
    if (targetId == null || _users.isEmpty) return;

    final currentId = _selectedChat?['id']?.toString();
    if (currentId == targetId) return;

    final matchIndex =
        _users.indexWhere((u) => u['id']?.toString() == targetId);
    if (matchIndex == -1) return;

    setState(() {
      _selectedChat = _users[matchIndex];
    });
    _updateSelectedChat();
    _saveLastSelectedUserId(targetId);
  }

  void listenToConversationChanges() {
    _isFirstConversationSnapshot = true;

    _conversationSub = FirebaseFirestore.instance
        .collection('conversations')
        .where('participants', arrayContains: senderId.toString())
        .orderBy('lastTimestamp', descending: true)
        .snapshots()
        .listen((snapshot) {

      // ── Detect new incoming messages ────────────────────────────────────
      if (!_isFirstConversationSnapshot) {
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added ||
              change.type == DocumentChangeType.modified) {
            final data = change.doc.data() as Map<String, dynamic>;

            // Only react to messages sent by the other person (not the admin).
            final lastSenderId = data['lastSenderId']?.toString() ?? '';
            if (lastSenderId == senderId.toString()) continue;

            final List participants =
                List<String>.from(data['participants'] ?? []);
            final String otherUserId = participants.firstWhere(
              (id) => id != senderId.toString(),
              orElse: () => '',
            );
            if (otherUserId.isEmpty) continue;

            final Timestamp? newTs = data['lastTimestamp'] as Timestamp?;
            final Timestamp? prevTs = _prevLastTimestamps[otherUserId];

            // Only trigger if the timestamp is genuinely newer.
            final bool isNewMessage = newTs != null &&
                (prevTs == null ||
                    newTs.compareTo(prevTs) > 0);
            if (!isNewMessage) continue;

            // Play sound and optionally show a browser notification.
            final String lastMessage = data['lastMessage']?.toString() ?? '';
            _handleIncomingMessage(
              senderIdStr: otherUserId,
              message: lastMessage,
            );
            break; // one notification per snapshot batch is enough
          }
        }
      }
      _isFirstConversationSnapshot = false;

      // ── Update previous timestamps ──────────────────────────────────────
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final List participants = List<String>.from(data['participants'] ?? []);
        final String otherUserId = participants.firstWhere(
          (id) => id != senderId.toString(),
          orElse: () => '',
        );
        if (otherUserId.isNotEmpty) {
          _prevLastTimestamps[otherUserId] =
              data['lastTimestamp'] as Timestamp?;
        }
      }

      // ── Update sidebar UI ───────────────────────────────────────────────
      Map<String, Map<String, dynamic>> tempMap = {};
      List<dynamic> sortedUsers = [];
      // Track added user IDs to prevent any duplicates.
      final Set<String> addedIds = {};

      // First pass: users with conversations, already ordered by lastTimestamp
      // (Firestore query uses orderBy('lastTimestamp', descending: true)).
      for (var doc in snapshot.docs) {
        final List participants =
            List<String>.from(doc['participants'] ?? []);
        final String otherUserId = participants.firstWhere(
          (id) => id != senderId.toString(),
          orElse: () => '',
        );
        if (otherUserId.isEmpty) continue;

        tempMap[otherUserId] = {
          'lastMessage': doc['lastMessage'] ?? '',
          'lastTimestamp': doc['lastTimestamp'],
        };

        if (!addedIds.contains(otherUserId)) {
          final user = _users.firstWhere(
            (u) => u['id'].toString() == otherUserId,
            orElse: () => null,
          );
          if (user != null) {
            sortedUsers.add(user);
            addedIds.add(otherUserId);
          }
        }
      }

      // Second pass: users who have no conversation yet (append to bottom).
      for (var user in _users) {
        final uid = user['id']?.toString() ?? '';
        if (uid.isNotEmpty && !addedIds.contains(uid)) {
          sortedUsers.add(user);
          addedIds.add(uid);
        }
      }

      setState(() {
        conversationMap = tempMap;
        _users = List.from(sortedUsers);

        // Apply filters and deduplication in the same setState call to
        // avoid a second rebuild from a subsequent _applyFilters() call.
        final Set<String> seenIds = {};
        _filteredUsers = _users.where((user) {
          final uid = user["id"]?.toString() ?? '';
          if (uid.isEmpty || seenIds.contains(uid)) return false;
          seenIds.add(uid);

          bool matchesSearch = user["name"]
              .toLowerCase()
              .contains(_searchQuery.toLowerCase());
          bool matchesPaid = !_showOnlyPaid || (user["is_paid"] == true);
          bool matchesOnline = !_showOnlyOnline || (user["is_online"] == true);
          int matchesCount = int.tryParse(user["matches"].toString()) ?? 0;
          bool matchesWithMatches = !_showWithMatches || (matchesCount > 0);
          bool matchesUnread =
              !_showOnlyUnread || (_unreadCounts[uid] ?? 0) > 0;

          return matchesSearch && matchesPaid && matchesOnline &&
              matchesWithMatches && matchesUnread;
        }).toList();

        if (_sortBy != 'recent') _sortUsers();

        if (_selectedChat != null &&
            !_filteredUsers.contains(_selectedChat)) {
          _selectedChat =
              _filteredUsers.isNotEmpty ? _filteredUsers[0] : null;
          if (_selectedChat != null) _updateSelectedChat();
        }
      });
    });
  }

  /// Called whenever a new message arrives from a user.
  /// Plays a notification sound and, when the tab is in the background,
  /// also shows a native browser notification.
  void _handleIncomingMessage({
    required String senderIdStr,
    required String message,
  }) {
    // Look up the sender's display name from the loaded user list.
    final user = _users.firstWhere(
      (u) => u['id'].toString() == senderIdStr,
      orElse: () => <String, dynamic>{},
    );
    final String senderName =
        (user.isNotEmpty ? user['name']?.toString() : null) ?? 'Someone';

    final String displayMessage =
        message.isEmpty ? '📷 Photo' : message;

    // Play sound only when the browser tab is in the background.
    if (WebNotificationService.isAppInBackground()) {
      WebNotificationService.playMessageSound();
    }

    // Show the popup notification only when the tab is not visible.
    WebNotificationService.showMessageNotification(
      senderName: senderName,
      message: displayMessage,
      userId: senderIdStr,
    );
  }
  void _applyFilters() {
    setState(() {
      // Build filtered list, deduplicating by userId as a safety net.
      final Set<String> seenIds = {};
      _filteredUsers = _users.where((user) {
        final uid = user["id"]?.toString() ?? '';
        if (uid.isEmpty || seenIds.contains(uid)) return false;
        seenIds.add(uid);

        // Search filter
        bool matchesSearch = user["name"]
            .toLowerCase()
            .contains(_searchQuery.toLowerCase());

        // Paid filter
        bool matchesPaid = !_showOnlyPaid || (user["is_paid"] == true);

        // Online filter
        bool matchesOnline = !_showOnlyOnline || (user["is_online"] == true);

        // Matches filter
        int matchesCount = int.tryParse(user["matches"].toString()) ?? 0;
        bool matchesWithMatches = !_showWithMatches || (matchesCount > 0);

        // Unread filter
        bool matchesUnread =
            !_showOnlyUnread || (_unreadCounts[uid] ?? 0) > 0;

        return matchesSearch && matchesPaid && matchesOnline &&
            matchesWithMatches && matchesUnread;
      }).toList();

      // Apply sorting
      if (_sortBy != 'recent') {
        _sortUsers();
      }

      // Ensure selected chat is still in filtered list, if not, select first
      if (_selectedChat != null && !_filteredUsers.contains(_selectedChat)) {
        if (_filteredUsers.isNotEmpty) {
          _selectedChat = _filteredUsers[0];
          _updateSelectedChat();
        } else {
          _selectedChat = null;
        }
      }
    });
  }

  void _sortUsers() {
    switch (_sortBy) {
      case 'recent':
        _filteredUsers.sort((a, b) {
          String aId = a['id'].toString();
          String bId = b['id'].toString();

          Timestamp? aTs = conversationMap[aId]?['lastTimestamp'];
          Timestamp? bTs = conversationMap[bId]?['lastTimestamp'];

          DateTime aTime = aTs?.toDate() ?? DateTime(1970);
          DateTime bTime = bTs?.toDate() ?? DateTime(1970);

          return bTime.compareTo(aTime);
        });
        break;
      case 'name':
        _filteredUsers.sort((a, b) => a["name"].compareTo(b["name"]));
        break;
      case 'matches':
        _filteredUsers.sort((a, b) {
          int aMatches = int.tryParse(a["matches"].toString()) ?? 0;
          int bMatches = int.tryParse(b["matches"].toString()) ?? 0;
          return bMatches.compareTo(aMatches);
        });
        break;
      case 'online':
        _filteredUsers.sort((a, b) {
          bool aOnline = a["is_online"] ?? false;
          bool bOnline = b["is_online"] ?? false;
          if (aOnline && !bOnline) return -1;
          if (!aOnline && bOnline) return 1;
          return 0;
        });
        break;
    }
  }

  void _resetFilters() {
    _searchDebounce?.cancel();
    setState(() {
      _showOnlyPaid = false;
      _showOnlyOnline = false;
      _showWithMatches = false;
      _showOnlyUnread = false;
      _sortBy = 'recent';
      _searchQuery = "";
    });
    fetchUsers(reset: true);
  }

  void _updateSelectedChat() {
    if (_selectedChat != null) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      // Update id FIRST so that _handleExternalSelection() (which fires on
      // every notifyListeners call) sees chatProvider.id == _selectedChat['id']
      // and short-circuits instead of overriding the selection.
      final rawId = _selectedChat!["id"];
      final parsedId = int.tryParse(rawId.toString());
      if (parsedId == null) {
        debugPrint('_updateSelectedChat: invalid user id "$rawId", skipping');
        return;
      }
      chatProvider.updateidd(parsedId);
      chatProvider.updateName(_selectedChat!["name"]);
      chatProvider.updateonline(_selectedChat!["is_online"] == true);
      chatProvider.updatePaidStatus(_selectedChat!["is_paid"] == true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ChatColors.of(context);
    // On mobile (when onUserTap is provided), take full available width;
    // on desktop keep the fixed sidebar width.
    final double? sidebarWidth = widget.onUserTap != null ? null : 280;
    final int unreadUsersCount =
        _unreadCounts.values.where((count) => count > 0).length;

    return Container(
      width: sidebarWidth,
      color: c.sidebar,
      child: Column(
        children: [
          // ── HEADER ──────────────────────────────────────────────────
          Container(
            height: 56,
            color: c.sidebar,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Conversations',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
              ],
            ),
          ),

          // ── SEARCH BAR ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: SizedBox(
              height: 40,
              child: TextField(
                decoration: InputDecoration(
                  hintText: "Search conversations...",
                  hintStyle: TextStyle(fontSize: 12, color: c.muted),
                  prefixIcon: Icon(Icons.search, size: 18, color: c.muted),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, size: 16, color: c.muted),
                          onPressed: () {
                            _searchDebounce?.cancel();
                            setState(() => _searchQuery = "");
                            fetchUsers(reset: true);
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: c.border, width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: c.border, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: c.primary, width: 1),
                  ),
                  filled: true,
                  fillColor: c.searchFill,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  isDense: true,
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(
                    const Duration(milliseconds: 400),
                    () => fetchUsers(reset: true),
                  );
                },
              ),
            ),
          ),

          // ── FILTER CHIPS ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('Paid', style: TextStyle(fontSize: 10)),
                        selected: _showOnlyPaid,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                        labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                        onSelected: (bool selected) {
                          setState(() {
                            _showOnlyPaid = selected;
                            _applyFilters();
                          });
                        },
                        selectedColor: c.primaryLight,
                        checkmarkColor: c.primary,
                        side: BorderSide(color: c.border),
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        label: const Text('Online', style: TextStyle(fontSize: 10)),
                        selected: _showOnlyOnline,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                        labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                        onSelected: (bool selected) {
                          setState(() {
                            _showOnlyOnline = selected;
                            _applyFilters();
                          });
                        },
                        selectedColor: c.primaryLight,
                        checkmarkColor: c.primary,
                        side: BorderSide(color: c.border),
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        label: const Text('Matches', style: TextStyle(fontSize: 10)),
                        selected: _showWithMatches,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                        labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                        onSelected: (bool selected) {
                          setState(() {
                            _showWithMatches = selected;
                            _applyFilters();
                          });
                        },
                        selectedColor: c.primaryLight,
                        checkmarkColor: c.primary,
                        side: BorderSide(color: c.border),
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Unread', style: TextStyle(fontSize: 10)),
                            if (unreadUsersCount > 0) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: _showOnlyUnread
                                      ? const Color(0xFF25D366)
                                      : const Color(0xFF25D366).withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$unreadUsersCount',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        selected: _showOnlyUnread,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                        labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                        onSelected: (bool selected) {
                          setState(() {
                            _showOnlyUnread = selected;
                            _applyFilters();
                          });
                        },
                        selectedColor: const Color(0xFF25D366).withOpacity(0.15),
                        checkmarkColor: const Color(0xFF25D366),
                        side: BorderSide(
                          color: _showOnlyUnread
                              ? const Color(0xFF25D366)
                              : c.border,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        height: 28,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: c.searchFill,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: c.border),
                        ),
                        child: DropdownButton<String>(
                          value: _sortBy,
                          underline: const SizedBox(),
                          icon: Icon(Icons.sort, size: 14, color: c.muted),
                          style: TextStyle(fontSize: 10, color: c.text),
                          dropdownColor: c.sidebar,
                          items: const [
                            DropdownMenuItem(value: 'recent', child: Text('Recent')),
                            DropdownMenuItem(value: 'name', child: Text('Name')),
                            DropdownMenuItem(value: 'matches', child: Text('Matches')),
                            DropdownMenuItem(value: 'online', child: Text('Online First')),
                          ],
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _sortBy = newValue;
                                _sortUsers();
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                if (_showOnlyPaid || _showOnlyOnline || _showWithMatches || _showOnlyUnread || _searchQuery.isNotEmpty)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _resetFilters,
                      icon: const Icon(Icons.clear_all, size: 14),
                      label: const Text('Clear', style: TextStyle(fontSize: 11)),
                      style: TextButton.styleFrom(
                        foregroundColor: c.primary,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        minimumSize: Size.zero,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── COUNT ROW ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _totalUsers > 0
                    ? '${_filteredUsers.length} / $_totalUsers users'
                    : '${_filteredUsers.length} users',
                style: TextStyle(fontSize: 11, color: c.muted),
              ),
            ),
          ),

          Container(height: 1, color: c.border),

          // ── LIST ────────────────────────────────────────────────────
          Expanded(
            child: _isInitialLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: c.primary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Loading users...',
                          style: TextStyle(color: c.muted, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : _filteredUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_off,
                                size: 40, color: Colors.grey[300]),
                            const SizedBox(height: 10),
                            Text(
                              'No users found',
                              style: TextStyle(color: c.muted, fontSize: 13),
                            ),
                            if (_showOnlyPaid ||
                                _showOnlyOnline ||
                                _showWithMatches ||
                                _showOnlyUnread ||
                                _searchQuery.isNotEmpty)
                              TextButton(
                                onPressed: _resetFilters,
                                style: TextButton.styleFrom(
                                    foregroundColor: c.primary),
                                child: const Text('Clear filters',
                                    style: TextStyle(fontSize: 12)),
                              ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount:
                            _filteredUsers.length + (_isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          // Loading footer
                          if (index == _filteredUsers.length) {
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: c.primary,
                                  ),
                                ),
                              ),
                            );
                          }

                          var user = _filteredUsers[index];
                          bool isSelected = _selectedChat == user;

                          return _buildUserRow(
                            user["name"] ?? "",
                            user["id"].toString(),
                            conversationMap[user["id"].toString()]
                                    ?['lastMessage'] ??
                                user["chat_message"] ??
                                "",
                            user["last_seen_text"] ?? "",
                            user["is_paid"] ?? false,
                            user["is_online"] ?? false,
                            user["profile_picture"] ?? "",
                            isSelected,
                            _unreadCounts[user["id"].toString()] ?? 0,
                            () {
                              setState(() {
                                _selectedChat = user;
                                _updateSelectedChat();
                              });
                              // Persist the selected user so the chat reopens to the same conversation.
                              _saveLastSelectedUserId(user["id"].toString());
                              // Notify parent so mobile view can switch to chat panel.
                              widget.onUserTap?.call();
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // ── USER ROW ────────────────────────────────────────────────────────
  Widget _buildUserRow(
    String name,
    String userId,
    String chatMessage,
    String lastSeen,
    bool isPaid,
    bool isOnline,
    String profileImage,
    bool isSelected,
    int unreadCount,
    VoidCallback onTap,
  ) {
    final c = ChatColors.of(context);

    final bool hasUnread = unreadCount > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? c.selectedRow
              : hasUnread
                  ? c.primaryLight
                  : c.sidebar,
          border: isSelected
              ? Border(left: BorderSide(color: c.primary, width: 3))
              : hasUnread
                  ? Border(left: BorderSide(color: c.primary, width: 3))
                  : null,
        ),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: c.cardBg,
                  backgroundImage: profileImage.isNotEmpty
                      ? NetworkImage(profileImage)
                      : null,
                  child: profileImage.isEmpty
                      ? Icon(Icons.person, color: Colors.grey[400], size: 20)
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isOnline ? c.online : c.border,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.sidebar, width: 2),
                    ),
                  ),
                ),
                if (isPaid)
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.sidebar, width: 1.5),
                      ),
                      child: const Icon(Icons.star, size: 8, color: Colors.white),
                    ),
                  ),
              ],
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight:
                          hasUnread ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 13,
                      color: isPaid ? c.primary : c.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (userId.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.tag, size: 10, color: c.muted),
                        const SizedBox(width: 2),
                        Text(
                          userId,
                          style: TextStyle(
                            fontSize: 10,
                            color: c.muted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 2),
                  Text(
                    isOnline ? "Online" : lastSeen,
                    style: TextStyle(
                      fontSize: 11,
                      color: isOnline ? c.online : c.muted,
                    ),
                  ),
                  if (chatMessage.isNotEmpty)
                    Text(
                      chatMessage,
                      style: TextStyle(
                        fontSize: 11,
                        color: hasUnread ? c.text : c.muted,
                        fontWeight: hasUnread
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),

            // Right column: WhatsApp-style unread message count badge
            if (hasUnread)
              Container(
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: c.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  unreadCount > _maxUnreadBadge ? '$_maxUnreadBadge+' : '$unreadCount',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
