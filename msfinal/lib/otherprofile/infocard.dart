import 'package:flutter/material.dart';

class MatrimonyInfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? iconColor;
  final Color? cardColor;
  final bool hasShadow;
  final double? width;
  final bool isImportant;

  const MatrimonyInfoCard({
    Key? key,
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor,
    this.cardColor,
    this.hasShadow = true,
    this.width,
    this.isImportant = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Matrimony-specific color scheme
    final primaryColor = Colors.red.shade600;
    final secondaryColor = Colors.pink.shade100;
    final accentColor = isImportant ? Colors.red.shade400 : Colors.red.shade300;

    return Container(
      width: width,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: cardColor ?? (isDarkMode ? Colors.grey[900] : Colors.white),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isImportant
              ? Colors.red.shade300.withOpacity(0.8)
              : (isDarkMode ? Colors.grey[800]! : Colors.grey.shade100),
          width: isImportant ? 2 : 1.5,
        ),
        boxShadow: hasShadow
            ? [
          BoxShadow(
            color: (isImportant ? Colors.red.shade100 : Colors.grey).withOpacity(0.15),
            blurRadius: isImportant ? 20 : 15,
            spreadRadius: isImportant ? 2 : 1,
            offset: const Offset(0, 6),
          ),
        ]
            : null,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isImportant
              ? [
            Colors.red.shade50.withOpacity(0.3),
            Colors.pink.shade50.withOpacity(0.2),
          ]
              : [
            Colors.white.withOpacity(0.9),
            Colors.grey.shade50.withOpacity(0.9),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Decorative corner elements
          if (isImportant)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(40),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      Colors.red.shade200.withOpacity(0.3),
                      Colors.red.shade100.withOpacity(0.1),
                    ],
                  ),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon Container with modern design
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        iconColor ?? primaryColor,
                        iconColor ?? Colors.red.shade400,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (iconColor ?? primaryColor).withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: Colors.white,
                  ),
                ),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title with decorative underline
                      Row(
                        children: [
                          Text(
                            title.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDarkMode
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                              letterSpacing: 1.2,
                              fontFamily: 'Roboto',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 30,
                            height: 2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.red.shade300,
                                  Colors.red.shade200,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Value with elegant typography
                      value.isNotEmpty
                          ? Text(
                        value,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: isImportant ? FontWeight.w800 : FontWeight.w700,
                          color: isDarkMode
                              ? Colors.white
                              : (isImportant ? Colors.red.shade800 : Colors.black87),
                          height: 1.4,
                          fontFamily: 'PlayfairDisplay',
                          letterSpacing: isImportant ? 0.3 : 0.2,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      )
                          : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 14,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Not specified',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Optional decorative element for important cards
                if (isImportant)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.star_outline,
                      size: 18,
                      color: Colors.red.shade300,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Alternative card design for partner preferences
class PartnerPreferenceCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final bool isEssential;

  const PartnerPreferenceCard({
    Key? key,
    required this.title,
    required this.value,
    required this.icon,
    this.isEssential = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEssential
              ? Colors.red.shade200.withOpacity(0.8)
              : Colors.grey.shade100,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.05),
            blurRadius: 12,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Heart-shaped icon container
            Container(
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.red.shade100,
                    Colors.pink.shade100,
                  ],
                ),
              ),
              child: Icon(
                icon,
                size: 20,
                color: Colors.red.shade600,
              ),
            ),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (isEssential)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.red.shade200,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'Essential',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.red.shade600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value.isNotEmpty ? value : 'Flexible',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
            ),

            // Heart indicator for essential preferences
            if (isEssential)
              Icon(
                Icons.favorite_outline,
                size: 16,
                color: Colors.red.shade300,
              ),
          ],
        ),
      ),
    );
  }
}

// Compact version for profile highlights
class ProfileHighlightCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const ProfileHighlightCard({
    Key? key,
    required this.label,
    required this.value,
    required this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade100,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red.shade50,
            ),
            child: Icon(
              icon,
              size: 16,
              color: Colors.red.shade600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}