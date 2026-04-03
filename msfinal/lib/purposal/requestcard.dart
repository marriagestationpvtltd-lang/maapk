import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ms2026/Auth/Screen/signupscreen10.dart';
import 'package:ms2026/Chat/ChatdetailsScreen.dart';
import 'package:ms2026/Models/masterdata.dart';
import 'package:ms2026/Notification/notification_inbox_service.dart';
import 'package:ms2026/Package/PackageScreen.dart';
import 'package:ms2026/otherprofile/otherprofileview.dart';
import 'package:ms2026/pushnotification/pushservice.dart';
import 'package:ms2026/purposal/purposalservice.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'Purposalmodel.dart';

class RequestCardDynamic extends StatefulWidget {
  final ProposalModel data;
  final int tabIndex;
  final String userid;
  final VoidCallback? onActionComplete;

  RequestCardDynamic({
    super.key,
    required this.data,
    required this.tabIndex,
    required this.userid,
    this.onActionComplete,
  });

  @override
  State<RequestCardDynamic> createState() => _RequestCardDynamicState();
}

class _RequestCardDynamicState extends State<RequestCardDynamic> {
  String usertye = '';
  String userimage = '';
  var pageno;
  var docstatus = 'not_uploaded';
  bool _isLoading = false;
  bool _isCheckingStatus = false;

  @override
  void initState() {
    super.initState();
    loadMasterData();
    _checkDocumentStatus();
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

  void loadMasterData() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    final userData = jsonDecode(userDataString!);
    final userId = int.tryParse(userData["id"].toString());

    try {
      UserMasterData user = await fetchUserMasterData(userId.toString());

      setState(() {
        usertye = user.usertype;
        userimage = user.profilePicture;
        pageno = user.pageno;
      });
    } catch (e) {
      print("Error: $e");
    }
  }

