// screens/main_controller_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ReUsable/Navbar.dart'; // AppNavbar with onItemSelected callback
import '../Home/Screen/HomeScreenPage.dart';
import '../liked/liked.dart';
import '../Chat/ChatlistScreen.dart';
import '../profile/myprofile.dart';

class MainControllerScreen extends StatefulWidget {
  final int initialIndex;
  const MainControllerScreen({Key? key, this.initialIndex = 0})
      : super(key: key);

  @override
  State<MainControllerScreen> createState() => _MainControllerScreenState();
}

class _MainControllerScreenState extends State<MainControllerScreen> {
  late int _selectedIndex;
  String? _senderId;
  String? _senderName;
  String? _currentUserImage;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _loadUserFromPrefs();
  }

  Future<void> _loadUserFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString('user_data');
      if (s != null && s.isNotEmpty) {
        final data = jsonDecode(s);
        setState(() {
          _senderId = data['id']?.toString();
          _senderName = data['firstName']?.toString() ?? 'User';
          _currentUserImage = data['profile_picture']?.toString();
        });
      }
    } catch (e) {
      debugPrint('MainControllerScreen: loadUser error: $e');
    }
  }

  // Build the pages. ChatListScreen requires senderId/name, so we pass when available.
  List<Widget> _buildScreens() {
    return [
      MatrimonyHomeScreen(), // index 0
      FavoritePeoplePage(),  // index 1 - Shortlist
      _senderId != null
          ? ChatListScreen()
          : Center(child: Text('Loading chat...')), // index 2
      MatrimonyProfilePage(), // index 3
    ];
  }

  @override
  Widget build(BuildContext context) {
    final screens = _buildScreens();

    return Scaffold(

      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: AppNavbar(
        selectedIndex: _selectedIndex,
        currentUserImage: _currentUserImage,
        onItemSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}
