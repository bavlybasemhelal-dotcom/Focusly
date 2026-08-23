import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/localization/app_localizations.dart';
import '../core/theme/app_colors.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

/// Model defining floating and rising productivity symbols across the screen.
class RisingSymbolConfig {
  final IconData icon;
  final double xRatio;
  final double ySeed;
  final double size;
  final Color darkColor;
  final Color lightColor;
  final double baseOpacity;
  final double floatSpeed;
  final double horizontalWobble;
  final double rotationMultiplier;
  final bool hasGlassFrame;

  const RisingSymbolConfig({
    required this.icon,
    required this.xRatio,
    required this.ySeed,
    required this.size,
    required this.darkColor,
    required this.lightColor,
    this.baseOpacity = 0.35,
    this.floatSpeed = 1.0,
    this.horizontalWobble = 14.0,
    this.rotationMultiplier = 1.0,
    this.hasGlassFrame = true,
  });
}

class SplashScreen extends StatefulWidget {
  final bool isFirstLaunch;

  const SplashScreen({
    super.key,
    this.isFirstLaunch = true,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _logoScaleAnimation;
  late final Animation<double> _logoFadeAnimation;
  late final AnimationController _risingSymbolsController;
  late final AnimationController _ringsPulseController;
  late final AnimationController _splashProgressController;

  static const List<RisingSymbolConfig> _symbols = [
    RisingSymbolConfig(
      icon: Icons.check_circle_rounded,
      xRatio: 0.08,
      ySeed: 0.15,
      size: 20,
      darkColor: AppColors.accentGreenNeon,
      lightColor: Color(0xFF10B981),
      baseOpacity: 0.55,
      floatSpeed: 0.8,
      horizontalWobble: 16,
      hasGlassFrame: true,
    ),
    RisingSymbolConfig(
      icon: Icons.checklist_rounded,
      xRatio: 0.16,
      ySeed: 0.45,
      size: 22,
      darkColor: AppColors.cyanElectric,
      lightColor: Color(0xFF2563EB),
      baseOpacity: 0.50,
      floatSpeed: 1.1,
      horizontalWobble: 20,
      hasGlassFrame: true,
    ),
    RisingSymbolConfig(
      icon: Icons.bolt_rounded,
      xRatio: 0.12,
      ySeed: 0.75,
      size: 18,
      darkColor: AppColors.amberGold,
      lightColor: Color(0xFFF59E0B),
      baseOpacity: 0.45,
      floatSpeed: 0.9,
      horizontalWobble: 12,
      hasGlassFrame: false,
    ),
    RisingSymbolConfig(
      icon: Icons.local_fire_department_rounded,
      xRatio: 0.25,
      ySeed: 0.30,
      size: 20,
      darkColor: AppColors.amberGold,
      lightColor: Color(0xFFF59E0B),
      baseOpacity: 0.45,
      floatSpeed: 1.0,
      horizontalWobble: 14,
      hasGlassFrame: true,
    ),
    RisingSymbolConfig(
      icon: Icons.task_alt_rounded,
      xRatio: 0.85,
      ySeed: 0.20,
      size: 22,
      darkColor: AppColors.accentGreenNeon,
      lightColor: Color(0xFF10B981),
      baseOpacity: 0.55,
      floatSpeed: 0.9,
      horizontalWobble: 18,
      hasGlassFrame: true,
    ),
    RisingSymbolConfig(
      icon: Icons.flag_rounded,
      xRatio: 0.78,
      ySeed: 0.55,
      size: 20,
      darkColor: AppColors.cyanElectric,
      lightColor: Color(0xFF0EA5E9),
      baseOpacity: 0.50,
      floatSpeed: 1.2,
      horizontalWobble: 15,
      hasGlassFrame: true,
    ),
    RisingSymbolConfig(
      icon: Icons.star_rounded,
      xRatio: 0.88,
      ySeed: 0.80,
      size: 19,
      darkColor: AppColors.amberGold,
      lightColor: Color(0xFFF59E0B),
      baseOpacity: 0.45,
      floatSpeed: 0.8,
      horizontalWobble: 12,
      hasGlassFrame: false,
    ),
  ];

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _logoScaleAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.elasticOut,
    );

    _logoFadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeIn,
    );

