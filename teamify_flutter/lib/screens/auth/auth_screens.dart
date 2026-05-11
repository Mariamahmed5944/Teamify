import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/routes.dart';
import '../../core/network/api_exception.dart';
import '../../core/session/session_controller.dart';
import '../../widgets/widgets.dart';
import '../../data/dummy_data.dart';

// ── Routing Logic ─────────────────────────────────────────────────────────────
void _navigateToCorrectHome(BuildContext context, String role,
    {String? email, String? name, bool isNew = false}) {
  if (role == 'Admin') {
    Navigator.pushNamedAndRemoveUntil(context, R.adminHome, (_) => false);
    return;
  }

  bool hasData = false;
  String displayName = name ?? 'User';

  if (email != null && email.trim().isNotEmpty) {
    final searchEmail = email.trim().toLowerCase();
    try {
      final user = DummyData.users
          .firstWhere((u) => u.email.toLowerCase() == searchEmail);
      displayName = user.name;
      hasData = DummyData.projects.any((p) => p.members.contains(user.name));
    } catch (_) {
      hasData = false;
    }
  } else if (name != null && name.trim().isNotEmpty) {
    hasData = DummyData.projects.any((p) => p.members.contains(name.trim()));
  }

  // Logic: Show NewUserHomeScreen ONLY for new registrations with no data.
  // Otherwise, show the original regular home screen.
  bool shouldShowEmptyHome = isNew && !hasData;

  debugPrint('--- AUTH NAVIGATION ---');
  debugPrint('Role: $role, isNew: $isNew, hasData: $hasData');
  debugPrint(
      'Target: ${shouldShowEmptyHome ? "NewUserHomeScreen" : "Regular Home"}');

  if (shouldShowEmptyHome) {
    Navigator.pushNamedAndRemoveUntil(context, R.newUserHome, (_) => false,
        arguments: {'role': role, 'name': displayName});
  } else {
    Navigator.pushNamedAndRemoveUntil(context,
        role == 'Student' ? R.studentHome : R.freelancerHome, (_) => false);
  }
}

String _homeRouteForSession(SessionController session) {
  final user = session.currentUser;
  if (user == null) return R.roleSelection;
  if (user.isAdmin) return R.adminHome;
  if (user.isStudent) return R.studentHome;
  return R.freelancerHome;
}

void _navigateFromSession(BuildContext context, {bool isNew = false}) {
  final session = context.read<SessionController>();
  if (session.isPendingApproval) {
    Navigator.pushNamedAndRemoveUntil(context, R.newUserHome, (_) => false,
        arguments: {
          'role': session.currentUser?.displayRole ?? 'User',
          'name': session.currentUser?.displayName ?? 'User',
          'pendingApproval': true,
        });
    return;
  }

  Navigator.pushNamedAndRemoveUntil(
      context, _homeRouteForSession(session), (_) => false);
}

void _showAuthError(BuildContext context, Object error) {
  final message = error is ApiException
      ? error.message
      : error is Exception
          ? error.toString().replaceFirst('Exception: ', '')
          : 'Something went wrong. Please try again.';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

String _displayNameFrom(String name, String email) {
  final fromName = name.trim().replaceAll(RegExp(r'\s+'), '_').toLowerCase();
  if (fromName.isNotEmpty) return fromName;
  final fromEmail =
      email.split('@').first.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  return fromEmail.isNotEmpty ? fromEmail : 'teamify_user';
}

// ── Teamify Logo Widget ───────────────────────────────────────────────────────
class _TeamifyLogo extends StatelessWidget {
  final double size;
  const _TeamifyLogo({this.size = 80});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

// ── Splash ────────────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), _routeAfterSessionRestore);
  }

  void _routeAfterSessionRestore() {
    if (!mounted) return;
    final session = context.read<SessionController>();
    if (session.status == SessionStatus.unknown) {
      Future.delayed(
          const Duration(milliseconds: 300), _routeAfterSessionRestore);
      return;
    }
    if (session.isAuthenticated || session.isPendingApproval) {
      _navigateFromSession(context);
    } else {
      Navigator.pushReplacementNamed(context, R.onboarding);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          _TeamifyLogo(size: 150),
          SizedBox(height: 16),
          Text(
            'Teamify',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A3A6B),
              letterSpacing: 1.0,
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Onboarding ────────────────────────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  final _pages = [
    _OnboardData(
      emoji: '💼',
      illustration: _IllustrationWork(),
      text: '"Work smarter together with\nAI-powered task allocation."',
      isLast: false,
    ),
    _OnboardData(
      emoji: '🔔',
      illustration: _IllustrationAlert(),
      text: '"Stay ahead — AI alerts you\nwhen tasks are at risk of\ndelay."',
      isLast: false,
    ),
    _OnboardData(
      emoji: '🔒',
      illustration: _IllustrationSecure(),
      text:
          '"Communicate safely with\nend-to-end encryption and\nsecure data protection."',
      isLast: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GestureDetector(
                onTap: () =>
                    Navigator.pushReplacementNamed(context, R.roleSelection),
                child: const Text('Skip',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16)),
              ),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (i) => setState(() => _page = i),
              itemCount: _pages.length,
              itemBuilder: (_, i) => _buildPage(_pages[i]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              if (_pages[_page].isLast)
                TButton(
                  label: 'Get Started',
                  onTap: () =>
                      Navigator.pushReplacementNamed(context, R.roleSelection),
                )
              else
                const SizedBox.shrink(),
              const SizedBox(height: 16),
              Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                      _pages.length,
                      (i) => Container(
                            width: i == _page ? 20 : 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                                color: i == _page
                                    ? AppColors.primary
                                    : AppColors.border,
                                borderRadius: BorderRadius.circular(4)),
                          ))),
              const SizedBox(height: 8),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildPage(_OnboardData d) {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(height: 240, child: d.illustration),
      const SizedBox(height: 32),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(d.text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 18,
                color: AppColors.textPrimary,
                height: 1.5,
                fontStyle: FontStyle.italic)),
      ),
    ]);
  }
}

