import 'dart:async';
import 'dart:html' as html;
import 'package:adminmrz/auth/service.dart';
import 'package:adminmrz/core/theme_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../adminchat/chatprovider.dart';
import '../adminchat/loading.dart';
import '../adminchat/services/web_notification_service.dart';
import '../dashboard/dashboardhome.dart';
import '../document/screens/docscreen.dart';
import '../package/packageScreen.dart';
import '../payment/paymentscreen.dart';
import '../settings/call_settings_screen.dart';
import '../users/userscreen.dart';

// ─── Breakpoints ─────────────────────────────────────────────────────────────
const _kMobileBreakpoint = 768.0;

// ─── Design tokens ────────────────────────────────────────────────────────────
const _kSidebarBg     = Color(0xFF0F172A);
const _kSidebarBorder = Color(0xFF1E293B);
const _kAccent        = Color(0xFF6366F1);
const _kAccentLight   = Color(0xFF818CF8);
const _kTextPrimary   = Color(0xFFE2E8F0);
const _kTextSecondary = Color(0xFF94A3B8);
const _kTextMuted     = Color(0xFF64748B);
const _kContentBg     = Color(0xFFF1F5F9);
const _kTopBarBg      = Colors.white;
const _kTopBarBorder  = Color(0xFFE2E8F0);

// ─── Nav item model ───────────────────────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

