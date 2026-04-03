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
import '../Calling/OutgoingCall.dart';
import '../Calling/videocall.dart';
import '../otherenew/othernew.dart';

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

class _AdminChatScreenState extends State<AdminChatScreen> {
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
    _loadUserImage();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
      // Auto-focus removed - users will click when ready to type
    });

// Automatically send profile card if provided (optional)
    if (widget.initialProfileData != null && !_profileCardSent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendProfileCard();
      });
    }
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
    _controller.dispose();
    _messageFocusNode.dispose();
    _audioPlayer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          0,
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
        .orderBy('timestamp', descending: false)
        .snapshots();
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

// FIXED: Updated message builder with correct sender logic
  Widget _buildMessageItem(DocumentSnapshot msg) {
    var data = msg.data() as Map<String, dynamic>;
    bool isMe = data['senderid'] == widget.senderID;
    String msgID = msg.id;
    Timestamp? ts = data['timestamp'];
    String formattedTime =
        ts != null ? DateFormat('HH:mm').format(ts.toDate()) : '';

// Determine if message is from admin
    bool isFromAdmin = data['senderid'] == _adminUserId;
    String senderName =
        isFromAdmin ? "Admin Support" : (isMe ? "You" : widget.userName);

    return GestureDetector(
      onDoubleTap: () => _toggleLike(msgID, data['liked'] ?? false),
      onLongPress: () => _setReplyTo(msgID, data),
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
    );
  }

// FIXED: Updated reply preview
  Widget _buildReplyPreview(String replyToID, bool isMe) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('adminchat')
          .doc(replyToID)
          .get(),
      builder: (context, snap) {
        if (snap.hasData && snap.data!.exists) {
          var replyData = snap.data!.data() as Map<String, dynamic>;
          bool isReplyFromMe = replyData['senderid'] == widget.senderID;
          bool isReplyFromAdmin = replyData['senderid'] == _adminUserId;
          String senderName = isReplyFromAdmin
              ? "Admin"
              : (isReplyFromMe ? "You" : widget.userName);

          String content = replyData['type'] == 'text'
              ? replyData['message']
              : '${replyData['type']} message';
          double textWidth = content.length * 8.0;
          double minWidth = 100.0;
          double maxWidth = MediaQuery.of(context).size.width * 0.6;
          double calculatedWidth = textWidth.clamp(minWidth, maxWidth);

          return ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: minWidth,
              maxWidth: maxWidth,
            ),
            child: IntrinsicWidth(
              child: Container(
                width: calculatedWidth,
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
                      children: [
                        Icon(
                          Icons.reply,
                          size: 16,
                          color: isMe
                              ? Colors.white70
                              : _primaryGradient.colors[0],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          senderName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isMe
                                ? Colors.white70
                                : _primaryGradient.colors[0],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      content,
                      style: TextStyle(
                        fontSize: 13,
                        color: isMe ? Colors.white : _textColor,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
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
                          // If user is already in this chat (viewing their own card), scroll to input
                          // If admin is viewing a user's card, open that user's chat
                          if (!widget.isAdmin) {
                            _messageFocusNode.requestFocus();
                            _scrollToBottom();
                          } else {
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
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProfileScreen(userId: userId),
                            ),
                          );
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.userName,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 20)),
            Text('Typically replies within 10 minutes',
                style: TextStyle(
                    fontSize: 13, color: Colors.white.withOpacity(0.8))),
          ],
        ),
        elevation: 0,
        actions: [
          // Call buttons removed as requested
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
// Show options menu
            },
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
              child: StreamBuilder<QuerySnapshot>(
                stream: _messagesStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                        child: Text('Error: ${snapshot.error}',
                            style: TextStyle(color: _textColor)));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting &&
                      _isFirstLoad) {
                    return Center(
                      child: CircularProgressIndicator(color: _accentColor),
                    );
                  }

                  bool hasNoMessages = !snapshot.hasData ||
                      snapshot.data!.docs.isEmpty ||
                      (snapshot.connectionState == ConnectionState.active &&
                          snapshot.data!.docs.isEmpty);

                  if (hasNoMessages &&
                      _showSuggestedMessages &&
                      !widget.isAdmin) {
                    return Column(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: _primaryGradient,
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.support_agent,
                                      size: 72,
                                      color: Colors.white.withOpacity(0.9)),
                                  const SizedBox(height: 20),
                                  Text('How can we help you?',
                                      style: TextStyle(
                                          fontSize: 20,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 12),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 40),
                                    child: Text(
                                        'Start a conversation or choose from common questions below',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 15,
                                            color:
                                                Colors.white.withOpacity(0.8))),
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

                  if (_isFirstLoad) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      setState(() {
                        _isFirstLoad = false;
                      });
                    });
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: _backgroundColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.only(top: 16, bottom: 12),
                      itemCount:
                          snapshot.hasData ? snapshot.data!.docs.length : 0,
                      itemBuilder: (context, index) {
                        var docs = snapshot.data!.docs;
                        return _buildMessageItem(docs[docs.length - 1 - index]);
                      },
                    ),
                  );
                },
              ),
            ),
            if (_replyToMessage != null) _buildReplyBar(),
            _buildInputBar(),
          ],
        ),
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
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
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