class _OnboardData {
  final String emoji, text;
  final Widget illustration;
  final bool isLast;
  const _OnboardData(
      {required this.emoji,
      required this.illustration,
      required this.text,
      required this.isLast});
}

class _IllustrationWork extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/onboarding1.png',
      width: 300,
      height: 220,
      fit: BoxFit.contain,
    );
  }
}

class _WorkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;

    // Background dots pattern
    paint.color = const Color(0xFFE8E8E8);
    for (int i = 0; i < 6; i++) {
      for (int j = 0; j < 4; j++) {
        canvas.drawCircle(Offset(i * 18.0, j * 18.0), 2.5, paint);
        canvas.drawCircle(Offset(w - i * 18.0, j * 18.0), 2.5, paint);
      }
    }

    // Table/floor line
    paint.color = const Color(0xFFE8E8E8);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(20, h * 0.72, w - 40, 8), const Radius.circular(4)),
        paint);

    // --- Board on wall ---
    paint.color = Colors.white;
    final boardRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.38, h * 0.05, w * 0.22, h * 0.38),
        const Radius.circular(6));
    canvas.drawRRect(boardRect, paint);
    paint.color = const Color(0xFFE0E0E0);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.5;
    canvas.drawRRect(boardRect, paint);
    paint.style = PaintingStyle.fill;
    // Blue square
    paint.color = const Color(0xFF2D5FA6);
    canvas.drawRect(
        Rect.fromLTWH(w * 0.49, h * 0.12, w * 0.07, h * 0.09), paint);
    // Gray squares
    paint.color = const Color(0xFFBBBBBB);
    canvas.drawRect(
        Rect.fromLTWH(w * 0.41, h * 0.12, w * 0.07, h * 0.09), paint);
    canvas.drawRect(
        Rect.fromLTWH(w * 0.41, h * 0.23, w * 0.07, h * 0.09), paint);
    canvas.drawRect(
        Rect.fromLTWH(w * 0.49, h * 0.23, w * 0.07, h * 0.09), paint);

    // --- Left person (woman leaning) ---
    // Body
    paint.color = const Color(0xFFF5F5F5);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.05, h * 0.38, w * 0.18, h * 0.30),
            const Radius.circular(8)),
        paint);
    // Hair
    paint.color = const Color(0xFF1A1A2E);
    canvas.drawCircle(Offset(w * 0.13, h * 0.28), w * 0.07, paint);
    // Head
    paint.color = const Color(0xFFD4956A);
    canvas.drawCircle(Offset(w * 0.14, h * 0.30), w * 0.055, paint);
    // Arm leaning forward
    paint.color = const Color(0xFFD4956A);
    final armPath = Path()
      ..moveTo(w * 0.18, h * 0.48)
      ..quadraticBezierTo(w * 0.28, h * 0.52, w * 0.33, h * 0.60);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 10;
    paint.strokeCap = StrokeCap.round;
    canvas.drawPath(armPath, paint);
    paint.style = PaintingStyle.fill;

    // --- Left laptop ---
    paint.color = const Color(0xFF222222);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.25, h * 0.55, w * 0.18, h * 0.14),
            const Radius.circular(4)),
        paint);
    paint.color = const Color(0xFF1A1A2E);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.22, h * 0.68, w * 0.24, h * 0.04),
            const Radius.circular(2)),
        paint);

    // --- Right person (man sitting) ---
    // Body - blue shirt
    paint.color = const Color(0xFF2D5FA6);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.62, h * 0.42, w * 0.20, h * 0.28),
            const Radius.circular(8)),
        paint);
    // Head
    paint.color = const Color(0xFFD4956A);
    canvas.drawCircle(Offset(w * 0.72, h * 0.30), w * 0.055, paint);
    // Hair
    paint.color = const Color(0xFF1A1A2E);
    canvas.drawArc(
        Rect.fromCircle(center: Offset(w * 0.72, h * 0.28), radius: w * 0.055),
        3.14,
        3.14,
        true,
        paint);

    // --- Right laptop ---
    paint.color = const Color(0xFF1A1A2E);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.58, h * 0.57, w * 0.20, h * 0.13),
            const Radius.circular(4)),
        paint);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.55, h * 0.69, w * 0.26, h * 0.03),
            const Radius.circular(2)),
        paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _IllustrationAlert extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/onboarding2.png',
      width: 300,
      height: 220,
      fit: BoxFit.contain,
    );
  }
}

