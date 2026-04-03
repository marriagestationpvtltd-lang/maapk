import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

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
  final TextEditingController _controller = TextEditingController();
  final AudioRecorder _record = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

// Automatically send profile card if provided (optional)
    if (widget.initialProfileData != null && !_profileCardSent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendProfileCard();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _record.dispose();
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
        .where('senderid', whereIn: [widget.senderID, "1"])
        .where('receiverid', whereIn: [widget.senderID, "1"])
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
        widget.isAdmin ? "user_id_placeholder" : "1"; // Admin ID is "1"

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
    if (_controller.text.trim().isNotEmpty) {
      await _sendMessage('text', _controller.text.trim());
      _controller.clear();
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

  Future<void> _startRecording() async {
    var status = await Permission.microphone.request();
    if (status.isGranted) {
      try {
        await _record.start(const RecordConfig(),
            path:
                '${Directory.systemTemp.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a');
        setState(() => _isRecording = true);
      } catch (e) {
        print('Error starting recording: $e');
      }
    } else {
      print('Microphone permission denied');
    }
  }

  Future<void> _stopRecording() async {
    try {
      String? path = await _record.stop();
      setState(() => _isRecording = false);
      if (path != null) {
        File file = File(path);
        String fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        UploadTask task = FirebaseStorage.instance
            .ref('adminchat/${widget.senderID}/voice/$fileName')
            .putFile(file);
        TaskSnapshot snap = await task;
        String url = await snap.ref.getDownloadURL();
        await _sendMessage(
            'voice', jsonEncode({'url': url, 'duration': '0:15'}));
      }
    } catch (e) {
      print('Error stopping recording: $e');
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

// Determine if message is from admin (admin ID is "1")
    bool isFromAdmin = data['senderid'] == "1";
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
                          fontSize: 13,
                          color: _lightTextColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
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
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        if (data['type'] == 'voice')
                          _buildVoiceMessage(data['message'], isMe),
                        if (data['type'] == 'doc')
                          _buildDocumentMessage(data['message'], isMe),
                        if (data['type'] == 'image')
                          _buildImageMessage(data['imageUrl'], isMe),
                        if (data['type'] == 'profile_card')
                          _buildProfileCardMessage(data['profileData'], isMe),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              formattedTime,
                              style: TextStyle(
                                fontSize: 11,
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
          bool isReplyFromAdmin = replyData['senderid'] == "1";
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

// Updated Profile Card Message with Blur Logic
  Widget _buildProfileCardMessage(
      Map<String, dynamic>? profileData, bool isMe) {
    if (profileData == null) {
      return Text('Profile Card',
          style: TextStyle(
            color: isMe ? Colors.white : _textColor,
          ));
    }

    final bool shouldBlurPhoto = profileData['shouldBlurPhoto'] ?? true;

    return Container(
      width: 280,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
// Header with ID
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _primaryGradient.colors[0].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'MS: ${profileData['userId'] ?? 'N/A'}',
                  style: TextStyle(
                    fontSize: 11,
                    color: _primaryGradient.colors[0],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              if (!shouldBlurPhoto)
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_open,
                      color: Colors.white, size: 12),
                ),
            ],
          ),
          const SizedBox(height: 12),

// Profile Image and Basic Info
          Row(
            children: [
// Profile Image with Blur Logic
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: shouldBlurPhoto
                        ? ImageFiltered(
                            imageFilter: ImageFilter.blur(
                              sigmaX: 5.0,
                              sigmaY: 5.0,
                            ),
                            child: Container(
                              width: 70,
                              height: 70,
                              color: Colors.grey.shade200,
                              child: profileData['profileImage'] != null &&
                                      profileData['profileImage']
                                          .toString()
                                          .isNotEmpty
                                  ? Image.network(
                                      profileData['profileImage'],
                                      width: 70,
                                      height: 70,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                          Icons.person,
                                          size: 35,
                                          color: Colors.grey),
                                    )
                                  : const Icon(Icons.person,
                                      size: 35, color: Colors.grey),
                            ),
                          )
                        : Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              image: profileData['profileImage'] != null &&
                                      profileData['profileImage']
                                          .toString()
                                          .isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(
                                          profileData['profileImage']),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                              color: Colors.grey.shade200,
                            ),
                            child: profileData['profileImage'] == null ||
                                    profileData['profileImage']
                                        .toString()
                                        .isEmpty
                                ? const Icon(Icons.person,
                                    size: 35, color: Colors.grey)
                                : null,
                          ),
                  ),
                  if (shouldBlurPhoto)
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lock,
                            color: Colors.white, size: 10),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
// Name and Basic Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${profileData['firstName'] ?? ''} ${profileData['lastName'] ?? ''}'
                          .trim(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: _textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (profileData['location'] != null &&
                        profileData['location'].toString().isNotEmpty &&
                        profileData['location'] != 'Location not specified')
                      Row(
                        children: [
                          Icon(Icons.location_on,
                              size: 11, color: _lightTextColor),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              profileData['location'],
                              style: TextStyle(
                                fontSize: 10,
                                color: _lightTextColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 2),
                    if (profileData['age'] != null &&
                        profileData['age'] != 'N/A')
                      Text(
                        'Age: ${profileData['age']}',
                        style: TextStyle(
                          fontSize: 10,
                          color: _lightTextColor,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

// Details Grid
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                if (profileData['religion'] != null &&
                    profileData['religion'] != 'N/A')
                  _buildProfileDetailRow(
                      Icons.menu_book, 'Religion', profileData['religion']),
                if (profileData['community'] != null &&
                    profileData['community'] != 'N/A')
                  _buildProfileDetailRow(
                      Icons.groups, 'Community', profileData['community']),
                if (profileData['occupation'] != null &&
                    profileData['occupation'] != 'N/A')
                  _buildProfileDetailRow(
                      Icons.work, 'Occupation', profileData['occupation']),
                if (profileData['education'] != null &&
                    profileData['education'] != 'N/A')
                  _buildProfileDetailRow(
                      Icons.school, 'Education', profileData['education']),
                if (profileData['height'] != null &&
                    profileData['height'] != 'N/A')
                  _buildProfileDetailRow(
                      Icons.height, 'Height', profileData['height']),
              ],
            ),
          ),
          const SizedBox(height: 8),

// Bio
          if (profileData['bio'] != null &&
              profileData['bio'].toString().isNotEmpty &&
              profileData['bio'] != 'No bio available')
            Text(
              profileData['bio'],
              style: TextStyle(
                fontSize: 11,
                color: _lightTextColor,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  Widget _buildProfileDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 12, color: _primaryGradient.colors[0]),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: _textColor,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 10,
                color: _lightTextColor,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
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
          if (!widget.isAdmin)
            GestureDetector(
              onLongPressStart: (_) => _startRecording(),
              onLongPressEnd: (_) => _stopRecording(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  _isRecording ? Icons.mic : Icons.mic_none,
                  color:
                      _isRecording ? _accentColor : _primaryGradient.colors[0],
                  size: 28,
                ),
              ),
            ),
          const SizedBox(width: 12),
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
