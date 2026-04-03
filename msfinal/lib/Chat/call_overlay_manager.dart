import 'package:flutter/material.dart';

const String activeCallRouteName = '/active-call';
const String minimizedCallHostRouteName = '/minimized-call-host';

/// Singleton class to manage call overlay state across the app
class CallOverlayManager extends ChangeNotifier {
  static final CallOverlayManager _instance = CallOverlayManager._internal();
  factory CallOverlayManager() => _instance;
  CallOverlayManager._internal();

  bool _isCallActive = false;
  bool _isMinimized = false;
  String? _callType;
  String? _otherUserName;
  String? _otherUserId;
  String? _currentUserId;
  String? _currentUserName;
  String _statusText = 'Calling...';
  Duration _duration = Duration.zero;

  VoidCallback? _onMaximize;
  VoidCallback? _onEnd;

  bool get isCallActive => _isCallActive;
  bool get isMinimized => _isMinimized;
  String? get callType => _callType;
  String? get otherUserName => _otherUserName;
  String? get otherUserId => _otherUserId;
  String get statusText => _statusText;
  Duration get duration => _duration;
  bool get isConnected => _duration > Duration.zero || _statusText == 'Connected';

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
    notifyListeners();
  }

  void updateCallState({
    required String statusText,
    Duration? duration,
    bool? isMinimized,
  }) {
    if (!_isCallActive) {
      return;
    }
    _statusText = statusText;
    if (duration != null) {
      _duration = duration;
    }
    if (isMinimized != null) {
      _isMinimized = isMinimized;
    }
    notifyListeners();
  }

  void minimizeCall() {
    if (_isCallActive && !_isMinimized) {
      _isMinimized = true;
      notifyListeners();
    }
  }

  void maximizeCall() {
    if (_isCallActive && _isMinimized) {
      _isMinimized = false;
      notifyListeners();
      _onMaximize?.call();
    }
  }

  void endCall() {
    final onEnd = _onEnd;
    if (onEnd != null) {
      onEnd();
      return;
    }
    reset();
  }

  void reset() {
    _isCallActive = false;
    _isMinimized = false;
    _callType = null;
    _otherUserName = null;
    _otherUserId = null;
    _currentUserId = null;
    _currentUserName = null;
    _statusText = 'Calling...';
    _duration = Duration.zero;
    _onMaximize = null;
    _onEnd = null;
    notifyListeners();
  }
}

/// Widget that displays minimized call overlay
class MinimizedCallOverlay extends StatelessWidget {
  const MinimizedCallOverlay({super.key});

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final manager = CallOverlayManager();

    return AnimatedBuilder(
      animation: manager,
      builder: (context, child) {
        if (!manager.isCallActive || !manager.isMinimized) {
          return const SizedBox.shrink();
        }

        final subtitle = manager.isConnected
            ? _formatDuration(manager.duration)
            : manager.statusText;

        return Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 12,
          right: 12,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: manager.maximizeCall,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF075E54),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                manager.otherUserName ?? 'Unknown',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: manager.maximizeCall,
                          icon: const Icon(Icons.open_in_full, color: Colors.white, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: manager.endCall,
                          icon: const Icon(Icons.call_end, color: Colors.white, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        minHeight: 4,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Wrapper widget that adds minimized call overlay to any screen
class CallOverlayWrapper extends StatelessWidget {
  final Widget child;

  const CallOverlayWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        const MinimizedCallOverlay(),
      ],
    );
  }
}
