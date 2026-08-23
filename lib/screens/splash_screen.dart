import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

// ==============================================================================
// FOCUSLY COLOR PALETTE (Extracted directly from the 3D Logo)
// ==============================================================================
const Color kBgDark = Color(0xFF060B24);
const Color kBgMidnight = Color(0xFF0B1647);
const Color kNavyDeep = Color(0xFF08123A);
const Color kCyanElectric = Color(0xFF00E5FF);
const Color kBlueSky = Color(0xFF29A9FF);
const Color kBlueRoyal = Color(0xFF1E58F6);
const Color kGreenNeon = Color(0xFF4ADE80);
const Color kGreenVibrant = Color(0xFF22C55E);
const Color kAmberGold = Color(0xFFFFB020);
const Color kTextWhite = Color(0xFFFFFFFF);
const Color kTextSlate = Color(0xFF94A3B8);

/// Model defining floating and rising productivity symbols across the screen.
class RisingSymbolConfig {
  final IconData icon;
  final double xRatio; // Horizontal position (0.0 to 1.0)
  final double ySeed; // Starting vertical phase offset (0.0 to 1.0)
  final double size; // Icon size
  final Color color; // Icon color
  final double baseOpacity; // Opacity
  final double floatSpeed; // Vertical travel speed multiplier
  final double horizontalWobble; // Horizontal sine-wave drift amount
  final double rotationMultiplier; // Rotation speed
  final bool hasGlassFrame; // Whether icon has a glowing micro-glass frame

  const RisingSymbolConfig({
    required this.icon,
    required this.xRatio,
    required this.ySeed,
    required this.size,
    required this.color,
    this.baseOpacity = 0.35,
    this.floatSpeed = 1.0,
    this.horizontalWobble = 14.0,
    this.rotationMultiplier = 1.0,
    this.hasGlassFrame = true,
  });
}

class SplashScreen extends StatefulWidget {
  /// Flag to simulate first-launch onboarding vs returning authenticated user.
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
  // ---------------------------------------------------------------------------
  // ANIMATION CONTROLLERS
  // ---------------------------------------------------------------------------
  // 1. Entrance Controller (0ms -> 900ms): Logo bounce & scale entrance
  late final AnimationController _entranceController;
  late final Animation<double> _logoScaleAnimation;
  late final Animation<double> _logoFadeAnimation;

  // 2. Rising & Floating Symbols Controller (Continuous upward particle drift)
  late final AnimationController _risingSymbolsController;

  // 3. Central Target Rings Pulse Controller (Looping 2.6s expansion & glow)
  late final AnimationController _ringsPulseController;

  // 4. Master 5-Second Splash & Loading Progress (0ms -> 5000ms)
  late final AnimationController _splashProgressController;

