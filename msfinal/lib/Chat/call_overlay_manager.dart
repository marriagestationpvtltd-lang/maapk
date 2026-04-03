import 'package:flutter/material.dart';

/// Singleton class to manage call overlay state across the app
class CallOverlayManager {
  static final CallOverlayManager _instance = CallOverlayManager._internal();
  factory CallOverlayManager() => _instance;
  CallOverlayManager._internal();

  // Current call state
  bool _isCallActive = false;
  bool _isMinimized = false;
  String? _callType; // 'audio' or 'video'
  String? _otherUserName;
  String? _otherUserId;
  String? _currentUserId;
  String? _currentUserName;

  // Callbacks
  VoidCallback? _onMaximize;
  VoidCallback? _onEnd;

  // Getters
  bool get isCallActive => _isCallActive;
  bool get isMinimized => _isMinimized;
  String? get callType => _callType;
  String? get otherUserName => _otherUserName;
  String? get otherUserId => _otherUserId;

  /// Start a new call
  void startCall({
    required String callType,
    required String otherUserName,
    required String otherUserId,
    required String currentUserId,
    required String currentUserName,
    required VoidCallback onMaximize,
    required VoidCallback onEnd,
  }) {
    _isCallActive = true;
    _isMinimized = false;
    _callType = callType;
    _otherUserName = otherUserName;
    _otherUserId = otherUserId;
    _currentUserId = currentUserId;
    _currentUserName = currentUserName;
    _onMaximize = onMaximize;
    _onEnd = onEnd;
  }

  /// Minimize the call
  void minimizeCall() {
    if (_isCallActive) {
      _isMinimized = true;
    }
  }

  /// Maximize the call
  void maximizeCall() {
    if (_isCallActive && _isMinimized) {
      _isMinimized = false;
      _onMaximize?.call();
    }
  }

  /// End the call
  void endCall() {
    _isCallActive = false;
    _isMinimized = false;
    _callType = null;
    _otherUserName = null;
    _otherUserId = null;
    _currentUserId = null;
    _currentUserName = null;
    _onEnd?.call();
    _onMaximize = null;
    _onEnd = null;
  }

  /// Reset state
  void reset() {
    _isCallActive = false;
    _isMinimized = false;
    _callType = null;
    _otherUserName = null;
    _otherUserId = null;
    _currentUserId = null;
    _currentUserName = null;
    _onMaximize = null;
    _onEnd = null;
  }
}

/// Widget that displays minimized call overlay
class MinimizedCallOverlay extends StatelessWidget {
  const MinimizedCallOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = CallOverlayManager();

    if (!manager.isCallActive || !manager.isMinimized) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 50,
      left: 16,
      right: 16,
      child: GestureDetector(
        onTap: () => manager.maximizeCall(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE53935), Color(0xFFEC407A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Call icon
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  manager.callType == 'video' ? Icons.videocam : Icons.call,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // Call info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      manager.callType == 'video' ? 'Video Call' : 'Voice Call',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      manager.otherUserName ?? 'Unknown',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Maximize button
                  IconButton(
                    onPressed: () => manager.maximizeCall(),
                    icon: const Icon(
                      Icons.open_in_full,
                      color: Colors.white,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),

                  // End call button
                  IconButton(
                    onPressed: () {
                      manager.endCall();
                    },
                    icon: const Icon(
                      Icons.call_end,
                      color: Colors.white,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wrapper widget that adds minimized call overlay to any screen
class CallOverlayWrapper extends StatefulWidget {
  final Widget child;

  const CallOverlayWrapper({
    super.key,
    required this.child,
  });

  @override
  State<CallOverlayWrapper> createState() => _CallOverlayWrapperState();
}

class _CallOverlayWrapperState extends State<CallOverlayWrapper> {
  @override
  void initState() {
    super.initState();
    // Listen to call state changes
    _setupListener();
  }

  void _setupListener() {
    // Refresh UI when call state changes
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {});
        _setupListener();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        const MinimizedCallOverlay(),
      ],
    );
  }
}