class _AlertPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;

    // Background circle
    paint.color = const Color(0xFFF0F0F0);
    canvas.drawCircle(Offset(w * 0.5, h * 0.55), w * 0.35, paint);

    // Left phone
    paint.color = const Color(0xFF1A3A6B);
    final leftPhone = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.05, h * 0.18, w * 0.28, h * 0.58),
      const Radius.circular(14),
    );
    canvas.drawRRect(leftPhone, paint);
    // Left phone screen
    paint.color = const Color(0xFFCCDDFF);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.08, h * 0.22, w * 0.22, h * 0.48),
            const Radius.circular(8)),
        paint);
    // Left person in phone
    paint.color = const Color(0xFF2D5FA6);
    canvas.drawCircle(Offset(w * 0.19, h * 0.35), w * 0.055, paint);
    paint.color = const Color(0xFFD4956A);
    canvas.drawCircle(Offset(w * 0.19, h * 0.35), w * 0.04, paint);

    // Right phone
    paint.color = const Color(0xFF1A3A6B);
    final rightPhone = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.67, h * 0.18, w * 0.28, h * 0.58),
      const Radius.circular(14),
    );
    canvas.drawRRect(rightPhone, paint);
    // Right phone screen
    paint.color = const Color(0xFFCCDDFF);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.70, h * 0.22, w * 0.22, h * 0.48),
            const Radius.circular(8)),
        paint);
    // Right person in phone
    paint.color = const Color(0xFFD4956A);
    canvas.drawCircle(Offset(w * 0.81, h * 0.35), w * 0.04, paint);

    // Handshake in middle
    paint.color = const Color(0xFFD4956A);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 8;
    paint.strokeCap = StrokeCap.round;
    // Left arm
    canvas.drawLine(
        Offset(w * 0.30, h * 0.55), Offset(w * 0.50, h * 0.52), paint);
    // Right arm
    canvas.drawLine(
        Offset(w * 0.70, h * 0.55), Offset(w * 0.50, h * 0.52), paint);
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.50, h * 0.52), 10, paint);

    // Gear icons
    paint.color = const Color(0xFFCCCCCC);
    _drawGear(canvas, Offset(w * 0.08, h * 0.12), 12, paint);
    _drawGear(canvas, Offset(w * 0.92, h * 0.12), 12, paint);
    _drawGear(canvas, Offset(w * 0.12, h * 0.88), 8, paint);
    _drawGear(canvas, Offset(w * 0.88, h * 0.88), 8, paint);

    // Leaf decorations
    paint.color = const Color(0xFF4DA6FF).withOpacity(0.5);
    canvas.drawOval(Rect.fromLTWH(w * 0.02, h * 0.72, 20, 30), paint);
    canvas.drawOval(Rect.fromLTWH(w * 0.88, h * 0.72, 20, 30), paint);
  }

  void _drawGear(Canvas canvas, Offset center, double radius, Paint paint) {
    canvas.drawCircle(center, radius, paint);
    paint.color = Colors.white;
    canvas.drawCircle(center, radius * 0.5, paint);
    paint.color = const Color(0xFFCCCCCC);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _IllustrationSecure extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/onboarding3.png',
      width: 300,
      height: 220,
      fit: BoxFit.contain,
    );
  }
}

class _SecurePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;

    // Top-left browser window
    _drawBrowserWindow(canvas, Rect.fromLTWH(0, 0, w * 0.42, h * 0.45), paint,
        hasChart: true);
    // Top-right browser window
    _drawBrowserWindow(
        canvas, Rect.fromLTWH(w * 0.55, h * 0.02, w * 0.42, h * 0.42), paint,
        hasChat: true);
    // Bottom-left person with tablet
    _drawPersonTablet(canvas, Offset(w * 0.18, h * 0.65), paint);
    // Bottom-right person
    _drawPersonEnvelope(canvas, Offset(w * 0.72, h * 0.62), paint);

    // Globe in middle
    paint.color = const Color(0xFFE0E8F0);
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), 18, paint);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.5;
    paint.color = const Color(0xFFAAAAAA);
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), 18, paint);
    paint.style = PaintingStyle.fill;

    // Chat bubbles
    paint.color = const Color(0xFFE8E8E8);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.22, h * 0.48, 30, 18),
            const Radius.circular(8)),
        paint);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.60, h * 0.22, 30, 18),
            const Radius.circular(8)),
        paint);
    // Dots in bubbles
    paint.color = const Color(0xFFAAAAAA);
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(
          Offset(w * 0.22 + 6 + i * 8.0, h * 0.48 + 9), 2.5, paint);
      canvas.drawCircle(
          Offset(w * 0.60 + 6 + i * 8.0, h * 0.22 + 9), 2.5, paint);
    }
  }

  void _drawBrowserWindow(Canvas canvas, Rect rect, Paint paint,
      {bool hasChart = false, bool hasChat = false}) {
    paint.color = Colors.white;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.drawRRect(rrect, paint);
    paint.color = const Color(0xFFE0E0E0);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1;
    canvas.drawRRect(rrect, paint);
    paint.style = PaintingStyle.fill;
    // Title bar
    paint.color = const Color(0xFFF5F5F5);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(rect.left + 1, rect.top + 1, rect.width - 2, 14),
            const Radius.circular(8)),
        paint);
    // Dots
    for (int i = 0; i < 3; i++) {
      paint.color = i == 0
          ? Colors.red
          : i == 1
              ? Colors.orange
              : Colors.green;
      canvas.drawCircle(
          Offset(rect.left + 8 + i * 10.0, rect.top + 8), 3, paint);
    }
    if (hasChart) {
      // Simple chart bars
      paint.color = const Color(0xFF2D5FA6);
      for (int i = 0; i < 5; i++) {
        final barH = (i % 3 + 1) * 10.0;
        canvas.drawRect(
            Rect.fromLTWH(
                rect.left + 8 + i * 12.0, rect.bottom - 20 - barH, 8, barH),
            paint);
      }
    }
    if (hasChat) {
      // Person avatar
      paint.color = const Color(0xFFD4956A);
      canvas.drawCircle(
          Offset(rect.left + rect.width * 0.5, rect.top + 35), 14, paint);
    }
  }

  void _drawPersonTablet(Canvas canvas, Offset center, Paint paint) {
    // Person sitting with tablet
    paint.color = const Color(0xFF2D2D2D);
    canvas.drawCircle(Offset(center.dx, center.dy - 30), 16, paint);
    paint.color = const Color(0xFFD4956A);
    canvas.drawCircle(Offset(center.dx, center.dy - 30), 12, paint);
    // Body
    paint.color = const Color(0xFF555577);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(center.dx - 18, center.dy - 15, 36, 35),
            const Radius.circular(6)),
        paint);
    // Tablet
    paint.color = const Color(0xFF333333);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(center.dx - 14, center.dy + 5, 28, 20),
            const Radius.circular(3)),
        paint);
    paint.color = const Color(0xFF87CEEB);
    canvas.drawRect(
        Rect.fromLTWH(center.dx - 11, center.dy + 8, 22, 14), paint);
    // Envelope being passed
    paint.color = const Color(0xFF2D5FA6);
    canvas.drawRect(Rect.fromLTWH(center.dx + 20, center.dy, 25, 18), paint);
    paint.color = Colors.white;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.5;
    canvas.drawLine(Offset(center.dx + 20, center.dy),
        Offset(center.dx + 32, center.dy + 9), paint);
    canvas.drawLine(Offset(center.dx + 45, center.dy),
        Offset(center.dx + 32, center.dy + 9), paint);
    paint.style = PaintingStyle.fill;
  }

  void _drawPersonEnvelope(Canvas canvas, Offset center, Paint paint) {
    // Person receiving envelope
    paint.color = const Color(0xFFD4956A);
    canvas.drawCircle(Offset(center.dx, center.dy - 30), 12, paint);
    paint.color = const Color(0xFF2D7D9A);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(center.dx - 16, center.dy - 15, 32, 30),
            const Radius.circular(6)),
        paint);
    // Hand reaching out
    paint.color = const Color(0xFFD4956A);
    canvas.drawOval(Rect.fromLTWH(center.dx - 30, center.dy, 20, 14), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Role Selection ────────────────────────────────────────────────────────────
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});
  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String _selected = 'Freelancer';

  final _roles = [
    {
      'id': 'Freelancer',
      'icon': Icons.laptop_outlined,
      'title': 'Freelancer',
      'sub': '"Tell us more about your professional background."'
    },
    {
      'id': 'Student',
      'icon': Icons.school_outlined,
      'title': 'Student',
      'sub': '"Help us connect you with the right team."'
    },
    {
      'id': 'Admin',
      'icon': Icons.admin_panel_settings_outlined,
      'title': 'Admin',
      'sub':
          '"Configure your admin settings to get full control of your workspace"'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(children: [
            const SizedBox(height: 20),
            const _TeamifyLogo(size: 120),
            const SizedBox(height: 28),
            const Text('Choose Your Role:',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark)),
            const SizedBox(height: 8),
            const Text('This helps us personalize your experience',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 32),
            ...(_roles.map((r) {
              final sel = _selected == r['id'];
              return GestureDetector(
                onTap: () => setState(() => _selected = r['id'] as String),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: sel ? AppColors.primary : AppColors.border,
                        width: sel ? 2 : 1),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8)),
                      child: Icon(r['icon'] as IconData,
                          color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(r['title'] as String,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                  fontSize: 15)),
                          Text(r['sub'] as String,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                        ])),
                  ]),
                ),
              );
            })),
            const Spacer(),
            TButton(
              label: 'Continue',
              onTap: () {
                if (_selected == 'Admin') {
                  Navigator.pushNamed(context, R.login, arguments: 'Admin');
                } else if (_selected == 'Student')
                  Navigator.pushNamed(context, R.login, arguments: 'Student');
                else
                  Navigator.pushNamed(context, R.login,
                      arguments: 'Freelancer');
              },
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }
}