  // Rich collection of productivity & To-Do symbols floating and rising
  static const List<RisingSymbolConfig> _symbols = [
    // Left Side Symbols
    RisingSymbolConfig(
      icon: Icons.check_circle_rounded,
      xRatio: 0.08,
      ySeed: 0.15,
      size: 20,
      color: kGreenNeon,
      baseOpacity: 0.45,
      floatSpeed: 0.8,
      horizontalWobble: 16,
      hasGlassFrame: true,
    ),
    RisingSymbolConfig(
      icon: Icons.checklist_rounded,
      xRatio: 0.16,
      ySeed: 0.45,
      size: 22,
      color: kCyanElectric,
      baseOpacity: 0.40,
      floatSpeed: 1.1,
      horizontalWobble: 20,
      hasGlassFrame: true,
    ),
    RisingSymbolConfig(
      icon: Icons.timer_rounded,
      xRatio: 0.06,
      ySeed: 0.75,
      size: 18,
      color: kBlueSky,
      baseOpacity: 0.35,
      floatSpeed: 0.95,
      horizontalWobble: 14,
      hasGlassFrame: false,
    ),
    RisingSymbolConfig(
      icon: Icons.bolt_rounded,
      xRatio: 0.22,
      ySeed: 0.85,
      size: 24,
      color: kGreenNeon,
      baseOpacity: 0.50,
      floatSpeed: 1.25,
      horizontalWobble: 22,
      hasGlassFrame: true,
    ),
    RisingSymbolConfig(
      icon: Icons.settings_rounded,
      xRatio: 0.14,
      ySeed: 0.05,
      size: 18,
      color: kCyanElectric,
      baseOpacity: 0.30,
      floatSpeed: 0.7,
      horizontalWobble: 12,
      hasGlassFrame: false,
    ),
    RisingSymbolConfig(
      icon: Icons.track_changes_rounded,
      xRatio: 0.25,
      ySeed: 0.30,
      size: 22,
      color: kBlueSky,
      baseOpacity: 0.40,
      floatSpeed: 1.0,
      horizontalWobble: 18,
      hasGlassFrame: true,
    ),

    // Right Side Symbols
    RisingSymbolConfig(
      icon: Icons.local_fire_department_rounded,
      xRatio: 0.88,
      ySeed: 0.10,
      size: 22,
      color: kAmberGold,
      baseOpacity: 0.50,
      floatSpeed: 1.15,
      horizontalWobble: 18,
      hasGlassFrame: true,
    ),
    RisingSymbolConfig(
      icon: Icons.task_alt_rounded,
      xRatio: 0.78,
      ySeed: 0.38,
      size: 20,
      color: kGreenNeon,
      baseOpacity: 0.45,
      floatSpeed: 0.9,
      horizontalWobble: 15,
      hasGlassFrame: true,
    ),
    RisingSymbolConfig(
      icon: Icons.auto_awesome_rounded,
      xRatio: 0.92,
      ySeed: 0.65,
      size: 22,
      color: kCyanElectric,
      baseOpacity: 0.45,
      floatSpeed: 1.2,
      horizontalWobble: 22,
      hasGlassFrame: false,
    ),
    RisingSymbolConfig(
      icon: Icons.alarm_on_rounded,
      xRatio: 0.74,
      ySeed: 0.80,
      size: 20,
      color: kBlueSky,
      baseOpacity: 0.35,
      floatSpeed: 0.85,
      horizontalWobble: 14,
      hasGlassFrame: true,
    ),
    RisingSymbolConfig(
      icon: Icons.flag_rounded,
      xRatio: 0.84,
      ySeed: 0.52,
      size: 18,
      color: kGreenNeon,
      baseOpacity: 0.35,
      floatSpeed: 1.05,
      horizontalWobble: 16,
      hasGlassFrame: false,
    ),
    RisingSymbolConfig(
      icon: Icons.format_list_bulleted_rounded,
      xRatio: 0.70,
      ySeed: 0.18,
      size: 22,
      color: kCyanElectric,
      baseOpacity: 0.40,
      floatSpeed: 0.75,
      horizontalWobble: 18,
      hasGlassFrame: true,
    ),

    // Ambient Center-Flank Symbols
    RisingSymbolConfig(
      icon: Icons.star_rounded,
      xRatio: 0.34,
      ySeed: 0.12,
      size: 16,
      color: kAmberGold,
      baseOpacity: 0.30,
      floatSpeed: 0.7,
      horizontalWobble: 10,
      hasGlassFrame: false,
    ),
    RisingSymbolConfig(
      icon: Icons.done_all_rounded,
      xRatio: 0.64,
      ySeed: 0.88,
      size: 20,
      color: kGreenNeon,
      baseOpacity: 0.40,
      floatSpeed: 1.1,
      horizontalWobble: 14,
      hasGlassFrame: true,
    ),
    RisingSymbolConfig(
      icon: Icons.calendar_today_rounded,
      xRatio: 0.32,
      ySeed: 0.82,
      size: 18,
      color: kBlueSky,
      baseOpacity: 0.30,
      floatSpeed: 0.9,
      horizontalWobble: 12,
      hasGlassFrame: false,
    ),
    RisingSymbolConfig(
      icon: Icons.flash_on_rounded,
      xRatio: 0.66,
      ySeed: 0.22,
      size: 20,
      color: kCyanElectric,
      baseOpacity: 0.35,
      floatSpeed: 1.15,
      horizontalWobble: 16,
      hasGlassFrame: false,
    ),
  ];

  @override
  void initState() {
    super.initState();

    // 1. Entrance animation setup
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _logoScaleAnimation = Tween<double>(
      begin: 0.70,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const ElasticOutCurve(0.85),
      ),
    );

