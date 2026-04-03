import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppNavbar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final String? currentUserImage;

  const AppNavbar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.currentUserImage,
  });

  Widget _navItem({
    required IconData icon,
    required String label,
    required int index,
    required bool active,
    required BuildContext context,
  }) {
    return GestureDetector(
      onTap: () => onItemSelected(index),   // 🔥 RETURN INDEX ONLY
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: active ? Colors.red.withOpacity(0.12) : Colors.transparent,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: active ? Colors.red : Colors.black54),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: active ? Colors.red : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, -2),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(
            icon: Icons.home,
            label: "Home",
            index: 0,
            active: selectedIndex == 0,
            context: context,
          ),
          _navItem(
            icon: Icons.bookmark,
            label: "Shortlist",
            index: 1,
            active: selectedIndex == 1,
            context: context,
          ),
          _navItem(
            icon: Icons.chat,
            label: "Chat",
            index: 2,
            active: selectedIndex == 2,
            context: context,
          ),
          _navItem(
            icon: Icons.person,
            label: "Account",
            index: 3,
            active: selectedIndex == 3,
            context: context,
          ),
        ],
      ),
    );
  }
}