// ── Sign In ───────────────────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscure = true;
  bool _rememberMe = false;
  bool _loading = false;
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await context.read<SessionController>().login(
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
          );
      if (!mounted) return;
      _navigateFromSession(context);
    } catch (error) {
      if (mounted) _showAuthError(context, error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role =
        ModalRoute.of(context)?.settings.arguments as String? ?? 'Freelancer';
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 16),
            const Center(child: _TeamifyLogo(size: 120)),
            const SizedBox(height: 32),
            const Text('Email',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 15)),
            const SizedBox(height: 8),
            _field(
                hint: 'example562@gmail.com',
                prefix: Icons.email_outlined,
                controller: _emailCtrl),
            const SizedBox(height: 16),
            const Text('Password',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 15)),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              decoration: InputDecoration(
                hintText: '••••••••••••••••••••',
                hintStyle: const TextStyle(color: AppColors.textHint),
                suffixIcon: IconButton(
                    icon: Icon(
                        _obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.textSecondary),
                    onPressed: () => setState(() => _obscure = !_obscure)),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.primary)),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              GestureDetector(
                onTap: () => setState(() => _rememberMe = !_rememberMe),
                child: Row(children: [
                  Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(3)),
                      child: _rememberMe
                          ? const Icon(Icons.check,
                              size: 12, color: AppColors.primary)
                          : null),
                  const SizedBox(width: 8),
                  const Text('Remember me',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                ]),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, R.forgotPassword),
                child: const Text('Forget Password?',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 24),
            TButton(
              label: _loading ? 'Signing in...' : 'Sign in',
              onTap: _loading ? null : _submitLogin,
            ),
            const SizedBox(height: 24),
            const Row(children: [
              Expanded(child: Divider()),
              Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('Or',
                      style: TextStyle(color: AppColors.textSecondary))),
              Expanded(child: Divider()),
            ]),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _socialImageBtn('assets/images/google_logo.png'),
              const SizedBox(width: 16),
              _socialImageBtn('assets/images/github_logo.png'),
            ]),
            const SizedBox(height: 20),
            Center(
                child: GestureDetector(
              onTap: () {
                if (role == 'Admin') {
                  Navigator.pushNamed(context, R.signupAdmin);
                } else if (role == 'Student')
                  Navigator.pushNamed(context, R.signupStudent);
                else
                  Navigator.pushNamed(context, R.signupFreelancer);
              },
              child: RichText(
                  text: const TextSpan(
                text: "Don't have an account? ",
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                children: [
                  TextSpan(
                    text: 'Sign up',
                    style: TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ],
              )),
            )),
          ]),
        ),
      ),
    );
  }

  Widget _socialImageBtn(String assetPath) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
          shape: BoxShape.circle, border: Border.all(color: AppColors.border)),
      child: Center(
          child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Image.asset(assetPath, fit: BoxFit.contain),
      )),
    );
  }
}

