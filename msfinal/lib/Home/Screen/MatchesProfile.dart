// matched_profile_card.dart
// Reusable Flutter widgets for the horizontal matched-profiles UI.
// Usage:
// import 'matched_profile_card.dart';
//
// MatchedProfilesList(
//   profiles: yourListOfMaps,
//   onSendRequest: (profile) { /* handle send request */ },
// )

import 'package:flutter/material.dart';

typedef SendRequestCallback = void Function(Map<String, dynamic> profile);

class MatchedProfilesList extends StatelessWidget {
  final List<Map<String, dynamic>> profiles;
  final SendRequestCallback? onSendRequest;
  final EdgeInsetsGeometry padding;
  final double cardWidth;

  const MatchedProfilesList({
    Key? key,
    required this.profiles,
    this.onSendRequest,
    this.padding = const EdgeInsets.only(left: 12),
    this.cardWidth = 200,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 276,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: profiles.length,
        padding: padding,
        itemBuilder: (context, index) {
          final profile = profiles[index];
          return Container(
            margin: EdgeInsets.only(right: 14),
            width: cardWidth,
            child: MatchedProfileCard(
              profile: profile,
              onSendRequest: () => onSendRequest?.call(profile),
              // forward status if present on profile map (keys: request_status)
              currentStatus: profile['request_status']?.toString(),
            ),
          );
        },
      ),
    );
  }
}

class MatchedProfileCard extends StatelessWidget {
  final Map<String, dynamic> profile;
  final VoidCallback? onSendRequest;
  final String? currentStatus; // null | 'loading' | 'pending' | 'sent' | 'error'

  const MatchedProfileCard({
    Key? key,
    required this.profile,
    this.onSendRequest,
    this.currentStatus,
  }) : super(key: key);

  String _getString(dynamic value) => (value ?? '').toString();

  @override
  Widget build(BuildContext context) {
    final name = _getString(profile['firstName']).isEmpty ? (_getString(profile['name']).isEmpty ? 'Name' : profile['name']) : profile['firstName'];
    final age = _getString(profile['age']);
    final height = _getString(profile['height_name'] ?? profile['height']);
    final profession = _getString(profile['designation'] ?? profile['profession']);
    final location = _getString((profile['city'] != null ? profile['city'] + (profile['country'] != null ? ', ' + profile['country'] : '') : profile['location']) ?? '');
    final imageUrl = _getString(profile['profile_picture'] ?? profile['image']);

    return Container(
      padding: EdgeInsets.all(5),
      height: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.red),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image + name overlay
          Stack(
            children: [
              SizedBox(
                height: 140,
                child: imageUrl.isNotEmpty
                    ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (c, e, s) => _placeholder(),
                )
                    : _placeholder(),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  color: Colors.black.withOpacity(0.55),
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),

          // Info section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Age ${age.isEmpty ? '-' : age} yrs, ${height.isEmpty ? '-' : height} cm',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                Row(
                  children: [
                    Icon(Icons.work_outline, size: 13, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        profession.isEmpty ? '-' : profession,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 13, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location.isEmpty ? '-' : location,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Send Request Button (now reacts to currentStatus)
                SizedBox(
                  height: 40,
                  child: _buildStatusButton(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusButton(BuildContext context) {
    final status = (currentStatus ?? '').toLowerCase();

    String label;
    bool enabled;

    switch (status) {
      case 'loading':
        label = 'Sending...';
        enabled = false;
        break;
      case 'pending':
        label = 'Pending';
        enabled = false;
        break;
      case 'sent':
        label = 'Sent';
        enabled = false;
        break;
      case 'error':
        label = 'Retry';
        enabled = true;
        break;
      default:
        label = 'Send Request';
        enabled = true;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEA4935), Color(0xFFEB3D82)],
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: enabled ? onSendRequest : null,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (status == 'loading') ...[
                    SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                  ] else ...[
                    Icon(Icons.send, size: 13, color: Color(0xFFEA4935)),
                    const SizedBox(width: 6),
                  ],

                  Text(
                    label,
                    style: TextStyle(
                      color: Color(0xFFEA4935),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(Icons.person, size: 48, color: Colors.grey),
      ),
    );
  }
}