    _risingSymbolsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _ringsPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    _splashProgressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    );

    _entranceController.forward();
    _splashProgressController.forward().then((_) => _onSplashCompleted());
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _risingSymbolsController.dispose();
    _ringsPulseController.dispose();
    _splashProgressController.dispose();
    super.dispose();
  }

  void _onSplashCompleted() {
    if (!mounted) return;

    User? currentUser;
    try {
      currentUser = FirebaseAuth.instance.currentUser;
    } catch (_) {}

    final Widget targetScreen = (currentUser != null)
        ? const HomeScreen()
        : (widget.isFirstLaunch
            ? const OnboardingScreen()
            : const HomeScreen());

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  String _getStatusText(double progress) {
    if (progress < 0.28) {
      return context.tr('splash_init_engine');
    } else if (progress < 0.60) {
      return context.tr('splash_sync_habits');
    } else if (progress < 0.88) {
      return context.tr('splash_opt_workspace');
    } else {
      return context.tr('splash_ready');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final brandPrimary = AppColors.brandPrimary(context);
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Ambient Glow Blooms
          _buildAmbientGlowBlooms(isDark),

          // 2. Rising Productivity Symbols
          AnimatedBuilder(
            animation: _risingSymbolsController,
            builder: (context, child) {
              return CustomPaint(
                size: MediaQuery.of(context).size,
                painter: _RisingSymbolsPainter(
                  progress: _risingSymbolsController.value,
                  symbols: _symbols,
                  isDark: isDark,
                ),
              );
            },
          ),

          // 3. Central Target Rings & Logo
          Center(
            child: AnimatedBuilder(
              animation: _ringsPulseController,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Concentric Target Rings
                    _buildPulsingTargetRings(
                      _ringsPulseController.value,
                      isDark,
                      brandPrimary,
                    ),

                    // Centered 3D Focusly Logo
                    ScaleTransition(
                      scale: _logoScaleAnimation,
                      child: FadeTransition(
                        opacity: _logoFadeAnimation,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: isDark
                                    ? brandPrimary.withValues(alpha: 0.45)
                                    : const Color(0xFF2563EB).withValues(alpha: 0.25),
                                blurRadius: 40,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark
                                      ? const Color(0xFF0F1B4C)
                                      : Colors.white,
                                  border: Border.all(
                                    color: brandPrimary,
                                    width: 3,
                                  ),
                                ),
                                child: Icon(
                                  Icons.track_changes_rounded,
                                  color: brandPrimary,
                                  size: 72,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // 4. Bottom 5-Second Progress Bar
          Positioned(
            bottom: 48,
            left: 36,
            right: 36,
            child: AnimatedBuilder(
              animation: _splashProgressController,
              builder: (context, child) {
                final progress = _splashProgressController.value;
                final percentage = (progress * 100).toInt();

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dynamic Status Text
                    Text(
                      _getStatusText(progress),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? secondaryTextColor : const Color(0xFF1E3A8A),
                        letterSpacing: 0.1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),

                    // Progress Track & Bar
                    Container(
                      height: 8,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F1B4C)
                            : const Color(0xFFE2E8F5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Stack(
                        children: [
                          FractionallySizedBox(
                            alignment: AlignmentDirectional.centerStart,
                            widthFactor: progress.clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isDark
                                      ? [
                                          AppColors.primaryBlue,
                                          AppColors.cyanElectric,
                                        ]
                                      : [
                                          const Color(0xFF3B82F6),
                                          const Color(0xFF1D4ED8),
                                        ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: brandPrimary.withValues(
                                      alpha: isDark ? 0.5 : 0.35,
                                    ),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Progress Counter
                    Text(
                      '$percentage%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: primaryTextColor,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmbientGlowBlooms(bool isDark) {
    final cyanGlow = isDark
        ? AppColors.cyanElectric.withValues(alpha: 0.16)
        : const Color(0xFF38BDF8).withValues(alpha: 0.20);
    final greenGlow = isDark
        ? AppColors.accentGreenNeon.withValues(alpha: 0.14)
        : const Color(0xFF34D399).withValues(alpha: 0.18);

    return Stack(
      children: [
        Positioned(
          top: -120,
          right: -120,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [cyanGlow, Colors.transparent],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -100,
          left: -100,
          child: Container(
            width: 380,
            height: 380,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [greenGlow, Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPulsingTargetRings(
    double pulseValue,
    bool isDark,
    Color brandPrimary,
  ) {
    final ring1Radius = 170.0 + (pulseValue * 12.0);
    final ring2Radius = 220.0 + (pulseValue * 18.0);
    final ring3Radius = 270.0 + (pulseValue * 24.0);

    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer Ring 3
        Container(
          width: ring3Radius,
          height: ring3Radius,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: brandPrimary.withValues(
                alpha: (0.16 - (pulseValue * 0.04)).clamp(0.03, 0.20),
              ),
              width: 1.0,
            ),
          ),
        ),

        // Middle Ring 2
        Container(
          width: ring2Radius,
          height: ring2Radius,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: brandPrimary.withValues(
                alpha: (0.22 - (pulseValue * 0.06)).clamp(0.06, 0.28),
              ),
              width: 1.2,
            ),
          ),
        ),

        // Inner Ring 1
        Container(
          width: ring1Radius,
          height: ring1Radius,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: brandPrimary.withValues(
                alpha: (0.32 - (pulseValue * 0.08)).clamp(0.10, 0.40),
              ),
              width: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom painter rendering rising productivity particles
class _RisingSymbolsPainter extends CustomPainter {
  final double progress;
  final List<RisingSymbolConfig> symbols;
  final bool isDark;

  _RisingSymbolsPainter({
    required this.progress,
    required this.symbols,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final config in symbols) {
      final effectiveProgress = (progress * config.floatSpeed + config.ySeed) % 1.0;
      final y = size.height * (1.0 - effectiveProgress);

      final wobble = math.sin(effectiveProgress * 2 * math.pi) * config.horizontalWobble;
      final x = size.width * config.xRatio + wobble;

      double opacity = config.baseOpacity;
      if (effectiveProgress < 0.15) {
        opacity *= (effectiveProgress / 0.15);
      } else if (effectiveProgress > 0.85) {
        opacity *= ((1.0 - effectiveProgress) / 0.15);
      }

      final color = isDark ? config.darkColor : config.lightColor;

      final textPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(config.icon.codePoint),
          style: TextStyle(
            fontSize: config.size,
            fontFamily: config.icon.fontFamily,
            package: config.icon.fontPackage,
            color: color.withValues(alpha: opacity.clamp(0.0, 1.0)),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RisingSymbolsPainter oldDelegate) => true;
}