Widget _field(
    {required String hint,
    IconData? prefix,
    bool obscure = false,
    TextEditingController? controller}) {
  return TextField(
    controller: controller,
    obscureText: obscure,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textHint),
      prefixIcon: prefix != null
          ? Icon(prefix, color: AppColors.textSecondary, size: 20)
          : null,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary)),
    ),
  );
}

// ── Admin Signup ──────────────────────────────────────────────────────────────
class AdminSignupScreen extends StatefulWidget {
  const AdminSignupScreen({super.key});
  @override
  State<AdminSignupScreen> createState() => _AdminSignupScreenState();
}

class _AdminSignupScreenState extends State<AdminSignupScreen> {
  bool _alerts = false;
  bool _twoFA = false;
  bool _loading = false;
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await context.read<SessionController>().register(
            displayName: _displayNameFrom(_nameCtrl.text, _emailCtrl.text),
            fullName: _nameCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
            role: 'member',
            userType: 'admin',
          );
      if (!mounted) return;
      _navigateFromSession(context, isNew: true);
    } catch (error) {
      if (mounted) _showAuthError(context, error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Center(child: _TeamifyLogo(size: 120)),
            const SizedBox(height: 16),
            const Center(
                child: Text('Set Up Your Admin Workspace',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark))),
            const Center(
                child: Text('Manage your team, security, and system settings',
                    style:
                        TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    textAlign: TextAlign.center)),
            const SizedBox(height: 28),
            const Text('Full Name',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 15)),
            const SizedBox(height: 8),
            _field(hint: 'example', controller: _nameCtrl),
            const SizedBox(height: 16),
            const Text('Email',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 15)),
            const SizedBox(height: 8),
            _field(
                hint: 'example562@gmail.com',
                prefix: Icons.email_outlined,
                controller: _emailCtrl),
            const SizedBox(height: 16),
            const Text('Password',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 15)),
            const SizedBox(height: 8),
            _field(
                hint: 'Password123',
                prefix: Icons.lock_outline,
                obscure: true,
                controller: _passwordCtrl),
            const SizedBox(height: 20),
            const Text('Security Settings',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 16)),
            const SizedBox(height: 12),
            _checkRow('Enable Security Alerts', _alerts,
                (v) => setState(() => _alerts = v)),
            const SizedBox(height: 8),
            _checkRow('Two-Factor Authentication (2FA)', _twoFA,
                (v) => setState(() => _twoFA = v)),
            const SizedBox(height: 40),
            TButton(
                label: _loading ? 'Creating...' : 'Continue',
                onTap: _loading ? null : _submit),
          ]),
        ),
      ),
    );
  }

  Widget _checkRow(String label, bool val, ValueChanged<bool> onChange) {
    return GestureDetector(
      onTap: () => onChange(!val),
      child: Row(children: [
        Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(3)),
            child: val
                ? const Icon(Icons.check, size: 12, color: AppColors.primary)
                : null),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
      ]),
    );
  }
}

// ── Freelancer Signup ─────────────────────────────────────────────────────────
class FreelancerSignupScreen extends StatefulWidget {
  const FreelancerSignupScreen({super.key});
  @override
  State<FreelancerSignupScreen> createState() => _FreelancerSignupScreenState();
}