  Future<void> _checkDocumentStatus() async {
    if (_isCheckingStatus) return;

    setState(() {
      _isCheckingStatus = true;
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');
      final userData = jsonDecode(userDataString!);
      final userId = int.tryParse(userData["id"].toString());

      final response = await http.post(
        Uri.parse("https://digitallami.com/Api2/check_document_status.php"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId}),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          setState(() {
            docstatus = result['status'] ?? 'not_uploaded';
          });
        }
      }
    } catch (e) {
      print("Error checking document status: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to check document status: $e"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
        _isCheckingStatus = false;
      });
    }
  }

  // Determine if current user is the receiver
  bool get _isReceiver => widget.data.receiverId == widget.userid;

  // Determine if request is pending
  bool get _isPending => widget.data.status?.toLowerCase() == 'pending';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status display
          _buildStatusText(),

          const SizedBox(height: 12),

          Row(
            children: [
              // Profile Image
              _buildProfileImage(),

              const SizedBox(width: 12),

              // User Details
              Expanded(
                child: _buildUserDetails(),
              ),

              const SizedBox(width: 8),

              // Action Buttons
              _buildActionButtons(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusText() {
    // Determine if current user is sender
    bool isSender = widget.data.senderId == widget.userid;

    if (widget.data.status == 'pending' && isSender) {
      return Text(
        " Your ${widget.data.requestType ?? "Request"} Request ${widget.data.status}...",
        style: TextStyle(
          fontSize: 18,
          color: Colors.orange,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    if (widget.data.status == 'accepted' && isSender) {
      return Text(
        "Your ${widget.data.requestType ?? "Request"} Request ${widget.data.status}",
        style: TextStyle(
          color: Colors.green,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    if (widget.data.status == 'rejected' && isSender) {
      return Text(
        "Your ${widget.data.requestType ?? "Request"} Request ${widget.data.status}",
        style: TextStyle(
          color: Colors.red,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    if (!isSender && widget.data.status == 'accepted') {
      return Text(
        "You have ${widget.data.requestType ?? "Request"} Request ${widget.data.status}",
        style: TextStyle(
          color: Colors.blue,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    if (!isSender && widget.data.status == 'pending') {
      return Text(
        "${widget.data.requestType ?? "Request"} Request ${widget.data.status}",
        style: TextStyle(
          color: Colors.orange,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildUserDetails() {
    // According to your PHP API, the data already contains the OTHER user's information
    // So we can use the data directly from widget.data
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "MS: ${widget.data.memberid.toString() ?? 'N/A'}  ${widget.data.lastName ?? ''}".trim(),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            if (widget.data.verified ?? false)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.verified,
                  color: Colors.red,
                  size: 16,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        _buildDetailRow(Icons.location_on_outlined, widget.data.city ?? 'Kathmandu'),
        const SizedBox(height: 2),
        _buildDetailRow(Icons.work_outline, widget.data.occupation ?? 'Fashion Designer'),
        _buildDetailRow(Icons.person_outline, widget.data.maritalstatus ?? 'Single'),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.black54),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    // For received pending requests (current user is receiver)
    if (_isReceiver && _isPending) {
      return Column(
        children: [
          // Accept Button
          GestureDetector(
            onTap: _handleAcceptRequest,
            child: Container(
              margin: EdgeInsets.only(bottom: 10),
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.white),
                  SizedBox(width: 10),
                  Text(
                    'Accept',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Reject Button
          GestureDetector(
            onTap: _handleRejectRequest,
            child: Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.cancel_outlined, color: Colors.black54),
                  SizedBox(width: 10),
                  Text(
                    'Reject',
                    style: TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // For accepted chat requests
    if (widget.data.status == 'accepted' && widget.data.requestType == 'Chat') {
      return Column(
        children: [
          GestureDetector(
            onTap: _handleChatNavigation,
            child: Container(
              margin: EdgeInsets.only(bottom: 10),
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.chat_bubble, color: Colors.white),
                  SizedBox(width: 10),
                  Text(
                    'Chat',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // For accepted profile requests
    if (widget.data.status == 'accepted' && widget.data.requestType == 'Profile') {
      return Column(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.person_outline, color: Colors.white),
                SizedBox(width: 10),
                Text(
                  'Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // For accepted photo requests
    if (widget.data.status == 'accepted' && widget.data.requestType == 'Photo') {
      return Column(
        children: [
          GestureDetector(
            onTap: (){
             if(docstatus == "approved" && usertye == "paid") {
               Navigator.push(
                 context,
                 MaterialPageRoute(
                   builder: (context) => UserProfilePage(
                     userId: int.parse(widget.data.memberid.toString()),
                   ),
                 ),
               );
             }
             if (docstatus == "not_uploaded" || docstatus == "rejected" || docstatus == "pending") {
               Navigator.push(context, MaterialPageRoute(builder: (context) => IDVerificationScreen()));
             }

             if (usertye == "free" && docstatus == "approved") {
               Navigator.push(context, MaterialPageRoute(builder: (context) => SubscriptionPage()));
             }


            },
            child: Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                children: [
                  Icon(Icons.photo_album, color: Colors.white),
                  SizedBox(width: 10),
                  Text(
                    'Photo',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // For sent pending requests (current user is sender)
    if (widget.data.senderId == widget.userid && _isPending) {
      return Column(
        children: [
          GestureDetector(
            onTap: _handleCancelRequest,
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: const [
                  Icon(Icons.cancel_outlined, color: Colors.white),
                  SizedBox(width: 10),
                  Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildProfileImage() {
    final imageUrl = widget.data.profilePicture ?? "https://via.placeholder.com/150";

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: Container(
            width: 70,
            height: 70,
            color: Colors.grey[200],
            child: Image.network(
              imageUrl,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 50,
                  height: 50,
                  color: Colors.grey[200],
                  child: Icon(Icons.person, color: Colors.grey[400], size: 28),
                );
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  width: 50,
                  height: 50,
                  color: Colors.grey[200],
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
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
        ),
        if (widget.data.verified ?? false)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  // Action Handlers
  Future<void> _handleAcceptRequest() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Accept Request"),
        content: const Text(
          "Are you sure you want to accept this request?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Accept"),
          ),
        ],
      ),
    );

    if (confirm) {
      try {
        bool success = await ProposalService.acceptProposal(
          widget.data.proposalId.toString(),
          widget.userid,
        );

        if (success) {
          final senderName = await NotificationInboxService.getCurrentUserDisplayName();
          await NotificationService.sendRequestAccepted(
            recipientUserId: widget.data.senderId ?? '',
            senderName: senderName,
            senderId: widget.userid,
            requestType: widget.data.requestType ?? 'Request',
          );
          await NotificationInboxService.markRequestResolved(
            peerUserId: widget.data.senderId ?? '',
            requestType: widget.data.requestType ?? 'Request',
            status: 'accepted',
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Request accepted successfully"),
              backgroundColor: Colors.green,
            ),
          );

          widget.onActionComplete?.call();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Failed to accept request"),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        print("Error accepting proposal: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleRejectRequest() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reject Request"),
        content: const Text(
          "Are you sure you want to reject this request?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Reject"),
          ),
        ],
      ),
    );

    if (confirm) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
        bool success = await ProposalService.rejectProposal(
          widget.data.proposalId.toString(),
          widget.userid,
        );

        if (context.mounted) {
          Navigator.pop(context);
        }

        if (success) {
          final senderName = await NotificationInboxService.getCurrentUserDisplayName();
          await NotificationService.sendRequestRejected(
            recipientUserId: widget.data.senderId ?? '',
            senderName: senderName,
            senderId: widget.userid,
            requestType: widget.data.requestType ?? 'Request',
          );
          await NotificationInboxService.markRequestResolved(
            peerUserId: widget.data.senderId ?? '',
            requestType: widget.data.requestType ?? 'Request',
            status: 'rejected',
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Request rejected"),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );

          widget.onActionComplete?.call();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Failed to reject request"),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context);
        }
        print("Error rejecting proposal: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleCancelRequest() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cancel Request"),
        content: const Text(
          "Are you sure you want to cancel this request?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Yes"),
          ),
        ],
      ),
    );

    if (confirm) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
        bool success = await ProposalService.rejectProposal(
          widget.data.proposalId.toString(),
          widget.userid,
        );

        if (context.mounted) {
          Navigator.pop(context);
        }

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Request cancelled successfully"),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );

          widget.onActionComplete?.call();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Failed to cancel request"),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context);
        }
        print("Error cancelling proposal: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleChatNavigation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');

      if (userDataString == null) {
        throw Exception('User data not found');
      }

      final userData = jsonDecode(userDataString);
      final currentUserIdStr = widget.userid.toString();
      final currentUserName = "${userData['id'] ?? ''} ${userData['lastName'] ?? ''}".trim();
      final currentUserImage = (userData['profilePicture']?.toString() ?? '');

      final isCurrentUserSender = currentUserIdStr == widget.data.senderId;
      final otherUserId = isCurrentUserSender
          ? (widget.data.receiverId ?? '')
          : (widget.data.senderId ?? '');

      // Use the other user's name from widget.data (which already contains the other user's info)
      final otherUserName = "MS: ${widget.data.memberid.toString() ?? ''} ${widget.data.firstName ?? ''} ${widget.data.lastName ?? ''}".trim();
      final otherUserImage = widget.data.profilePicture ?? '';

      List<String> userIds = [currentUserIdStr, otherUserId];
      userIds.sort();
      final chatRoomId = userIds.join('_');

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
          'participants': [currentUserIdStr, otherUserId],
          'participantNames': {
            currentUserIdStr: currentUserName,
            otherUserId: otherUserName,
          },
          'participantImages': {
            currentUserIdStr: currentUserImage,
            otherUserId: otherUserImage,
          },
          'unreadCount': {
            currentUserIdStr: 0,
            otherUserId: 0,
          },
          'lastMessage': '',
          'lastMessageType': 'text',
          'lastMessageTime': DateTime.now(),
          'lastMessageSenderId': '',
          'createdAt': DateTime.now(),
          'updatedAt': DateTime.now(),
        });
      }

      if (docstatus == "approved" && usertye == "paid") {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailScreen(
              chatRoomId: chatRoomId,
              receiverId: otherUserId,
              receiverName: otherUserName.isNotEmpty
                  ? otherUserName
                  : "User $otherUserId",
              receiverImage: otherUserImage.isNotEmpty
                  ? otherUserImage
                  : 'https://via.placeholder.com/150',
              currentUserId: currentUserIdStr,
              currentUserName: currentUserName.isNotEmpty
                  ? currentUserName
                  : "User $currentUserIdStr",
              currentUserImage: currentUserImage.isNotEmpty
                  ? currentUserImage
                  : 'https://via.placeholder.com/150',
            ),
          ),
        );
      }

      if (docstatus == "not_uploaded" || docstatus == "rejected" || docstatus == "pending") {
        Navigator.push(context, MaterialPageRoute(builder: (context) => IDVerificationScreen()));
      }

      if (usertye == "free" && docstatus == "approved") {
        showUpgradeDialog(context);
      }
    } catch (e) {
      print("Error navigating to chat: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open chat. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
