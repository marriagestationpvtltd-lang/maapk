import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'call_history_model.dart';
import '../service/socket_service.dart';
import 'package:uuid/uuid.dart';

class CallHistoryService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String COLLECTION_NAME = 'callHistory';

  // Log a new call
  static Future<String> logCall({
    required String callerId,
    required String callerName,
    required String callerImage,
    required String recipientId,
    required String recipientName,
    required String recipientImage,
    required CallType callType,
    required String initiatedBy,
  }) async {
    try {
      final callId = _firestore.collection(COLLECTION_NAME).doc().id;
      final callHistory = CallHistory(
        callId: callId,
        callerId: callerId,
        callerName: callerName,
        callerImage: callerImage,
        recipientId: recipientId,
        recipientName: recipientName,
        recipientImage: recipientImage,
        callType: callType,
        startTime: DateTime.now(),
        endTime: null,
        duration: 0,
        status: CallStatus.missed, // Default to missed, will be updated
        initiatedBy: initiatedBy,
      );

      await _firestore
          .collection(COLLECTION_NAME)
          .doc(callId)
          .set(callHistory.toMap());

      return callId;
    } catch (e) {
      print('Error logging call: $e');
      return '';
    }
  }

  // Update call when it ends
  static Future<void> updateCallEnd({
    required String callId,
    required CallStatus status,
    int duration = 0,
  }) async {
    try {
      await _firestore.collection(COLLECTION_NAME).doc(callId).update({
        'endTime': Timestamp.fromDate(DateTime.now()),
        'duration': duration,
        'status': status.toString().split('.').last,
      });
    } catch (e) {
      print('Error updating call end: $e');
    }
  }

  // Get call history for a specific user
  static Stream<List<CallHistory>> getCallHistory(String userId) {
    return _firestore
        .collection(COLLECTION_NAME)
        .orderBy('startTime', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      // Filter to only calls involving this user
      final allCalls = snapshot.docs
          .map((doc) => CallHistory.fromMap(doc.data(), doc.id))
          .where((call) => call.callerId == userId || call.recipientId == userId)
          .toList();

      // Sort by start time
      allCalls.sort((a, b) => b.startTime.compareTo(a.startTime));

      return allCalls.take(100).toList();
    });
  }

  // Get call history with pagination
  static Future<List<CallHistory>> getCallHistoryPaginated({
    required String userId,
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      Query query = _firestore
          .collection(COLLECTION_NAME)
          .where('callerId', isEqualTo: userId)
          .orderBy('startTime', descending: true)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final callerSnapshot = await query.get();
      final callerCalls = callerSnapshot.docs
          .map((doc) => CallHistory.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      // Get calls where user is recipient
      Query recipientQuery = _firestore
          .collection(COLLECTION_NAME)
          .where('recipientId', isEqualTo: userId)
          .orderBy('startTime', descending: true)
          .limit(limit);

      if (lastDocument != null) {
        recipientQuery = recipientQuery.startAfterDocument(lastDocument);
      }

      final recipientSnapshot = await recipientQuery.get();
      final recipientCalls = recipientSnapshot.docs
          .map((doc) => CallHistory.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      // Combine and sort
      final allCalls = [...callerCalls, ...recipientCalls];
      allCalls.sort((a, b) => b.startTime.compareTo(a.startTime));

      return allCalls.take(limit).toList();
    } catch (e) {
      print('Error getting call history: $e');
      return [];
    }
  }

  // Get missed calls count
  static Future<int> getMissedCallsCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(COLLECTION_NAME)
          .where('recipientId', isEqualTo: userId)
          .where('status', isEqualTo: 'missed')
          .get();

      return snapshot.docs.length;
    } catch (e) {
      print('Error getting missed calls count: $e');
      return 0;
    }
  }

  // Clear all call history for a user (optional feature)
  static Future<void> clearCallHistory(String userId) async {
    try {
      // Delete calls where user is caller
      final callerCalls = await _firestore
          .collection(COLLECTION_NAME)
          .where('callerId', isEqualTo: userId)
          .get();

      for (var doc in callerCalls.docs) {
        await doc.reference.delete();
      }

      // Delete calls where user is recipient
      final recipientCalls = await _firestore
          .collection(COLLECTION_NAME)
          .where('recipientId', isEqualTo: userId)
          .get();

      for (var doc in recipientCalls.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('Error clearing call history: $e');
    }
  }

  // Delete a specific call from history
  static Future<void> deleteCall(String callId) async {
    try {
      await _firestore.collection(COLLECTION_NAME).doc(callId).delete();
    } catch (e) {
      print('Error deleting call: $e');
    }
  }

  // Write an inline call event message into the chat message stream (WhatsApp-style).
  // Pass [chatRoomId] for regular user-to-user chat.
  // Pass [isAdminChat]=true + [adminChatSenderId] + [adminChatReceiverId] for admin chat.
  // Pass [messageDocId] to use a stable document ID (e.g. channel name) so that both
  // the caller and recipient sides can write without creating duplicate messages.
  static Future<void> logCallMessageInChat({
    required String callerId,
    required String callType, // 'audio' or 'video'
    required String callStatus, // 'completed', 'missed', 'declined', 'cancelled'
    required int duration,
    String? chatRoomId,
    bool isAdminChat = false,
    String? adminChatSenderId,
    String? adminChatReceiverId,
    String? messageDocId,
  }) async {
    try {
      if (isAdminChat) {
        final senderId = adminChatSenderId ?? callerId;
        final receiverId = adminChatReceiverId ?? '';
        if (receiverId.isNotEmpty) {
          final List<String> ids = [senderId, receiverId]..sort();
          final adminChatRoomId = ids.join('_');
          final payload = jsonEncode({
            'callType': callType,
            'callStatus': callStatus,
            'duration': duration,
            'callerId': callerId,
          });
          SocketService().sendMessage(
            chatRoomId: adminChatRoomId,
            senderId: senderId,
            receiverId: receiverId,
            message: payload,
            messageType: 'call',
            messageId: const Uuid().v4(),
            user1Name: '',
            user2Name: '',
            user1Image: '',
            user2Image: '',
          );
        }
      } else if (chatRoomId != null && chatRoomId.isNotEmpty) {
        final docId = messageDocId ?? _firestore.collection('chatRooms').doc().id;
        final msgRef = _firestore
            .collection('chatRooms')
            .doc(chatRoomId)
            .collection('messages')
            .doc(docId);
        await msgRef.set({
          'messageId': msgRef.id,
          'senderId': callerId,
          'message': '',
          'messageType': 'call',
          'callType': callType,
          'callStatus': callStatus,
          'duration': duration,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'isDelivered': false,
        });
      }
    } catch (e) {
      print('Error logging call message in chat (chatRoomId: $chatRoomId, isAdminChat: $isAdminChat): $e');
    }
  }

  // Get current user ID from SharedPreferences
  static Future<String> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    if (userDataString != null) {
      // Parse the user data to extract user ID
      // This depends on how user_data is stored
      return userDataString; // Adjust this based on actual storage format
    }
    return '';
  }
}