class _FreelancerSignupScreenState extends State<FreelancerSignupScreen> {
  String _field2 = '';
  String _level = 'Beginner';
  String _avail = '';
  final List<String> _selectedSkills = ['UI Design', 'UX Design'];
  bool _loading = false;
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  final List<String> _levelOptions = [
    'Beginner',
    'Junior',
    'Mid-Level',
    'Senior',
    'Expert'
  ];
  final List<String> _skillsOptions = [
    'UI/UX Design',
    'Product Design',
    'Flutter',
    'Frontend Development',
    'Backend Development',
    'Figma',
    'Graphic Design',
    'Mobile App Development',
    'Project Management',
    'AI Tools'
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await context.read<SessionController>().register(
        displayName: _displayNameFrom(_nameCtrl.text, _emailCtrl.text),
        fullName: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        role: 'member',
        userType: 'freelancer',
        extra: {
          'professional_field': _field2,
          'experience_level': _level,
          'availability': _avail,
          'skills': _selectedSkills.join(','),
        },
      );
      if (!mounted) return;
      _navigateFromSession(context, isNew: true);
    } catch (error) {
      if (mounted) _showAuthError(context, error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSingleSelect(String title, List<String> options, String current,
      Function(String) onSelect) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 20),
            ...options.map((opt) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(opt,
                      style: TextStyle(
                        color: opt == current
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        fontWeight: opt == current
                            ? FontWeight.bold
                            : FontWeight.normal,
                      )),
                  trailing: opt == current
                      ? const Icon(Icons.check_circle, color: AppColors.primary)
                      : null,
                  onTap: () {
                    onSelect(opt);
                    Navigator.pop(context);
                  },
                )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showMultiSelect() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Primary Skills',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _skillsOptions.map((skill) {
                  final isSelected = _selectedSkills.contains(skill);
                  return FilterChip(
                    label: Text(skill),
                    selected: isSelected,
                    onSelected: (val) {
                      setModalState(() {
                        if (val) {
                          _selectedSkills.add(skill);
                        } else {
                          _selectedSkills.remove(skill);
                        }
                      });
                      setState(() {});
                    },
                    selectedColor: AppColors.primary.withOpacity(0.1),
                    checkmarkColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.border)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              TButton(label: 'Done', onTap: () => Navigator.pop(context)),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Full Name',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 15)),
            const SizedBox(height: 8),
            _field(hint: 'example', controller: _nameCtrl),
            const SizedBox(height: 16),
            const Text('Email',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 15)),
            const SizedBox(height: 8),
            _field(
                hint: 'example562@gmail.com',
                prefix: Icons.email_outlined,
                controller: _emailCtrl),
            const SizedBox(height: 16),
            const Text('Password',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 15)),
            const SizedBox(height: 8),
            _field(
                hint: 'Password123',
                prefix: Icons.lock_outline,
                obscure: true,
                controller: _passwordCtrl),
            const SizedBox(height: 16),
            const Text('Professional Field',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 15)),
            const SizedBox(height: 8),
            ...[
              'Designer',
              'Developer',
              'Marketer',
              'Project Manager',
              'Content Creator',
              'Other'
            ].map((f) =>
                _radioRow(f, _field2, (v) => setState(() => _field2 = v))),
            const SizedBox(height: 16),
            const Text('Experience Level',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 15)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _showSingleSelect('Experience Level', _levelOptions,
                  _level, (v) => setState(() => _level = v)),
              child: _selectionField(_level),
            ),
            const SizedBox(height: 16),
            const Text('Availability',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 15)),
            const SizedBox(height: 8),
            ...['Full Time', 'Part Time', 'Freelancer'].map(
                (a) => _radioRow(a, _avail, (v) => setState(() => _avail = v))),
            const SizedBox(height: 16),
            const Text('Primary Skills',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 15)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _showMultiSelect,
              child: _selectionFieldMulti(_selectedSkills),
            ),
            const SizedBox(height: 24),
            TButton(
                label: _loading ? 'Creating...' : 'Continue',
                onTap: _loading ? null : _submit),
          ]),
        ),
      ),
    );
  }

  Widget _selectionField(String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(value,
              style:
                  const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
          const Icon(Icons.keyboard_arrow_down,
              color: AppColors.textSecondary, size: 20),
        ],
      ),
    );
  }

  Widget _selectionFieldMulti(List<String> values) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: values.isEmpty
                ? const Text('Select skills',
                    style: TextStyle(color: AppColors.textHint, fontSize: 14))
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: values
                        .map((v) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: AppColors.primary.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(v,
                                      style: const TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () =>
                                        setState(() => values.remove(v)),
                                    child: const Icon(Icons.close,
                                        size: 14, color: AppColors.primary),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
          ),
          const Icon(Icons.keyboard_arrow_down,
              color: AppColors.textSecondary, size: 20),
        ],
      ),
    );
  }

  Widget _radioRow(
      String label, String selected, ValueChanged<String> onSelect) {
    return GestureDetector(
      onTap: () => onSelect(label),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2)),
              child: selected == label
                  ? Center(
                      child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle)))
                  : null),
          const SizedBox(width: 10),
          Text(label,
              style:
                  const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
        ]),
      ),
    );
  }
}

// ── Student Signup ────────────────────────────────────────────────────────────
class StudentSignupScreen extends StatefulWidget {
  const StudentSignupScreen({super.key});
  @override
  State<StudentSignupScreen> createState() => _StudentSignupScreenState();
}

