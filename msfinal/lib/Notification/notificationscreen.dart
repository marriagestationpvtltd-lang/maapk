import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../otherenew/othernew.dart';

class MatrimonyNotificationPage extends StatefulWidget {
  const MatrimonyNotificationPage({Key? key}) : super(key: key);

  @override
  State<MatrimonyNotificationPage> createState() =>
      _MatrimonyNotificationPageState();
}

class _MatrimonyNotificationPageState
    extends State<MatrimonyNotificationPage> {
  // Toggle states for notification types
  bool _pushEnabled = true;
  bool _emailEnabled = true;
  bool _smsEnabled = false;
  bool _showSettings = false; // Controls visibility of settings panel

  List<dynamic> _notifications = [];
  bool _isLoading = true;
  final String _baseUrl = "https://digitallami.com/Api2"; // Update with your domain

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  final String _requestUrl = "https://digitallami.com/request/request_list.php";

  Future<void> _fetchNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    final userData = jsonDecode(userDataString!);
    final userId = userData["id"].toString();

    try {
      // 🔥 CALL BOTH APIs
      final requestResponse = await http.get(
        Uri.parse('$_requestUrl?receiver_id=$userId'),
      );

      final settingsResponse = await http.get(
        Uri.parse('$_baseUrl/get_notifications.php?user_id=$userId'),
      );

      if (requestResponse.statusCode == 200 &&
          settingsResponse.statusCode == 200) {

        final requestData = json.decode(requestResponse.body);
        final settingsData = json.decode(settingsResponse.body);

        // 🔥 MAP REQUEST DATA → OLD NOTIFICATION FORMAT
        List<dynamic> mappedNotifications =
        (requestData['data'] ?? []).map((item) {

          String type = item['type'] ?? 'photo_request';

          String title = "";
          String message = "";

          if (type == 'photo_request') {
            title = "${item['lastName']} sent you a photo request";
            message = "Tap to respond";
          }
          else if (type == 'profile_view') {
            title = "${item['lastName']} viewed your profile 👀";
            message = "Check their profile";
          }
          else {
            title = "${item['lastName']} notification";
            message = "Tap to view";
          }

          return {
            "id": item['id'],
            "type": type,
            "title": title,
            "message": message,
            "time": item['created_at'] ?? "Just now",
            "is_read": 0,
            "sender_id": item['sender_id'],
          };

        }).toList();

        setState(() {
          _notifications = mappedNotifications;

          // ✅ KEEP YOUR TOGGLES FROM OLD API
          _pushEnabled = settingsData['settings']['push_enabled'];
          _emailEnabled = settingsData['settings']['email_enabled'];
          _smsEnabled = settingsData['settings']['sms_enabled'];

          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    final userData = jsonDecode(userDataString!);
    final userId = userData["id"].toString();
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/update_notification_settings.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId, // Replace with actual user ID
          'push_enabled': _pushEnabled ? 1 : 0,
          'email_enabled': _emailEnabled ? 1 : 0,
          'sms_enabled': _smsEnabled ? 1 : 0,
        }),
      );

      if (response.statusCode == 200) {
        print('Settings updated successfully');
      }
    } catch (e) {
      print('Error updating settings: $e');
    }
  }

  Future<void> _markAsRead(int notificationId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/mark_as_read.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'notification_id': notificationId,
        }),
      );

      if (response.statusCode == 200) {
        // Update local state
        setState(() {
          _notifications = _notifications.map((notification) {
            if (notification['id'] == notificationId) {
              notification['is_read'] = 1;
            }
            return notification;
          }).toList();
        });
      }
    } catch (e) {
      print('Error marking as read: $e');
    }
  }

  Future<void> _deleteNotification(int notificationId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/delete_notification.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'notification_id': notificationId,
        }),
      );

      if (response.statusCode == 200) {
        // Remove from local list
        setState(() {
          _notifications.removeWhere((n) => n['id'] == notificationId);
        });
      }
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  // Map type to icon and color
  IconData _getIcon(String type) {
    switch (type) {
      case 'profile_view':
        return Icons.remove_red_eye;
      case 'photo_request':
        return Icons.photo_camera;
      case 'profile_request':
        return Icons.person_search;
      case 'contact_request':
        return Icons.contact_page;
      case 'accepted':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'likes_you':
        return Icons.favorite;
      default:
        return Icons.notifications;
    }
  }

  Color _getColor(String type) {

    switch (type) {
      case 'profile_view':
        return Colors.teal;
      case 'photo_request':
        return Colors.orange;
      case 'profile_request':
        return Colors.blue;
      case 'contact_request':
        return Colors.purple;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'likes_you':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Notifications', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.red,
        actions: [
          // Settings toggle button
          IconButton(
            icon: Icon(_showSettings ? Icons.settings : Icons.settings_outlined),
            onPressed: () {
              setState(() {
                _showSettings = !_showSettings;
              });
            },
            tooltip: 'Toggle Settings',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Animated Settings Panel
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              height: _showSettings ? 200 : 0,
              child: _showSettings
                  ? Column(
                children: [
                  // Settings Header
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: const Row(
                      children: [
                        Icon(Icons.settings, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Notification Settings',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Notification Toggles
                  _buildToggle('Push Notifications', _pushEnabled, (val) {
                    setState(() => _pushEnabled = val);
                    _updateNotificationSettings();
                  }),
                  const SizedBox(height: 8),
                  _buildToggle('Email Notifications', _emailEnabled, (val) {
                    setState(() => _emailEnabled = val);
                    _updateNotificationSettings();
                  }),
                  const SizedBox(height: 8),
                  _buildToggle('SMS Notifications', _smsEnabled, (val) {
                    setState(() => _smsEnabled = val);
                    _updateNotificationSettings();
                  }),
                  const SizedBox(height: 16),
                ],
              )
                  : const SizedBox.shrink(),
            ),
            // Notification List
            Expanded(
              child: _notifications.isEmpty
                  ? const Center(
                child: Text(
                  'No notifications yet',
                  style: TextStyle(color: Colors.grey),
                ),
              )
                  : ListView.builder(
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  final notif = _notifications[index];
                  return Dismissible(
                    key: Key(notif['id'].toString()),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(
                        Icons.delete,
                        color: Colors.white,
                      ),
                    ),
                    confirmDismiss: (direction) async {
                      return await showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text("Delete Notification"),
                            content: const Text(
                                "Are you sure you want to delete this notification?"),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text("Cancel"),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: const Text("Delete"),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    onDismissed: (direction) {
                      _deleteNotification(notif['id']);
                    },
                    child: GestureDetector(
                      onTap: () {
                        if (notif['is_read'] == 0) {
                          _markAsRead(notif['id']);
                        }

                        int userId = int.parse(notif['sender_id'].toString());

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProfileScreen(userId: userId.toString()),
                          ),
                        );
                      },

                      child: Card(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        margin:
                        const EdgeInsets.symmetric(vertical: 8),
                        elevation: 2,
                        color: notif['is_read'] == 0
                            ? Colors.grey[50]
                            : Colors.white,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                          leading: Icon(
                            _getIcon(notif['type']),
                            color: _getColor(notif['type']),
                            size: 32,
                          ),
                          title: Text(
                            notif['title'] ?? '',
                            style: TextStyle(
                              fontWeight: notif['is_read'] == 0
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                notif['message'] ?? '',
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                notif['time'] ?? '',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                          trailing: notif['is_read'] == 0
                              ? const CircleAvatar(
                            radius: 6,
                            backgroundColor: Colors.red,
                          )
                              : null,
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
    );
  }

  Widget _buildToggle(
      String title, bool value, void Function(bool) onChanged) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.red,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}