    _logoFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    // 2. Rising symbols continuous looping animation
    _risingSymbolsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 9000),
    )..repeat();

    // 3. Central pulsing target rings controller
    _ringsPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    // 4. Master 5-second splash progress
    _splashProgressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    );

    _splashProgressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigateToNextScreen();
      }
    });

    // Start animations
    _entranceController.forward();
    _splashProgressController.forward();
  }

  /// Handles destination routing
  void _navigateToNextScreen() {
    if (!mounted) return;

    bool isAuthenticated = false;
    try {
      final user = FirebaseAuth.instance.currentUser;
      isAuthenticated = user != null;
    } catch (_) {
      isAuthenticated = !widget.isFirstLaunch;
    }

    final Widget destination = (isAuthenticated || !widget.isFirstLaunch)
        ? const HomeScreen()
        : const OnboardingScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => destination,
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

  @override
  void dispose() {
    _entranceController.dispose();
    _risingSymbolsController.dispose();
    _ringsPulseController.dispose();
    _splashProgressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: kBgDark,
      body: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // -----------------------------------------------------------------
          // 1. AMBIENT BACKGROUND GLOW BLOOMS
          // -----------------------------------------------------------------
          _buildAmbientGlowBlooms(screenSize),

          // -----------------------------------------------------------------
          // 2. RISING & FLOATING PRODUCTIVITY SYMBOLS (Bottom -> Up Particle Wave)
          // -----------------------------------------------------------------
          ..._buildRisingFloatingSymbols(screenSize),

          // -----------------------------------------------------------------
          // 3. CENTER TARGET RINGS & PERFECTLY CENTERED LOGO
          // -----------------------------------------------------------------
          _buildCenteredTargetAndLogo(),

          // -----------------------------------------------------------------
          // 4. BOTTOM NEON LOADING BAR & LIVE STAGE PROGRESS
          // -----------------------------------------------------------------
          Positioned(
            left: 24,
            right: 24,
            bottom: 38,
            child: _buildFuturisticLoadingSection(),
          ),
        ],
      ),
    );
  }

  /// Ambient background aurora blooms
  Widget _buildAmbientGlowBlooms(Size size) {
    return AnimatedBuilder(
      animation: _ringsPulseController,
      builder: (context, child) {
        final double pulse = _ringsPulseController.value;
        return Stack(
          children: [
            // Top-right cyan aurora
            Positioned(
              top: -60,
              right: -60,
              child: Container(
                width: 340 + (pulse * 30),
                height: 340 + (pulse * 30),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      kCyanElectric.withValues(alpha: 0.18 + (pulse * 0.08)),
                      kBlueRoyal.withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Bottom-left green neon aurora
            Positioned(
              bottom: -40,
              left: -50,
              child: Container(
                width: 320 + (pulse * 25),
                height: 320 + (pulse * 25),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      kGreenNeon.withValues(alpha: 0.15 + (pulse * 0.06)),
                      kCyanElectric.withValues(alpha: 0.04),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Center radial background illumination
            Center(
              child: Container(
                width: 440,
                height: 440,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      kBlueRoyal.withValues(alpha: 0.26 + (pulse * 0.08)),
                      kNavyDeep.withValues(alpha: 0.45),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Builds the perfectly centered concentric rings and the logo right in the middle
  Widget _buildCenteredTargetAndLogo() {
    return AnimatedBuilder(
      animation: _ringsPulseController,
      builder: (context, child) {
        final double pulse = _ringsPulseController.value;
        return Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer Glowing Ring
              Container(
                width: 310 + (pulse * 18),
                height: 310 + (pulse * 18),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: kCyanElectric.withValues(alpha: 0.14 + (pulse * 0.08)),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: kCyanElectric.withValues(alpha: 0.06 + (pulse * 0.05)),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),

              // Middle Neon Green Target Ring
              Container(
                width: 250 + (pulse * 12),
                height: 250 + (pulse * 12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: kGreenNeon.withValues(alpha: 0.20 + (pulse * 0.10)),
                    width: 1.5,
                  ),
                ),
              ),

              // Inner Concentric Cyan Ring
              Container(
                width: 190 + (pulse * 8),
                height: 190 + (pulse * 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: kCyanElectric.withValues(alpha: 0.25 + (pulse * 0.12)),
                    width: 2.0,
                  ),
                ),
              ),

              // 3D Centered Logo (Cleanly in the dead center of the concentric rings)
              AnimatedBuilder(
                animation: _entranceController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _logoScaleAnimation.value,
                    child: Opacity(
                      opacity: _logoFadeAnimation.value,
                      child: child,
                    ),
                  );
                },
                child: Container(
                  width: 210,
                  height: 210,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: kCyanElectric.withValues(alpha: 0.35),
                        blurRadius: 45,
                        spreadRadius: 4,
                      ),
                      BoxShadow(
                        color: kGreenNeon.withValues(alpha: 0.25),
                        blurRadius: 65,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kNavyDeep,
                          border: Border.all(color: kCyanElectric, width: 2),
                        ),
                        child: const Icon(
                          Icons.track_changes_rounded,
                          size: 96,
                          color: kCyanElectric,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Builds symbols that continuously rise and drift from bottom to top
  List<Widget> _buildRisingFloatingSymbols(Size size) {
    return _symbols.map((config) {
      return AnimatedBuilder(
        animation: _risingSymbolsController,
        builder: (context, child) {
          final double progress = _risingSymbolsController.value;

          // Compute continuous vertical rising position with wrapping
          final double rawY = (config.ySeed - (progress * config.floatSpeed)) % 1.0;
          final double currentYRatio = rawY < 0 ? rawY + 1.0 : rawY;
          final double currentY = currentYRatio * size.height;

          // Horizontal sine-wave wobble
          final double t = (progress * 4 * math.pi) + (config.ySeed * 2 * math.pi);
          final double dx = math.sin(t) * config.horizontalWobble;
          final double currentX = (size.width * config.xRatio) + dx;

          // Rotation
          final double rotation = math.cos(t) * 0.15 * config.rotationMultiplier;

          // Smooth edge fading near top and bottom
          double opacity = config.baseOpacity;
          if (currentYRatio < 0.12) {
            opacity *= (currentYRatio / 0.12);
          } else if (currentYRatio > 0.88) {
            opacity *= ((1.0 - currentYRatio) / 0.12);
          }

          return Positioned(
            left: currentX - (config.size / 2),
            top: currentY - (config.size / 2),
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.rotate(
                angle: rotation,
                child: config.hasGlassFrame
                    ? Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F1B4C).withValues(alpha: 0.60),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: config.color.withValues(alpha: 0.35),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: config.color.withValues(alpha: 0.20),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Icon(
                          config.icon,
                          size: config.size,
                          color: config.color,
                        ),
                      )
                    : Icon(
                        config.icon,
                        size: config.size,
                        color: config.color,
                      ),
              ),
            ),
          );
        },
      );
    }).toList();
  }

  /// Futuristic neon gradient progress bar with live percentage and stage sequencer
  Widget _buildFuturisticLoadingSection() {
    return AnimatedBuilder(
      animation: _splashProgressController,
      builder: (context, child) {
        final double progress = _splashProgressController.value.clamp(0.0, 1.0);
        final int percent = (progress * 100).toInt();

        // 4-Stage Dynamic Status Strings aligned with the 5.0 seconds duration
        String statusText;
        if (progress < 0.30) {
          statusText = '⚡ Initializing smart task engine...';
        } else if (progress < 0.60) {
          statusText = '🎯 Syncing habits & focus streaks...';
        } else if (progress < 0.90) {
          statusText = '🚀 Preparing your daily workspace...';
        } else {
          statusText = '✨ Ready to focus!';
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Row: Dynamic Stage Title & Live Percentage
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    statusText,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kTextSlate,
                      letterSpacing: 0.2,
                    ),
                  ),
                  Text(
                    '$percent%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: kCyanElectric,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Neon Glowing Multi-Stop Gradient Track
            Container(
              height: 7,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF0D1845),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: kCyanElectric.withValues(alpha: 0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  FractionallySizedBox(
                    widthFactor: progress,
                    heightFactor: 1.0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            kBlueRoyal,
                            kCyanElectric,
                            kGreenNeon,
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: kGreenNeon.withValues(alpha: 0.6),
                            blurRadius: 10,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