class _StudentSignupScreenState extends State<StudentSignupScreen> {
  String _team = '';
  String _selectedLevel = 'Beginner';
  String _selectedMajor = 'Computer Science';
  final List<String> _selectedSkills = ['Flutter', 'UI/UX Design'];
  bool _loading = false;
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  final List<String> _levelOptions = [
    'Beginner',
    'Junior',
    'Mid-Level',
    'Senior',
    'Expert'
  ];
  final List<String> _majorOptions = [
    'Computer Science',
    'Information Systems',
    'Software Engineering',
    'Artificial Intelligence',
    'Data Science',
    'Business Administration',
    'Graphic Design',
    'Multimedia',
    'Marketing',
    'Other'
  ];
  final List<String> _skillsOptions = [
    'UI/UX Design',
    'Product Design',
    'Flutter',
    'Frontend Development',
    'Backend Development',
    'Figma',
    'Graphic Design',
    'Mobile App Development',
    'Project Management',
    'AI Tools'
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await context.read<SessionController>().register(
        displayName: _displayNameFrom(_nameCtrl.text, _emailCtrl.text),
        fullName: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        role: 'member',
        userType: 'student',
        extra: {
          'current_level': _selectedLevel,
          'major': _selectedMajor,
          'skills': _selectedSkills.join(','),
          'looking_for_team': _team.toLowerCase() == 'yes',
        },
      );
      if (!mounted) return;
      _navigateFromSession(context, isNew: true);
    } catch (error) {
      if (mounted) _showAuthError(context, error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSingleSelect(String title, List<String> options, String current,
      Function(String) onSelect) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 20),
            ...options.map((opt) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(opt,
                      style: TextStyle(
                        color: opt == current
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        fontWeight: opt == current
                            ? FontWeight.bold
                            : FontWeight.normal,
                      )),
                  trailing: opt == current
                      ? const Icon(Icons.check_circle, color: AppColors.primary)
                      : null,
                  onTap: () {
                    onSelect(opt);
                    Navigator.pop(context);
                  },
                )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showMultiSelect() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Primary Skills',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _skillsOptions.map((skill) {
                  final isSelected = _selectedSkills.contains(skill);
                  return FilterChip(
                    label: Text(skill),
                    selected: isSelected,
                    onSelected: (val) {
                      setModalState(() {
                        if (val) {
                          _selectedSkills.add(skill);
                        } else {
                          _selectedSkills.remove(skill);
                        }
                      });
                      setState(() {});
                    },
                    selectedColor: AppColors.primary.withOpacity(0.1),
                    checkmarkColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.border)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              TButton(label: 'Done', onTap: () => Navigator.pop(context)),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Full Name',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 15)),
            const SizedBox(height: 8),
            _field(hint: 'example', controller: _nameCtrl),
            const SizedBox(height: 16),
            const Text('Email',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 15)),
            const SizedBox(height: 8),
            _field(
                hint: 'example562@gmail.com',
                prefix: Icons.email_outlined,
                controller: _emailCtrl),
            const SizedBox(height: 16),
            const Text('Password',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 15)),
            const SizedBox(height: 8),
            _field(
                hint: 'Password123',
                prefix: Icons.lock_outline,
                obscure: true,
                controller: _passwordCtrl),
            const SizedBox(height: 16),
            const Text('Current Level',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 15)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _showSingleSelect('Current Level', _levelOptions,
                  _selectedLevel, (v) => setState(() => _selectedLevel = v)),
              child: _selectionField(_selectedLevel),
            ),
            const SizedBox(height: 16),
            const Text('Major',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 15)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _showSingleSelect('Major', _majorOptions,
                  _selectedMajor, (v) => setState(() => _selectedMajor = v)),
              child: _selectionField(_selectedMajor),
            ),
            const SizedBox(height: 16),
            const Text('Primary Skills',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 15)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _showMultiSelect,
              child: _selectionFieldMulti(_selectedSkills),
            ),
            const SizedBox(height: 16),
            const Text('Looking for a team?',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 15)),
            const SizedBox(height: 8),
            _radioRowSimple('Yes', _team, (v) => setState(() => _team = v)),
            _radioRowSimple('NO', _team, (v) => setState(() => _team = v)),
            const SizedBox(height: 24),
            TButton(
                label: _loading ? 'Creating...' : 'Continue',
                onTap: _loading ? null : _submit),
          ]),
        ),
      ),
    );
  }

  Widget _selectionField(String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(value,
              style:
                  const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
          const Icon(Icons.keyboard_arrow_down,
              color: AppColors.textSecondary, size: 20),
        ],
      ),
    );
  }

  Widget _selectionFieldMulti(List<String> values) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: values.isEmpty
                ? const Text('Select skills',
                    style: TextStyle(color: AppColors.textHint, fontSize: 14))
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: values
                        .map((v) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: AppColors.primary.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(v,
                                      style: const TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () =>
                                        setState(() => values.remove(v)),
                                    child: const Icon(Icons.close,
                                        size: 14, color: AppColors.primary),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
          ),
          const Icon(Icons.keyboard_arrow_down,
              color: AppColors.textSecondary, size: 20),
        ],
      ),
    );
  }

  Widget _radioRowSimple(
      String label, String selected, ValueChanged<String> onSelect) {
    return GestureDetector(
      onTap: () => onSelect(label),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2)),
              child: selected == label
                  ? Center(
                      child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle)))
                  : null),
          const SizedBox(width: 10),
          Text(label,
              style:
                  const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
        ]),
      ),
    );
  }
}

// ── Verify Email ──────────────────────────────────────────────────────────────
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});
  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  int _countdown = 0;

  void _resendCode() {
    if (_countdown > 0) return;
    setState(() => _countdown = 60);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Code resent! Check your email.'),
      backgroundColor: AppColors.primary,
    ));
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _countdown--);
      return _countdown > 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const Spacer(),
            Image.asset(
              'assets/images/verify_email.png',
              width: 240,
              height: 180,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 28),
            const Text('Verify your email',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text('A 6-digit code was sent to example*****@gmail.com',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 32),
            Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  6,
                  (index) => Container(
                    width: 44,
                    height: 52,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(10)),
                    child: TextField(
                      autofocus: index == 0,
                      onChanged: (v) {
                        if (v.length == 1 && index < 5) {
                          FocusScope.of(context).nextFocus();
                        }
                      },
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                          border: InputBorder.none, counterText: ''),
                    ),
                  ),
                )),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _countdown == 0 ? _resendCode : null,
              child: RichText(
                  text: TextSpan(
                text: "Didn't receive the code? ",
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 14),
                children: [
                  TextSpan(
                    text:
                        _countdown > 0 ? 'Resend in ${_countdown}s' : 'Resend',
                    style: TextStyle(
                      color: _countdown > 0
                          ? AppColors.textHint
                          : AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                ],
              )),
            ),
            const Spacer(),
            TButton(
                label: 'Verify',
                onTap: () {
                  final role =
                      ModalRoute.of(context)?.settings.arguments as String? ??
                          'Freelancer';
                  Navigator.pushNamed(context, R.otpVerification,
                      arguments: {'role': role, 'flow': 'signup'});
                }),
          ]),
        ),
      ),
    );
  }
}

// ── Forgot Password ───────────────────────────────────────────────────────────
class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios,
                size: 18, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context)),
        title: const Text('Forgot Password',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        actions: [
          Row(children: [
            Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                    color: AppColors.border, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                    color: AppColors.border, shape: BoxShape.circle)),
            const SizedBox(width: 16),
          ])
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
              child: Image.asset('assets/images/forgot_password.png',
                  height: 180, fit: BoxFit.contain)),
          const Center(
              child: Text('Forgot Password?',
                  style:
                      TextStyle(fontSize: 16, color: AppColors.textSecondary))),
          const SizedBox(height: 32),
          const Text('Your Email',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  fontSize: 15)),
          const SizedBox(height: 8),
          _field(hint: 'example562@gmail.com', prefix: Icons.email_outlined),
          const Spacer(),
          TButton(
              label: 'Got OTP',
              onTap: () => Navigator.pushNamed(context, R.otpVerification,
                  arguments: {'flow': 'forgotPassword'})),
        ]),
      ),
    );
  }
}

// ── OTP Verification ──────────────────────────────────────────────────────────
class OTPVerificationScreen extends StatefulWidget {
  const OTPVerificationScreen({super.key});
  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  int _countdown = 0;

