import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../Auth/Login/Email.dart';
import '../Auth/Login/LoginMain.dart';
import '../Auth/Screen/Signup.dart';


class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pc = PageController();

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Widget _buildGetStartedPill() {
    return GestureDetector(
      onTap: (){
        Navigator.push(context, MaterialPageRoute(builder: (context) =>
           // IntroduceYourselfPage(),
        PrefilledEmailScreen()
        ));
      },
      child: Container(
        height: 62,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text(
              'Get Started',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            SizedBox(width: 10),
            CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFFff5a4f),
              child: Icon(Icons.arrow_forward, color: Colors.white, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Full gradient used on both pages
    return Scaffold(
      body: Stack(
        children: [
          // PageView
          PageView(
            controller: _pc,
            children: const [
              OnboardPageOne(),
              OnboardPageTwo(),
            ],
          ),

          // Skip button top-right
          Positioned(
            top: MediaQuery.of(context).padding.top + 14,
            right: 18,
            child: TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => PrefilledEmailScreen(),));
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),

          // Page indicator (above pill)
          Positioned(
            left: 0,
            right: 0,
            bottom: 120,
            child: Center(
              child: SmoothPageIndicator(
                controller: _pc,
                count: 2,
                effect: const ExpandingDotsEffect(
                  dotHeight: 8,
                  dotWidth: 8,
                  spacing: 8,
                  activeDotColor: Colors.white,
                  dotColor: Colors.white38,
                ),
              ),
            ),
          ),

          // Get started pill
          Positioned(
            left: 24,
            right: 24,
            bottom: 36,
            child: _buildGetStartedPill(),
          ),
        ],
      ),
    );
  }
}

/// ---------- Page 1 ----------
class OnboardPageOne extends StatelessWidget {
  const OnboardPageOne({super.key});

  // placeholder profile images (picsum)
  static const String img1 =
      'https://picsum.photos/seed/p1/200'; // top-left small
  static const String img2 = 'https://picsum.photos/seed/p2/200'; // mid small
  static const String img3 = 'https://picsum.photos/seed/p3/200'; // other

  @override
  Widget build(BuildContext context) {
    // main gradient
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFf04b3b), Color(0xFFe83a7f)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          // Top-left arc
          const Positioned(
            left: -140,
            top: -220,
            child: ArcBigCircle(),
          ),

          // dotted arc (small white dash path) - mimic screenshot with custom painter
          const Positioned(
            left: -20,
            top: 40,
            child: DottedArc(
              size: 420,
            ),
          ),

          // floating icons & small avatars
          // top-left small avatar
          Positioned(
            left: 28,
            top: 100,
            child: CircleAvatarWithBorder(
              imageUrl: img1,
              size: 70,
            ),
          ),

          // top-right small chat icon bubble
          Positioned(
            right: 90,
            top: 132,
            child: const FloatingIcon(icon: Icons.chat_bubble_outline),
          ),

          // mid floating avatar (toward center-right)
          Positioned(
            left: 220,
            top: 260,
            child: CircleAvatarWithBorder(
              imageUrl: img2,
              size: 62,
            ),
          ),

          // heart icon near center-right
          const Positioned(
            right: 140,
            top: 300,
            child: FloatingIcon(icon: Icons.favorite_border),
          ),

          // folder icon near lower-left
          const Positioned(
            left: 110,
            top: 360,
            child: FloatingIcon(icon: Icons.folder_outlined),
          ),

          // Main textual content anchored bottom-left
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(),
                  // Title
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Real People, Real Story',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        height: 1.02,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'A space where real people connect through genuine conversations and create stories that truly matter.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        height: 1.6,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 160),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------- Page 2 ----------
class OnboardPageTwo extends StatelessWidget {
  const OnboardPageTwo({super.key});

