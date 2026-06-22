import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;
  const SplashScreen({super.key, required this.nextScreen});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _blobCtrl;
  late AnimationController _logoCtrl;
  late AnimationController _textCtrl;
  late AnimationController _exitCtrl;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _iconSpin;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _taglineOpacity;
  late Animation<double> _exitOpacity;

  @override
  void initState() {
    super.initState();

    // Force light status bar with dark icons (since background is light cream)
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );

    // Blobs entrance animation
    _blobCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Logo entrance animation (elastic)
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _logoScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoCtrl,
        curve: const Interval(0.0, 1.0, curve: Curves.elasticOut),
      ),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoCtrl,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );
    _iconSpin = Tween<double>(begin: -0.15, end: 0.0).animate(
      CurvedAnimation(
        parent: _logoCtrl,
        curve: const Interval(0.0, 1.0, curve: Curves.elasticOut),
      ),
    );

    // Text entrance (delayed after logo)
    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textCtrl,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    // Exit animation (fading out content, background stays solid cream)
    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitCtrl, curve: Curves.easeInOut),
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    // Start blobs sliding in immediately
    _blobCtrl.forward();
    
    await Future.delayed(const Duration(milliseconds: 300));
    _logoCtrl.forward();
    
    await Future.delayed(const Duration(milliseconds: 600));
    _textCtrl.forward();
    
    // Minimum splash duration (1.8 seconds)
    await Future.delayed(const Duration(milliseconds: 1800));

    // Ensure provider data is fully loaded
    if (mounted) {
      final provider = Provider.of<FinanceProvider>(context, listen: false);
      while (provider.isLoading) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }

    // Fade out elements (keeping background solid)
    await _exitCtrl.forward();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (ctx, anim, anim2) => widget.nextScreen,
          transitionsBuilder: (ctx, anim, anim2, child) {
            return FadeTransition(
              opacity: anim,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 450),
        ),
      );
    }
  }

  @override
  void dispose() {
    _blobCtrl.dispose();
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.warmCream, // Light cream background
      body: FadeTransition(
        opacity: _exitOpacity,
        child: Stack(
          children: [
            // Top-Left Blob (Plum) — slides in from top-left
            AnimatedBuilder(
              animation: _blobCtrl,
              builder: (ctx, child) {
                final val = CurvedAnimation(
                  parent: _blobCtrl,
                  curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
                ).value;
                return Opacity(
                  opacity: val.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(-90 * (1 - val), -90 * (1 - val)),
                    child: child,
                  ),
                );
              },
              child: SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: CustomPaint(
                  painter: _TopLeftBlobPainter(),
                ),
              ),
            ),

            // Top-Right Blob (Terracotta) — slides in from top-right, slightly delayed
            AnimatedBuilder(
              animation: _blobCtrl,
              builder: (ctx, child) {
                final val = CurvedAnimation(
                  parent: _blobCtrl,
                  curve: const Interval(0.08, 0.62, curve: Curves.easeOutCubic),
                ).value;
                return Opacity(
                  opacity: val.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(90 * (1 - val), -90 * (1 - val)),
                    child: child,
                  ),
                );
              },
              child: SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: CustomPaint(
                  painter: _TopRightBlobPainter(),
                ),
              ),
            ),

            // Bottom-Left Blob (Terracotta) — slides in from bottom-left, more delayed
            AnimatedBuilder(
              animation: _blobCtrl,
              builder: (ctx, child) {
                final val = CurvedAnimation(
                  parent: _blobCtrl,
                  curve: const Interval(0.14, 0.68, curve: Curves.easeOutCubic),
                ).value;
                return Opacity(
                  opacity: val.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(-90 * (1 - val), 90 * (1 - val)),
                    child: child,
                  ),
                );
              },
              child: SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: CustomPaint(
                  painter: _BottomLeftBlobPainter(),
                ),
              ),
            ),

            // Bottom-Right Blob (Plum) — slides in from bottom-right, most delayed
            AnimatedBuilder(
              animation: _blobCtrl,
              builder: (ctx, child) {
                final val = CurvedAnimation(
                  parent: _blobCtrl,
                  curve: const Interval(0.20, 0.74, curve: Curves.easeOutCubic),
                ).value;
                return Opacity(
                  opacity: val.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(90 * (1 - val), 90 * (1 - val)),
                    child: child,
                  ),
                );
              },
              child: SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: CustomPaint(
                  painter: _BottomRightBlobPainter(),
                ),
              ),
            ),

            // Middle-Right Concentric Curves — fade in slowly after blobs
            AnimatedBuilder(
              animation: _blobCtrl,
              builder: (ctx, child) {
                final val = CurvedAnimation(
                  parent: _blobCtrl,
                  curve: const Interval(0.30, 0.85, curve: Curves.easeOutCubic),
                ).value;
                return Opacity(
                  opacity: val.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(28 * (1 - val), 0),
                    child: child,
                  ),
                );
              },
              child: SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: CustomPaint(
                  painter: _RightCurvesPainter(),
                ),
              ),
            ),

            // Main Content Centered
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo mark
                  AnimatedBuilder(
                    animation: _logoCtrl,
                    builder: (ctx, child) => Opacity(
                      opacity: _logoOpacity.value,
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: Transform.rotate(
                          angle: _iconSpin.value * math.pi * 2,
                          child: _LogoMark(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // App name + tagline
                  AnimatedBuilder(
                    animation: _textCtrl,
                    builder: (ctx, child) => FadeTransition(
                      opacity: _textOpacity,
                      child: SlideTransition(
                        position: _textSlide,
                        child: Column(
                          children: [
                            RichText(
                              text: const TextSpan(
                                style: TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'Poppins',
                                  letterSpacing: 0.5,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Takara',
                                    style: TextStyle(color: AppTheme.darkPlum),
                                  ),
                                  TextSpan(
                                    text: 'Noto',
                                    style: TextStyle(color: Color(0xFFD4A820)), // Gold coin color
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom version label
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _textCtrl,
                builder: (ctx, child) => FadeTransition(
                  opacity: _taglineOpacity,
                  child: Text(
                    'v1.0',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.mutedLightPlum.withValues(alpha: 0.4),
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Logo Mark Widget ──────────────────────────────────────────────────────────
class _LogoMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      height: 108,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFD4A820),
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4A820).withValues(alpha: 0.35),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(54),
        child: Image.asset(
          'assets/images/logo.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

// ─── Custom Painters for Organic Blobs and Line Art ─────────────────────────

class _TopLeftBlobPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.darkPlum
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(0, size.height * 0.28)
      ..quadraticBezierTo(
        size.width * 0.15, size.height * 0.24,
        size.width * 0.22, size.height * 0.14,
      )
      ..quadraticBezierTo(
        size.width * 0.28, size.height * 0.05,
        size.width * 0.35, 0,
      )
      ..close();

    canvas.drawPath(path, paint);

    // Draw dots pattern
    final dotPaint = Paint()
      ..color = AppTheme.warmCream.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    final dots = [
      Offset(size.width * 0.05, size.height * 0.08),
      Offset(size.width * 0.08, size.height * 0.05),
      Offset(size.width * 0.05, size.height * 0.14),
      Offset(size.width * 0.08, size.height * 0.11),
      Offset(size.width * 0.11, size.height * 0.08),
      Offset(size.width * 0.08, size.height * 0.17),
      Offset(size.width * 0.11, size.height * 0.14),
      Offset(size.width * 0.14, size.height * 0.11),
    ];
    for (final dot in dots) {
      canvas.drawCircle(dot, 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TopRightBlobPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD36F4C) // Terracotta Orange
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width * 0.58, 0)
      ..quadraticBezierTo(
        size.width * 0.65, size.height * 0.12,
        size.width * 0.78, size.height * 0.18,
      )
      ..quadraticBezierTo(
        size.width * 0.88, size.height * 0.22,
        size.width, size.height * 0.32,
      )
      ..close();

    canvas.drawPath(path, paint);

    // Draw leaf shape outline
    final leafPaint = Paint()
      ..color = AppTheme.warmCream.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final leafPath = Path()
      ..moveTo(size.width * 0.82, size.height * 0.06)
      ..quadraticBezierTo(
        size.width * 0.74, size.height * 0.10,
        size.width * 0.78, size.height * 0.18,
      )
      ..quadraticBezierTo(
        size.width * 0.88, size.height * 0.14,
        size.width * 0.82, size.height * 0.06,
      );
    canvas.drawPath(leafPath, leafPaint);

    canvas.drawLine(
      Offset(size.width * 0.82, size.height * 0.06),
      Offset(size.width * 0.78, size.height * 0.18),
      leafPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BottomLeftBlobPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD36F4C) // Terracotta Orange
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.12, size.height * 0.78,
        size.width * 0.18, size.height * 0.88,
      )
      ..quadraticBezierTo(
        size.width * 0.22, size.height * 0.94,
        size.width * 0.32, size.height,
      )
      ..close();

    canvas.drawPath(path, paint);

    // Draw leaf shape outline
    final leafPaint = Paint()
      ..color = AppTheme.warmCream.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final leafPath = Path()
      ..moveTo(size.width * 0.06, size.height * 0.92)
      ..quadraticBezierTo(
        size.width * 0.14, size.height * 0.88,
        size.width * 0.10, size.height * 0.80,
      )
      ..quadraticBezierTo(
        size.width * 0.02, size.height * 0.84,
        size.width * 0.06, size.height * 0.92,
      );
    canvas.drawPath(leafPath, leafPaint);

    canvas.drawLine(
      Offset(size.width * 0.06, size.height * 0.92),
      Offset(size.width * 0.10, size.height * 0.80),
      leafPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BottomRightBlobPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.darkPlum
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width, size.height)
      ..lineTo(size.width * 0.58, size.height)
      ..quadraticBezierTo(
        size.width * 0.66, size.height * 0.88,
        size.width * 0.78, size.height * 0.82,
      )
      ..quadraticBezierTo(
        size.width * 0.88, size.height * 0.76,
        size.width, size.height * 0.68,
      )
      ..close();

    canvas.drawPath(path, paint);

    // Draw dots pattern
    final dotPaint = Paint()
      ..color = AppTheme.warmCream.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    final dots = [
      Offset(size.width * 0.92, size.height * 0.92),
      Offset(size.width * 0.88, size.height * 0.95),
      Offset(size.width * 0.92, size.height * 0.85),
      Offset(size.width * 0.88, size.height * 0.88),
      Offset(size.width * 0.84, size.height * 0.91),
      Offset(size.width * 0.88, size.height * 0.80),
      Offset(size.width * 0.84, size.height * 0.83),
      Offset(size.width * 0.80, size.height * 0.86),
    ];
    for (final dot in dots) {
      canvas.drawCircle(dot, 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RightCurvesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.mutedLightPlum.withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final center = Offset(size.width * 1.1, size.height * 0.5);
    canvas.drawCircle(center, size.width * 0.25, paint);
    canvas.drawCircle(center, size.width * 0.32, paint);
    canvas.drawCircle(center, size.width * 0.39, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