  void _resendCode() {
    if (_countdown > 0) return;
    setState(() => _countdown = 60);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('OTP resent successfully!'),
      backgroundColor: AppColors.primary,
    ));
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _countdown--);
      return _countdown > 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios,
                size: 18, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context)),
        title: const Text('OTP Verification',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        actions: [
          Row(children: [
            Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                    color: AppColors.border, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                    color: AppColors.border, shape: BoxShape.circle)),
            const SizedBox(width: 16),
          ])
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Image.asset('assets/images/otp_verification.png',
              height: 180, fit: BoxFit.contain),
          const SizedBox(height: 16),
          const Text('Enter OTP',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                4,
                (index) => Container(
                  width: 56,
                  height: 60,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(10)),
                  child: TextField(
                    autofocus: index == 0,
                    onChanged: (v) {
                      if (v.length == 1 && index < 3) {
                        FocusScope.of(context).nextFocus();
                      }
                    },
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                        border: InputBorder.none, counterText: ''),
                  ),
                ),
              )),
          const SizedBox(height: 16),
          const Text(
              'Please enter the 4-digit code sent to:\nexample***@gmail.com',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _countdown == 0 ? _resendCode : null,
            child: RichText(
                text: TextSpan(
              text: "Didn't receive the code? ",
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 14),
              children: [
                TextSpan(
                  text: _countdown > 0 ? 'Resend in ${_countdown}s' : 'Resend',
                  style: TextStyle(
                    color:
                        _countdown > 0 ? AppColors.textHint : AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                )
              ],
            )),
          ),
          const Spacer(),
          TButton(
              label: 'Verify',
              onTap: () {
                final args = ModalRoute.of(context)?.settings.arguments
                    as Map<String, dynamic>?;
                final flow = args?['flow'] ?? 'signup';
                final role = args?['role'] ?? 'Freelancer';

                if (flow == 'forgotPassword') {
                  Navigator.pushNamed(context, R.createNewPassword,
                      arguments: role);
                } else {
                  if (role == 'Admin') {
                    Navigator.pushNamed(context, R.confirmationAdmin);
                  } else if (role == 'Student')
                    Navigator.pushNamed(context, R.confirmationStudent);
                  else
                    Navigator.pushNamed(context, R.confirmationFreelancer);
                }
              }),
        ]),
      ),
    );
  }
}

// ── Create New Password ───────────────────────────────────────────────────────
class CreateNewPasswordScreen extends StatefulWidget {
  const CreateNewPasswordScreen({super.key});
  @override
  State<CreateNewPasswordScreen> createState() =>
      _CreateNewPasswordScreenState();
}

class _CreateNewPasswordScreenState extends State<CreateNewPasswordScreen> {
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios,
                size: 18, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context)),
        title: const Text('Create New Password',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        actions: [
          Row(children: [
            Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                    color: AppColors.border, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                    color: AppColors.border, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle)),
            const SizedBox(width: 16),
          ])
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
              child: Image.asset('assets/images/create_new_password.png',
                  height: 180, fit: BoxFit.contain)),
          const SizedBox(height: 24),
          const Text('New Password',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  fontSize: 15)),
          const SizedBox(height: 8),
          TextField(
            obscureText: _obscureNew,
            decoration: InputDecoration(
              hintText: '••••••••••••••••••••',
              hintStyle: const TextStyle(color: AppColors.textHint),
              suffixIcon: IconButton(
                icon: Icon(
                    _obscureNew
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.textSecondary,
                    size: 20),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Confirm Password',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  fontSize: 15)),
          const SizedBox(height: 8),
          TextField(
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              hintText: '••••••••••••••••••••',
              hintStyle: const TextStyle(color: AppColors.textHint),
              suffixIcon: IconButton(
                icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.textSecondary,
                    size: 20),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary)),
            ),
          ),
          const Spacer(),
          TButton(
            label: 'Reset Password',
            onTap: () {
              Navigator.pushNamedAndRemoveUntil(context, R.login, (_) => false);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Password reset successfully! Please sign in.'),
                backgroundColor: AppColors.primary,
              ));
            },
          ),
        ]),
      ),
    );
  }
}

// ── Confirmation Admin ────────────────────────────────────────────────────────
class ConfirmationAdminScreen extends StatelessWidget {
  const ConfirmationAdminScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return _ConfirmationScreen(
      emoji: '💻🖥️',
      text: '"You now have full admin access."',
      onTap: () => _navigateToCorrectHome(context, 'Admin', isNew: true),
    );
  }
}

// ── Confirmation Freelancer ───────────────────────────────────────────────────
class ConfirmationFreelancerScreen extends StatelessWidget {
  const ConfirmationFreelancerScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return _ConfirmationScreen(
      emoji: '✅📄',
      text: '" Teams can now find you based\non yourself "',
      onTap: () => _navigateToCorrectHome(context, 'Freelancer', isNew: true),
    );
  }
}

// ── Confirmation Student ──────────────────────────────────────────────────────
class ConfirmationStudentScreen extends StatelessWidget {
  const ConfirmationStudentScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return _ConfirmationScreen(
      emoji: '👫✅',
      text: '" we will help you to find the the\nright project team"',
      onTap: () => _navigateToCorrectHome(context, 'Student', isNew: true),
    );
  }
}

class _ConfirmationScreen extends StatelessWidget {
  final String emoji, text;
  final VoidCallback onTap;
  const _ConfirmationScreen(
      {required this.emoji, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const Spacer(),
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                  color: const Color(0xFFF5F5FA),
                  borderRadius: BorderRadius.circular(20)),
              child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 70))),
            ),
            const SizedBox(height: 32),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18,
                    color: AppColors.primaryDark,
                    height: 1.5,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500)),
            const Spacer(),
            TButton(label: 'Go to Home', onTap: onTap),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }
}