  static const String leftImg = 'https://picsum.photos/seed/g1/300/450';
  static const String centerImg = 'https://picsum.photos/seed/g2/400/600';
  static const String rightImg = 'https://picsum.photos/seed/g3/300/450';
  static const String small1 = 'https://picsum.photos/seed/u5/200';
  static const String small2 = 'https://picsum.photos/seed/u6/200';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFf04b3b), Color(0xFFe83a7f)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          // top shadowed rounded cards row
          Positioned(
            top: 92,
            left: 24,
            right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // left small card
                Transform.translate(
                  offset: const Offset(-8, 20),
                  child: RoundedImageCard(
                    imageUrl: leftImg,
                    width: 110,
                    height: 170,
                    borderRadius: 18,
                  ),
                ),

                const SizedBox(width: 12),

                // center big card
                RoundedImageCard(
                  imageUrl: centerImg,
                  width: 170,
                  height: 260,
                  borderRadius: 18,
                ),

                const SizedBox(width: 12),

                // right small card
                Transform.translate(
                  offset: const Offset(8, 20),
                  child: RoundedImageCard(
                    imageUrl: rightImg,
                    width: 110,
                    height: 170,
                    borderRadius: 18,
                  ),
                ),
              ],
            ),
          ),

          // small floating avatars + send icon (center area)
          Positioned(
            left: 110,
            top: 350,
            child: CircleAvatarWithBorder(
              imageUrl: small1,
              size: 58,
            ),
          ),
          const Positioned(
            left: 185,
            top: 370,
            child: FloatingIcon(icon: Icons.send),
          ),
          Positioned(
            right: 110,
            top: 350,
            child: CircleAvatarWithBorder(
              imageUrl: small2,
              size: 58,
            ),
          ),

          // heart icon near right card
          const Positioned(
            right: 70,
            top: 220,
            child: FloatingIcon(icon: Icons.favorite_border),
          ),

          // Text area at bottom-left
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Find Your Kind Of Connection',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Find your kind of connection with people who share your vibe, match your energy, and make every conversation feel natural.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.95),
                        fontSize: 14,
                        height: 1.6,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 140),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------- small helper widgets ----------

class CircleAvatarWithBorder extends StatelessWidget {
  final String imageUrl;
  final double size;
  const CircleAvatarWithBorder({
    super.key,
    required this.imageUrl,
    this.size = 60,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(colors: [Colors.white, Colors.white70]),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 6,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: CircleAvatar(
        radius: (size - 6) / 2,
        backgroundImage: NetworkImage(imageUrl),
      ),
    );
  }
}

class FloatingIcon extends StatelessWidget {
  final IconData icon;
  const FloatingIcon({super.key, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(color: Colors.white, width: 1.6),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 6,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }
}

class RoundedImageCard extends StatelessWidget {
  final String imageUrl;
  final double width;
  final double height;
  final double borderRadius;
  const RoundedImageCard({
    super.key,
    required this.imageUrl,
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          )
        ],
        image: DecorationImage(
          image: NetworkImage(imageUrl),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

/// Big light arc circle used top-left (partially off-screen)
class ArcBigCircle extends StatelessWidget {
  const ArcBigCircle({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 420,
      height: 420,
      child: CustomPaint(
        painter: _ArcPainter(),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color.fromARGB(60, 255, 255, 255);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// dotted arc path painter to mimic dashed curve in the screenshot
class DottedArc extends StatelessWidget {
  final double size;
  const DottedArc({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DottedArcPainter(),
      ),
    );
  }
}

class _DottedArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..strokeWidth = 1.9
      ..style = PaintingStyle.stroke;

    // approximate arc path by drawing many small arcs/dashes
    const int segments = 40;
    final Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final double startAngle = -3.14 / 1.9;
    final double sweep = 3.14 / 2.1;

    for (int i = 0; i < segments; i++) {
      final double dashStart = startAngle + (sweep / segments) * i + 0.01;
      final double dashSweep = (sweep / segments) * 0.6;
      canvas.drawArc(rect, dashStart, dashSweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
