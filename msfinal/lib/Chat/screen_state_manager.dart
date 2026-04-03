
class ScreenStateManager {
  static final ScreenStateManager _instance = ScreenStateManager._internal();
  factory ScreenStateManager() => _instance;
  ScreenStateManager._internal();

  // Track currently active chat screen
  String? _activeChatRoomId;
  String? _currentUserId;

  // Track if chat screen is active
  bool get isChatScreenActive => _activeChatRoomId != null;

  // Check if specific chat is active
  bool isChatActive(String chatRoomId, String userId) {
    return _activeChatRoomId == chatRoomId && _currentUserId == userId;
  }

  // Set chat as active
  void setChatActive(String chatRoomId, String userId) {
    _activeChatRoomId = chatRoomId;
    _currentUserId = userId;
  }

  // Clear chat active state
  void clearChatActive() {
    _activeChatRoomId = null;
    _currentUserId = null;
  }

  // Track screen lifecycle
  void onChatScreenOpened(String chatRoomId, String userId) {
    setChatActive(chatRoomId, userId);
  }

  void onChatScreenClosed() {
    clearChatActive();
  }
}

// Helper method to check if notification should be shown
bool shouldShowChatNotification(Map<String, dynamic> data) {
  final manager = ScreenStateManager();
  final chatRoomId = data['chatRoomId'];
  final receiverId = data['receiverId'];

  // If this is a chat notification and user is viewing the same chat, don't show
  if (data['type'] == 'chat' &&
      chatRoomId != null &&
      receiverId != null &&
      manager.isChatActive(chatRoomId, receiverId)) {
    return false;
  }

  return true;
}