// ─── Page ────────────────────────────────────────────────────────────────────
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;
  bool _isSidebarExpanded = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late final List<Widget> _pages;

  // ── Global chat notification listener ────────────────────────────────────
  // Listens to Firestore conversations at all times so that chat notifications
  // are delivered even when the admin is on a page other than the Chat tab.
  static const int _adminSenderId = 1;
  StreamSubscription<QuerySnapshot>? _globalConversationSub;
  final Map<String, Timestamp?> _globalPrevTimestamps = {};
  bool _isFirstGlobalSnapshot = true;
  // Tracks known user names fetched lazily for notification display.
  final Map<String, String> _globalUserNames = {};
  // JS event listener reference kept so we can remove it on dispose.
  late final void Function(html.Event) _onChatNotifEvent;

  @override
  void initState() {
    super.initState();
    _pages = [
      DashboardHome(onNavigate: _onItemTapped),
      UsersPage(onOpenChat: _openChatForUser),
      const DocumentsPage(),
      const PackagesPage(),
      const PaymentsPage(),
      Loading(),
      const CallSettingsScreen(),
    ];
    _startGlobalConversationListener();
    _onChatNotifEvent = _handleChatNotifJsEvent;
    html.window.addEventListener('chatNotification', _onChatNotifEvent);
  }

  @override
  void dispose() {
    _globalConversationSub?.cancel();
    html.window.removeEventListener('chatNotification', _onChatNotifEvent);
    super.dispose();
  }

  /// Handles the custom browser event dispatched when the admin clicks a
  /// chat browser notification.  Navigates to the Chat tab and opens the
  /// conversation with the user.
  void _handleChatNotifJsEvent(html.Event event) {
    if (!mounted) return;
    final detail = (event as html.CustomEvent).detail;
    final userIdStr = detail != null ? detail['userId']?.toString() : null;
    if (userIdStr == null || userIdStr.isEmpty) return;
    final userId = int.tryParse(userIdStr);
    if (userId == null) return;
    _openChatForUser(userId);
  }

  /// Firestore listener that runs regardless of which page is active.
  /// When a new message arrives and the Chat tab is NOT open, a browser
  /// notification is shown so the admin is always informed.
  void _startGlobalConversationListener() {
    _isFirstGlobalSnapshot = true;
    _globalConversationSub = FirebaseFirestore.instance
        .collection('conversations')
        .where('participants', arrayContains: _adminSenderId.toString())
        .orderBy('lastTimestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      if (!_isFirstGlobalSnapshot) {
        for (final change in snapshot.docChanges) {
          if (change.type != DocumentChangeType.added &&
              change.type != DocumentChangeType.modified) continue;

          final data = change.doc.data() as Map<String, dynamic>;

          // Only react to messages sent by the user (not the admin).
          final lastSenderId = data['lastSenderId']?.toString() ?? '';
          if (lastSenderId == _adminSenderId.toString()) continue;

          final List participants =
              List<String>.from(data['participants'] ?? []);
          final String otherUserId = participants.firstWhere(
            (id) => id != _adminSenderId.toString(),
            orElse: () => '',
          );
          if (otherUserId.isEmpty) continue;

          final Timestamp? newTs = data['lastTimestamp'] as Timestamp?;
          final Timestamp? prevTs = _globalPrevTimestamps[otherUserId];

          final bool isNewMessage = newTs != null &&
              (prevTs == null || newTs.compareTo(prevTs) > 0);
          if (!isNewMessage) continue;

          // Skip if the Chat tab is currently visible — ChatSidebar handles it.
          if (_selectedIndex == 5) continue;

          final String lastMessage = data['lastMessage']?.toString() ?? '';
          _showGlobalNotification(
            userId: otherUserId,
            message: lastMessage,
          );
          break; // one notification per snapshot batch is enough (matches ChatSidebar behaviour)
        }
      }
      _isFirstGlobalSnapshot = false;

      // Update previous timestamps.
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final List participants = List<String>.from(data['participants'] ?? []);
        final String otherUserId = participants.firstWhere(
          (id) => id != _adminSenderId.toString(),
          orElse: () => '',
        );
        if (otherUserId.isNotEmpty) {
          _globalPrevTimestamps[otherUserId] =
              data['lastTimestamp'] as Timestamp?;
        }
      }
    });
  }

  /// Shows a browser notification and, when the tab is in the background,
  /// also plays the notification sound.  Called by the global listener when
  /// the admin is on a page other than the Chat tab.
  Future<void> _showGlobalNotification({
    required String userId,
    required String message,
  }) async {
    // Resolve a display name; use the cache when available.
    String senderName = _globalUserNames[userId] ?? '';
    if (senderName.isEmpty) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        if (doc.exists) {
          final data = doc.data();
          senderName =
              data?['name']?.toString() ?? data?['displayName']?.toString() ?? '';
        }
      } catch (_) {}
      if (senderName.isEmpty) senderName = 'Someone';
      // Limit the cache size to avoid unbounded growth in long-running sessions.
      if (_globalUserNames.length >= 200) _globalUserNames.clear();
      _globalUserNames[userId] = senderName;
    }

    final String displayMessage = message.isEmpty ? '📷 Photo' : message;

    // Play sound only when the browser tab is in the background.
    if (WebNotificationService.isAppInBackground()) {
      WebNotificationService.playMessageSound();
    }

    // Always show the browser notification popup (admin is on a different page).
    WebNotificationService.showMessageNotification(
      senderName: senderName,
      message: displayMessage,
      userId: userId,
      showInForeground: true,
    );
  }

  /// Navigate to the Chat tab and pre-select [userId] so the conversation
  /// opens immediately — mirroring how the chat sidebar selects a user.
  void _openChatForUser(int userId) {
    // Update the ChatProvider to select this user (same as chat sidebar does)
    final chatProvider = context.read<ChatProvider>();
    chatProvider.updateidd(userId);
    // Switch to Chat tab (index 5)
    setState(() => _selectedIndex = 5);
  }

  static const List<_NavItem> _navItems = [
    _NavItem(icon: Icons.grid_view_rounded,   label: 'Dashboard'),
    _NavItem(icon: Icons.people_alt_rounded,  label: 'Members'),
    _NavItem(icon: Icons.description_rounded, label: 'Documents'),
    _NavItem(icon: Icons.inventory_2_rounded, label: 'Packages'),
    _NavItem(icon: Icons.payments_rounded,    label: 'Payments'),
    _NavItem(icon: Icons.chat_bubble_rounded, label: 'Chat'),
    _NavItem(icon: Icons.tune_rounded,        label: 'Call Settings'),
  ];

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);
  void _toggleSidebar()        => setState(() => _isSidebarExpanded = !_isSidebarExpanded);

  // ─── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final adminData    = authProvider.adminData;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < _kMobileBreakpoint;
        if (isMobile) {
          return _buildMobileLayout(adminData, authProvider);
        }
        return Scaffold(
          body: Row(
            children: [
              _buildSidebar(adminData, authProvider),
              Expanded(child: _buildMainContent()),
            ],
          ),
        );
      },
    );
  }

  // ─── Mobile layout ──────────────────────────────────────────────────────────
  Widget _buildMobileLayout(
    Map<String, dynamic>? adminData,
    AuthProvider authProvider,
  ) {
    final isChatPage = _selectedIndex == 5;
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(adminData, authProvider),
      body: Column(
        children: [
          _buildMobileTopBar(),
          Expanded(
            child: isChatPage
                ? _pages[_selectedIndex]
                : Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    padding: const EdgeInsets.all(16),
                    child: _pages[_selectedIndex],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileTopBar() {
    final title    = _navItems[_selectedIndex].label;
    final cs       = Theme.of(context).colorScheme;
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final topBarBg = cs.surface;
    final topBarBorder = cs.outlineVariant;
    final iconBg   = isDark ? const Color(0xFF263248) : const Color(0xFFF8FAFC);
    final mutedColor = cs.onSurface.withOpacity(0.45);

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: topBarBg,
        border: Border(bottom: BorderSide(color: topBarBorder)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
                borderRadius: BorderRadius.circular(8),
                child: Icon(Icons.menu_rounded, size: 20, color: mutedColor),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _logoMark(),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            width: 34,
            height: 34,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: topBarBorder),
            ),
            child: IconButton(
              onPressed: () => context.read<ThemeProvider>().toggleTheme(),
              icon: Icon(
                isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                size: 16,
                color: mutedColor,
              ),
              padding: EdgeInsets.zero,
              tooltip: isDark ? 'Light Mode' : 'Dark Mode',
            ),
          ),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: topBarBorder),
            ),
            child: IconButton(
              onPressed: () {},
              icon: Icon(Icons.notifications_outlined, size: 16, color: mutedColor),
              padding: EdgeInsets.zero,
              tooltip: 'Notifications',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(
    Map<String, dynamic>? adminData,
    AuthProvider authProvider,
  ) {
    final name     = adminData?['name']?.toString() ?? 'Admin';
    final role     = adminData?['role']?.toString() ?? 'admin';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'A';

    return Drawer(
      width: 260,
      backgroundColor: _kSidebarBg,
      child: Column(
        children: [
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _kSidebarBorder)),
            ),
            child: Row(
              children: [
                _logoMark(),
                const SizedBox(width: 10),
                Expanded(
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Marriage Station',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _kTextPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 1),
                      Text(
                        'Admin Panel',
                        style: TextStyle(fontSize: 10, color: _kTextMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _navItems.length,
              itemBuilder: (_, i) => _buildDrawerNavTile(i),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _kSidebarBorder)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: _kAccent.withOpacity(0.2),
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _kAccentLight,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _kTextPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        role,
                        style: const TextStyle(fontSize: 10, color: _kTextMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async => await authProvider.logout(),
                      borderRadius: BorderRadius.circular(6),
                      child: const Icon(
                        Icons.logout_rounded,
                        size: 16,
                        color: _kTextMuted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerNavTile(int index) {
    final isActive = _selectedIndex == index;
    final item     = _navItems[index];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _onItemTapped(index);
            _scaffoldKey.currentState?.closeDrawer();
          },
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: isActive ? _kAccent.withOpacity(0.14) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(
                  color: isActive ? _kAccent : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 2),
                Icon(
                  item.icon,
                  size: 18,
                  color: isActive ? _kAccentLight : _kTextSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive ? _kTextPrimary : _kTextSecondary,
                    ),
                  ),
                ),
                if (isActive)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: _kAccentLight,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Sidebar ────────────────────────────────────────────────────────────────
  Widget _buildSidebar(
    Map<String, dynamic>? adminData,
    AuthProvider authProvider,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: _isSidebarExpanded ? 240 : 68,
      decoration: const BoxDecoration(color: _kSidebarBg),
      child: Column(
        children: [
          _buildSidebarHeader(),
          Expanded(child: _buildNavList()),
          _buildSidebarFooter(adminData, authProvider),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader() {
    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: _isSidebarExpanded ? 14 : 0),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _kSidebarBorder)),
      ),
      child: _isSidebarExpanded
          ? Row(
              children: [
                _logoMark(),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Marriage Station',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _kTextPrimary,
                          letterSpacing: -0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 1),
                      Text(
                        'Admin Panel',
                        style: TextStyle(fontSize: 10, color: _kTextMuted),
                      ),
                    ],
                  ),
                ),
                _sidebarToggleButton(),
              ],
            )
          : Center(
              child: GestureDetector(
                onTap: _toggleSidebar,
                child: _logoMark(),
              ),
            ),
    );
  }

  Widget _logoMark() {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(9),
      ),
      child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 18),
    );
  }

  Widget _sidebarToggleButton() {
    return SizedBox(
      width: 28,
      height: 28,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _toggleSidebar,
          borderRadius: BorderRadius.circular(6),
          child: const Icon(
            Icons.chevron_left_rounded,
            size: 18,
            color: _kTextMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildNavList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _navItems.length,
      itemBuilder: (_, i) => _buildNavTile(i),
    );
  }

  Widget _buildNavTile(int index) {
    final isActive = _selectedIndex == index;
    final item     = _navItems[index];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onItemTapped(index),
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(
              horizontal: _isSidebarExpanded ? 10 : 0,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: isActive ? _kAccent.withOpacity(0.14) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(
                  color: isActive ? _kAccent : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: _isSidebarExpanded
                ? Row(
                    children: [
                      const SizedBox(width: 2),
                      Icon(
                        item.icon,
                        size: 18,
                        color: isActive ? _kAccentLight : _kTextSecondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isActive
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isActive ? _kTextPrimary : _kTextSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isActive)
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: _kAccentLight,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  )
                : Center(
                    child: Tooltip(
                      message: item.label,
                      child: Icon(
                        item.icon,
                        size: 20,
                        color: isActive ? _kAccentLight : _kTextSecondary,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarFooter(
    Map<String, dynamic>? adminData,
    AuthProvider authProvider,
  ) {
    final name   = adminData?['name']?.toString() ?? 'Admin';
    final role   = adminData?['role']?.toString() ?? 'admin';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'A';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _kSidebarBorder)),
      ),
      child: _isSidebarExpanded
          ? Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: _kAccent.withOpacity(0.2),
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _kAccentLight,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _kTextPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        role,
                        style: const TextStyle(
                          fontSize: 10,
                          color: _kTextMuted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async => await authProvider.logout(),
                      borderRadius: BorderRadius.circular(6),
                      child: const Icon(
                        Icons.logout_rounded,
                        size: 16,
                        color: _kTextMuted,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Center(
              child: Tooltip(
                message: 'Logout',
                child: GestureDetector(
                  onTap: () async => await authProvider.logout(),
                  child: const Icon(
                    Icons.logout_rounded,
                    size: 18,
                    color: _kTextMuted,
                  ),
                ),
              ),
            ),
    );
  }

  // ─── Main content area ──────────────────────────────────────────────────────
  Widget _buildMainContent() {
    final bool isChatPage = _selectedIndex == 5;
    // Members page (index 1) has its own "Member Directory" header, so the
    // top bar and outer padding are redundant and waste vertical space.
    final bool isMembersPage = _selectedIndex == 1;
    return Column(
      children: [
        if (!isChatPage && !isMembersPage) _buildTopBar(),
        Expanded(
          child: isChatPage
              ? _pages[_selectedIndex]
              : Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  padding: isMembersPage
                      ? EdgeInsets.zero
                      : const EdgeInsets.all(24),
                  child: _pages[_selectedIndex],
                ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    final title = _navItems[_selectedIndex].label;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topBarBg = cs.surface;
    final topBarBorder = cs.outlineVariant;
    final iconBg = isDark ? const Color(0xFF263248) : const Color(0xFFF8FAFC);
    final mutedColor = cs.onSurface.withOpacity(0.45);

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: topBarBg,
        border: Border(bottom: BorderSide(color: topBarBorder)),
      ),
      child: Row(
        children: [
          // Breadcrumb
          Icon(Icons.home_outlined, size: 14, color: mutedColor),
          const SizedBox(width: 6),
          Text('/', style: TextStyle(fontSize: 12, color: mutedColor)),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const Spacer(),
          // Dark / Light mode toggle
          Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: topBarBorder),
            ),
            child: IconButton(
              onPressed: () => context.read<ThemeProvider>().toggleTheme(),
              icon: Icon(
                isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                size: 18,
                color: mutedColor,
              ),
              padding: EdgeInsets.zero,
              tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            ),
          ),
          // Notification bell
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: topBarBorder),
            ),
            child: IconButton(
              onPressed: () {},
              icon: Icon(
                Icons.notifications_outlined,
                size: 18,
                color: mutedColor,
              ),
              padding: EdgeInsets.zero,
              tooltip: 'Notifications',
            ),
          ),
        ],
      ),
    );
  }
}