import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import 'dart:convert';

// ─────────────────────────────────────────────
//  SHADER WARM-UP
//
//  Runs BEFORE runApp() by drawing every shape variant used in the app to an
//  offscreen PictureRecorder canvas. This forces Metal to compile the GPU
//  shader programs before the user touches anything, eliminating the first-tap
//  stall on iOS/SE3.
//
//  WHY NOT Offstage / Opacity(0.001)?
//  • Offstage skips the GPU paint pass entirely — shaders never compile.
//  • Opacity(≠1.0) triggers a saveLayer compositing pass. Metal compiles
//    shaders per pipeline-state; an offscreen saveLayer uses a different
//    state than the main scene, so compiled shaders are not reused.
//
//  ShaderWarmUp.execute() draws to the same pipeline-state used by the main
//  scene rendering, so every compilation here is reused when real widgets draw.
// ─────────────────────────────────────────────
class _AppShaderWarmUp extends ShaderWarmUp {
  const _AppShaderWarmUp();

  // Large enough to cover any phone screen in any orientation.
  @override
  Size get size => const Size(480.0, 960.0);

  @override
  Future<void> warmUpOnCanvas(Canvas canvas) async {
    final Paint fill = Paint()
      ..color = const Color(0xFF0C1F35)
      ..style = PaintingStyle.fill;

    // Hairline border — width 0.5, used everywhere as unselected tile borders.
    final Paint hairline = Paint()
      ..color = const Color(0x1AFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // Thin border — width 1.0, used in circle icon containers and dialogs.
    final Paint stroke1 = Paint()
      ..color = const Color(0x80F4C842)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Medium border — width 1.5, used for SELECTED tile state.
    // This is the state first painted when the user taps an action tile.
    final Paint stroke15 = Paint()
      ..color = const Color(0x80F4C842)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Every border-radius value used in BoxDecoration across the whole app.
    // Metal compiles one shader program per (draw-type, pipeline-state) pair.
    // Drawing each radius here compiles the rrect program for that geometry.
    const radii = [
      2.0,   // BorderRadius.circular(2) — drag handle
      4.0,   // BorderRadius.circular(4) — chart bars
      6.0,   // BorderRadius.circular(6) — depth-bar segment
      7.0,   // BorderRadius.circular(7) — priority badge
      8.0,   // BorderRadius.circular(8) — priority selector chip
      10.0,  // BorderRadius.circular(10) — movement banner, text field
      12.0,  // BorderRadius.circular(12) — buttons, onboarding tile
      14.0,  // BorderRadius.circular(14) — action tile, stat card, settings row
      16.0,  // BorderRadius.circular(16) — LOG button, buoy/storm pill
      18.0,  // BorderRadius.circular(18) — weekly headline card
      20.0,  // BorderRadius.circular(20) — AlertDialog shape, direction pill
      24.0,  // BorderRadius.circular(24) — Dialog container, sheet container
    ];

    var y = 0.0;
    for (final r in radii) {
      final rect = Rect.fromLTWH(0, y, 260, 50);
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(r));

      // Fill — background colour of containers.
      canvas.drawRRect(rrect, fill);
      // Hairline stroke — unselected border (0.5px).
      canvas.drawRRect(rrect, hairline);
      // Normal stroke — dialog/button borders (1.0px).
      canvas.drawRRect(rrect, stroke1);
      // Thick stroke — selected tile border (1.5px).
      // The border-width transition (0.5 → 1.5) is the first visual change
      // when the user taps a tile. If this shader isn't compiled, that tap lags.
      canvas.drawRRect(rrect, stroke15);

      y += 56;
    }

    // Vertical-only radius (bottom sheet top corners).
    final sheetRRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(0, y, 260, 50),
      topLeft: const Radius.circular(24),
      topRight: const Radius.circular(24),
    );
    canvas.drawRRect(sheetRRect, fill);
    canvas.drawRRect(sheetRRect, hairline);
    y += 56;

    // Circle — icon containers, selection circles, stat circles.
    for (final r in [11.0, 13.0, 18.0, 19.0, 26.0, 28.0, 32.0, 36.0, 48.0]) {
      canvas.drawCircle(Offset(r, y + r), r, fill);
      canvas.drawCircle(Offset(r, y + r), r, hairline);
      canvas.drawCircle(Offset(r, y + r), r, stroke1);
      canvas.drawCircle(Offset(r, y + r), r, stroke15);
    }

    // Plain rect — overlay backgrounds, ocean background fill.
    canvas.drawRect(const Rect.fromLTWH(0, 0, 480, 960), fill);

    // Shadow — Material dialogs draw an elevation shadow using drawShadow.
    canvas.drawShadow(
      Path()
        ..addRRect(RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, 260, 50),
          const Radius.circular(24),
        )),
      Colors.black,
      8.0,
      false,
    );

    // Anglerfish lure glow — RadialGradient with 3 stops (layers 9–10).
    // Compiles the radial-gradient pipeline state used every frame at depth.
    for (final glowR in [55.0, 80.0]) {
      canvas.drawCircle(
        Offset(130, y + 26),
        glowR,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFF00E676).withOpacity(0.30),
              const Color(0xFF00E676).withOpacity(0.05),
              Colors.transparent,
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(Rect.fromCenter(
              center: Offset(130, y + 26),
              width: glowR * 2,
              height: glowR * 2)),
      );
    }

    // Bioluminescent abyss particle glow (layer 8+ cyan motes).
    canvas.drawCircle(
      Offset(130, y + 26),
      12.0,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF80DEEA).withOpacity(0.45),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(118, y + 14, 24, 24)),
    );

    // Vignette radial gradient — one per layer depth band (sampled at 3 levels).
    for (final opacity in [0.22, 0.35, 0.52]) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, 480, 960),
        Paint()
          ..shader = RadialGradient(
            colors: [Colors.transparent, Colors.black.withOpacity(opacity)],
            radius: 0.80,
          ).createShader(const Rect.fromLTWH(0, 0, 480, 960)),
      );
    }
  }
}

// ─────────────────────────────────────────────
//  ENTRY POINT
// ─────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Must run before runApp so shaders are compiled before the first frame.
  await const _AppShaderWarmUp().execute();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const ProductivityDepthApp());
}

// ─────────────────────────────────────────────
//  DATA MODEL
// ─────────────────────────────────────────────
class LayerData {
  final String name;
  final String subtitle;
  final String description;
  final String persona;
  final IconData icon;
  final Color iconColor;
  final Color topColor;
  final Color bottomColor;
  final Color textColor;

  const LayerData({
    required this.name,
    required this.subtitle,
    required this.description,
    required this.persona,
    required this.icon,
    required this.iconColor,
    required this.topColor,
    required this.bottomColor,
    required this.textColor,
  });
}

const List<LayerData> kLayers = [
  LayerData(
    name: 'The Island',
    subtitle: 'Above the surface, above it all',
    description: 'You live above the waterline. Energy flows freely, habits are locked in, and life feels aligned. The sun is out and the ocean is beneath you — not threatening, just there.',
    persona: 'The consistent achiever. Someone who wakes with purpose, executes without friction, and ends each day with real satisfaction. Routines feel effortless because they have become identity.',
    icon: Icons.wb_sunny_rounded,
    iconColor: Color(0xFFFFC107),
    topColor: Color(0xFF87CEEB),
    bottomColor: Color(0xFF4AB3D0),
    textColor: Color(0xFF1A3A5C),
  ),
  LayerData(
    name: 'Clear Shallows',
    subtitle: 'Light reaches all the way down',
    description: 'The water is bright and warm. You can see the bottom clearly. Momentum is real, the surface is close, and every stroke forward feels rewarding.',
    persona: 'The high performer on a strong run. Productive, motivated, and building habits that stick. One or two more good days and you break the surface.',
    icon: Icons.waves_rounded,
    iconColor: Color(0xFF4FC3F7),
    topColor: Color(0xFF5BBFE0),
    bottomColor: Color(0xFF3BA8CC),
    textColor: Colors.white,
  ),
  LayerData(
    name: 'Coral Reef',
    subtitle: 'Something beautiful is growing',
    description: 'Colour and life surround you. You are doing well — there is beauty in your routine and things are actively growing. The reef thrives when tended consistently.',
    persona: 'The grounded worker. Consistent output, clear priorities, and a life that feels purposeful most of the time. Not exceptional every day, but reliably good.',
    icon: Icons.spa_rounded,
    iconColor: Color(0xFFFF7043),
    topColor: Color(0xFF3BA8CC),
    bottomColor: Color(0xFF2990B8),
    textColor: Colors.white,
  ),
  LayerData(
    name: 'Fish Schools',
    subtitle: 'Movement, but no clear direction',
    description: 'Life moves in schools here. You are productive and moving with direction, but the depth is starting to show. Distraction is easy, focus requires effort.',
    persona: 'The competent striver. Getting things done but occasionally losing the thread. Still more up days than down, but complacency is starting to creep in.',
    icon: Icons.scatter_plot_rounded,
    iconColor: Color(0xFF29B6F6),
    topColor: Color(0xFF2990B8),
    bottomColor: Color(0xFF1E78A0),
    textColor: Colors.white,
  ),
  LayerData(
    name: 'Neutral Zone',
    subtitle: 'Still water. Neither rising nor falling',
    description: 'The water is still and quiet. Neither rising nor sinking — you are maintaining, but not pushing forward. Days pass without much to show.',
    persona: 'The person running on autopilot. Technically functional, but not growing. Not failing, but not building anything either. The comfort zone has become the holding zone.',
    icon: Icons.remove_rounded,
    iconColor: Color(0xFF42A5F5),
    topColor: Color(0xFF1E6A8C),
    bottomColor: Color(0xFF165678),
    textColor: Colors.white,
  ),
  LayerData(
    name: 'Jellyfish Drift',
    subtitle: 'Carried by the current, not the will',
    description: 'You drift with the current rather than swimming against it. Decisions feel soft and time slips through without much to show. The pull downward is gentle but real.',
    persona: 'The procrastinator finding comfort in busyness without output. Reactive rather than proactive. Intentions are good but execution keeps getting postponed until tomorrow.',
    icon: Icons.blur_circular,
    iconColor: Color(0xFFAB47BC),
    topColor: Color(0xFF165678),
    bottomColor: Color(0xFF104264),
    textColor: Colors.white,
  ),
  LayerData(
    name: 'The Shipwreck',
    subtitle: 'Where forgotten ships sleep',
    description: 'Old ambitions lie broken on the floor here. There are reminders of what was once planned, but momentum has fully stalled. The wreck is a warning.',
    persona: 'Someone whose goals have been silently abandoned. Weeks pass without meaningful progress. Plans made with good intentions now gather rust at the bottom.',
    icon: Icons.anchor_rounded,
    iconColor: Color(0xFF78909C),
    topColor: Color(0xFF104264),
    bottomColor: Color(0xFF0C3050),
    textColor: Colors.white70,
  ),
  LayerData(
    name: 'Shark Waters',
    subtitle: 'Danger moves in silence',
    description: 'Something hunts you here — self-doubt, avoidance, dread. You know you should rise but the current pulls hard. Every task feels like a threat.',
    persona: 'The person in a real slump. Energy is low, routines have collapsed, and starting anything feels harder than it should. Avoidance has become the default strategy.',
    icon: Icons.warning_rounded,
    iconColor: Color(0xFFEF5350),
    topColor: Color(0xFF0C3050),
    bottomColor: Color(0xFF082040),
    textColor: Colors.white70,
  ),
  LayerData(
    name: 'Deep Ocean',
    subtitle: 'The weight here has no name',
    description: 'Pressure builds at this depth. Light barely reaches. It takes real effort just to stay still and not sink further. The weight is physical.',
    persona: 'Overwhelmed and withdrawing. Responsibilities pile up unaddressed. The gap between where you are and where you want to be has grown into something that feels impossible.',
    icon: Icons.compress_rounded,
    iconColor: Color(0xFF5C6BC0),
    topColor: Color(0xFF082040),
    bottomColor: Color(0xFF051530),
    textColor: Colors.white60,
  ),
  LayerData(
    name: 'Anglerfish Lair',
    subtitle: 'Dark light leads nowhere',
    description: 'A deceptive light lures you deeper. Distractions glow in the dark, pulling you away from what matters. Every escape feels like relief but leads further down.',
    persona: 'Someone in a destructive spiral. Escaping into screens, sleep, or anything that feels easier than facing the work. The lure looks like comfort but it is a trap.',
    icon: Icons.flashlight_on_rounded,
    iconColor: Color(0xFF00E676),
    topColor: Color(0xFF051530),
    bottomColor: Color(0xFF030D20),
    textColor: Colors.white54,
  ),
  LayerData(
    name: 'The Abyss',
    subtitle: 'Where all motion ends',
    description: 'Complete darkness. No direction, no momentum, no spark. The weight of everything has become crushing and the surface feels impossibly far away.',
    persona: 'Full burnout. Exhaustion is total. Getting out of bed is a challenge. This layer demands rest and a genuine rebuild from zero — not a push, but a pause.',
    icon: Icons.do_not_disturb_on_rounded,
    iconColor: Color(0xFF757575),
    topColor: Color(0xFF030D20),
    bottomColor: Color(0xFF010508),
    textColor: Colors.white38,
  ),
];

const List<String> kDefaultCategories = [
  'Study',
  'Exercise',
  'Work',
  'Reading',
  'Meditation',
  'Creative Work',
  'Cleaning',
  'Side Project',
];

// Coral thresholds — you reach layer i when corals >= kLayerThresholds[i]
const List<int> kLayerThresholds = [
  1100, // 0  — The Island
  1000, // 1  — Clear Shallows
   900, // 2  — Coral Reef
   800, // 3  — Fish Schools
   700, // 4  — Neutral Zone
   600, // 5  — Jellyfish Drift
   500, // 6  — The Shipwreck
   400, // 7  — Shark Waters
   300, // 8  — Deep Ocean
   200, // 9  — Anglerfish Lair
     0, // 10 — The Abyss
];

// ─────────────────────────────────────────────
//  DEBUG — set false to disable daily log limit
// ─────────────────────────────────────────────
const bool kEnforceDailyLimit = false;

// ─────────────────────────────────────────────
//  OCEAN HAPTICS
//
//  Centralised haptic feedback tuned for iOS Taptic Engine.
//  Each pattern is designed to feel thematic — surface interactions
//  are light ripples, gains feel like treasure surfacing, storms
//  rumble like rolling thunder, and sinking carries weight.
//
//  All multi-beat patterns use Future.delayed so the Taptic Engine
//  has time to reset between strikes (~80-120ms minimum).
// ─────────────────────────────────────────────
class OceanHaptics {
  OceanHaptics._();

  // ── Surface touches — calm water ripple ──────────
  /// LOG button press, settings tap, mechanic info pills.
  static void surfaceTap() {
    HapticFeedback.lightImpact();
  }

  /// Action tile toggle in log sheet (existing behaviour, kept as-is).
  static void selectionTick() {
    HapticFeedback.selectionClick();
  }

  // ── Positive outcomes — treasure from the deep ───
  /// Coral gain on a productive day.  A satisfying double-pulse:
  /// light anticipation tap → heavier "coin drop" thud.
  static void coralGain() {
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 100), () {
      HapticFeedback.heavyImpact();
    });
  }

  /// Layer ascent — crossing a pressure boundary upward.
  /// Heavy "breakthrough" followed by a lighter settling ripple.
  static void layerAscend() {
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 120), () {
      HapticFeedback.mediumImpact();
    });
    Future.delayed(const Duration(milliseconds: 260), () {
      HapticFeedback.lightImpact();
    });
  }

  // ── Negative outcomes — the ocean's weight ───────
  /// Storm event (3-day stagnation penalty).
  /// Triple rolling-thunder: three heavy beats with increasing gaps.
  static void storm() {
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 110), () {
      HapticFeedback.heavyImpact();
    });
    Future.delayed(const Duration(milliseconds: 280), () {
      HapticFeedback.heavyImpact();
    });
  }

  /// Sinking / coral loss on a bad day.
  /// Descending double-beat — medium tap then a heavy pull downward.
  static void sink() {
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 140), () {
      HapticFeedback.heavyImpact();
    });
  }

  /// Layer descent — sinking past a depth boundary.
  /// Sharp alert double-tap followed by heavy pull.
  static void layerDescend() {
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 80), () {
      HapticFeedback.lightImpact();
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      HapticFeedback.heavyImpact();
    });
  }

  // ── Neutral / protective ─────────────────────────
  /// Rescue buoy absorbs a loss — relief, not celebration.
  /// Gentle double-pulse: light tap confirms, medium settles.
  static void rescueBuoy() {
    HapticFeedback.lightImpact();
    Future.delayed(const Duration(milliseconds: 120), () {
      HapticFeedback.mediumImpact();
    });
  }

  /// Holding steady — no gain, no loss. Calm single pulse.
  static void holdSteady() {
    HapticFeedback.mediumImpact();
  }

  // ── Reflection dialog — context-aware ────────────
  /// Called when the post-log reflection dialog opens.
  /// Picks the right pattern based on coral delta.
  static void reflection(int delta) {
    if (delta > 0) {
      coralGain();
    } else if (delta < 0) {
      sink();
    } else {
      holdSteady();
    }
  }

  // ── Milestone / commitment ───────────────────────
  /// "Dive in" confirm — committing actions to the ocean.
  static void diveIn() {
    HapticFeedback.mediumImpact();
  }

  /// Onboarding "DIVE IN" — first plunge into the ocean.
  static void firstDive() {
    HapticFeedback.heavyImpact();
  }

  /// Weekly summary appears — a distinct achievement beat.
  /// Ascending triple-pulse: light → medium → heavy.
  static void weeklySummary() {
    HapticFeedback.lightImpact();
    Future.delayed(const Duration(milliseconds: 100), () {
      HapticFeedback.mediumImpact();
    });
    Future.delayed(const Duration(milliseconds: 230), () {
      HapticFeedback.heavyImpact();
    });
  }

  /// Priority cycle tap — subtle tick between low/mid/high.
  static void priorityCycle() {
    HapticFeedback.selectionClick();
  }
}

class LayerIconWidget extends StatelessWidget {
  final int layerIndex;
  final double size;

  const LayerIconWidget({
    super.key,
    required this.layerIndex,
    this.size = 90,
  });

  @override
  Widget build(BuildContext context) {
    final data = kLayers[layerIndex];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: data.iconColor.withOpacity(0.12),
        border: Border.all(
          color: data.iconColor.withOpacity(0.35),
          width: 1.5,
        ),
      ),
      child: Icon(
        data.icon,
        color: data.iconColor,
        size: size * 0.44,
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  APP ROOT
// ─────────────────────────────────────────────
class ProductivityDepthApp extends StatelessWidget {
  const ProductivityDepthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Productivity Depth',
      theme: ThemeData(
        fontFamily: 'SF Pro Display',
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(),
      ),
      home: const AppRouter(),
    );
  }
}

// ─────────────────────────────────────────────
//  ROUTER
// ─────────────────────────────────────────────
class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  bool _splashDone = false;
  bool _onboarded = false;
  bool _dataReady = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final prefs = await SharedPreferences.getInstance();
    final cats = prefs.getStringList('categories');
    _onboarded = cats != null && cats.isNotEmpty;
    _dataReady = true;
    // If splash already finished, trigger rebuild immediately.
    // Otherwise splash will check _dataReady when its animation ends.
    if (_splashDone && mounted) setState(() {});
  }

  void _onSplashComplete() {
    _splashDone = true;
    if (_dataReady && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Show splash until BOTH animation completes AND data is ready.
    if (!_splashDone || !_dataReady) {
      return _SplashScreen(onComplete: _onSplashComplete);
    }
    return _onboarded
        ? const OceanScreen()
        : OnboardingScreen(onComplete: () => setState(() => _onboarded = true));
  }
}

// ─────────────────────────────────────────────
//  SPLASH / LAUNCH SCREEN
//
//  Animation timeline (total ≈ 2.6 s):
//    0–400 ms   Background gradient settles, vignette fades in
//    0–700 ms   Sonar ripple rings pulse outward (3 staggered)
//    100–600 ms Icon scales 0.6→1.0 with overshoot, glow blooms
//    350–850 ms "Productivity" fades + slides up
//    500–1000ms "DEPTH" fades + slides up
//    700–1200ms Tagline fades in
//    1200–2600ms Hold, particles drift
//    2200–2600ms Everything fades out (opacity 1→0)
// ─────────────────────────────────────────────
class _SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const _SplashScreen({required this.onComplete});

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with TickerProviderStateMixin {
  // Master timeline that drives the entire sequence.
  late final AnimationController _master;
  // Continuous loop for background painter (ripples, particles).
  late final AnimationController _loop;
  // Exit fade-out.
  late final AnimationController _exit;

  // Derived animations from the master timeline.
  late final Animation<double> _iconScale;
  late final Animation<double> _iconOpacity;
  late final Animation<double> _glowOpacity;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _titleSlide;
  late final Animation<double> _depthOpacity;
  late final Animation<double> _depthSlide;
  late final Animation<double> _taglineOpacity;
  late final Animation<double> _ripple1;
  late final Animation<double> _ripple2;
  late final Animation<double> _ripple3;

  static const _totalMs = 2600;

  @override
  void initState() {
    super.initState();

    _master = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _totalMs),
    );
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
    _exit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    // ── Icon ──
    _iconScale = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(
        parent: _master,
        curve: const Interval(0.04, 0.30, curve: _OvershootCurve(1.8)),
      ),
    );
    _iconOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _master,
        curve: const Interval(0.04, 0.18, curve: Curves.easeOut),
      ),
    );
    _glowOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _master,
        curve: const Interval(0.12, 0.35, curve: Curves.easeOut),
      ),
    );

    // ── Title: "Productivity" ──
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _master,
        curve: const Interval(0.14, 0.35, curve: Curves.easeOut),
      ),
    );
    _titleSlide = Tween<double>(begin: 14.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _master,
        curve: const Interval(0.14, 0.35, curve: Curves.easeOutCubic),
      ),
    );

    // ── Title: "DEPTH" ──
    _depthOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _master,
        curve: const Interval(0.20, 0.42, curve: Curves.easeOut),
      ),
    );
    _depthSlide = Tween<double>(begin: 14.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _master,
        curve: const Interval(0.20, 0.42, curve: Curves.easeOutCubic),
      ),
    );

    // ── Tagline ──
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _master,
        curve: const Interval(0.28, 0.48, curve: Curves.easeOut),
      ),
    );

    // ── Sonar ripples (staggered) ──
    _ripple1 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _master,
        curve: const Interval(0.0, 0.50, curve: Curves.easeOut),
      ),
    );
    _ripple2 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _master,
        curve: const Interval(0.08, 0.58, curve: Curves.easeOut),
      ),
    );
    _ripple3 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _master,
        curve: const Interval(0.16, 0.66, curve: Curves.easeOut),
      ),
    );

    _master.forward();
    _master.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _beginExit();
      }
    });
  }

  void _beginExit() {
    _exit.forward().then((_) {
      widget.onComplete();
    });
  }

  @override
  void dispose() {
    _master.dispose();
    _loop.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020A18),
      body: AnimatedBuilder(
        animation: Listenable.merge([_master, _loop, _exit]),
        builder: (context, _) {
          final exitOpacity = 1.0 - _exit.value;
          return Opacity(
            opacity: exitOpacity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── Animated ocean background ──
                CustomPaint(
                  painter: _SplashPainter(
                    t: _loop.value,
                    ripple1: _ripple1.value,
                    ripple2: _ripple2.value,
                    ripple3: _ripple3.value,
                    glowOpacity: _glowOpacity.value,
                  ),
                ),
                // ── Foreground content ──
                SafeArea(
                  child: Column(
                    children: [
                      const Spacer(flex: 3),
                      // ── Glowing icon ──
                      Transform.scale(
                        scale: _iconScale.value,
                        child: Opacity(
                          opacity: _iconOpacity.value,
                          child: _buildIcon(),
                        ),
                      ),
                      const SizedBox(height: 36),
                      // ── "Productivity" ──
                      Transform.translate(
                        offset: Offset(0, _titleSlide.value),
                        child: Opacity(
                          opacity: _titleOpacity.value,
                          child: const Text(
                            'Productivity',
                            style: TextStyle(
                              color: Color(0xFFF4C842),
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 3.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      // ── "DEPTH" ──
                      Transform.translate(
                        offset: Offset(0, _depthSlide.value),
                        child: Opacity(
                          opacity: _depthOpacity.value,
                          child: const Text(
                            'DEPTH',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 10,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // ── Tagline ──
                      Opacity(
                        opacity: _taglineOpacity.value,
                        child: const Text(
                          'How deep are you?',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const Spacer(flex: 4),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildIcon() {
    return SizedBox(
      width: 110,
      height: 110,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow ring
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFF4C842).withOpacity(0.25),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF4C842).withOpacity(0.12),
                  blurRadius: 30,
                  spreadRadius: 4,
                ),
                BoxShadow(
                  color: const Color(0xFF4FC3F7).withOpacity(0.08),
                  blurRadius: 50,
                  spreadRadius: 8,
                ),
              ],
            ),
          ),
          // Inner filled circle
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0E2A48),
                  Color(0xFF071830),
                ],
              ),
              border: Border.all(
                color: const Color(0xFFF4C842).withOpacity(0.40),
                width: 1.0,
              ),
            ),
            child: const Icon(
              Icons.water_rounded,
              color: Color(0xFFF4C842),
              size: 42,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SPLASH CUSTOM PAINTER
//
//  Draws: ocean gradient, sonar ripple rings,
//  rising bubbles, depth vignette, icon glow halo.
// ─────────────────────────────────────────────
class _SplashPainter extends CustomPainter {
  final double t;
  final double ripple1;
  final double ripple2;
  final double ripple3;
  final double glowOpacity;

  _SplashPainter({
    required this.t,
    required this.ripple1,
    required this.ripple2,
    required this.ripple3,
    required this.glowOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h * 0.36; // Icon center vertical position

    // ── Ocean depth gradient ──
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0A2540), // Surface hint
            Color(0xFF071B35), // Mid ocean
            Color(0xFF040F24), // Deep
            Color(0xFF020A18), // Abyss
          ],
          stops: [0.0, 0.3, 0.65, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // ── Subtle horizontal light bands (caustics hint) ──
    for (int i = 0; i < 4; i++) {
      final bandY = h * (0.08 + i * 0.06) +
          math.sin(t * math.pi * 2 * (3 + i) + i * 1.5) * 6;
      final bandAlpha = 0.018 + math.sin(t * math.pi * 2 * (5 + i) + i * 2.3).abs() * 0.012;
      canvas.drawRect(
        Rect.fromLTWH(0, bandY, w, 1.5),
        Paint()..color = const Color(0xFF4FC3F7).withOpacity(bandAlpha),
      );
    }

    // ── Sonar ripple rings expanding from icon center ──
    _drawRipple(canvas, cx, cy, ripple1, w * 0.85);
    _drawRipple(canvas, cx, cy, ripple2, w * 0.65);
    _drawRipple(canvas, cx, cy, ripple3, w * 0.48);

    // ── Rising bubble particles ──
    _drawBubbles(canvas, w, h);

    // ── Central glow halo behind icon ──
    if (glowOpacity > 0) {
      canvas.drawCircle(
        Offset(cx, cy),
        90,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFF4C842).withOpacity(0.08 * glowOpacity),
              const Color(0xFF4FC3F7).withOpacity(0.04 * glowOpacity),
              Colors.transparent,
            ],
            stops: const [0.0, 0.45, 1.0],
          ).createShader(
            Rect.fromCenter(center: Offset(cx, cy), width: 180, height: 180),
          ),
      );
    }

    // ── Deep vignette ──
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.transparent,
            const Color(0xFF020A18).withOpacity(0.55),
          ],
          radius: 0.75,
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
  }

  void _drawRipple(Canvas canvas, double cx, double cy, double progress, double maxR) {
    if (progress <= 0) return;
    final r = maxR * progress;
    // Fade out as it expands — fully gone at progress 1.0
    final alpha = (1.0 - progress) * 0.18;
    if (alpha <= 0) return;
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = const Color(0xFF4FC3F7).withOpacity(alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 * (1.0 - progress * 0.6),
    );
  }

  void _drawBubbles(Canvas canvas, double w, double h) {
    // 12 deterministic bubbles — no allocations, purely analytical positions.
    const count = 12;
    for (int i = 0; i < count; i++) {
      final sn = i / (count - 1.0);

      // Each bubble has a unique phase, speed, and horizontal offset.
      final phase = sn * 6.28 + i * 1.37;
      final speed = 2 + (i % 4);
      final ny = 1.0 - ((sn + t * speed) % 1.0);
      final nx = 0.08 + sn * 0.84 +
          math.sin(t * math.pi * 2 * (2 + i % 3) + phase) * 0.03;

      final x = nx * w;
      final y = ny * h;
      final r = 1.0 + (i % 3) * 0.8;

      // Fade near top and bottom edges.
      final edgeFade = (ny.clamp(0.0, 0.1) / 0.1) *
          ((1.0 - ny).clamp(0.0, 0.1) / 0.1);
      final alpha = 0.12 * edgeFade +
          math.sin(t * math.pi * 2 * (6 + i % 5) + phase).abs() * 0.06 * edgeFade;

      if (alpha > 0.01) {
        canvas.drawCircle(
          Offset(x, y),
          r,
          Paint()..color = const Color(0xFF80DEEA).withOpacity(alpha),
        );
        // Tiny specular highlight
        canvas.drawCircle(
          Offset(x - r * 0.3, y - r * 0.3),
          r * 0.35,
          Paint()..color = Colors.white.withOpacity(alpha * 0.5),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SplashPainter old) => true;
}

// Slight overshoot curve for the icon entrance — feels physical/bouncy.
class _OvershootCurve extends Curve {
  final double period;
  const _OvershootCurve(this.period);

  @override
  double transformInternal(double t) {
    final s = period / 4;
    t -= 1;
    return t * t * ((period + 1) * t + s) + 1;
  }
}

// ─────────────────────────────────────────────
//  ONBOARDING SCREEN
// ─────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fade;

  final Set<String> _selected = {};

  static const Map<String, IconData> _categoryIcons = {
    'Study / Learning': Icons.menu_book_rounded,
    'Exercise / Gym': Icons.fitness_center_rounded,
    'Work / Career': Icons.work_rounded,
    'Reading': Icons.import_contacts_rounded,
    'Meditation': Icons.self_improvement_rounded,
    'Creative Work': Icons.palette_rounded,
    'Cleaning': Icons.cleaning_services_rounded,
    'Side Project': Icons.rocket_launch_rounded,
    'Journaling': Icons.edit_note_rounded,
    'Cooking': Icons.restaurant_rounded,
    'Language Practice': Icons.translate_rounded,
    'Coding': Icons.code_rounded,
  };

  final List<String> _allCategories = [
    'Study / Learning',
    'Exercise / Gym',
    'Work / Career',
    'Reading',
    'Meditation',
    'Creative Work',
    'Cleaning',
    'Side Project',
    'Journaling',
    'Cooking',
    'Language Practice',
    'Coding',
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    OceanHaptics.firstDive();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('categories', _selected.toList());
    await prefs.setInt('currentLayer', 4);
    await prefs.setInt('corals', 700);
    await prefs.setInt('streak', 0);
    await prefs.setInt('highestLayer', 4);
    await prefs.setInt('deepestLayer', 4);
    await prefs.setInt('stormDays', 0);
    await prefs.setBool('rescueAvailable', true);
    await prefs.setInt('rescueDayCounter', 0);
    await prefs.setBool('rescueDayActive', false);
    await prefs.setBool('momentumBonusUsed', false);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030D20),
      body: Stack(
        children: [
          const OceanBackground(layer: 3),
          FadeTransition(
            opacity: _fade,
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 44),
                  const Text(
                    'Productivity',
                    style: TextStyle(
                      color: Color(0xFFF4C842),
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                    ),
                  ),
                  const Text(
                    'DEPTH',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 46,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Where do you stand in the ocean of life?',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'SELECT YOUR PRODUCTIVE ACTIONS',
                        style: TextStyle(
                          color: Color(0xFFF4C842),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Choose at least 3. Each counts once per day.',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 2.7,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: _allCategories.length,
                        itemBuilder: (context, i) {
                          final cat = _allCategories[i];
                          final sel = _selected.contains(cat);
                          final catIcon =
                              _categoryIcons[cat] ?? Icons.circle_outlined;
                          return GestureDetector(
                            onTap: () {
                              OceanHaptics.selectionTick();
                              setState(() =>
                                sel ? _selected.remove(cat) : _selected.add(cat));
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: sel
                                    ? const Color(0xFFF4C842).withOpacity(0.14)
                                    : Colors.white.withOpacity(0.06),
                                border: Border.all(
                                  color: sel
                                      ? const Color(0xFFF4C842).withOpacity(0.65)
                                      : Colors.white.withOpacity(0.1),
                                  width: sel ? 1.5 : 0.5,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Row(
                                  children: [
                                    Icon(
                                      catIcon,
                                      color: sel
                                          ? const Color(0xFFF4C842)
                                          : Colors.white38,
                                      size: 17,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        cat,
                                        style: TextStyle(
                                          color: sel
                                              ? const Color(0xFFF4C842)
                                              : Colors.white60,
                                          fontSize: 12,
                                          fontWeight: sel
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (sel)
                                      const Icon(
                                          Icons.check_circle_rounded,
                                          color: Color(0xFFF4C842),
                                          size: 15),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                    child: Column(
                      children: [
                        Text(
                          '${_selected.length} selected',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _selected.length >= 3 ? _start : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF4C842),
                              disabledBackgroundColor:
                                  Colors.white.withOpacity(0.1),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text(
                              'DIVE IN',
                              style: TextStyle(
                                color: _selected.length >= 3
                                    ? const Color(0xFF1A1A2E)
                                    : Colors.white24,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 3,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  OCEAN BACKGROUND PAINTER
//
//  Two independent animation axes:
//    t1 — primary  47 s cycle  (waves, particle drift, ray sway, creature motion)
//    t2 — secondary 83 s cycle (large-scale drift, pressure pulses, slow sway)
//
//  Combined repeat period: 47 × 83 = 3 901 s ≈ 65 minutes.
//  Each element carries a unique phase seed so no two ever synchronise.
//  Raw elapsed seconds are used throughout — zero modulo discontinuities.
//
//  Performance:
//  • Background gradient shader cached per (layer, size).
//  • Vignette shader cached per layer.
//  • All other per-frame objects allocated on the stack — no heap pressure.
//  • Analytical particle positions — no list allocations.
// ─────────────────────────────────────────────


// ─────────────────────────────────────────────
//  OCEAN BACKGROUND — 60 fps animated scene
//
//  Architecture:
//    • Two AnimationControllers output normalised t ∈ [0,1]:
//        t1 — 47 s primary cycle
//        t2 — 83 s secondary cycle
//    • Combined no-repeat period: 47 × 83 = 3 901 s ≈ 65 min
//    • All motion uses _s(t, n, φ) = sin(t·n·2π + φ) with integer n,
//      guaranteeing value(0) == value(1) → perfect seamless loop.
//    • Gradient shaders cached per (layer, size).
// ─────────────────────────────────────────────

class OceanBackground extends StatefulWidget {
  final int layer;
  const OceanBackground({super.key, required this.layer});

  @override
  State<OceanBackground> createState() => _OceanBackgroundState();
}

class _OceanBackgroundState extends State<OceanBackground>
    with TickerProviderStateMixin {
  late AnimationController _ctrl1;
  late AnimationController _ctrl2;

  @override
  void initState() {
    super.initState();
    _ctrl1 = AnimationController(vsync: this, duration: const Duration(seconds: 47))..repeat();
    _ctrl2 = AnimationController(vsync: this, duration: const Duration(seconds: 83))..repeat();
  }

  @override
  void dispose() { _ctrl1.dispose(); _ctrl2.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_ctrl1, _ctrl2]),
      builder: (_, __) => CustomPaint(
        painter: OceanPainter(
          layer: widget.layer,
          t1: _ctrl1.value,
          t2: _ctrl2.value,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class OceanPainter extends CustomPainter {
  final int layer;
  final double t1;
  final double t2;

  static final Map<int, Shader> _bgCache  = {};
  static final Map<int, Shader> _vigCache = {};
  static final Map<String, Shader> _shaderCache = {};
  static Size _cachedSize = Size.zero;

  static void _invalidateCaches(Size s) {
    _bgCache.clear(); _vigCache.clear(); _shaderCache.clear();
    _cachedSize = s;
  }

  OceanPainter({required this.layer, required this.t1, required this.t2});

  static double _s(double t, int n, double phase) =>
      math.sin(t * n * math.pi * 2 + phase);
  static double _c(double t, int n, double phase) =>
      math.cos(t * n * math.pi * 2 + phase);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (_cachedSize != size) _invalidateCaches(size);

    final data = kLayers[layer];
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
        Paint()..shader = _bgCache.putIfAbsent(layer,
            () => LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [data.topColor, data.bottomColor],
            ).createShader(Rect.fromLTWH(0, 0, w, h))));

    if (layer == 0) {
      _drawIsland(canvas, w, h);
    } else {
      _drawUnderwater(canvas, w, h);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  LAYER 0 — THE ISLAND
  //  "Above the surface, above it all"
  //  Warm, triumphant, sun-drenched paradise with volumetric light.
  // ═══════════════════════════════════════════════════════════════════════════

  void _drawIsland(Canvas canvas, double w, double h) {
    _drawGodRays(canvas, w, h);
    _drawClouds(canvas, w, h);
    _drawSun(canvas, w, h);

    // Sea surface
    final seaShader = _shaderCache.putIfAbsent('islandSea',
        () => const LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFF1B7AA0), Color(0xFF0C3D62)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)));
    canvas.drawRect(Rect.fromLTWH(0, h * 0.50, w, h * 0.50), Paint()..shader = seaShader);

    _drawOceanWave(canvas, w, h, 0.500, wCycles: 3, tCycles: 3, modW: 5, modT: 5, amp: 10.0,
        color: const Color(0xFF1E90B0), opacity: 0.70);
    _drawOceanWave(canvas, w, h, 0.508, wCycles: 5, tCycles: 5, modW: 7, modT: 7, amp:  7.0,
        color: const Color(0xFF28A0C0), opacity: 0.55);
    _drawOceanWave(canvas, w, h, 0.516, wCycles: 7, tCycles: 7, modW: 9, modT: 9, amp:  4.5,
        color: const Color(0xFF35B0CC), opacity: 0.38);

    _drawWaveFoam(canvas, w, h);
    _drawSeaSparkles(canvas, w, h);
    _drawIslandLand(canvas, w, h);
    _drawPalm(canvas, w, h);
    _drawBirds(canvas, w, h);
    _drawButterflies(canvas, w, h);
  }

  void _drawGodRays(Canvas canvas, double w, double h) {
    // Volumetric light shafts from sun position through sky
    final sunX = w * 0.78;
    final sunY = h * 0.13;
    for (int i = 0; i < 5; i++) {
      final sn = (i * 0.2) % 1.0;
      final angle = -0.40 + i * 0.18 + _s(t2, 1, sn * 5.0) * 0.06;
      final rayLen = h * 0.55 + _s(t1, 2 + i % 3, sn * 4.0) * h * 0.04;
      final rayW = 18.0 + _s(t1, 3 + i % 2, sn * 6.28) * 6.0;
      final alpha = 0.028 + _s(t1, 4 + i % 3, sn * 3.0).abs() * 0.018;

      final endX = sunX + math.cos(angle) * rayLen;
      final endY = sunY + math.sin(angle) * rayLen;
      final perpX = math.cos(angle + math.pi / 2) * rayW;
      final perpY = math.sin(angle + math.pi / 2) * rayW;

      final path = Path()
        ..moveTo(sunX - perpX * 0.2, sunY - perpY * 0.2)
        ..lineTo(sunX + perpX * 0.2, sunY + perpY * 0.2)
        ..lineTo(endX + perpX, endY + perpY)
        ..lineTo(endX - perpX, endY - perpY)
        ..close();
      canvas.drawPath(path, Paint()
        ..color = const Color(0xFFFFF8E1).withOpacity(alpha));
    }
  }

  void _drawClouds(Canvas canvas, double w, double h) {
    const seeds  = [0.07, 0.22, 0.38, 0.55, 0.71, 0.86];
    const sizes  = [0.28, 0.18, 0.24, 0.16, 0.22, 0.14];
    const yFracs = [0.06, 0.11, 0.07, 0.14, 0.04, 0.17];
    const drifts = [2,    3,    2,    3,    2,    3   ];

    for (int i = 0; i < 6; i++) {
      final sx = seeds[i];
      final cx = ((sx + t2 * drifts[i]) % 1.0) * w * 1.30 - w * 0.15;
      final cy = h * yFracs[i] + _s(t2, 1, sx * math.pi * 3) * h * 0.006;
      final r  = w * sizes[i];

      // Cloud shadow (subtle depth)
      final shadowP = Paint()..color = Colors.black.withOpacity(0.03);
      canvas.drawOval(Rect.fromCenter(
          center: Offset(cx + 3, cy + 4), width: r * 1.04, height: r * 0.44), shadowP);

      // Main cloud body — layered for volume
      final cp1 = Paint()..color = Colors.white.withOpacity(0.14);
      final cp2 = Paint()..color = Colors.white.withOpacity(0.22);
      final cp3 = Paint()..color = Colors.white.withOpacity(0.10);

      canvas.drawOval(Rect.fromCenter(
          center: Offset(cx, cy + r * 0.05), width: r * 1.10, height: r * 0.46), cp1);
      canvas.drawOval(Rect.fromCenter(
          center: Offset(cx - r * 0.22, cy), width: r * 0.65, height: r * 0.40), cp2);
      canvas.drawOval(Rect.fromCenter(
          center: Offset(cx + r * 0.24, cy - r * 0.02), width: r * 0.58, height: r * 0.36), cp2);
      // Top puff
      canvas.drawOval(Rect.fromCenter(
          center: Offset(cx + r * 0.06, cy - r * 0.12), width: r * 0.42, height: r * 0.28), cp3);
    }
  }

  void _drawSun(Canvas canvas, double w, double h) {
    final sx = w * 0.78;
    final sy = h * 0.13;

    // Outer corona pulse
    final coronaR = 58.0 + _s(t2, 1, 1.1) * 8.0 + _s(t1, 3, 0.5) * 4.0;
    final coronaShader = _shaderCache.putIfAbsent('corona',
        () => RadialGradient(
          colors: [const Color(0xFFFFF176).withOpacity(0.12), const Color(0xFFFFCC00).withOpacity(0.04), Colors.transparent],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCenter(center: Offset(sx, sy), width: 160, height: 160)));
    canvas.drawCircle(Offset(sx, sy), coronaR, Paint()..shader = coronaShader);

    // Inner halo
    final haloR = 44.0 + _s(t1, 2, 1.1) * 5.0;
    canvas.drawCircle(Offset(sx, sy), haloR,
        Paint()..color = const Color(0xFFFFF176).withOpacity(0.18));

    // Sun disc with subtle radial gradient
    canvas.drawCircle(Offset(sx, sy), 32,
        Paint()..color = const Color(0xFFFFF176).withOpacity(0.88));
    canvas.drawCircle(Offset(sx, sy), 20,
        Paint()..color = const Color(0xFFFFFFCC).withOpacity(0.95));

    // Sun flare spikes
    for (int i = 0; i < 8; i++) {
      final angle = i * math.pi / 4 + _s(t2, 1, 0.0) * 0.08;
      final spikeLen = 38.0 + _s(t1, 3 + i % 3, i.toDouble()) * 6.0;
      final alpha = 0.06 + _s(t1, 4 + i % 2, i * 0.8).abs() * 0.04;
      canvas.drawLine(
        Offset(sx + math.cos(angle) * 24, sy + math.sin(angle) * 24),
        Offset(sx + math.cos(angle) * spikeLen, sy + math.sin(angle) * spikeLen),
        Paint()..color = const Color(0xFFFFF8E1).withOpacity(alpha)
          ..strokeWidth = 1.6..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawOceanWave(Canvas canvas, double w, double h, double yFrac,
      {required int wCycles, required int tCycles,
       required int modW,    required int modT,
       required double amp, required Color color, required double opacity}) {
    final baseY = h * yFrac;
    final path = Path()..moveTo(-2, baseY);
    for (double x = 0; x <= w + 2; x += 2) {
      final xn = x / w;
      final y = baseY
          + math.sin(xn * wCycles * math.pi * 2 + t1 * tCycles * math.pi * 2) * amp
          + math.sin(xn * modW * math.pi * 2 + t2 * modT * math.pi * 2 + 1.3) * amp * 0.32;
      path.lineTo(x, y);
    }
    path..lineTo(w + 2, h)..lineTo(-2, h)..close();
    canvas.drawPath(path, Paint()..color = color.withOpacity(opacity));
  }

  void _drawWaveFoam(Canvas canvas, double w, double h) {
    // Tiny white foam dots along wave crests
    for (int i = 0; i < 20; i++) {
      final sn = (i * 0.05) % 1.0;
      final xn = sn;
      final x = xn * w;
      final baseY = h * 0.500;
      final y = baseY
          + math.sin(xn * 3 * math.pi * 2 + t1 * 3 * math.pi * 2) * 10.0
          + math.sin(xn * 5 * math.pi * 2 + t2 * 5 * math.pi * 2 + 1.3) * 3.2
          - 2.0;
      final br = (0.3 + _s(t1, 5 + i % 4, sn * 8.0) * 0.5).clamp(0.0, 1.0);
      if (br > 0.15) {
        canvas.drawCircle(Offset(x, y), 1.0 + br * 1.2,
            Paint()..color = Colors.white.withOpacity(0.18 * br));
      }
    }
  }

  void _drawSeaSparkles(Canvas canvas, double w, double h) {
    for (int i = 0; i < 18; i++) {
      final sn = (i * 0.0556) % 1.0;
      final sx = sn * w + _s(t1, 3 + i % 4, sn * 6.28) * 12.0;
      final sy = h * 0.50 + sn * h * 0.04 + _s(t1, 4 + i % 3, sn * 6.28 + 0.5) * 4.0;
      final br = (0.25 + _s(t1, 5 + i % 5, sn * 6.28) * 0.50).clamp(0.0, 1.0);
      if (br > 0.12) {
        canvas.drawCircle(Offset(sx % w, sy), 1.5 * br,
            Paint()..color = const Color(0xFF6DD5F5).withOpacity(0.50 * br));
        // Tiny cross sparkle on brightest
        if (br > 0.55) {
          final sp = Paint()..color = Colors.white.withOpacity(0.25 * br)..strokeWidth = 0.6;
          canvas.drawLine(Offset(sx % w - 3, sy), Offset(sx % w + 3, sy), sp);
          canvas.drawLine(Offset(sx % w, sy - 3), Offset(sx % w, sy + 3), sp);
        }
      }
    }
  }

  void _drawIslandLand(Canvas canvas, double w, double h) {
    // Beach sand with gradient
    canvas.drawOval(Rect.fromCenter(
        center: Offset(w / 2, h * 0.500), width: w * 0.50, height: h * 0.075),
        Paint()..color = const Color(0xFFD4A574));
    // Wet sand ring
    canvas.drawOval(Rect.fromCenter(
        center: Offset(w / 2, h * 0.504), width: w * 0.52, height: h * 0.068),
        Paint()..color = const Color(0xFFB8956A).withOpacity(0.4)
          ..style = PaintingStyle.stroke..strokeWidth = 2.0);
    // Grass layers
    canvas.drawOval(Rect.fromCenter(
        center: Offset(w / 2, h * 0.482), width: w * 0.32, height: h * 0.055),
        Paint()..color = const Color(0xFF4CAF50));
    canvas.drawOval(Rect.fromCenter(
        center: Offset(w / 2, h * 0.468), width: w * 0.20, height: h * 0.038),
        Paint()..color = const Color(0xFF66BB6A));
    // Tiny flowers
    for (int i = 0; i < 4; i++) {
      final fx = w * 0.40 + i * w * 0.05;
      final fy = h * 0.472 + _s(t2, 1, i * 1.5) * 1.0;
      final br = (0.6 + _s(t1, 3, i.toDouble()) * 0.4).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(fx, fy), 1.5,
          Paint()..color = Color.lerp(const Color(0xFFFF6B6B), const Color(0xFFFFD93D), i / 3.0)!.withOpacity(0.6 * br));
    }
  }

  void _drawPalm(Canvas canvas, double w, double h) {
    final sway = _s(t2, 1, 0.7) * 4.0 + _s(t1, 3, 1.3) * 1.5;
    final base = Offset(w * 0.52 + sway * 0.3, h * 0.465);
    final tip  = Offset(w * 0.50 + sway, h * 0.315);

    // Trunk with subtle curve (two segments)
    final mid = Offset(
      (base.dx + tip.dx) / 2 + sway * 0.4,
      (base.dy + tip.dy) / 2,
    );
    final trunkP = Paint()..color = const Color(0xFF795548)..strokeWidth = 5.0..strokeCap = StrokeCap.round;
    canvas.drawLine(base, mid, trunkP);
    canvas.drawLine(mid, tip, Paint()..color = const Color(0xFF8D6E63)..strokeWidth = 4.0..strokeCap = StrokeCap.round);

    // Trunk texture rings
    for (int r = 0; r < 6; r++) {
      final rt = r / 6.0;
      final rx = base.dx + (tip.dx - base.dx) * rt + sway * 0.3 * rt;
      final ry = base.dy + (tip.dy - base.dy) * rt;
      canvas.drawLine(Offset(rx - 2.5, ry), Offset(rx + 2.5, ry),
          Paint()..color = const Color(0xFF5D4037).withOpacity(0.3)..strokeWidth = 0.8);
    }

    // Fronds with thickness variation
    for (final (double angle, double len, int lp) in [
      (-1.25, w * 0.14, 0), (-0.35, w * 0.15, 1),
      ( 0.45, w * 0.13, 2), (-1.95, w * 0.11, 3), (1.15, w * 0.11, 4),
    ]) {
      final a = angle + _s(t1, 2 + lp, lp.toDouble()) * 0.08 + sway * 0.015;
      final frondEnd = Offset(tip.dx + math.cos(a) * len, tip.dy + math.sin(a) * len * 0.52);
      // Draw frond as two lines for leaf thickness
      final perpAngle = a + math.pi / 2;
      final offset = 1.2;
      canvas.drawLine(
        Offset(tip.dx + math.cos(perpAngle) * offset, tip.dy + math.sin(perpAngle) * offset),
        frondEnd,
        Paint()..color = const Color(0xFF388E3C)..strokeWidth = 2.8..strokeCap = StrokeCap.round);
      canvas.drawLine(
        Offset(tip.dx - math.cos(perpAngle) * offset, tip.dy - math.sin(perpAngle) * offset),
        frondEnd,
        Paint()..color = const Color(0xFF2E7D32)..strokeWidth = 2.2..strokeCap = StrokeCap.round);
    }

    // Coconuts
    for (int ci = 0; ci < 2; ci++) {
      final ca = -0.7 + ci * 0.5 + _s(t1, 2, ci.toDouble()) * 0.04;
      final cx = tip.dx + math.cos(ca) * 6;
      final cy = tip.dy + math.sin(ca) * 4 + 4;
      canvas.drawCircle(Offset(cx, cy), 3.0, Paint()..color = const Color(0xFF5D4037));
      canvas.drawCircle(Offset(cx - 0.8, cy - 0.8), 1.0,
          Paint()..color = const Color(0xFF8D6E63).withOpacity(0.6));
    }
  }

  void _drawBirds(Canvas canvas, double w, double h) {
    for (int i = 0; i < 6; i++) {
      final sn = (i * 0.1666) % 1.0;
      final bx = ((sn + t2 * (2 + i % 2)) % 1.0) * w * 1.20 - w * 0.10;
      final by = h * 0.05 + sn * h * 0.10 + _s(t2, 1, sn * 6.28) * h * 0.025;
      final wf = _s(t1, 4 + i % 3, sn * 6.28) * 4.5;
      final bp = Path()
        ..moveTo(bx - 7, by + wf * 0.5)
        ..quadraticBezierTo(bx - 2, by - wf, bx, by - wf * 0.2)
        ..quadraticBezierTo(bx + 2, by - wf, bx + 7, by + wf * 0.5);
      canvas.drawPath(bp, Paint()
        ..color = Colors.black.withOpacity(0.42)..strokeWidth = 1.4..style = PaintingStyle.stroke);
    }
  }

  void _drawButterflies(Canvas canvas, double w, double h) {
    for (int i = 0; i < 3; i++) {
      final sn = (i * 0.333) % 1.0;
      final bx = w * 0.35 + _s(t1, 2 + i, sn * 5.0) * w * 0.10 + _s(t2, 1, sn * 3.0) * w * 0.04;
      final by = h * 0.36 + _c(t1, 3 + i, sn * 4.0) * h * 0.04 + _c(t2, 1, sn * 2.0) * h * 0.02;
      final wingFlap = _s(t1, 8 + i * 2, sn * 6.28).abs() * 3.5;
      final wingAlpha = 0.3 + _s(t1, 3 + i, sn * 4.0).abs() * 0.15;
      final col = [const Color(0xFFFFAB40), const Color(0xFFFF7043), const Color(0xFFFFD54F)][i];
      // Left wing
      canvas.drawOval(Rect.fromCenter(
          center: Offset(bx - 2.5, by), width: 4.0, height: wingFlap + 1.5),
          Paint()..color = col.withOpacity(wingAlpha));
      // Right wing
      canvas.drawOval(Rect.fromCenter(
          center: Offset(bx + 2.5, by), width: 4.0, height: wingFlap + 1.5),
          Paint()..color = col.withOpacity(wingAlpha));
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  UNDERWATER DISPATCHER
  // ═══════════════════════════════════════════════════════════════════════════

  void _drawUnderwater(Canvas canvas, double w, double h) {
    if      (layer == 1) { _drawClearShallows(canvas, w, h); }
    else if (layer == 2) { _drawCoralReef(canvas, w, h); }
    else if (layer == 3) { _drawFishSchools(canvas, w, h); }
    else if (layer == 4) { _drawNeutralZone(canvas, w, h); }
    else if (layer == 5) { _drawJellyfishDrift(canvas, w, h); }
    else if (layer == 6) { _drawShipwreck(canvas, w, h); }
    else if (layer == 7) { _drawSharkWaters(canvas, w, h); }
    else if (layer == 8) { _drawDeepOcean(canvas, w, h); }
    else if (layer == 9) { _drawAnglerLair(canvas, w, h); }
    else if (layer == 10){ _drawTheAbyss(canvas, w, h); }

    // Biome bubbles
    if ((layer >= 1 && layer <= 4) || layer == 6 || layer == 8 || layer == 9) {
      _drawParticles(canvas, w, h);
    }

    // Deep layer darkening
    if (layer >= 7) {
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
          Paint()..color = Colors.black.withOpacity(((layer - 6) / 5.0).clamp(0.0, 0.60)));
    }
    // Vignette
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
        Paint()..shader = _vigCache.putIfAbsent(layer,
            () => RadialGradient(
              colors: [Colors.transparent, Colors.black.withOpacity((0.18 + layer * 0.030).clamp(0.18, 0.55))],
              radius: 0.78,
            ).createShader(Rect.fromLTWH(0, 0, w, h))));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  LAYER 1 — CLEAR SHALLOWS
  //  "Light reaches all the way down"
  //  Underwater sunlight, rippling surface above, seagrass meadow, tiny fish.
  // ═══════════════════════════════════════════════════════════════════════════

  void _drawClearShallows(Canvas canvas, double w, double h) {
    // Sun disk visible from below surface
    final sunX = w * 0.55 + _s(t2, 1, 0.3) * w * 0.02;
    final sunY = h * 0.06;
    final sunR = 40.0 + _s(t1, 2, 0.5) * 3.0;
    canvas.drawCircle(Offset(sunX, sunY), sunR * 1.8,
        Paint()..color = const Color(0xFFE3F2FD).withOpacity(0.06));
    canvas.drawCircle(Offset(sunX, sunY), sunR,
        Paint()..color = const Color(0xFFBBDEFB).withOpacity(0.12));

    // Rippling surface refraction (seen from below)
    for (int i = 0; i < 8; i++) {
      final sn = (i * 0.125) % 1.0;
      final rx = sn * w + _s(t1, 3 + i % 3, sn * 8.0) * w * 0.06;
      final ry = h * 0.02 + _s(t1, 4 + i % 4, sn * 6.0) * h * 0.015;
      final rLen = w * 0.08 + _s(t1, 2 + i % 5, sn * 5.0) * w * 0.03;
      canvas.drawLine(
        Offset(rx, ry), Offset(rx + rLen, ry + _s(t1, 5 + i % 3, sn * 7.0) * 3.0),
        Paint()..color = Colors.white.withOpacity(0.035)..strokeWidth = 2.0..strokeCap = StrokeCap.round,
      );
    }

    // Enhanced caustic rays
    _drawCausticRays(canvas, w, h, alpha: 0.060, count: 8);

    // Dancing light coins on the floor
    for (int i = 0; i < 12; i++) {
      final sn = (i * 0.0833) % 1.0;
      final lx = sn * w + _s(t1, 3 + i % 5, sn * 9.0) * w * 0.06;
      final ly = h * 0.75 + sn * h * 0.18 + _s(t1, 4 + i % 3, sn * 7.0) * h * 0.02;
      final lr = 8.0 + _s(t1, 5 + i % 4, sn * 5.0) * 4.0;
      final la = (0.020 + _s(t1, 2 + i % 3, sn * 8.0).abs() * 0.018).clamp(0.0, 0.04);
      canvas.drawOval(Rect.fromCenter(
          center: Offset(lx, ly), width: lr * 2, height: lr * 0.6),
          Paint()..color = const Color(0xFF81D4FA).withOpacity(la));
    }

    // Seagrass meadow at bottom
    _drawSeagrass(canvas, w, h);

    // Small tropical fish silhouettes
    _drawSmallFish(canvas, w, h, count: 6, color: const Color(0xFF4FC3F7), yCenter: 0.45);
  }

  // Helper — undulating floor surface Y at a given x for Clear Shallows
  double _shallowFloorY(double x, double w, double h) {
    final xn = x / w;
    return h * 0.92
        + math.sin(xn * 3 * math.pi * 2) * h * 0.008
        + math.sin(xn * 7 * math.pi * 2 + 1.2) * h * 0.004;
  }

  void _drawSeagrass(Canvas canvas, double w, double h) {
    final floorY = h * 0.92;

    // ── Layer 1: Deep rock base (fully opaque, darkest) ──
    // Covers bottom 15% — ensures no water bleed at all
    canvas.drawRect(Rect.fromLTWH(0, floorY + h * 0.02, w, h * 0.15),
        Paint()..color = const Color(0xFF0E2A1E));

    // ── Layer 2: Packed sediment (opaque, slightly lighter) ──
    final sedimentPath = Path()..moveTo(-2, h);
    for (double x = -2; x <= w + 2; x += 4) {
      sedimentPath.lineTo(x, _shallowFloorY(x, w, h) + h * 0.015);
    }
    sedimentPath..lineTo(w + 2, h)..close();
    canvas.drawPath(sedimentPath, Paint()..color = const Color(0xFF163826));

    // Sediment strata line
    final strataPath = Path();
    for (double x = -2; x <= w + 2; x += 4) {
      final y = _shallowFloorY(x, w, h) + h * 0.035;
      if (x <= -2) { strataPath.moveTo(x, y); } else { strataPath.lineTo(x, y); }
    }
    canvas.drawPath(strataPath, Paint()
      ..color = const Color(0xFF1E4A32).withOpacity(0.6)
      ..strokeWidth = 0.8..style = PaintingStyle.stroke);

    // ── Layer 3: Sandy topsoil (opaque, warmest tone) ──
    final sandPath = Path()..moveTo(-2, h);
    for (double x = -2; x <= w + 2; x += 4) {
      sandPath.lineTo(x, _shallowFloorY(x, w, h));
    }
    sandPath..lineTo(w + 2, h)..close();
    canvas.drawPath(sandPath, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: const [Color(0xFF1E5438), Color(0xFF163826)],
      ).createShader(Rect.fromLTWH(0, floorY - 8, w, h * 0.04)));

    // ── Sand surface highlight ──
    final edgePath = Path();
    for (double x = -2; x <= w + 2; x += 4) {
      final y = _shallowFloorY(x, w, h);
      if (x <= -2) { edgePath.moveTo(x, y); } else { edgePath.lineTo(x, y); }
    }
    canvas.drawPath(edgePath, Paint()
      ..color = const Color(0xFF3E8B5E).withOpacity(0.25)
      ..strokeWidth = 1.5..style = PaintingStyle.stroke);

    // ── Embedded pebbles and shells (sit half-in the sand) ──
    for (int i = 0; i < 14; i++) {
      final sn = (i * 0.0714) % 1.0;
      final px = sn * w * 1.05 - w * 0.025;
      final surfY = _shallowFloorY(px, w, h);
      final pebbleW = 3.5 + (i % 3) * 2.5;
      final pebbleH = 2.5 + (i % 2) * 1.5;
      final col = [const Color(0xFF3D5A45), const Color(0xFF4A6B52), const Color(0xFF556B5A)][i % 3];
      // Half-embedded: centre sits at surface, only top half visible
      canvas.drawOval(
        Rect.fromCenter(center: Offset(px, surfY + pebbleH * 0.3), width: pebbleW, height: pebbleH),
        Paint()..color = col,
      );
      // Tiny sand-shadow crescent above
      canvas.drawArc(
        Rect.fromCenter(center: Offset(px, surfY + pebbleH * 0.1), width: pebbleW + 1, height: pebbleH * 0.4),
        3.3, 2.6, false,
        Paint()..color = const Color(0xFF0E2A1E).withOpacity(0.35)
          ..strokeWidth = 0.7..style = PaintingStyle.stroke,
      );
    }

    // ── Seagrass blades rooted into the sand ──
    for (int i = 0; i < 18; i++) {
      final sn = (i * 0.0556) % 1.0;
      final baseX = sn * w * 1.1 - w * 0.05;
      final baseY = _shallowFloorY(baseX, w, h);
      final bladeH = h * 0.08 + sn * h * 0.05;
      final sway = _s(t1, 2 + i % 4, sn * 6.28) * 8.0 + _s(t2, 1, sn * 4.0) * 4.0;
      final tipX = baseX + sway;
      final tipY = baseY - bladeH;
      final col = Color.lerp(const Color(0xFF2E7D32), const Color(0xFF388E3C), sn)!;

      // Root mound — opaque, bulges above sand surface
      canvas.drawOval(
        Rect.fromCenter(center: Offset(baseX, baseY), width: 8.0, height: 5.0),
        Paint()..color = const Color(0xFF245A34),
      );

      // Main blade
      canvas.drawPath(
        Path()..moveTo(baseX, baseY - 1.0)
          ..quadraticBezierTo(baseX + sway * 0.4, baseY - bladeH * 0.5, tipX, tipY),
        Paint()..color = col.withOpacity(0.30)..strokeWidth = 2.2..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );

      // Secondary thinner blade for density
      if (i % 3 == 0) {
        final sway2 = _s(t1, 3 + i % 3, sn * 6.28 + 1.0) * 6.0 + _s(t2, 1, sn * 3.0) * 3.0;
        canvas.drawPath(
          Path()..moveTo(baseX + 3, baseY - 1.0)
            ..quadraticBezierTo(baseX + 3 + sway2 * 0.4, baseY - bladeH * 0.35, baseX + 3 + sway2, baseY - bladeH * 0.7),
          Paint()..color = col.withOpacity(0.20)..strokeWidth = 1.4..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke,
        );
      }
    }
  }

  void _drawSmallFish(Canvas canvas, double w, double h,
      {required int count, required Color color, required double yCenter}) {
    for (int i = 0; i < count; i++) {
      final sn = (i / count) % 1.0;
      final driftN = 2 + (i % 3);
      final fx = ((sn + t1 * driftN) % 1.0) * w * 1.2 - w * 0.1;
      final fy = h * yCenter + _s(t1, 3 + i % 4, sn * 6.28) * h * 0.06;
      final faceRight = (driftN % 2 == 0);
      final fLen = 4.0 + sn * 3.0;
      final alpha = 0.22 + sn * 0.10;
      canvas.drawOval(Rect.fromCenter(
          center: Offset(fx, fy), width: fLen * 2, height: fLen * 0.5),
          Paint()..color = color.withOpacity(alpha));
      final tx = fx + (faceRight ? -fLen : fLen);
      canvas.drawPath(
        Path()..moveTo(tx, fy)
          ..lineTo(tx + (faceRight ? -3 : 3), fy - 2.5)
          ..lineTo(tx + (faceRight ? -3 : 3), fy + 2.5)..close(),
        Paint()..color = color.withOpacity(alpha * 0.7));
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  LAYER 2 — CORAL REEF
  //  "Something beautiful is growing"
  //  A living reef garden viewed from within — brain corals, fan corals,
  //  tube sponges, bioluminescent polyps, reef fish, plankton clouds.
  // ═══════════════════════════════════════════════════════════════════════════

  void _drawCoralReef(Canvas canvas, double w, double h) {
    _drawCausticRays(canvas, w, h, alpha: 0.042, count: 6);
    _drawPlanktonCloud(canvas, w, h);
    _drawReefFloor(canvas, w, h);
    _drawBrainCorals(canvas, w, h);
    _drawFanCorals(canvas, w, h);
    _drawTubeSponges(canvas, w, h);
    _drawStaghornBranches(canvas, w, h);
    _drawReefAnemones(canvas, w, h);
    _drawReefFish(canvas, w, h);
    _drawBioluminescentPolyps(canvas, w, h);
    _drawCoralSpawnParticles(canvas, w, h);
  }

  double _reefFloorY(double x, double w, double h) {
    final xn = x / w;
    return h * 0.82
        + math.sin(xn * 2 * math.pi * 2) * h * 0.012
        + math.sin(xn * 5 * math.pi * 2 + 0.7) * h * 0.006
        + math.sin(xn * 11 * math.pi * 2 + 2.3) * h * 0.003;
  }

  void _drawReefFloor(Canvas canvas, double w, double h) {
    // Bedrock
    canvas.drawRect(Rect.fromLTWH(0, h * 0.84, w, h * 0.20),
        Paint()..color = const Color(0xFF0A1A22));

    // Deep substrate
    final deepPath = Path()..moveTo(-2, h);
    for (double x = -2; x <= w + 2; x += 3) {
      deepPath.lineTo(x, _reefFloorY(x, w, h) + h * 0.03);
    }
    deepPath..lineTo(w + 2, h)..close();
    canvas.drawPath(deepPath, Paint()..color = const Color(0xFF0E2028));

    // Sandy reef surface with warm undertone
    final surfPath = Path()..moveTo(-2, h);
    for (double x = -2; x <= w + 2; x += 3) {
      surfPath.lineTo(x, _reefFloorY(x, w, h));
    }
    surfPath..lineTo(w + 2, h)..close();
    canvas.drawPath(surfPath, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: const [Color(0xFF1A3838), Color(0xFF0E2028)],
      ).createShader(Rect.fromLTWH(0, h * 0.80, w, h * 0.06)));

    // Surface highlight
    final edgePath = Path();
    for (double x = -2; x <= w + 2; x += 3) {
      final y = _reefFloorY(x, w, h);
      if (x <= -2) { edgePath.moveTo(x, y); } else { edgePath.lineTo(x, y); }
    }
    canvas.drawPath(edgePath, Paint()
      ..color = const Color(0xFF2A6858).withOpacity(0.22)
      ..strokeWidth = 1.2..style = PaintingStyle.stroke);

    // Sand ripples
    for (int i = 0; i < 6; i++) {
      final sn = (i * 0.167) % 1.0;
      final ry = _reefFloorY(sn * w, w, h) + h * 0.015 + i * h * 0.005;
      final ripplePath = Path();
      for (double x = sn * w * 0.3; x <= sn * w * 0.3 + w * 0.20; x += 3) {
        final y = ry + math.sin(x / w * 14 * math.pi * 2) * 1.2;
        if (x <= sn * w * 0.3) { ripplePath.moveTo(x, y); } else { ripplePath.lineTo(x, y); }
      }
      canvas.drawPath(ripplePath, Paint()
        ..color = const Color(0xFF1A3838).withOpacity(0.10)
        ..strokeWidth = 0.6..style = PaintingStyle.stroke);
    }
  }

  void _drawBrainCorals(Canvas canvas, double w, double h) {
    const corals = [
      (0.18, 0.55, 0.040, Color(0xFFFF7043)),
      (0.50, 0.48, 0.032, Color(0xFFE91E63)),
      (0.78, 0.52, 0.036, Color(0xFFFF5722)),
      (0.35, 0.72, 0.028, Color(0xFFAB47BC)),
      (0.65, 0.68, 0.034, Color(0xFFFF8A65)),
    ];
    for (int i = 0; i < corals.length; i++) {
      final (xFrac, yFrac, rFrac, col) = corals[i];
      final cx = w * xFrac + _s(t2, 1, i * 1.5) * w * 0.005;
      final surfY = _reefFloorY(cx, w, h);
      final cy = surfY - h * rFrac * 0.5;
      final rx = w * rFrac;
      final ry = h * rFrac * 0.60;

      // Dome body
      canvas.drawOval(Rect.fromCenter(
          center: Offset(cx, cy), width: rx * 2, height: ry * 2),
          Paint()..color = col.withOpacity(0.38));

      // Brain ridges — sinuous lines across the dome
      for (int ridge = 0; ridge < 4; ridge++) {
        final ridgeY = cy - ry * 0.4 + ridge * ry * 0.25;
        final ridgePath = Path();
        final phase = _s(t1, 3 + i % 4, i * 2.0 + ridge * 1.5) * 2.0;
        for (double rx2 = cx - rx * 0.7; rx2 <= cx + rx * 0.7; rx2 += 2) {
          final frac = (rx2 - (cx - rx * 0.7)) / (rx * 1.4);
          final y = ridgeY + math.sin(frac * 5 * math.pi * 2 + phase) * ry * 0.08;
          if (rx2 <= cx - rx * 0.7) { ridgePath.moveTo(rx2, y); } else { ridgePath.lineTo(rx2, y); }
        }
        canvas.drawPath(ridgePath, Paint()
          ..color = col.withOpacity(0.20)
          ..strokeWidth = 0.8..style = PaintingStyle.stroke);
      }

      // Highlight crescent
      canvas.drawArc(
        Rect.fromCenter(center: Offset(cx - rx * 0.15, cy - ry * 0.25), width: rx * 0.8, height: ry * 0.5),
        3.6, 1.8, false,
        Paint()..color = Colors.white.withOpacity(0.07)..strokeWidth = 1.5..style = PaintingStyle.stroke);

      // Root attachment to floor
      canvas.drawOval(Rect.fromCenter(
          center: Offset(cx, surfY), width: rx * 1.3, height: ry * 0.3),
          Paint()..color = const Color(0xFF1A3030));
    }
  }

  void _drawFanCorals(Canvas canvas, double w, double h) {
    const fans = [
      (0.12, 0.10, true, Color(0xFFE040FB)),
      (0.88, 0.08, false, Color(0xFFF06292)),
      (0.25, 0.12, true, Color(0xFFFF80AB)),
      (0.75, 0.14, false, Color(0xFFCE93D8)),
    ];
    for (int i = 0; i < fans.length; i++) {
      final (xFrac, hFrac, facingRight, col) = fans[i];
      final baseX = w * xFrac;
      final baseY = _reefFloorY(baseX, w, h);
      final fanH = h * hFrac;
      final sway = _s(t1, 2 + i % 3, i * 1.7) * 6.0 + _s(t2, 1, i * 2.3) * 3.0;
      final dir = facingRight ? 1.0 : -1.0;

      // Fan skeleton — central stem + radiating veins
      final tipX = baseX + dir * fanH * 0.15 + sway;
      final tipY = baseY - fanH;

      // Central stem
      canvas.drawPath(
        Path()..moveTo(baseX, baseY)
          ..quadraticBezierTo(baseX + sway * 0.4, baseY - fanH * 0.5, tipX, tipY),
        Paint()..color = col.withOpacity(0.45)..strokeWidth = 1.8..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke);

      // Radiating veins from stem
      for (int v = 0; v < 7; v++) {
        final vFrac = 0.25 + v * 0.10;
        final stemX = baseX + (tipX - baseX) * vFrac + sway * vFrac * 0.3;
        final stemY = baseY + (tipY - baseY) * vFrac;
        final vAngle = dir * (-0.6 + v * 0.15) + _s(t1, 3 + (i + v) % 5, i * 1.2 + v * 0.8) * 0.08;
        final vLen = fanH * (0.06 + v * 0.012);
        final vTipX = stemX + math.cos(vAngle - math.pi / 2) * vLen;
        final vTipY = stemY + math.sin(vAngle - math.pi / 2) * vLen;
        canvas.drawLine(Offset(stemX, stemY), Offset(vTipX, vTipY),
            Paint()..color = col.withOpacity(0.28)..strokeWidth = 0.7..strokeCap = StrokeCap.round);
      }

      // Mesh webbing between veins (semi-transparent fill)
      final meshPath = Path()..moveTo(baseX, baseY);
      for (int v = 0; v <= 7; v++) {
        final vFrac = 0.25 + v * 0.10;
        final stemX = baseX + (tipX - baseX) * vFrac + sway * vFrac * 0.3;
        final stemY = baseY + (tipY - baseY) * vFrac;
        final vAngle = dir * (-0.6 + v * 0.15);
        final vLen = fanH * (0.06 + v * 0.012);
        meshPath.lineTo(stemX + math.cos(vAngle - math.pi / 2) * vLen,
                        stemY + math.sin(vAngle - math.pi / 2) * vLen);
      }
      meshPath.lineTo(tipX, tipY);
      meshPath.close();
      canvas.drawPath(meshPath, Paint()..color = col.withOpacity(0.08));

      // Root clump
      canvas.drawOval(Rect.fromCenter(
          center: Offset(baseX, baseY + 1), width: 6, height: 3.5),
          Paint()..color = const Color(0xFF1A3030));
    }
  }

  void _drawTubeSponges(Canvas canvas, double w, double h) {
    const tubes = [
      (0.42, 0.06, Color(0xFFFFAB40)),
      (0.58, 0.05, Color(0xFFFF7043)),
      (0.30, 0.04, Color(0xFFFFA726)),
      (0.70, 0.055, Color(0xFFFF8A65)),
    ];
    for (int i = 0; i < tubes.length; i++) {
      final (xFrac, hFrac, col) = tubes[i];
      final baseX = w * xFrac;
      final baseY = _reefFloorY(baseX, w, h);
      final tubeH = h * hFrac;
      final tubeW = tubeH * 0.30;
      final sway = _s(t1, 3 + i % 3, i * 2.1) * 3.0 + _s(t2, 1, i * 1.4) * 1.5;

      // Tube body
      final topCX = baseX + sway;
      final topCY = baseY - tubeH;
      canvas.drawPath(
        Path()
          ..moveTo(baseX - tubeW * 0.5, baseY)
          ..quadraticBezierTo(baseX - tubeW * 0.5 + sway * 0.3, baseY - tubeH * 0.5,
                              topCX - tubeW * 0.5, topCY)
          ..lineTo(topCX + tubeW * 0.5, topCY)
          ..quadraticBezierTo(baseX + tubeW * 0.5 + sway * 0.3, baseY - tubeH * 0.5,
                              baseX + tubeW * 0.5, baseY)
          ..close(),
        Paint()..color = col.withOpacity(0.35));

      // Opening at top
      canvas.drawOval(Rect.fromCenter(
          center: Offset(topCX, topCY), width: tubeW, height: tubeW * 0.40),
          Paint()..color = col.withOpacity(0.50));
      canvas.drawOval(Rect.fromCenter(
          center: Offset(topCX, topCY), width: tubeW * 0.5, height: tubeW * 0.20),
          Paint()..color = const Color(0xFF1A2020).withOpacity(0.6));

      // Texture lines
      for (int tl = 1; tl <= 3; tl++) {
        final ty = baseY - tubeH * tl * 0.25;
        final tx = baseX + sway * tl * 0.25 / 3;
        canvas.drawLine(Offset(tx - tubeW * 0.35, ty), Offset(tx + tubeW * 0.35, ty),
            Paint()..color = col.withOpacity(0.15)..strokeWidth = 0.5);
      }
    }
  }

  void _drawStaghornBranches(Canvas canvas, double w, double h) {
    const clusters = [
      (0.15, Color(0xFFFF5722)),
      (0.52, Color(0xFFE91E63)),
      (0.85, Color(0xFFFF7043)),
    ];
    for (int ci = 0; ci < clusters.length; ci++) {
      final (xFrac, col) = clusters[ci];
      final baseX = w * xFrac;
      final baseY = _reefFloorY(baseX, w, h);

      for (int b = 0; b < 4; b++) {
        final angle = -1.2 + b * 0.55 + _s(t1, 2 + (ci + b) % 4, ci * 1.5 + b * 0.8) * 0.06;
        final branchLen = h * 0.04 + b * h * 0.008;
        final sway = _s(t1, 3 + (ci + b) % 3, ci * 2.0 + b * 1.2) * 3.0;
        final tipX = baseX + math.cos(angle) * branchLen + sway;
        final tipY = baseY + math.sin(angle) * branchLen;

        canvas.drawPath(
          Path()..moveTo(baseX, baseY)
            ..quadraticBezierTo(
              baseX + math.cos(angle) * branchLen * 0.5 + sway * 0.4,
              baseY + math.sin(angle) * branchLen * 0.5,
              tipX, tipY),
          Paint()..color = col.withOpacity(0.40)
            ..strokeWidth = 2.0..strokeCap = StrokeCap.round..style = PaintingStyle.stroke);

        // Sub-branches
        for (int sb = 0; sb < 2; sb++) {
          final subFrac = 0.4 + sb * 0.3;
          final sx = baseX + (tipX - baseX) * subFrac;
          final sy = baseY + (tipY - baseY) * subFrac;
          final subAngle = angle + (sb == 0 ? -0.5 : 0.5);
          final subLen = branchLen * 0.35;
          canvas.drawLine(Offset(sx, sy),
              Offset(sx + math.cos(subAngle) * subLen, sy + math.sin(subAngle) * subLen),
              Paint()..color = col.withOpacity(0.28)
                ..strokeWidth = 1.2..strokeCap = StrokeCap.round);
        }

        // Polyp tip
        canvas.drawCircle(Offset(tipX, tipY), 2.0,
            Paint()..color = col.withOpacity(0.50));
      }
    }
  }

  void _drawReefAnemones(Canvas canvas, double w, double h) {
    const anemones = [
      (0.22, Color(0xFFE040FB), 9),
      (0.48, Color(0xFFFF5252), 11),
      (0.72, Color(0xFFFFAB40), 8),
      (0.38, Color(0xFFF48FB1), 10),
      (0.62, Color(0xFFCE93D8), 9),
    ];
    for (int ai = 0; ai < anemones.length; ai++) {
      final (xFrac, col, tentCount) = anemones[ai];
      final baseX = w * xFrac;
      final baseY = _reefFloorY(baseX, w, h);

      // Base column
      canvas.drawOval(Rect.fromCenter(
          center: Offset(baseX, baseY - 2), width: 10, height: 5),
          Paint()..color = col.withOpacity(0.20));

      // Tentacles — fan out in a crown
      for (int t = 0; t < tentCount; t++) {
        final spread = math.pi * 0.85;
        final angle = -math.pi / 2 - spread / 2 + t * spread / (tentCount - 1);
        final tentLen = h * 0.025 + (t % 3) * h * 0.006;
        final sway = _s(t1, 3 + (ai + t) % 5, ai * 1.5 + t * 0.7) * 5.0
                   + _s(t2, 1, ai * 2.0 + t * 0.4) * 2.5;
        final midX = baseX + math.cos(angle) * tentLen * 0.5 + sway * 0.4;
        final midY = baseY - 3 + math.sin(angle) * tentLen * 0.5;
        final tipX = baseX + math.cos(angle) * tentLen + sway;
        final tipY = baseY - 3 + math.sin(angle) * tentLen;

        canvas.drawPath(
          Path()..moveTo(baseX, baseY - 3)..quadraticBezierTo(midX, midY, tipX, tipY),
          Paint()..color = col.withOpacity(0.30)..strokeWidth = 1.3..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke);

        // Glowing tip
        final tipGlow = (0.35 + _s(t1, 5 + (ai + t) % 4, ai * 0.8 + t * 1.1).abs() * 0.25).clamp(0.0, 0.6);
        canvas.drawCircle(Offset(tipX, tipY), 1.3,
            Paint()..color = col.withOpacity(tipGlow));
      }
    }
  }

  void _drawReefFish(Canvas canvas, double w, double h) {
    const fishDefs = [
      (Color(0xFFFF7043), 3, 5.5), (Color(0xFFE91E63), 5, 4.0),
      (Color(0xFF29B6F6), 4, 6.0), (Color(0xFFFFAB40), 2, 4.5),
    ];
    for (int gi = 0; gi < fishDefs.length; gi++) {
      final (col, driftN, baseLen) = fishDefs[gi];
      final goesRight = driftN % 2 == 0;
      for (int fi = 0; fi < 3; fi++) {
        final sn = (gi * 0.25 + fi * 0.08) % 1.0;
        final phase = (sn + t1 * driftN) % 1.0;
        // Even driftN → left-to-right.  Odd driftN → right-to-left.
        final fx = goesRight
            ? phase * w * 1.3 - w * 0.15
            : (1.0 - phase) * w * 1.3 - w * 0.15;
        final swimY = h * 0.30 + sn * h * 0.42;
        final fy = swimY + _s(t1, 3 + (gi + fi) % 4, sn * 6.28) * h * 0.03;
        final fLen = baseLen + fi * 1.0;
        final alpha = 0.25 + sn * 0.08;

        canvas.drawOval(Rect.fromCenter(
            center: Offset(fx, fy), width: fLen * 2.2, height: fLen * 0.55),
            Paint()..color = col.withOpacity(alpha));
        // Belly
        canvas.drawOval(Rect.fromCenter(
            center: Offset(fx, fy + fLen * 0.06), width: fLen * 1.5, height: fLen * 0.18),
            Paint()..color = Colors.white.withOpacity(alpha * 0.20));
        // Tail — always behind the direction of travel
        final tx = fx + (goesRight ? -fLen * 1.0 : fLen * 1.0);
        canvas.drawPath(
          Path()..moveTo(tx, fy)
            ..lineTo(tx + (goesRight ? -4 : 4), fy - 3)
            ..lineTo(tx + (goesRight ? -4 : 4), fy + 3)..close(),
          Paint()..color = col.withOpacity(alpha * 0.65));
      }
    }
  }

  void _drawBioluminescentPolyps(Canvas canvas, double w, double h) {
    for (int i = 0; i < 16; i++) {
      final sn = (i * 0.0625) % 1.0;
      final px = sn * w + _s(t2, 1, sn * 5.0) * w * 0.02;
      final py = _reefFloorY(px, w, h) - h * 0.005 - (i % 3) * h * 0.006;
      final pulse = (0.2 + _s(t1, 4 + i % 5, sn * 7.0 + i * 0.5) * 0.5).clamp(0.0, 0.7);
      if (pulse < 0.08) continue;
      final col = [const Color(0xFF00E5FF), const Color(0xFF76FF03), const Color(0xFFE040FB),
                    const Color(0xFFFFD740)][i % 4];

      // Glow halo
      canvas.drawCircle(Offset(px, py), 4.0 * pulse,
          Paint()..color = col.withOpacity(0.05 * pulse));
      // Polyp dot
      canvas.drawCircle(Offset(px, py), 1.2 * pulse + 0.5,
          Paint()..color = col.withOpacity(0.35 * pulse));
    }
  }

  void _drawPlanktonCloud(Canvas canvas, double w, double h) {
    for (int i = 0; i < 20; i++) {
      final sn = (i * 0.05) % 1.0;
      final driftN = 1 + (i % 3);
      final riseN = 1 + (i % 2);
      final px = ((sn + t1 * driftN) % 1.0) * w;
      final py = ((sn * 0.7 + t1 * riseN * 0.2) % 1.0) * h * 0.70 + h * 0.05;
      final alpha = 0.04 + _s(t1, 5 + i % 5, sn * 8.0).abs() * 0.04;
      if (alpha < 0.01) continue;
      canvas.drawCircle(Offset(px, py), 0.7 + sn * 0.5,
          Paint()..color = const Color(0xFFB2EBF2).withOpacity(alpha));
    }
  }

  void _drawCoralSpawnParticles(Canvas canvas, double w, double h) {
    for (int i = 0; i < 14; i++) {
      final sn = (i * 0.0714) % 1.0;
      final riseN = 1 + (i % 3);
      final ny = 1.0 - (sn + t1 * riseN) % 1.0;
      final nx = sn + _s(t1, 2 + i % 4, sn * 6.28) * 0.06;
      final px = (nx % 1.0) * w;
      final py = ny * h;
      final edgeFade = (math.min(ny, 1.0 - ny) * 5.0).clamp(0.0, 1.0);
      final alpha = (0.12 + _s(t1, 3 + i % 3, sn * 5.0).abs() * 0.12) * edgeFade;
      if (alpha < 0.015) continue;
      final col = [const Color(0xFFFF7043), const Color(0xFFE91E63), const Color(0xFFAB47BC),
                    const Color(0xFFFFAB40)][i % 4];
      // Glow
      canvas.drawCircle(Offset(px, py), 3.0,
          Paint()..color = col.withOpacity(alpha * 0.3));
      canvas.drawCircle(Offset(px, py), 1.0,
          Paint()..color = col.withOpacity(alpha));
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  LAYER 3 — FISH SCHOOLS
  //  "Movement, but no clear direction"
  //  Multiple schools swirling with kelp silhouettes and dimming light.
  // ═══════════════════════════════════════════════════════════════════════════

  void _drawFishSchools(Canvas canvas, double w, double h) {
    _drawCausticRays(canvas, w, h, alpha: 0.022, count: 4);
    _drawKelpForest(canvas, w, h);
    _drawFishSchool(canvas, w, h);
    _drawScatteredFish(canvas, w, h);
  }

  // Helper — undulating floor surface Y at a given x for Fish Schools
  double _fishFloorY(double x, double w, double h) {
    final xn = x / w;
    return h * 0.90
        + math.sin(xn * 4 * math.pi * 2) * h * 0.010
        + math.sin(xn * 9 * math.pi * 2 + 0.8) * h * 0.005
        + math.sin(xn * 2 * math.pi * 2 + 2.1) * h * 0.006;
  }

  void _drawKelpForest(Canvas canvas, double w, double h) {
    final floorY = h * 0.90;

    // ── Layer 1: Bedrock base (fully opaque, darkest) ──
    canvas.drawRect(Rect.fromLTWH(0, floorY + h * 0.02, w, h * 0.15),
        Paint()..color = const Color(0xFF060E14));

    // ── Layer 2: Deep rock stratum ──
    final deepRockPath = Path()..moveTo(-2, h);
    for (double x = -2; x <= w + 2; x += 3) {
      deepRockPath.lineTo(x, _fishFloorY(x, w, h) + h * 0.025);
    }
    deepRockPath..lineTo(w + 2, h)..close();
    canvas.drawPath(deepRockPath, Paint()..color = const Color(0xFF0A1820));

    // Deep strata line
    final deepStrataPath = Path();
    for (double x = -2; x <= w + 2; x += 3) {
      final y = _fishFloorY(x, w, h) + h * 0.045;
      if (x <= -2) { deepStrataPath.moveTo(x, y); } else { deepStrataPath.lineTo(x, y); }
    }
    canvas.drawPath(deepStrataPath, Paint()
      ..color = const Color(0xFF14282E).withOpacity(0.7)
      ..strokeWidth = 0.6..style = PaintingStyle.stroke);

    // ── Layer 3: Mid rock layer ──
    final midRockPath = Path()..moveTo(-2, h);
    for (double x = -2; x <= w + 2; x += 3) {
      midRockPath.lineTo(x, _fishFloorY(x, w, h) + h * 0.012);
    }
    midRockPath..lineTo(w + 2, h)..close();
    canvas.drawPath(midRockPath, Paint()..color = const Color(0xFF0E2028));

    // ── Layer 4: Rock surface (topmost, slightly lighter) ──
    final surfPath = Path()..moveTo(-2, h);
    for (double x = -2; x <= w + 2; x += 3) {
      surfPath.lineTo(x, _fishFloorY(x, w, h));
    }
    surfPath..lineTo(w + 2, h)..close();
    canvas.drawPath(surfPath, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: const [Color(0xFF152E38), Color(0xFF0E2028)],
      ).createShader(Rect.fromLTWH(0, floorY - 10, w, h * 0.03)));

    // ── Rocky edge highlight ──
    final edgePath = Path();
    for (double x = -2; x <= w + 2; x += 3) {
      final y = _fishFloorY(x, w, h);
      if (x <= -2) { edgePath.moveTo(x, y); } else { edgePath.lineTo(x, y); }
    }
    canvas.drawPath(edgePath, Paint()
      ..color = const Color(0xFF2A5568).withOpacity(0.30)
      ..strokeWidth = 1.5..style = PaintingStyle.stroke);

    // ── Embedded boulders ──
    for (int i = 0; i < 8; i++) {
      final sn = (i * 0.125) % 1.0;
      final bx = sn * w;
      final surfY = _fishFloorY(bx, w, h);
      final bW = 10.0 + (i % 3) * 6.0;
      final bH = 6.0 + (i % 2) * 3.0;
      // Boulder sits half-embedded in the rock surface
      canvas.drawOval(
        Rect.fromCenter(center: Offset(bx, surfY + bH * 0.25), width: bW, height: bH),
        Paint()..color = const Color(0xFF1A3442),
      );
      // Shadow crescent above boulder
      canvas.drawArc(
        Rect.fromCenter(center: Offset(bx, surfY), width: bW + 2, height: bH * 0.35),
        3.3, 2.6, false,
        Paint()..color = const Color(0xFF060E14).withOpacity(0.4)
          ..strokeWidth = 0.8..style = PaintingStyle.stroke,
      );
    }

    // ── Kelp stalks rooted into the rock ──
    for (int i = 0; i < 6; i++) {
      final sn = (i * 0.167) % 1.0;
      final baseX = w * 0.08 + sn * w * 0.84;
      final baseY = _fishFloorY(baseX, w, h);
      final kelpH = h * 0.30 + sn * h * 0.15;
      final sway = _s(t1, 2 + i % 3, sn * 5.0) * 12.0 + _s(t2, 1, sn * 3.0) * 6.0;

      // Holdfast — opaque root mass gripping rock surface
      canvas.drawOval(
        Rect.fromCenter(center: Offset(baseX, baseY), width: 14.0, height: 7.0),
        Paint()..color = const Color(0xFF1A3A28),
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(baseX - 3, baseY - 0.5), width: 8.0, height: 4.5),
        Paint()..color = const Color(0xFF245A34).withOpacity(0.7),
      );

      // Kelp stalk
      final path = Path()..moveTo(baseX, baseY - 2.0);
      for (double frac = 0; frac <= 1.0; frac += 0.1) {
        final swayAt = sway * frac * frac;
        path.lineTo(
          baseX + swayAt + _s(t1, 4 + i % 3, sn * 6.28 + frac * 3.0) * 4.0 * frac,
          baseY - kelpH * frac,
        );
      }

      canvas.drawPath(path, Paint()
        ..color = const Color(0xFF1B5E20).withOpacity(0.18)
        ..strokeWidth = 3.5..strokeCap = StrokeCap.round..style = PaintingStyle.stroke);

      // Kelp leaves
      for (int leaf = 1; leaf <= 3; leaf++) {
        final lFrac = leaf * 0.25;
        final lx = baseX + sway * lFrac * lFrac;
        final ly = baseY - kelpH * lFrac;
        final dir = leaf % 2 == 0 ? 1.0 : -1.0;
        final leafSway = _s(t1, 3 + (i + leaf) % 4, sn * 5.0 + leaf * 1.2) * 3.0;
        canvas.drawOval(Rect.fromCenter(
            center: Offset(lx + dir * 6 + leafSway, ly), width: 10, height: 3.5),
            Paint()..color = const Color(0xFF2E7D32).withOpacity(0.14));
      }
    }
  }

  void _drawFishSchool(Canvas canvas, double w, double h) {
    final cx = w * 0.50 + _s(t1, 2, 0.0) * w * 0.126 + _s(t2, 1, 1.2) * w * 0.036;
    final cy = h * 0.44 + _c(t1, 3, 0.5) * h * 0.099 + _c(t2, 1, 2.1) * h * 0.027;
    final schoolVX = _c(t1, 2, 0.0);

    const count = 38;
    for (int i = 0; i < count; i++) {
      final sn    = (i * 0.0263) % 1.0;
      final phase = sn * math.pi * 2;
      final n1    = 3 + i % 5;
      final n2    = 4 + i % 4;
      final fx = cx + _s(t1, n1, phase) * w * 0.099 + _s(t2, 1, phase + 1.0) * w * 0.018;
      final fy = cy + _c(t1, n2, phase + 0.7) * h * 0.081 + _c(t2, 1, phase + 2.0) * h * 0.018;
      if (fx < -12 || fx > w + 12 || fy < -12 || fy > h + 12) continue;

      final faceRight = (schoolVX + _c(t1, n1, phase) * 0.25) >= 0;
      final fishLen   = 5.5 + sn * 4.0;
      final alpha     = 0.28 + sn * 0.14;

      canvas.drawOval(Rect.fromCenter(center: Offset(fx, fy),
          width: fishLen * 2.2, height: fishLen * 0.64),
          Paint()..color = const Color(0xFF29B6F6).withOpacity(alpha));
      canvas.drawOval(Rect.fromCenter(
          center: Offset(fx + (faceRight ? fishLen * 0.10 : -fishLen * 0.10), fy + 1.0),
          width: fishLen * 1.2, height: fishLen * 0.22),
          Paint()..color = Colors.white.withOpacity(alpha * 0.26));
      final tx = fx + (faceRight ? -fishLen : fishLen);
      canvas.drawPath(
        Path()..moveTo(tx, fy)
              ..lineTo(tx + (faceRight ? -5 : 5), fy - 4)
              ..lineTo(tx + (faceRight ? -5 : 5), fy + 4)..close(),
        Paint()..color = const Color(0xFF29B6F6).withOpacity(alpha * 0.72));
    }
  }

  void _drawScatteredFish(Canvas canvas, double w, double h) {
    // A few larger solitary fish with more detail
    for (int i = 0; i < 3; i++) {
      final sn = (i * 0.333) % 1.0;
      final driftN = 1 + (i % 2);
      final fx = ((sn + t2 * driftN) % 1.0) * w * 1.3 - w * 0.15;
      final fy = h * 0.20 + i * h * 0.22 + _s(t1, 2 + i, sn * 4.0) * h * 0.03;
      final fLen = 12.0 + i * 3.0;
      final faceRight = driftN % 2 == 0;

      // Body
      canvas.drawOval(Rect.fromCenter(
          center: Offset(fx, fy), width: fLen * 2.4, height: fLen * 0.7),
          Paint()..color = const Color(0xFF0288D1).withOpacity(0.20));
      // Belly highlight
      canvas.drawOval(Rect.fromCenter(
          center: Offset(fx, fy + fLen * 0.08), width: fLen * 1.8, height: fLen * 0.25),
          Paint()..color = Colors.white.withOpacity(0.06));
      // Tail
      final tx = fx + (faceRight ? -fLen * 1.1 : fLen * 1.1);
      canvas.drawPath(
        Path()..moveTo(tx, fy)
          ..lineTo(tx + (faceRight ? -8 : 8), fy - 6)
          ..lineTo(tx + (faceRight ? -8 : 8), fy + 6)..close(),
        Paint()..color = const Color(0xFF0288D1).withOpacity(0.16));
      // Eye
      final ex = fx + (faceRight ? fLen * 0.5 : -fLen * 0.5);
      canvas.drawCircle(Offset(ex, fy - 1), 1.5,
          Paint()..color = Colors.white.withOpacity(0.15));
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  LAYER 4 — NEUTRAL ZONE
  //  "Still water. Neither rising nor falling"
  //  Vast empty suspension. Marine snow. Faint aurora-like color shifts.
  // ═══════════════════════════════════════════════════════════════════════════

  void _drawNeutralZone(Canvas canvas, double w, double h) {
    // Thermocline bands
    for (int i = 0; i < 3; i++) {
      final ly = h * (0.30 + i * 0.18) + _s(t2, 1, i * 1.5) * h * 0.008;
      canvas.drawRect(Rect.fromLTWH(0, ly - 0.5, w, 1.2),
          Paint()..color = Colors.white.withOpacity(0.018));
    }

    // Subtle aurora-like color shifts
    final auroraPhase = t2;
    for (int i = 0; i < 3; i++) {
      final sn = (i * 0.333) % 1.0;
      final ax = w * (0.2 + sn * 0.6) + _s(t2, 1, sn * 4.0) * w * 0.15;
      final ay = h * (0.3 + sn * 0.3) + _c(t2, 1, sn * 3.0) * h * 0.08;
      final ar = w * 0.25 + _s(t1, 2, sn * 5.0) * w * 0.05;
      final hue = (auroraPhase * 1 + sn) % 1.0;
      final col = Color.lerp(
        const Color(0xFF42A5F5),
        const Color(0xFF26C6DA),
        hue,
      )!;
      canvas.drawOval(Rect.fromCenter(
          center: Offset(ax, ay), width: ar * 2, height: ar * 0.6),
          Paint()..color = col.withOpacity(0.012));
    }

    // Marine snow — very faint, barely visible suspended particles
    for (int i = 0; i < 20; i++) {
      final sn = (i * 0.05) % 1.0;
      final driftN = 1;
      final nx = (sn + t2 * driftN * 0.3) % 1.0;
      final riseN = 1;
      final ny = (sn * 0.7 + t1 * riseN * 0.15) % 1.0;
      final px = nx * w + _s(t1, 3 + i % 4, sn * 8.0) * 6.0;
      final py = ny * h + _s(t1, 4 + i % 3, sn * 6.0) * 4.0;
      final alpha = 0.05 + _s(t1, 5 + i % 5, sn * 7.0).abs() * 0.04;
      canvas.drawCircle(Offset(px, py), 0.8 + sn * 0.5,
          Paint()..color = Colors.white.withOpacity(alpha));
    }

    // Horizontal current drift lines
    for (int i = 0; i < 4; i++) {
      final sn = (i * 0.25) % 1.0;
      final ly = h * (0.25 + sn * 0.50);
      final driftN = 1;
      final lx = ((sn + t1 * driftN) % 1.0) * w * 1.4 - w * 0.2;
      final lineLen = w * 0.12 + _s(t1, 2 + i, sn * 4.0) * w * 0.03;
      canvas.drawLine(
        Offset(lx, ly), Offset(lx + lineLen, ly + _s(t1, 3 + i, sn * 5.0) * 2.0),
        Paint()..color = Colors.white.withOpacity(0.015)..strokeWidth = 0.8..strokeCap = StrokeCap.round,
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  LAYER 5 — JELLYFISH DRIFT
  //  "Carried by the current, not the will"
  //  Ethereal jellyfish with trailing tentacles and bioluminescent pulses.
  // ═══════════════════════════════════════════════════════════════════════════

  void _drawJellyfishDrift(Canvas canvas, double w, double h) {
    const colors = [
      Color(0xFFCE93D8), Color(0xFFF48FB1),
      Color(0xFFE040FB), Color(0xFFF06292), Color(0xFFBA68C8),
    ];
    const count = 12;

    for (int i = 0; i < count; i++) {
      final sn  = (i * 0.0833) % 1.0;
      final col = colors[i % colors.length];

      // Diagonal drift
      final xDriftN = 1 + (i % 4);
      final yDriftN = 1 + (i % 3);
      final nx = (sn + t1 * xDriftN) % 1.0;
      final ny = 1.0 - (sn * 0.7 + t1 * yDriftN) % 1.0;

      // Wobble
      final xWob = _s(t1, 2 + (i % 4), sn * math.pi * 7.5) * w * 0.045
                 + _s(t2, 1, sn * math.pi * 4.0) * w * 0.018;
      final yWob = _s(t1, 2 + (i % 5), sn * math.pi * 6.2) * h * 0.030;

      final bx = (nx * w + xWob).clamp(0.0, w);
      final by = (ny * h + yWob).clamp(0.0, h);

      // Size and pulse
      final baseR = 10.0 + sn * 14.0;
      final pulsePhase = _s(t1, 3 + (i % 4), sn * 6.28 + 2.0);
      final pulse = 0.85 + pulsePhase * 0.15;
      var rp = baseR * pulse;

      // Edge fade
      final xEdge = math.min(nx, 1.0 - nx) * 5.0;
      final yEdge = ny * 4.0;
      final edgeFade = (math.min(xEdge, yEdge)).clamp(0.0, 1.0);

      final baseAlpha = (0.16 + sn * 0.08) * edgeFade;
      if (baseAlpha < 0.01) continue;

      rp *= (0.5 + edgeFade * 0.5).clamp(0.0, 1.0);
      if (rp < 1.0) continue;

      // Outer glow
      canvas.drawCircle(Offset(bx, by), rp * 1.6,
          Paint()..shader = RadialGradient(
            colors: [col.withOpacity(baseAlpha * 0.30), Colors.transparent],
          ).createShader(Rect.fromCenter(center: Offset(bx, by),
              width: rp * 3.2, height: rp * 3.2)));

      // Bell (dome shape)
      final bellPath = Path()
        ..moveTo(bx - rp, by)
        ..quadraticBezierTo(bx - rp, by - rp * 0.8, bx, by - rp)
        ..quadraticBezierTo(bx + rp, by - rp * 0.8, bx + rp, by)
        ..quadraticBezierTo(bx + rp * 0.4, by + rp * 0.15, bx, by + rp * 0.1)
        ..quadraticBezierTo(bx - rp * 0.4, by + rp * 0.15, bx - rp, by)
        ..close();
      canvas.drawPath(bellPath, Paint()..color = col.withOpacity(baseAlpha));

      // Bell rim highlight
      canvas.drawPath(
        Path()
          ..moveTo(bx - rp * 0.8, by)
          ..quadraticBezierTo(bx, by + rp * 0.12, bx + rp * 0.8, by),
        Paint()..color = Colors.white.withOpacity(baseAlpha * 0.4)
          ..style = PaintingStyle.stroke..strokeWidth = 0.8,
      );

      // Specular highlight
      if (rp > 4.0) {
        canvas.drawCircle(Offset(bx - rp * 0.25, by - rp * 0.35), rp * 0.18,
            Paint()..color = Colors.white.withOpacity(baseAlpha * 0.55));
      }

      // Trailing tentacles
      if (rp > 5.0) {
        final tentCount = rp > 10 ? 5 : 3;
        for (int t = 0; t < tentCount; t++) {
          final tentX = bx - rp * 0.6 + t * (rp * 1.2 / (tentCount - 1));
          final tentSway = _s(t1, 4 + (i + t) % 5, sn * 6.28 + t * 1.2) * rp * 0.3;
          final tentLen = rp * (0.8 + sn * 0.6) * (pulsePhase > 0 ? 1.0 : 0.7);
          canvas.drawPath(
            Path()..moveTo(tentX, by + rp * 0.08)
              ..quadraticBezierTo(tentX + tentSway * 0.5, by + tentLen * 0.5,
                                  tentX + tentSway, by + tentLen),
            Paint()..color = col.withOpacity(baseAlpha * 0.45)
              ..strokeWidth = 0.8..strokeCap = StrokeCap.round..style = PaintingStyle.stroke,
          );
        }
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  LAYER 6 — THE SHIPWRECK
  //  "Where forgotten ships sleep"
  //  Detailed wreck with seaweed growth, ghostly porthole glow, floating debris.
  // ═══════════════════════════════════════════════════════════════════════════

  void _drawShipwreck(Canvas canvas, double w, double h) {
    _drawWreckSeafloor(canvas, w, h);
    _drawWreckSeaweed(canvas, w, h);
    _drawWreckHull(canvas, w, h);
    _drawWreckDebris(canvas, w, h);
    _drawFloatingDebris(canvas, w, h);
  }

  void _drawWreckSeafloor(Canvas canvas, double w, double h) {
    canvas.drawRect(Rect.fromLTWH(0, h * 0.87, w, h * 0.13),
        Paint()..shader = LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.transparent, const Color(0xFF0C1820).withOpacity(0.75)])
            .createShader(Rect.fromLTWH(0, h * 0.87, w, h * 0.13)));
  }

  void _drawWreckSeaweed(Canvas canvas, double w, double h) {
    // Seaweed growing from hull and floor
    for (int i = 0; i < 8; i++) {
      final sn = (i * 0.125) % 1.0;
      final baseX = w * 0.25 + sn * w * 0.50;
      final baseY = h * 0.88 + sn * h * 0.06;
      final weedH = h * 0.06 + sn * h * 0.04;
      final sway = _s(t1, 2 + i % 3, sn * 5.0) * 7.0 + _s(t2, 1, sn * 3.0) * 3.0;
      canvas.drawPath(
        Path()..moveTo(baseX, baseY)
          ..quadraticBezierTo(baseX + sway * 0.5, baseY - weedH * 0.5, baseX + sway, baseY - weedH),
        Paint()..color = const Color(0xFF1B5E20).withOpacity(0.22)
          ..strokeWidth = 1.8..strokeCap = StrokeCap.round..style = PaintingStyle.stroke,
      );
    }
  }

  void _drawWreckHull(Canvas canvas, double w, double h) {
    canvas.save();
    canvas.translate(w * 0.48, h * 0.79);
    canvas.rotate(0.24);

    final hL = w * 0.40;
    final hD = h * 0.078;

    // Main hull
    final hull = Path()
      ..moveTo(-hL, -hD * 0.28)
      ..lineTo(-hL,  hD * 1.00)
      ..quadraticBezierTo(-hL * 0.50, hD * 1.20,  0,         hD * 1.15)
      ..quadraticBezierTo( hL * 0.60, hD * 1.18,  hL * 0.80, hD * 0.68)
      ..lineTo(hL * 0.85, -hD * 0.05)
      ..lineTo(hL * 0.70, -hD * 0.42)
      ..lineTo(hL * 0.48, -hD * 0.46)
      ..lineTo(hL * 0.44, -hD * 0.32)
      ..lineTo(hL * 0.18, -hD * 0.48)
      ..lineTo(-hL * 0.30, -hD * 0.50)
      ..lineTo(-hL * 0.82, -hD * 0.36)
      ..close();

    canvas.drawPath(hull, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [const Color(0xFF1E2E3C), const Color(0xFF0E1820)])
          .createShader(Rect.fromCenter(center: Offset.zero, width: hL * 2, height: hD * 2.6)));

    // Hull plating lines
    for (int pl = 0; pl < 5; pl++) {
      final px = -hL * 0.76 + pl * hL * 0.36;
      canvas.drawLine(Offset(px, -hD * 0.28), Offset(px + hD * 0.07, hD * 0.88),
          Paint()..color = const Color(0xFF28404E).withOpacity(0.48)..strokeWidth = 1.1);
    }

    // Bio-growth patches
    for (int bp = 0; bp < 5; bp++) {
      final bpx = -hL * 0.68 + bp * hL * 0.33;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(bpx, hD * 0.34), width: hL * 0.14, height: hD * 0.20),
              const Radius.circular(2.5)),
          Paint()..color = const Color(0xFF183830).withOpacity(0.52));
    }

    // Keel stripe
    canvas.drawLine(Offset(-hL * 0.90, -hD * 0.38), Offset(hL * 0.66, -hD * 0.38),
        Paint()..color = const Color(0xFF263C4A).withOpacity(0.72)..strokeWidth = 2.0);

    // Portholes with ghostly glow
    for (int p = 0; p < 5; p++) {
      final px = -hL * 0.60 + p * hL * 0.28;
      if (p == 2) continue;
      canvas.drawCircle(Offset(px, hD * 0.14), hD * 0.18 + 1.8,
          Paint()..color = const Color(0xFF162430).withOpacity(0.80));
      canvas.drawCircle(Offset(px, hD * 0.14), hD * 0.18,
          Paint()..color = const Color(0xFF060C12));

      // Ghostly green glow from one porthole
      if (p == 1) {
        final glowAlpha = 0.06 + _s(t1, 3, 0.5).abs() * 0.04;
        canvas.drawCircle(Offset(px, hD * 0.14), hD * 0.25,
            Paint()..color = const Color(0xFF80CBC4).withOpacity(glowAlpha));
      }

      canvas.drawCircle(Offset(px - hD * 0.055, hD * 0.07), hD * 0.050,
          Paint()..color = const Color(0xFF1A2E3C).withOpacity(0.30));
    }

    // Superstructure
    final superPath = Path()
      ..moveTo(-hL * 0.26, -hD * 0.38)
      ..lineTo(-hL * 0.26, -hD * 1.10)
      ..lineTo( hL * 0.10, -hD * 1.06)
      ..lineTo( hL * 0.12, -hD * 0.76)
      ..lineTo( hL * 0.10, -hD * 0.38)
      ..close();
    canvas.drawPath(superPath, Paint()..color = const Color(0xFF172330).withOpacity(0.88));
    for (int bw = 0; bw < 3; bw++) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(-hL * 0.21 + bw * hL * 0.11, -hD * 1.04, hL * 0.066, hD * 0.22),
              const Radius.circular(1.5)),
          Paint()..color = const Color(0xFF040810));
    }

    // Broken mast
    final mSway = _s(t2, 1, 0.5) * 1.0;
    canvas.drawLine(Offset(-hL * 0.06, -hD * 0.38), Offset(-hL * 0.08 + mSway, -hD * 2.05),
        Paint()..color = const Color(0xFF2A3E4C).withOpacity(0.80)..strokeWidth = 3.4);
    canvas.drawLine(Offset(-hL * 0.08 + mSway, -hD * 2.05),
                    Offset( hL * 0.34 + mSway, -hD * 1.08),
        Paint()..color = const Color(0xFF1E3040).withOpacity(0.64)..strokeWidth = 2.4);
    canvas.drawLine(Offset(-hL * 0.18 + mSway, -hD * 1.55),
                    Offset( hL * 0.06 + mSway, -hD * 1.50),
        Paint()..color = const Color(0xFF1E3040).withOpacity(0.56)..strokeWidth = 1.7);

    // Dangling rigging
    for (int rc = 0; rc < 4; rc++) {
      final rx  = -hL * 0.15 + rc * hL * 0.06 + mSway;
      final ry2 = -hD * 0.40 + _s(t1, 2 + rc, rc.toDouble()) * hD * 0.05;
      canvas.drawLine(Offset(rx, -hD * 1.50),
                      Offset(rx + _s(t1, 2 + rc, rc * 1.5) * 2.5, ry2),
          Paint()..color = const Color(0xFF1A2C3A).withOpacity(0.38)..strokeWidth = 1.0);
    }

    // Anchor chain
    for (int ac = 0; ac < 9; ac++) {
      final ay = -hD * 0.08 + ac * hD * 0.12;
      final ax = -hL * 0.88 + math.sin(ac * 0.8) * hD * 0.07;
      canvas.drawOval(Rect.fromCenter(center: Offset(ax, ay), width: hD * 0.17, height: hD * 0.10),
          Paint()..color = const Color(0xFF263C4A).withOpacity(0.48)..style = PaintingStyle.stroke..strokeWidth = 1.4);
    }

    canvas.restore();
  }

  void _drawWreckDebris(Canvas canvas, double w, double h) {
    for (final (double px, double py, double sz) in [
      (w * 0.18, h * 0.91, 12.0), (w * 0.30, h * 0.94, 8.0),
      (w * 0.58, h * 0.92, 10.0), (w * 0.72, h * 0.95, 7.0), (w * 0.83, h * 0.90, 9.0),
    ]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(px, py), width: sz, height: sz * 0.38),
              const Radius.circular(2)),
          Paint()..color = const Color(0xFF1C2E3C).withOpacity(0.52));
    }
    // Sediment motes
    for (int i = 0; i < 10; i++) {
      final sn  = (i * 0.10) % 1.0;
      final rise = (t1 * 2 + sn) % 1.0;
      final py  = h * 0.82 + sn * h * 0.11 - rise * h * 0.08;
      final px  = sn * w + _s(t1, 2 + i % 3, sn * 6.28) * 7.0;
      canvas.drawCircle(Offset(px % w, py), 1.0 + sn * 1.0,
          Paint()..color = const Color(0xFF2A3C4A).withOpacity(0.18));
    }
  }

  void _drawFloatingDebris(Canvas canvas, double w, double h) {
    // Floating wood planks and rope fragments
    for (int i = 0; i < 4; i++) {
      final sn = (i * 0.25) % 1.0;
      final driftN = 1 + (i % 2);
      final dx = ((sn + t2 * driftN) % 1.0) * w;
      final dy = h * 0.30 + sn * h * 0.35 + _s(t1, 2 + i, sn * 5.0) * h * 0.02;
      final rot = _s(t1, 3 + i, sn * 4.0) * 0.15;
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(rot);
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-8, -2, 16, 4), const Radius.circular(1.5)),
        Paint()..color = const Color(0xFF3E2723).withOpacity(0.18),
      );
      canvas.restore();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  LAYER 7 — SHARK WATERS
  //  "Danger moves in silence"
  //  No creatures — pure hostile environment. Rolling fog banks, volcanic
  //  fissure glow, falling ash, heat shimmer, pressure waves, electrical
  //  discharges, dark current tendrils. Oppressive, suffocating atmosphere.
  // ═══════════════════════════════════════════════════════════════════════════

  void _drawSharkWaters(Canvas canvas, double w, double h) {
    _drawVolcanicGlow(canvas, w, h);
    _drawFissures(canvas, w, h);
    _drawFogBanks(canvas, w, h);
    _drawHeatShimmer(canvas, w, h);
    _drawDarkCurrents(canvas, w, h);
    _drawPressureWaves(canvas, w, h);
    _drawFallingAsh(canvas, w, h);
    _drawEmbers(canvas, w, h);
  }

  void _drawVolcanicGlow(Canvas canvas, double w, double h) {
    // Deep crimson glow pulsing from below — volcanic heat
    final pulse1 = 0.065 + _s(t1, 2, 0.3) * 0.028 + _s(t2, 1, 1.1) * 0.014;
    final pulse2 = 0.040 + _s(t1, 3, 1.8) * 0.020 + _s(t2, 1, 2.5) * 0.010;

    // Primary glow from bottom
    canvas.drawRect(Rect.fromLTWH(0, h * 0.50, w, h * 0.50),
        Paint()..shader = LinearGradient(
          begin: Alignment.bottomCenter, end: Alignment.topCenter,
          colors: [const Color(0xFF8B0000).withOpacity(pulse1),
                   const Color(0xFF4A0000).withOpacity(pulse1 * 0.3),
                   Colors.transparent],
          stops: const [0.0, 0.4, 1.0],
        ).createShader(Rect.fromLTWH(0, h * 0.50, w, h * 0.50)));

    // Secondary glow — shifting hotspot
    final hotX = w * 0.50 + _s(t2, 1, 0.7) * w * 0.25;
    final hotY = h * 0.90 + _c(t2, 1, 1.3) * h * 0.04;
    canvas.drawCircle(Offset(hotX, hotY), w * 0.35, Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF8B0000).withOpacity(pulse2),
                 const Color(0xFF4A0000).withOpacity(pulse2 * 0.25),
                 Colors.transparent],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(Rect.fromCenter(center: Offset(hotX, hotY),
          width: w * 0.70, height: w * 0.70)));
  }

  void _drawFissures(Canvas canvas, double w, double h) {
    // Volcanic cracks in the deep floor — glowing red-orange seams
    const fissures = [
      (0.15, 0.92, 0.30, 0.94), (0.45, 0.95, 0.70, 0.90),
      (0.60, 0.88, 0.85, 0.93), (0.25, 0.96, 0.42, 0.91),
    ];
    for (int i = 0; i < fissures.length; i++) {
      final (x1f, y1f, x2f, y2f) = fissures[i];
      final glow = (0.04 + _s(t1, 2 + i, i * 1.5) * 0.03 + _s(t2, 1, i * 2.3).abs() * 0.02).clamp(0.0, 0.10);
      if (glow < 0.01) continue;

      final x1 = w * x1f;
      final y1 = h * y1f;
      final x2 = w * x2f;
      final y2 = h * y2f;
      final midX = (x1 + x2) / 2 + _s(t1, 3 + i % 3, i * 1.8) * w * 0.02;
      final midY = (y1 + y2) / 2 + _c(t1, 2 + i % 4, i * 2.2) * h * 0.008;

      // Wide glow around crack
      final crackPath = Path()..moveTo(x1, y1)..quadraticBezierTo(midX, midY, x2, y2);
      canvas.drawPath(crackPath, Paint()
        ..color = const Color(0xFFBF360C).withOpacity(glow * 0.5)
        ..strokeWidth = 8.0..strokeCap = StrokeCap.round..style = PaintingStyle.stroke);
      // Core crack line
      canvas.drawPath(crackPath, Paint()
        ..color = const Color(0xFFFF6F00).withOpacity(glow)
        ..strokeWidth = 1.5..strokeCap = StrokeCap.round..style = PaintingStyle.stroke);
      // Hot white centre
      canvas.drawPath(crackPath, Paint()
        ..color = const Color(0xFFFFAB91).withOpacity(glow * 0.4)
        ..strokeWidth = 0.5..strokeCap = StrokeCap.round..style = PaintingStyle.stroke);
    }
  }

  void _drawFogBanks(Canvas canvas, double w, double h) {
    // Multiple fog layers drifting at different speeds and depths
    // Each bank is a wide soft oval that crosses the screen periodically
    const banks = 8;
    for (int i = 0; i < banks; i++) {
      final sn = i / banks.toDouble();
      final driftN = 1 + (i % 3);   // integer → cyclic
      final phase = (sn + t2 * driftN) % 1.0;

      // Fog bank position
      final fx = phase * w * 1.8 - w * 0.4;
      final bandY = h * (0.08 + sn * 0.75);
      final fy = bandY + _s(t1, 2 + i % 4, sn * 5.0) * h * 0.04
               + _s(t2, 1, sn * 3.0) * h * 0.02;

      // Size — wider when deeper in the scene
      final fogW = w * (0.35 + sn * 0.20) + _s(t1, 3 + i % 3, sn * 4.0) * w * 0.04;
      final fogH = h * (0.04 + sn * 0.03) + _s(t1, 4 + i % 4, sn * 6.0) * h * 0.008;

      // Edge fade for smooth entry/exit
      final edgeFade = (math.min(phase, 1.0 - phase) * 3.5).clamp(0.0, 1.0);
      // Breathing opacity
      final breathe = _s(t1, 3 + i % 5, sn * 7.0) * 0.008;
      final alpha = ((0.028 + sn * 0.015 + breathe) * edgeFade).clamp(0.0, 0.06);
      if (alpha < 0.003) continue;

      // Fog body — radial gradient for soft edges
      canvas.drawOval(Rect.fromCenter(
          center: Offset(fx, fy), width: fogW, height: fogH),
          Paint()..shader = RadialGradient(
            colors: [const Color(0xFF1A0A0A).withOpacity(alpha),
                     const Color(0xFF1A0A0A).withOpacity(alpha * 0.4),
                     Colors.transparent],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(Rect.fromCenter(
              center: Offset(fx, fy), width: fogW, height: fogH)));

      // Secondary wisp — offset, thinner, slightly different timing
      final wispX = fx + _s(t1, 2 + i % 3, sn * 8.0) * w * 0.05;
      final wispY = fy + _c(t1, 3 + i % 4, sn * 6.0) * h * 0.015;
      canvas.drawOval(Rect.fromCenter(
          center: Offset(wispX, wispY), width: fogW * 0.6, height: fogH * 0.5),
          Paint()..color = const Color(0xFF1A0A0A).withOpacity(alpha * 0.5));
    }
  }

  void _drawHeatShimmer(Canvas canvas, double w, double h) {
    // Wavy distortion lines rising from the volcanic floor
    for (int i = 0; i < 5; i++) {
      final sn = (i * 0.20) % 1.0;
      final riseN = 1 + (i % 3);
      final riseT = (sn + t1 * riseN) % 1.0;
      final baseX = w * (0.12 + sn * 0.76);
      final lineY = h * 0.95 - riseT * h * 0.55;

      final alpha = ((0.020 + sn * 0.010) * (1.0 - riseT)).clamp(0.0, 0.035);
      if (alpha < 0.003) continue;

      final shimmerPath = Path();
      final lineW = w * 0.12 + _s(t1, 2 + i % 3, sn * 4.0) * w * 0.03;
      for (double dx = -lineW; dx <= lineW; dx += 3) {
        final frac = (dx + lineW) / (lineW * 2);
        final wave = math.sin(frac * 6 * math.pi * 2 + t1 * (4 + i % 3) * math.pi * 2) * 2.5;
        if (dx <= -lineW) { shimmerPath.moveTo(baseX + dx, lineY + wave); }
        else { shimmerPath.lineTo(baseX + dx, lineY + wave); }
      }
      canvas.drawPath(shimmerPath, Paint()
        ..color = const Color(0xFFBF360C).withOpacity(alpha)
        ..strokeWidth = 1.0..strokeCap = StrokeCap.round..style = PaintingStyle.stroke);
    }
  }

  void _drawDarkCurrents(Canvas canvas, double w, double h) {
    // Sinuous tendrils of darker water snaking across the scene
    for (int i = 0; i < 5; i++) {
      final sn = (i * 0.20) % 1.0;
      final sweepN = 1 + (i % 2);
      final phase = (sn + t1 * sweepN) % 1.0;
      final cx = phase * w * 2.0 - w * 0.5;
      final baseY = h * (0.15 + sn * 0.60);
      final dy = _s(t2, 1, sn * math.pi * 4) * h * 0.06
               + _s(t1, 3 + i % 3, sn * math.pi * 5) * h * 0.03;
      final cy = baseY + dy;

      // Asymmetric visibility envelope
      final double fade;
      if (phase < 0.10) { fade = phase / 0.10; }
      else if (phase < 0.45) { fade = (0.45 - phase) / 0.35; }
      else { fade = 0.0; }
      final alpha = ((0.035 + i * 0.005) * fade).clamp(0.0, 0.06);
      if (alpha < 0.003) continue;

      // Organic S-curve — cubic bezier
      final flip = (i % 2 == 0) ? 1.0 : -1.0;
      final armLen = w * 0.12;
      final spread = h * (0.025 + sn * 0.015);
      final cp1y = cy - spread * flip * (0.8 + _s(t1, 2 + i % 4, sn * 5) * 0.3);
      final cp2y = cy + spread * flip * (0.7 + _s(t2, 1, sn * 7) * 0.3);

      for (final (double strokeW, double alphaScale) in [
        (32.0, 0.25), (18.0, 0.50), (8.0, 1.00),
      ]) {
        canvas.drawPath(
          Path()..moveTo(cx - armLen, cy - spread * flip * 0.5)
            ..cubicTo(cx - armLen, cp1y, cx + armLen, cp2y, cx + armLen, cy + spread * flip * 0.5),
          Paint()..color = const Color(0xFF0A0005).withOpacity(alpha * alphaScale)
            ..strokeWidth = strokeW..strokeCap = StrokeCap.round..style = PaintingStyle.stroke);
      }
    }
  }

  void _drawPressureWaves(Canvas canvas, double w, double h) {
    // Concentric ripples expanding from unseen impact points
    const sources = [(0.25, 0.60), (0.75, 0.45), (0.50, 0.80)];
    for (int si = 0; si < sources.length; si++) {
      final (xFrac, yFrac) = sources[si];
      final ox = w * xFrac + _s(t2, 1, si * 2.0) * w * 0.06;
      final oy = h * yFrac + _c(t2, 1, si * 3.0) * h * 0.04;

      for (int ring = 0; ring < 3; ring++) {
        final age = (t1 * (2 + si) + ring / 3.0 + si * 0.33) % 1.0;
        final ringR = age * w * 0.30;
        final alpha = (1.0 - age) * 0.030;
        if (alpha < 0.003) continue;
        canvas.drawCircle(Offset(ox, oy), ringR,
            Paint()..color = const Color(0xFF8B0000).withOpacity(alpha)
              ..style = PaintingStyle.stroke..strokeWidth = 1.2);
      }
    }
  }

  void _drawFallingAsh(Canvas canvas, double w, double h) {
    // Volcanic ash particles slowly drifting downward
    for (int i = 0; i < 18; i++) {
      final sn = (i * 0.0556) % 1.0;
      final fallN = 1 + (i % 3);
      final driftN = 1 + (i % 2);
      final ny = (sn + t1 * fallN * 0.6) % 1.0;
      final nx = (sn * 0.8 + t1 * driftN * 0.15
               + _s(t1, 3 + i % 4, sn * 6.28) * 0.04) % 1.0;
      final px = nx * w;
      final py = ny * h;

      // Edge fade
      final edgeFade = (math.min(ny, 1.0 - ny) * 5.0).clamp(0.0, 1.0);
      final alpha = (0.06 + sn * 0.04) * edgeFade;
      if (alpha < 0.01) continue;

      final ashSize = 1.0 + sn * 1.5;
      // Tumble rotation
      final rot = t1 * (3 + i % 4) * math.pi * 2 + sn * 6.28;
      final ashW = ashSize * (0.6 + math.cos(rot).abs() * 0.4);
      final ashH = ashSize * (0.6 + math.sin(rot).abs() * 0.4);

      canvas.drawOval(Rect.fromCenter(
          center: Offset(px, py), width: ashW * 2, height: ashH),
          Paint()..color = const Color(0xFF3E2723).withOpacity(alpha));
    }
  }

  void _drawEmbers(Canvas canvas, double w, double h) {
    // Tiny glowing orange-red sparks rising from the fissures
    for (int i = 0; i < 8; i++) {
      final sn = (i * 0.125) % 1.0;
      final riseN = 2 + (i % 3);
      final ny = 1.0 - (sn + t1 * riseN) % 1.0;
      final nx = (sn * 0.6 + 0.20 + _s(t1, 3 + i % 4, sn * 5.0) * 0.06) % 1.0;
      final px = nx * w;
      final py = ny * h;

      final edgeFade = (math.min(ny, 1.0 - ny) * 4.0).clamp(0.0, 1.0);
      final flicker = (0.5 + _s(t1, 6 + i % 5, sn * 8.0) * 0.5).clamp(0.0, 1.0);
      final alpha = (0.10 * edgeFade * flicker).clamp(0.0, 0.10);
      if (alpha < 0.01) continue;

      // Glow
      canvas.drawCircle(Offset(px, py), 3.5,
          Paint()..color = const Color(0xFFFF6F00).withOpacity(alpha * 0.3));
      // Core spark
      canvas.drawCircle(Offset(px, py), 1.0,
          Paint()..color = const Color(0xFFFFAB91).withOpacity(alpha));
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  LAYER 8 — DEEP OCEAN
  //  "The weight here has no name"
  //  Hydrothermal vent smoke, crushing pressure, bioluminescent motes.
  // ═══════════════════════════════════════════════════════════════════════════

  void _drawDeepOcean(Canvas canvas, double w, double h) {
    // Pressure pulse from edges
    _drawPressurePulse(canvas, w, h);

    // Hydrothermal vent
    _drawHydrothermalVent(canvas, w, h);

    // Bioluminescent deep-sea sparks
    _drawDeepBioSparks(canvas, w, h);

    // Pressure crack lines
    _drawPressureCracks(canvas, w, h);
  }

  void _drawPressurePulse(Canvas canvas, double w, double h) {
    // Darkness breathes inward from edges
    final breathe = 0.08 + _s(t1, 2, 0.5) * 0.03 + _s(t2, 1, 1.0) * 0.02;
    // Top
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.15),
        Paint()..shader = LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(breathe), Colors.transparent])
            .createShader(Rect.fromLTWH(0, 0, w, h * 0.15)));
    // Bottom
    canvas.drawRect(Rect.fromLTWH(0, h * 0.85, w, h * 0.15),
        Paint()..shader = LinearGradient(
          begin: Alignment.bottomCenter, end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(breathe), Colors.transparent])
            .createShader(Rect.fromLTWH(0, h * 0.85, w, h * 0.15)));
    // Left
    canvas.drawRect(Rect.fromLTWH(0, 0, w * 0.12, h),
        Paint()..shader = LinearGradient(
          begin: Alignment.centerLeft, end: Alignment.centerRight,
          colors: [Colors.black.withOpacity(breathe * 0.7), Colors.transparent])
            .createShader(Rect.fromLTWH(0, 0, w * 0.12, h)));
    // Right
    canvas.drawRect(Rect.fromLTWH(w * 0.88, 0, w * 0.12, h),
        Paint()..shader = LinearGradient(
          begin: Alignment.centerRight, end: Alignment.centerLeft,
          colors: [Colors.black.withOpacity(breathe * 0.7), Colors.transparent])
            .createShader(Rect.fromLTWH(w * 0.88, 0, w * 0.12, h)));
  }

  void _drawHydrothermalVent(Canvas canvas, double w, double h) {
    // Vent base at bottom
    final ventX = w * 0.40 + _s(t2, 1, 0.8) * w * 0.03;
    final ventY = h * 0.95;

    // Vent opening
    canvas.drawOval(Rect.fromCenter(
        center: Offset(ventX, ventY), width: 24, height: 8),
        Paint()..color = const Color(0xFF1A237E).withOpacity(0.4));

    // Rising dark smoke plumes
    for (int i = 0; i < 6; i++) {
      final sn = (i * 0.167) % 1.0;
      final riseN = 1 + (i % 3);
      final riseT = (sn + t1 * riseN) % 1.0;
      final smokeY = ventY - riseT * h * 0.40;
      final smokeX = ventX + _s(t1, 3 + i % 4, sn * 6.28) * 15.0 * riseT;
      final smokeR = 6.0 + riseT * 12.0;
      final alpha = (0.10 * (1.0 - riseT)).clamp(0.0, 0.10);
      if (alpha < 0.005) continue;
      canvas.drawCircle(Offset(smokeX, smokeY), smokeR,
          Paint()..color = const Color(0xFF1A1A2E).withOpacity(alpha));
    }

    // Vent glow
    final glowAlpha = 0.04 + _s(t1, 3, 0.5).abs() * 0.02;
    canvas.drawCircle(Offset(ventX, ventY), 18,
        Paint()..shader = RadialGradient(
          colors: [const Color(0xFFFF6F00).withOpacity(glowAlpha), Colors.transparent],
        ).createShader(Rect.fromCenter(center: Offset(ventX, ventY), width: 36, height: 36)));
  }

  void _drawDeepBioSparks(Canvas canvas, double w, double h) {
    for (int i = 0; i < 8; i++) {
      final sn = (i * 0.125) % 1.0;
      final px = sn * w + _s(t1, 3 + i % 5, sn * 7.0) * w * 0.06;
      final py = sn * h + _c(t1, 4 + i % 3, sn * 6.0) * h * 0.05;
      final br = (0.3 + _s(t1, 5 + i % 4, sn * 8.0) * 0.5).clamp(0.0, 1.0);
      if (br < 0.15) continue;
      final col = [const Color(0xFF80DEEA), const Color(0xFF4DD0E1), const Color(0xFF00BCD4)][i % 3];
      // Glow
      canvas.drawCircle(Offset(px, py), 4.0 * br,
          Paint()..color = col.withOpacity(0.06 * br));
      // Core
      canvas.drawCircle(Offset(px, py), 1.2 * br,
          Paint()..color = col.withOpacity(0.12 * br));
    }
  }

  void _drawPressureCracks(Canvas canvas, double w, double h) {
    for (int i = 0; i < 3; i++) {
      final sn = (i * 0.333) % 1.0;
      final startX = w * (0.15 + sn * 0.7);
      final startY = h * (0.70 + sn * 0.20);
      final alpha = 0.03 + _s(t1, 2 + i, sn * 5.0).abs() * 0.02;

      final path = Path()..moveTo(startX, startY);
      for (int seg = 0; seg < 4; seg++) {
        final dx = (seg + 1) * w * 0.04 * (i % 2 == 0 ? 1 : -1);
        final dy = (seg + 1) * h * 0.02;
        path.lineTo(startX + dx + _s(t1, 3 + seg, sn * 4.0 + seg.toDouble()) * 3.0,
                    startY + dy);
      }
      canvas.drawPath(path, Paint()
        ..color = const Color(0xFF283593).withOpacity(alpha)
        ..strokeWidth = 0.8..strokeCap = StrokeCap.round..style = PaintingStyle.stroke);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  LAYER 9 — ANGLERFISH LAIR
  //  "Dark light leads nowhere"
  //  Multiple deceptive lures, barely visible predator outline, trap lights.
  // ═══════════════════════════════════════════════════════════════════════════

  void _drawAnglerLair(Canvas canvas, double w, double h) {
    // Toxic green ambience from below
    final ambientAlpha = 0.02 + _s(t1, 2, 0.3).abs() * 0.01;
    canvas.drawRect(Rect.fromLTWH(0, h * 0.6, w, h * 0.4),
        Paint()..shader = LinearGradient(
          begin: Alignment.bottomCenter, end: Alignment.topCenter,
          colors: [const Color(0xFF00E676).withOpacity(ambientAlpha), Colors.transparent])
            .createShader(Rect.fromLTWH(0, h * 0.6, w, h * 0.4)));

    // Main lure
    _drawAnglerLure(canvas, w, h, 0.50, 0.28, 1.0);

    // Secondary deceptive lures
    _drawAnglerLure(canvas, w, h, 0.22, 0.55, 0.5);
    _drawAnglerLure(canvas, w, h, 0.78, 0.42, 0.35);
    _drawAnglerLure(canvas, w, h, 0.35, 0.72, 0.25);

    // Barely visible jaw outline
    _drawAnglerJaw(canvas, w, h);

    // Dangling filaments
    _drawDanglingFilaments(canvas, w, h);
  }

  void _drawAnglerLure(Canvas canvas, double w, double h,
      double xFrac, double yFrac, double scale) {
    final lx = w * xFrac + _s(t1, 2, xFrac * 5.0) * w * 0.12 * scale
             + _s(t2, 1, yFrac * 3.0) * w * 0.08 * scale;
    final ly = h * yFrac + _c(t1, 3, yFrac * 4.0) * h * 0.06 * scale
             + _c(t2, 1, xFrac * 2.0) * h * 0.04 * scale;
    final intensity = (0.55 + _s(t1, 5, xFrac * 3.0 + 0.3) * 0.35).clamp(0.0, 1.0) * scale;
    final glowR = 68.0 * intensity;

    // Outer glow
    canvas.drawCircle(Offset(lx, ly), glowR, Paint()
      ..shader = RadialGradient(colors: [
        const Color(0xFF00E676).withOpacity(0.28 * intensity),
        const Color(0xFF00E676).withOpacity(0.04 * intensity),
        Colors.transparent,
      ], stops: const [0.0, 0.5, 1.0]).createShader(
          Rect.fromCenter(center: Offset(lx, ly), width: glowR * 2, height: glowR * 2)));

    // Core
    canvas.drawCircle(Offset(lx, ly), 3.4 * intensity,
        Paint()..color = const Color(0xFF00E676).withOpacity(0.92 * intensity));

    // Stalk line
    canvas.drawLine(Offset(lx, ly),
        Offset(lx + _s(t2, 1, xFrac * 6.0) * 30 * scale, ly + 28 * scale + _c(t1, 3, yFrac * 3.0) * 9 * scale),
        Paint()..color = const Color(0xFF00E676).withOpacity(0.13 * intensity)..strokeWidth = 0.8);
  }

  void _drawAnglerJaw(Canvas canvas, double w, double h) {
    // Barely visible massive jaw beneath the main lure
    final jawX = w * 0.50 + _s(t2, 1, 1.0) * w * 0.05;
    final jawY = h * 0.55 + _c(t2, 1, 2.0) * h * 0.03;
    final jawOpen = 0.6 + _s(t1, 2, 0.5) * 0.15;
    final alpha = 0.025;

    // Upper jaw
    canvas.drawPath(
      Path()..moveTo(jawX - w * 0.15, jawY)
        ..quadraticBezierTo(jawX, jawY - h * 0.06 * jawOpen, jawX + w * 0.15, jawY),
      Paint()..color = Colors.white.withOpacity(alpha)
        ..strokeWidth = 1.2..style = PaintingStyle.stroke,
    );
    // Lower jaw
    canvas.drawPath(
      Path()..moveTo(jawX - w * 0.13, jawY)
        ..quadraticBezierTo(jawX, jawY + h * 0.05 * jawOpen, jawX + w * 0.13, jawY),
      Paint()..color = Colors.white.withOpacity(alpha * 0.7)
        ..strokeWidth = 1.0..style = PaintingStyle.stroke,
    );

    // Tooth hints
    for (int t = 0; t < 5; t++) {
      final tx = jawX - w * 0.10 + t * w * 0.05;
      final ty = jawY - h * 0.01;
      canvas.drawLine(Offset(tx, ty), Offset(tx, ty + h * 0.015),
          Paint()..color = Colors.white.withOpacity(alpha * 0.5)..strokeWidth = 0.6);
    }
  }

  void _drawDanglingFilaments(Canvas canvas, double w, double h) {
    for (int i = 0; i < 6; i++) {
      final sn = (i * 0.167) % 1.0;
      final startX = w * (0.15 + sn * 0.70);
      final startY = h * 0.10 + sn * h * 0.15;
      final filLen = h * 0.10 + sn * h * 0.08;
      final sway = _s(t1, 2 + i % 4, sn * 5.0) * 8.0 + _s(t2, 1, sn * 3.0) * 4.0;

      canvas.drawPath(
        Path()..moveTo(startX, startY)
          ..quadraticBezierTo(startX + sway * 0.5, startY + filLen * 0.5,
                              startX + sway, startY + filLen),
        Paint()..color = const Color(0xFF00E676).withOpacity(0.04)
          ..strokeWidth = 0.6..strokeCap = StrokeCap.round..style = PaintingStyle.stroke,
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  LAYER 10 — THE ABYSS
  //  "Where all motion ends"
  //  Leviathan eye with slow blink, void particles, tectonic fractures.
  // ═══════════════════════════════════════════════════════════════════════════

  void _drawTheAbyss(Canvas canvas, double w, double h) {
    _drawVoidParticles(canvas, w, h);
    _drawTectonicFractures(canvas, w, h);
    _drawLeviathanEye(canvas, w, h);
  }

  void _drawVoidParticles(Canvas canvas, double w, double h) {
    // Particles being pulled toward the eye
    final ex = w * 0.50 + _s(t2, 1, 1.7) * 7.0;
    final ey = h * 0.40 + _c(t2, 1, 2.3) * 5.0;

    for (int i = 0; i < 12; i++) {
      final sn = (i * 0.0833) % 1.0;
      final angle = sn * math.pi * 2 + _s(t1, 2 + i % 3, sn * 4.0) * 0.3;
      final spiralN = 1 + (i % 3);
      final dist = w * 0.50 * (1.0 - (sn * 0.3 + t1 * spiralN) % 1.0);
      final px = ex + math.cos(angle + t1 * spiralN * math.pi * 2) * dist;
      final py = ey + math.sin(angle + t1 * spiralN * math.pi * 2) * dist * 0.6;

      if (px < 0 || px > w || py < 0 || py > h) continue;

      final distFrac = dist / (w * 0.50);
      final alpha = (0.06 * distFrac).clamp(0.0, 0.06);
      if (alpha < 0.005) continue;

      canvas.drawCircle(Offset(px, py), 0.8 + distFrac * 1.2,
          Paint()..color = const Color(0xFF757575).withOpacity(alpha));
    }
  }

  void _drawTectonicFractures(Canvas canvas, double w, double h) {
    for (int i = 0; i < 4; i++) {
      final sn = (i * 0.25) % 1.0;
      final startX = w * (0.10 + sn * 0.80);
      final startY = h * (0.75 + sn * 0.15);
      final glowAlpha = 0.02 + _s(t1, 2 + i, sn * 5.0).abs() * 0.015;

      final path = Path()..moveTo(startX, startY);
      for (int seg = 0; seg < 5; seg++) {
        final dx = (seg + 1) * w * 0.03 * (i % 2 == 0 ? 1 : -1);
        final dy = (seg + 1) * h * 0.015;
        path.lineTo(
          startX + dx + _s(t1, 3 + seg % 3, sn * 4.0 + seg.toDouble()) * 4.0,
          startY + dy,
        );
      }
      // Glow line
      canvas.drawPath(path, Paint()
        ..color = const Color(0xFFB8860B).withOpacity(glowAlpha)
        ..strokeWidth = 1.2..strokeCap = StrokeCap.round..style = PaintingStyle.stroke);
      // Bright core
      canvas.drawPath(path, Paint()
        ..color = const Color(0xFFFFB300).withOpacity(glowAlpha * 0.5)
        ..strokeWidth = 0.4..strokeCap = StrokeCap.round..style = PaintingStyle.stroke);
    }
  }

  void _drawLeviathanEye(Canvas canvas, double w, double h) {
    final ex = w * 0.50 + _s(t2, 1, 1.7) * 7.0;
    final ey = h * 0.40 + _c(t2, 1, 2.3) * 5.0;
    const irisR = 118.0;

    // Slow blink — eyelids close and open on t2 cycle
    final blinkPhase = t2;
    double blinkClose;
    if (blinkPhase < 0.06) {
      blinkClose = blinkPhase / 0.06; // closing
    } else if (blinkPhase < 0.12) {
      blinkClose = 1.0 - (blinkPhase - 0.06) / 0.06; // opening
    } else {
      blinkClose = 0.0; // open
    }

    // Ambient glow
    final glowPulse = 0.048 + _s(t1, 2, 0.5) * 0.016;
    canvas.drawCircle(Offset(ex, ey), irisR * 2.4, Paint()
      ..shader = RadialGradient(colors: [
        const Color(0xFFB8860B).withOpacity(glowPulse),
        Colors.transparent,
      ]).createShader(Rect.fromCenter(center: Offset(ex, ey), width: irisR * 4.8, height: irisR * 4.8)));

    // Veins radiating from eye
    for (int v = 0; v < 8; v++) {
      final vAngle = v * math.pi / 4 + _s(t2, 1, v.toDouble()) * 0.05;
      final vLen = irisR * 1.6 + _s(t1, 2 + v % 3, v * 1.2) * irisR * 0.2;
      final vAlpha = 0.015 + _s(t1, 3 + v % 4, v * 0.8).abs() * 0.010;
      canvas.drawLine(
        Offset(ex + math.cos(vAngle) * irisR * 1.2, ey + math.sin(vAngle) * irisR * 1.2),
        Offset(ex + math.cos(vAngle) * vLen, ey + math.sin(vAngle) * vLen),
        Paint()..color = const Color(0xFF8B0000).withOpacity(vAlpha)..strokeWidth = 1.0,
      );
    }

    // Sclera + iris
    canvas.drawCircle(Offset(ex, ey), irisR * 1.18, Paint()..color = const Color(0xFF181210));

    // Iris pupil contraction
    final pupilContract = 0.20 + _s(t1, 3, 0.3) * 0.04;
    canvas.drawCircle(Offset(ex, ey), irisR, Paint()
      ..shader = RadialGradient(
        colors: const [Color(0xFF3E1E00), Color(0xFF1C0900), Color(0xFF0C0400)],
        stops: const [0.0, 0.55, 1.0])
        .createShader(Rect.fromCenter(center: Offset(ex, ey), width: irisR * 2, height: irisR * 2)));

    // Iris ring texture
    for (int ring = 1; ring <= 6; ring++) {
      canvas.drawCircle(Offset(ex, ey), irisR * (ring / 6.5),
          Paint()..color = const Color(0xFF5C2800).withOpacity(0.18 + ring * 0.04)
            ..style = PaintingStyle.stroke..strokeWidth = 1.6);
    }

    // Iris fiber detail
    for (int fiber = 0; fiber < 16; fiber++) {
      final fAngle = fiber * math.pi / 8;
      canvas.drawLine(
        Offset(ex + math.cos(fAngle) * irisR * 0.25, ey + math.sin(fAngle) * irisR * 0.25),
        Offset(ex + math.cos(fAngle) * irisR * 0.85, ey + math.sin(fAngle) * irisR * 0.85),
        Paint()..color = const Color(0xFF5C2800).withOpacity(0.06)..strokeWidth = 0.6,
      );
    }

    // Slit pupil
    canvas.drawOval(Rect.fromCenter(
        center: Offset(ex, ey), width: irisR * pupilContract, height: irisR * 1.68),
        Paint()..color = Colors.black);

    // Catch-light
    canvas.drawArc(
      Rect.fromCenter(center: Offset(ex - irisR * 0.22, ey - irisR * 0.30), width: irisR * 0.40, height: irisR * 0.26),
      0.4, 1.4, false,
      Paint()..color = const Color(0xFFB8860B).withOpacity(0.13)..style = PaintingStyle.stroke..strokeWidth = 2.4);

    // Eyelids with blink
    final topLidDrop  = blinkClose * irisR * 0.55;
    final botLidRise  = blinkClose * irisR * 0.50;

    final topSkin = Path()
      ..moveTo(ex - irisR * 1.28, ey)
      ..quadraticBezierTo(ex, ey - irisR * 1.24 + topLidDrop, ex + irisR * 1.28, ey)
      ..quadraticBezierTo(ex, ey - irisR * 0.76 + topLidDrop, ex - irisR * 1.28, ey)..close();
    canvas.drawPath(topSkin, Paint()..color = const Color(0xFF060306).withOpacity(0.62 + blinkClose * 0.35));

    final botSkin = Path()
      ..moveTo(ex - irisR * 1.28, ey)
      ..quadraticBezierTo(ex, ey + irisR * 1.24 - botLidRise, ex + irisR * 1.28, ey)
      ..quadraticBezierTo(ex, ey + irisR * 0.72 - botLidRise, ex - irisR * 1.28, ey)..close();
    canvas.drawPath(botSkin, Paint()..color = const Color(0xFF060306).withOpacity(0.58 + blinkClose * 0.35));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SHARED — Caustic light rays
  // ═══════════════════════════════════════════════════════════════════════════

  void _drawCausticRays(Canvas canvas, double w, double h,
      {required double alpha, required int count}) {
    for (int i = 0; i < count; i++) {
      final sn   = (i * 0.1618) % 1.0;
      final sway = _s(t1, 2 + i % 3, sn * 6.28) * 22.0 + _s(t2, 1, sn * 6.28 + 1.0) * 9.0;
      final rx   = w * (0.04 + i / (count - 1) * 0.92) + sway;
      final topW = 9.0  + _s(t1, 3 + i % 4, sn * 6.28 + 2.0) * 3.5;
      final botW = 62.0 + _s(t2, 1, sn * 6.28 + 3.0) * 16.0;
      final ray  = Path()
        ..moveTo(rx, 0)..lineTo(rx + topW, 0)
        ..lineTo(rx + botW, h)..lineTo(rx + botW - topW, h)..close();
      canvas.drawPath(ray, Paint()..color = Colors.white.withOpacity(alpha));
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SHARED — Rising bubbles (biome-specific)
  // ═══════════════════════════════════════════════════════════════════════════

  void _drawParticles(Canvas canvas, double w, double h) {
    final count = switch (layer) {
      4  => 10,
      8  => 9,
      9  => 9,
      _  => math.max(0, 24 - layer * 2),
    };
    if (count == 0) return;

    for (int i = 0; i < count; i++) {
      final sn = count > 1 ? (i / (count - 1.0)) : 0.5;

      double nx, ny, r, baseAlpha;

      if (layer == 1) {
        final riseN  = 2 + (i % 4);
        final driftN = 1 + (i % 2);
        ny = 1.0 - (sn + t1 * riseN) % 1.0;
        nx = (sn * 0.6 + t1 * driftN * 0.3 + _s(t1, 3 + i % 4, sn * 6.28) * 0.05) % 1.0;
        r  = 1.2 + sn * 3.0;
        baseAlpha = 0.28 + sn * 0.10;

      } else if (layer == 2) {
        final side  = i % 2 == 0 ? sn * 0.16 : 0.84 + sn * 0.14;
        final riseN = 2 + (i % 3);
        ny = 1.0 - (sn + t1 * riseN) % 1.0;
        nx = (side + _s(t1, 2 + i % 5, sn * 6.28) * 0.04) % 1.0;
        r  = 1.0 + sn * 2.6;
        baseAlpha = 0.22 + sn * 0.08;

      } else if (layer == 3) {
        final xDriftN = 1 + (i % 5);
        final yRiseN  = 1 + (i % 4);
        nx = (sn + t1 * xDriftN) % 1.0;
        ny = 1.0 - (sn * 0.8 + t1 * yRiseN) % 1.0;
        final xTurb = _s(t1, 4 + i % 5, sn * 9.42) * 0.07
                    + _s(t1, 6 + i % 4, sn * 11.0) * 0.04;
        final yTurb = _s(t1, 5 + i % 3, sn * 7.85) * 0.035;
        nx = (nx + xTurb).clamp(0.0, 1.0);
        ny = (ny + yTurb).clamp(0.02, 0.98);
        r  = 1.0 + sn * 2.4;
        baseAlpha = 0.18 + sn * 0.08;

      } else if (layer == 4) {
        final xDriftN = 1;
        final yRiseN  = 1;
        nx = (sn + t1 * xDriftN) % 1.0;
        ny = 1.0 - (sn * 0.8 + t1 * yRiseN * 0.55) % 1.0;
        final xTurb = _s(t1, 3 + i % 4, sn * 9.42) * 0.045
                    + _s(t1, 5 + i % 3, sn * 11.0)  * 0.022;
        final yTurb = _s(t1, 4 + i % 3, sn * 7.85)  * 0.020;
        nx = (nx + xTurb).clamp(0.0, 1.0);
        ny = (ny + yTurb).clamp(0.02, 0.98);
        r  = 1.2 + sn * 3.0;
        baseAlpha = 0.12 + sn * 0.06;

      } else if (layer == 6) {
        final riseN = 1 + (i % 3);
        ny = 1.0 - (sn * 0.6 + t1 * riseN * 0.7) % 1.0;
        final hullX = 0.30 + sn * 0.40;
        nx = (hullX + _s(t1, 2 + i % 3, sn * 6.28) * 0.06) % 1.0;
        r  = 1.2 + sn * 3.2;
        baseAlpha = 0.18 + sn * 0.08;

      } else if (layer == 8) {
        final dir  = i % 3;
        final ph   = (i * 0.3819) % 1.0;
        final riseN = 1 + (i % 4);
        if (dir == 0) {
          ny = 1.0 - (ph + t1 * riseN) % 1.0;
          nx = (ph * 0.85 + 0.07 + _s(t1, 3 + i % 5, ph * 9.0) * 0.08) % 1.0;
        } else if (dir == 1) {
          final driftN = 1 + (i % 3);
          nx = (ph * 0.4 + t1 * driftN * 0.55) % 1.0;
          ny = 1.0 - (ph * 0.5 + t1 * riseN * 0.80) % 1.0;
        } else {
          final driftN = 1 + (i % 3);
          nx = 1.0 - (ph * 0.4 + t1 * driftN * 0.55) % 1.0;
          ny = 1.0 - (ph * 0.5 + t1 * riseN * 0.80) % 1.0;
        }
        final xTurb = _s(t1, 4 + i % 5, ph * 9.42) * 0.06
                    + _s(t1, 6 + i % 3, ph * 11.0)  * 0.03;
        final yTurb = _s(t1, 5 + i % 4, ph * 7.85)  * 0.03;
        nx = (nx + xTurb).clamp(0.0, 1.0);
        ny = (ny + yTurb).clamp(0.0, 1.0);
        r  = 0.8 + ph * 1.8;
        baseAlpha = 0.10 + ph * 0.05;

      } else {
        // Anglerfish Lair (layer 9)
        final dir   = i % 3;
        final ph    = (i * 0.3819) % 1.0;
        final riseN = 1 + (i % 4);
        if (dir == 0) {
          ny = 1.0 - (ph + t1 * riseN * 0.60) % 1.0;
          nx = (ph * 0.85 + 0.07 + _s(t1, 3 + i % 5, ph * 9.0) * 0.07) % 1.0;
        } else if (dir == 1) {
          final driftN = 1 + (i % 3);
          nx = (ph * 0.4 + t1 * driftN * 0.34) % 1.0;
          ny = 1.0 - (ph * 0.5 + t1 * riseN * 0.50) % 1.0;
        } else {
          final driftN = 1 + (i % 3);
          nx = 1.0 - (ph * 0.4 + t1 * driftN * 0.34) % 1.0;
          ny = 1.0 - (ph * 0.5 + t1 * riseN * 0.50) % 1.0;
        }
        final xTurb = _s(t1, 4 + i % 5, ph * 9.42) * 0.045
                    + _s(t1, 6 + i % 3, ph * 11.0)  * 0.022;
        final yTurb = _s(t1, 5 + i % 4, ph * 7.85)  * 0.022;
        nx = (nx + xTurb).clamp(0.0, 1.0);
        ny = (ny + yTurb).clamp(0.0, 1.0);
        r  = 0.7 + ph * 1.4;
        baseAlpha = 0.08 + ph * 0.04;
      }

      // Shared wobble
      final xWob = _s(t1, 3 + i % 4, sn * 7.54) * (2.5 + r * 1.4)
                 + _s(t2, 1, sn * math.pi * 5.0) * (1.5 + r * 0.6);
      final yWob = _s(t1, 2 + i % 5, sn * 9.42) * (1.5 + r * 0.6);

      final px = (nx * w + xWob).clamp(0.0, w);
      final py = (ny * h + yWob).clamp(0.0, h);

      // Edge fade
      final leftF   = (px / (w * 0.10)).clamp(0.0, 1.0);
      final rightF  = ((w - px) / (w * 0.10)).clamp(0.0, 1.0);
      final topF    = (py / (h * 0.08)).clamp(0.0, 1.0);
      final bottomF = ((h - py) / (h * 0.06)).clamp(0.0, 1.0);
      final edgeFade = leftF * rightF * topF * bottomF;
      if (edgeFade < 0.01) continue;

      final alpha  = (baseAlpha * edgeFade).clamp(0.0, 0.36);
      final radius = r * (0.4 + edgeFade * 0.6);
      if (radius < 0.5) continue;

      canvas.drawCircle(Offset(px, py), radius,
          Paint()..color = Colors.white.withOpacity(alpha * 0.55));
      canvas.drawCircle(Offset(px, py), radius,
          Paint()
            ..color = Colors.white.withOpacity(alpha * 0.85)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.6);
      if (radius > 1.8) {
        canvas.drawCircle(
          Offset(px - radius * 0.30, py - radius * 0.30),
          radius * 0.22,
          Paint()..color = Colors.white.withOpacity((alpha * 1.3).clamp(0.0, 1.0)),
        );
      }
    }
  }

  @override
  bool shouldRepaint(OceanPainter old) =>
      old.t1 != t1 || old.t2 != t2 || old.layer != layer;
}


// ─────────────────────────────────────────────
//  MAIN OCEAN SCREEN
// ─────────────────────────────────────────────
class OceanScreen extends StatefulWidget {
  const OceanScreen({super.key});

  @override
  State<OceanScreen> createState() => _OceanScreenState();
}

class _OceanScreenState extends State<OceanScreen>
    with TickerProviderStateMixin {
  int currentLayer = 4;
  int highestLayer = 4;
  int deepestLayer = 4;
  int streak = 0;
  int stormDays = 0;
  bool rescueAvailable = true;
  int rescueDayCounter = 0;
  bool rescueDayActive = false;
  bool momentumBonusUsed = false;
  bool immunityUsed = false;
  int corals = 700;
  String lastLoggedDate = '';
  List<String> categories = [];
  Map<String, String> priorities = {};

  // ── Weekly tracking ──────────────────────────
  int weeklyLogCount = 0;
  int weeklyStartLayer = 4;
  int weeklyCoralStart = 700;
  List<int> weeklyLayers = [];
  List<int> weeklyActionCounts = [];
  List<int> weeklyCoralChanges = [];
  Map<String, int> weeklyActivityMap = {};

  // ── Log history (calendar) ────────────────────
  List<Map<String, dynamic>> logHistory = [];

  late AnimationController _pulseCtrl;

  // ── Coral animation ────────────────────────────
  late AnimationController _coralCountCtrl;
  int _displayCorals = 700;   // smoothly-animated display value
  int _coralFrom = 700;       // animation start
  int _coralTo = 700;         // animation end

  @override
  void initState() {
    super.initState();
    _pulseCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);

    // Rolling counter — 1s ease-out so large jumps feel dramatic
    _coralCountCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..addListener(() {
        setState(() {
          _displayCorals =
              (_coralFrom + (_coralTo - _coralFrom) * Curves.easeOutCubic.transform(_coralCountCtrl.value)).round();
        });
      });

    _load();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _coralCountCtrl.dispose();
    super.dispose();
  }

  /// Trigger the coral rolling-counter animation.
  void _animateCoralChange(int from, int to) {
    _coralFrom = from;
    _coralTo = to;
    _displayCorals = from;
    _coralCountCtrl.forward(from: 0.0);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentLayer = prefs.getInt('currentLayer') ?? 4;
      highestLayer = prefs.getInt('highestLayer') ?? currentLayer;
      deepestLayer = prefs.getInt('deepestLayer') ?? currentLayer;
      streak = prefs.getInt('streak') ?? 0;
      stormDays = prefs.getInt('stormDays') ?? 0;
      rescueAvailable = prefs.getBool('rescueAvailable') ?? true;
      rescueDayCounter = prefs.getInt('rescueDayCounter') ?? 0;
      rescueDayActive = prefs.getBool('rescueDayActive') ?? false;
      momentumBonusUsed = prefs.getBool('momentumBonusUsed') ?? false;
      immunityUsed = prefs.getBool('immunityUsed') ?? false;
      corals = prefs.getInt('corals') ?? 700;
      lastLoggedDate = prefs.getString('lastLoggedDate') ?? '';
      categories = prefs.getStringList('categories') ?? kDefaultCategories;
      final prioKeys = prefs.getStringList('priorityKeys') ?? [];
      final prioVals = prefs.getStringList('priorityVals') ?? [];
      priorities = {
        for (int i = 0; i < prioKeys.length && i < prioVals.length; i++)
          prioKeys[i]: prioVals[i]
      };

      weeklyLogCount = prefs.getInt('weeklyLogCount') ?? 0;
      weeklyStartLayer = prefs.getInt('weeklyStartLayer') ?? currentLayer;
      weeklyCoralStart = prefs.getInt('weeklyCoralStart') ?? corals;
      weeklyLayers = (prefs.getStringList('weeklyLayers') ?? [])
          .map(int.parse).toList();
      weeklyActionCounts = (prefs.getStringList('weeklyActionCounts') ?? [])
          .map(int.parse).toList();
      weeklyCoralChanges = (prefs.getStringList('weeklyCoralChanges') ?? [])
          .map(int.parse).toList();
      final actKeys = prefs.getStringList('weeklyActivityKeys') ?? [];
      final actVals = prefs.getStringList('weeklyActivityVals') ?? [];
      weeklyActivityMap = {
        for (int i = 0; i < actKeys.length && i < actVals.length; i++)
          actKeys[i]: int.tryParse(actVals[i]) ?? 0
      };

      // Sync animated display value with persisted corals.
      _displayCorals = corals;
      _coralFrom = corals;
      _coralTo = corals;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('currentLayer', currentLayer);
    await prefs.setInt('highestLayer', highestLayer);
    await prefs.setInt('deepestLayer', deepestLayer);
    await prefs.setInt('streak', streak);
    await prefs.setInt('stormDays', stormDays);
    await prefs.setBool('rescueAvailable', rescueAvailable);
    await prefs.setInt('rescueDayCounter', rescueDayCounter);
    await prefs.setBool('rescueDayActive', rescueDayActive);
    await prefs.setBool('momentumBonusUsed', momentumBonusUsed);
    await prefs.setBool('immunityUsed', immunityUsed);
    await prefs.setInt('corals', corals);
    await prefs.setString('lastLoggedDate', lastLoggedDate);
    await prefs.setStringList('categories', categories);
    await prefs.setStringList('priorityKeys', priorities.keys.toList());
    await prefs.setStringList('priorityVals', priorities.values.toList());

    await prefs.setInt('weeklyLogCount', weeklyLogCount);
    await prefs.setInt('weeklyStartLayer', weeklyStartLayer);
    await prefs.setInt('weeklyCoralStart', weeklyCoralStart);
    await prefs.setStringList(
        'weeklyLayers', weeklyLayers.map((e) => e.toString()).toList());
    await prefs.setStringList('weeklyActionCounts',
        weeklyActionCounts.map((e) => e.toString()).toList());
    await prefs.setStringList('weeklyCoralChanges',
        weeklyCoralChanges.map((e) => e.toString()).toList());
    await prefs.setStringList(
        'weeklyActivityKeys', weeklyActivityMap.keys.toList());
    await prefs.setStringList('weeklyActivityVals',
        weeklyActivityMap.values.map((e) => e.toString()).toList());
  }

  // ── Persist per-day history entry for calendar heatmap ──
  Future<void> _saveDayLog({
    required String date,
    required List<String> actions,
    required int coralDelta,
    required int layerBefore,
    required int layerAfter,
    required int coralsAfter,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final entry = jsonEncode({
      'actions': actions,
      'coralDelta': coralDelta,
      'layerBefore': layerBefore,
      'layerAfter': layerAfter,
      'coralsAfter': coralsAfter,
    });
    await prefs.setString('log_$date', entry);
    // Maintain a date index for fast calendar queries
    final dates = prefs.getStringList('logDates') ?? [];
    if (!dates.contains(date)) {
      dates.add(date);
      await prefs.setStringList('logDates', dates);
    }
  }

  int _layerFromCorals(int c) {
    for (int i = 0; i < kLayerThresholds.length; i++) {
      if (c >= kLayerThresholds[i]) return i;
    }
    return 10;
  }

  double _priorityPoints(String action) {
    final p = priorities[action] ?? 'mid';
    if (p == 'high') return 3.0;
    if (p == 'low')  return 1.0;
    return 2.0;
  }

  double _computePoints(Set<String> selected) =>
      selected.fold(0.0, (sum, a) => sum + _priorityPoints(a));

  int _coralDelta(double points) {
    final rng = math.Random();

    int base;
    if (points >= 8.0)      base = 49 + rng.nextInt(5);
    else if (points >= 6.0) base = 0;
    else if (points >= 1.0) base = -(49 + rng.nextInt(7));
    else                    base = -(100 + rng.nextInt(4));

    if (base > 0) {
      if (streak >= 3 && !momentumBonusUsed) {
        base *= 2;
        momentumBonusUsed = true;
      }
      if (streak >= 7 && rng.nextBool()) {
        base *= 2;
      }
    }

    return base;
  }

  void _processActions(int actions, Set<String> selected) {
    rescueDayActive = false;
    rescueDayCounter++;
    if (rescueDayCounter >= 7) {
      rescueDayCounter = 0;
      rescueDayActive = true;
      rescueAvailable = true;
    }

    final points = _computePoints(selected);
    int delta = _coralDelta(points);

    if (streak >= 14 && delta < 0 && !immunityUsed) {
      delta = 0;
      immunityUsed = true;
    }

    if (rescueAvailable && delta < 0) {
      delta = 0;
      rescueAvailable = false;
      _save();
      OceanHaptics.rescueBuoy();
      _showInfoDialog(
        layerIndex: currentLayer,
        title: 'Rescue Buoy Used',
        message:
            'Your buoy held you in place today. No corals lost — rest well. The ocean will wait.',
        buttonText: 'Thank you',
        accentColor: const Color(0xFF4FC3F7),
      );
    }

    if (delta == 0 && currentLayer > 0) {
      stormDays++;
      if (stormDays >= 3) {
        delta = -50;
        stormDays = 0;
        OceanHaptics.storm();
        _showInfoDialog(
          title: 'A Storm Has Come',
          message:
              '3 days without movement. The tides turn against you — you lose 50 corals.',
          buttonText: 'Face the Storm',
          accentColor: Colors.orange,
          icon: Icons.bolt_rounded,
        );
      }
    } else {
      stormDays = 0;
    }

    final newCorals = (corals + delta).clamp(0, 999999);
    final newLayer = _layerFromCorals(newCorals);

    if (delta >= 0) {
      streak++;
    } else {
      streak = 0;
      momentumBonusUsed = false;
      immunityUsed = false;
    }

    if (newLayer < highestLayer) highestLayer = newLayer;
    if (newLayer > deepestLayer) deepestLayer = newLayer;

    if (weeklyLogCount == 0) {
      weeklyStartLayer = currentLayer;
      weeklyCoralStart = corals;
    }
    weeklyLayers.add(newLayer);
    weeklyActionCounts.add(actions);
    weeklyCoralChanges.add(delta);
    for (final act in selected) {
      weeklyActivityMap[act] = (weeklyActivityMap[act] ?? 0) + 1;
    }
    weeklyLogCount++;

    lastLoggedDate = _todayString();

    final prev = currentLayer;
    final oldCorals = corals;
    setState(() {
      corals = newCorals;
      currentLayer = newLayer;
    });
    _save();

    // Persist daily history for calendar heatmap
    _saveDayLog(
      date: _todayString(),
      actions: selected.toList(),
      coralDelta: delta,
      layerBefore: prev,
      layerAfter: newLayer,
      coralsAfter: newCorals,
    );

    // Fire the coral animation AFTER setState so the underlying value is
    // already correct. The display still shows the old number and ticks toward
    // the new one over ~1s.
    _animateCoralChange(oldCorals, newCorals);

    if (weeklyLogCount >= 7) {
      final snapLayers = List<int>.from(weeklyLayers);
      final snapActions = List<int>.from(weeklyActionCounts);
      final snapCoralChanges = List<int>.from(weeklyCoralChanges);
      final snapActivity = Map<String, int>.from(weeklyActivityMap);
      final snapStart = weeklyStartLayer;
      final snapCoralStart = weeklyCoralStart;

      setState(() {
        weeklyLogCount = 0;
        weeklyLayers = [];
        weeklyActionCounts = [];
        weeklyCoralChanges = [];
        weeklyActivityMap = {};
        weeklyStartLayer = newLayer;
        weeklyCoralStart = newCorals;
      });
      _save();

      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        _showReflection(actions, delta, prev, newLayer, onDismiss: () {
          if (!mounted) return;
          OceanHaptics.weeklySummary();
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => WeeklySummaryScreen(
              layers: snapLayers,
              actionCounts: snapActions,
              coralChanges: snapCoralChanges,
              activityMap: snapActivity,
              startLayer: snapStart,
              endLayer: newLayer,
              totalCorals: newCorals,
              weeklyCoralStart: snapCoralStart,
            ),
          ));
        });
      });
    } else {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _showReflection(actions, delta, prev, newLayer);
      });
    }
  }

  void _showReflection(int actions, int delta, int prev, int newLayer,
      {VoidCallback? onDismiss}) {
    OceanHaptics.reflection(delta);

    // Layer transition haptics — crossing a depth boundary.
    if (newLayer != prev) {
      Future.delayed(const Duration(milliseconds: 350), () {
        if (newLayer < prev) {
          OceanHaptics.layerAscend();
        } else {
          OceanHaptics.layerDescend();
        }
      });
    }

    final rng = math.Random();
    const rise = [
      'You rose toward the island today.',
      'The tide lifted you higher.',
      'Light grows above you.',
      'One stroke closer to the surface.',
    ];
    const stay = [
      'You held your ground against the tide.',
      'The current could not move you today.',
      'Still waters — you held your depth.',
    ];
    const fall = [
      'The ocean pulled you deeper today.',
      'The pressure grows around you.',
      'You drift further from the light.',
      'The abyss is patient.',
    ];

    String msg;
    String sub;
    IconData dirIcon;
    Color dirColor;

    if (delta > 0) {
      msg = rise[rng.nextInt(rise.length)];
      sub = '$actions actions  •  +$delta corals';
      dirIcon = Icons.keyboard_arrow_up_rounded;
      dirColor = const Color(0xFF4CAF50);
    } else if (delta < 0) {
      msg = fall[rng.nextInt(fall.length)];
      sub = '$actions actions  •  $delta corals';
      dirIcon = Icons.keyboard_arrow_down_rounded;
      dirColor = Colors.redAccent;
    } else {
      msg = stay[rng.nextInt(stay.length)];
      sub = '$actions actions  •  no corals gained';
      dirIcon = Icons.remove_rounded;
      dirColor = const Color(0xFFF4C842);
    }

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF0C1F35),
            borderRadius: BorderRadius.circular(24),
            border:
                Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LayerIconWidget(layerIndex: newLayer, size: 72),
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: dirColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: dirColor.withOpacity(0.3), width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(dirIcon, color: dirColor, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      kLayers[newLayer].name,
                      style: TextStyle(
                          color: dirColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                msg,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(sub,
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onDismiss?.call();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF4C842),
                    foregroundColor: const Color(0xFF1A1A2E),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    onDismiss != null ? 'See Weekly Summary' : 'Continue',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, letterSpacing: 1)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInfoDialog({
    int? layerIndex,
    required String title,
    required String message,
    required String buttonText,
    Color accentColor = const Color(0xFFF4C842),
    IconData? icon,
  }) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF0C1F35),
            borderRadius: BorderRadius.circular(24),
            border:
                Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (layerIndex != null) ...[
                LayerIconWidget(layerIndex: layerIndex, size: 64),
                const SizedBox(height: 16),
              ] else if (icon != null) ...[
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentColor.withOpacity(0.15),
                    border: Border.all(
                        color: accentColor.withOpacity(0.4), width: 1),
                  ),
                  child: Icon(icon, color: accentColor, size: 26),
                ),
                const SizedBox(height: 16),
              ],
              Text(title,
                  style: TextStyle(
                      color: accentColor,
                      fontSize: 19,
                      fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(message,
                  style: const TextStyle(
                      color: Colors.white60, fontSize: 14, height: 1.6),
                  textAlign: TextAlign.center),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: const Color(0xFF1A1A2E),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(buttonText,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, letterSpacing: 1)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  bool get _hasLoggedToday =>
      kEnforceDailyLimit && lastLoggedDate == _todayString();

  void _openLogSheet() {
    if (_hasLoggedToday) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => LogActionsSheet(
        categories: categories,
        priorities: priorities,
        onConfirm: (count, selected) {
          Navigator.pop(context);
          _processActions(count, selected);
        },
        onCategoriesUpdated: (cats) {
          setState(() => categories = cats);
          _save();
        },
        onPrioritiesUpdated: (prio) {
          setState(() => priorities = prio);
          _save();
        },
      ),
    );
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SettingsSheet(
        categories: categories,
        priorities: priorities,
        onPrioritiesUpdated: (prio) {
          setState(() => priorities = prio);
          _save();
        },
        onCategoriesUpdated: (cats) {
          setState(() => categories = cats);
          _save();
        },
        onReset: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const AppRouter()),
              (_) => false,
            );
          }
        },
      ),
    );
  }

  void _showMechanicInfo(String type) {
    const Map<String, Map<String, dynamic>> info = {
      'momentum': {
        'title': 'Momentum Multiplier',
        'body':
            '3-day streak: your corals that day are doubled — once.\n7-day streak: a chance to double again, at random.\n14-day streak: one loss becomes zero.\n\nConsistency compounds.',
        'icon': Icons.local_fire_department_rounded,
        'color': Color(0xFFFFA726),
      },
      'storm': {
        'title': 'The Storm',
        'body':
            '3 stagnant days in a row triggers a storm — you lose 50 corals.\n\nThe ocean punishes stillness.',
        'icon': Icons.bolt_rounded,
        'color': Colors.orange,
      },
      'rescue': {
        'title': 'Rescue Buoy',
        'body':
            'Once every 7 days, your buoy is ready. If you would lose corals, it activates automatically — you get 0 instead.\n\nA good day leaves it untouched.\n\nRepresents a rest day. Resets every 7 days.',
        'icon': Icons.anchor_rounded,
        'color': Color(0xFF4FC3F7),
      },
      'treasure': {
        'title': 'Treasure System',
        'body':
            'Every 7 consecutive productive days unlocks new rewards — sea creatures, island decorations, coral reefs.\n\nComing in a future update.',
        'icon': Icons.stars_rounded,
        'color': Color(0xFFF4C842),
      },
    };
    final d = info[type]!;
    _showInfoDialog(
      title: d['title'] as String,
      message: d['body'] as String,
      buttonText: 'Got it',
      accentColor: d['color'] as Color,
      icon: d['icon'] as IconData,
    );
  }

  Widget _buildDepthBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Text('DEPTH',
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(
                currentLayer == 0
                    ? 'The Island'
                    : 'Layer $currentLayer of 10',
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: List.generate(11, (i) {
              final active = i == currentLayer;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  height: active ? 10 : 6,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    color: active
                        ? (i == 0
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFF4C842))
                        : Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _statCard(Icons.local_fire_department_rounded,
              const Color(0xFFFFA726), '$streak', 'Streak'),
          const SizedBox(width: 8),
          _statCard(Icons.keyboard_arrow_up_rounded, const Color(0xFF4CAF50),
              highestLayer == 0 ? 'Island' : 'L$highestLayer', 'Best'),
          const SizedBox(width: 8),
          _statCard(Icons.keyboard_arrow_down_rounded, const Color(0xFF5C6BC0),
              'L$deepestLayer', 'Deepest'),
        ],
      ),
    );
  }

  Widget _statCard(IconData icon, Color color, String val, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          border: Border.all(
              color: Colors.white.withOpacity(0.08), width: 0.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(val,
                style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            Text(label,
                style: const TextStyle(
                    color: Colors.white38, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildMechanicsBadges() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _mechBadge(Icons.local_fire_department_rounded,
              const Color(0xFFFFA726), 'Momentum', () => _showMechanicInfo('momentum')),
          const SizedBox(width: 8),
          _mechBadge(Icons.bolt_rounded, Colors.orange, 'Storm',
              () => _showMechanicInfo('storm')),
          const SizedBox(width: 8),
          _mechBadge(Icons.anchor_rounded, const Color(0xFF4FC3F7), 'Rescue',
              () => _showMechanicInfo('rescue')),
          const SizedBox(width: 8),
          _mechBadge(Icons.stars_rounded, const Color(0xFFF4C842), 'Treasure',
              () => _showMechanicInfo('treasure')),
        ],
      ),
    );
  }

  Widget _mechBadge(
      IconData icon, Color color, String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          OceanHaptics.surfaceTap();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.25),
            border: Border.all(
                color: Colors.white.withOpacity(0.08), width: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 3),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 9)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoggedTodayState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Colors.white.withOpacity(0.1), width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline_rounded,
              color: Colors.white.withOpacity(0.35), size: 18),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'The tide has settled for today.',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                'Return when the current shifts — tomorrow.',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 11,
                    fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final layer = kLayers[currentLayer];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Ocean background isolated so its 60fps repaints don't dirty the UI.
          RepaintBoundary(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 1000),
              child: OceanBackground(
                  key: ValueKey(currentLayer), layer: currentLayer),
            ),
          ),

          // Storm pulse isolated so it doesn't drag the UI layer.
          if (stormDays >= 2 && currentLayer > 0)
            Positioned.fill(
              child: RepaintBoundary(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (_, __) => DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.orange
                              .withOpacity(0.15 + _pulseCtrl.value * 0.3),
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'PRODUCTIVITY DEPTH',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(Icons.spa_rounded,
                                  color: Color(0xFFFF7043), size: 12),
                              const SizedBox(width: 4),
                              Text(
                                '$_displayCorals Corals',
                                style: const TextStyle(
                                  color: Color(0xFFFF7043),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (currentLayer > 0) ...[
                                const SizedBox(width: 5),
                                Text(
                                  '/ ${kLayerThresholds[currentLayer - 1]}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.28),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          OceanHaptics.surfaceTap();
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) =>
                                LayerMapScreen(currentLayer: currentLayer),
                          ));
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white.withOpacity(0.14),
                                width: 0.5),
                          ),
                          child: const Icon(Icons.map_outlined,
                              color: Colors.white60, size: 18),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          OceanHaptics.surfaceTap();
                          _openSettings();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white.withOpacity(0.14),
                                width: 0.5),
                          ),
                          child: const Icon(Icons.tune_rounded,
                              color: Colors.white60, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedBuilder(
                          animation: _pulseCtrl,
                          builder: (_, __) => Transform.scale(
                            scale: 1.0 + _pulseCtrl.value * 0.04,
                            child: LayerIconWidget(
                                layerIndex: currentLayer, size: 96),
                          ),
                        ),
                        const SizedBox(height: 18),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 500),
                          child: Text(
                            layer.name,
                            key: ValueKey(currentLayer),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 500),
                          child: Text(
                            layer.subtitle,
                            key: ValueKey('${currentLayer}sub'),
                            style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 15,
                                fontStyle: FontStyle.italic),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 22),

                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.11),
                                width: 0.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                currentLayer == 0
                                    ? Icons.wb_sunny_rounded
                                    : Icons.water_rounded,
                                color: const Color(0xFFF4C842),
                                size: 15,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                currentLayer == 0
                                    ? 'On the Island'
                                    : 'Layer $currentLayer of 10',
                                style: const TextStyle(
                                  color: Color(0xFFF4C842),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (rescueAvailable && currentLayer > 0) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0C3050).withOpacity(0.7),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Colors.lightBlue.withOpacity(0.3),
                                  width: 0.5),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.anchor_rounded,
                                    color: Colors.lightBlue, size: 14),
                                SizedBox(width: 6),
                                Text(
                                  'Rescue Buoy ready — auto-activates if you lose corals',
                                  style: TextStyle(
                                      color: Colors.lightBlue, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],

                        if (stormDays >= 2 && currentLayer > 0) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Colors.orange.withOpacity(0.3),
                                  width: 0.5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.bolt_rounded,
                                    color: Colors.orange, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  'Storm warning — ${3 - stormDays} day${(3 - stormDays) != 1 ? 's' : ''} until the tide strikes',
                                  style: const TextStyle(
                                      color: Colors.orange, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                Container(
                  padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    border: Border(
                        top: BorderSide(
                            color: Colors.white.withOpacity(0.07),
                            width: 0.5)),
                  ),
                  child: Column(
                    children: [
                      _buildDepthBar(),
                      const SizedBox(height: 14),
                      _buildStatsRow(),
                      const SizedBox(height: 10),
                      _buildMechanicsBadges(),
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _hasLoggedToday
                            ? _buildLoggedTodayState()
                            : SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: ElevatedButton(
                                  onPressed: () {
                                    OceanHaptics.surfaceTap();
                                    _openLogSheet();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFF4C842),
                                    foregroundColor: const Color(0xFF1A1A2E),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16)),
                                    elevation: 0,
                                  ),
                                  child: const Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.water_drop_outlined,
                                          size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        'LOG TODAY\'S ACTIONS',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                            letterSpacing: 1.5),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(height: 8),
                    ],
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

// ─────────────────────────────────────────────
//  LOG ACTIONS BOTTOM SHEET
// ─────────────────────────────────────────────
class LogActionsSheet extends StatefulWidget {
  final List<String> categories;
  final Map<String, String> priorities;
  final void Function(int count, Set<String> selected) onConfirm;
  final void Function(List<String> cats) onCategoriesUpdated;
  final void Function(Map<String, String> prio) onPrioritiesUpdated;

  const LogActionsSheet({
    super.key,
    required this.categories,
    required this.priorities,
    required this.onConfirm,
    required this.onCategoriesUpdated,
    required this.onPrioritiesUpdated,
  });

  @override
  State<LogActionsSheet> createState() => _LogActionsSheetState();
}

class _LogActionsSheetState extends State<LogActionsSheet> {
  late List<String> _cats;
  late Map<String, String> _priorities;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _cats = List.from(widget.categories);
    _priorities = Map.from(widget.priorities);
  }

  void _cyclePriority(String cat) {
    OceanHaptics.priorityCycle();
    setState(() {
      final current = _priorities[cat] ?? 'mid';
      if (current == 'mid') _priorities[cat] = 'high';
      else if (current == 'high') _priorities[cat] = 'low';
      else _priorities[cat] = 'mid';
    });
  }

  void _addCategory() async {
    final ctrl = TextEditingController();
    String selectedPriority = 'mid';
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: const Color(0xFF0C1F35),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Action',
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'e.g. Language Practice',
                  hintStyle: const TextStyle(color: Colors.white38),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.2), width: 0.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Color(0xFFF4C842), width: 1),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Priority',
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 8),
                  _PrioritySelector(
                    selected: selectedPriority,
                    onChanged: (p) => setLocal(() => selectedPriority = p),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.white54))),
            TextButton(
              onPressed: () {
                final val = ctrl.text.trim();
                if (val.isNotEmpty) {
                  if (_cats.contains(val)) {
                    showDialog(
                      context: context,
                      builder: (_) => Dialog(
                        backgroundColor: Colors.transparent,
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0C1F35),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                                color: Colors.redAccent.withOpacity(0.4),
                                width: 1),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.redAccent.withOpacity(0.12),
                                  border: Border.all(
                                      color: Colors.redAccent.withOpacity(0.4),
                                      width: 1),
                                ),
                                child: const Icon(Icons.do_not_disturb_on_outlined,
                                    color: Colors.redAccent, size: 24),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Already in the ocean',
                                style: TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '"$val" already exists in your actions. Each action must be unique.',
                                style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 13,
                                    height: 1.5),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 22),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                  ),
                                  child: const Text('Got it',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                    return;
                  }
                  setState(() {
                    _cats.add(val);
                    _priorities[val] = selectedPriority;
                  });
                  widget.onCategoriesUpdated(_cats);
                  widget.onPrioritiesUpdated(_priorities);
                }
                Navigator.pop(context);
              },
              child: const Text('Add',
                  style: TextStyle(color: Color(0xFFF4C842))),
            ),
          ],
        ),
      ),
    );
  }

  double _pointsFor(String action) {
    final p = _priorities[action] ?? 'mid';
    if (p == 'high') return 3.0;
    if (p == 'low')  return 1.0;
    return 2.0;
  }

  @override
  Widget build(BuildContext context) {
    final points = _selected.fold(0.0, (s, a) => s + _pointsFor(a));

    String movementLabel;
    String movementHint;
    Color moveColor;
    IconData moveIcon;

    if (points >= 8.0) {
      movementLabel = 'Rise';
      movementHint = 'Excellent!';
      moveColor = const Color(0xFF4CAF50);
      moveIcon = Icons.keyboard_arrow_up_rounded;
    } else if (points >= 6.0) {
      movementLabel = 'Hold position';
      final needed = (8.0 - points).toInt();
      movementHint = '$needed pts more to rise';
      moveColor = const Color(0xFFF4C842);
      moveIcon = Icons.remove_rounded;
    } else if (points >= 1.0) {
      movementLabel = 'Sink';
      final needed = (8.0 - points).toInt();
      movementHint = '$needed pts more to rise';
      moveColor = Colors.orange;
      moveIcon = Icons.keyboard_arrow_down_rounded;
    } else {
      movementLabel = 'Deep Sink';
      movementHint = 'Log at least 1 action';
      moveColor = Colors.redAccent;
      moveIcon = Icons.keyboard_double_arrow_down_rounded;
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0A1929),
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
          border:
              Border.all(color: Colors.white.withOpacity(0.08), width: 0.5),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('What did you do today?',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                      SizedBox(height: 2),
                      Text('Each action counts once per day',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      points % 1 == 0 ? '${points.toInt()}' : '$points',
                      style: TextStyle(
                          color: moveColor,
                          fontSize: 22,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: moveColor.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: moveColor.withOpacity(0.28), width: 0.5),
                ),
                child: Row(
                  children: [
                    Icon(moveIcon, color: moveColor, size: 18),
                    const SizedBox(width: 6),
                    Text(movementLabel,
                        style: TextStyle(
                            color: moveColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text(movementHint,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _cats.length + 1,
                itemBuilder: (_, i) {
                  if (i == _cats.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: TextButton.icon(
                        onPressed: _addCategory,
                        icon: const Icon(Icons.add_circle_outline_rounded,
                            color: Colors.white38, size: 18),
                        label: const Text('Add custom action',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 13)),
                      ),
                    );
                  }
                  final cat = _cats[i];
                  final sel = _selected.contains(cat);
                  return GestureDetector(
                    onTap: () {
                      OceanHaptics.selectionTick();
                      setState(() => sel
                          ? _selected.remove(cat)
                          : _selected.add(cat));
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: sel
                            ? const Color(0xFFF4C842).withOpacity(0.1)
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: sel
                              ? const Color(0xFFF4C842).withOpacity(0.5)
                              : Colors.white.withOpacity(0.07),
                          width: sel ? 1.5 : 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: sel
                                  ? const Color(0xFFF4C842)
                                  : Colors.transparent,
                              border: Border.all(
                                color: sel
                                    ? const Color(0xFFF4C842)
                                    : Colors.white30,
                                width: 1,
                              ),
                            ),
                            child: sel
                                ? const Icon(Icons.check_rounded,
                                    color: Color(0xFF1A1A2E), size: 14)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              cat,
                              style: TextStyle(
                                color: sel
                                    ? const Color(0xFFF4C842)
                                    : Colors.white70,
                                fontSize: 15,
                                fontWeight: sel
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _cyclePriority(cat),
                            child: _PriorityBadge(
                              priority: _priorities[cat] ?? 'mid',
                              tappable: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    final selected = Set<String>.from(_selected);
                    showDialog(
                      context: context,
                      builder: (_) => Dialog(
                        backgroundColor: Colors.transparent,
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0C1F35),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                                width: 0.5),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFF4C842).withOpacity(0.12),
                                  border: Border.all(
                                      color: const Color(0xFFF4C842).withOpacity(0.4),
                                      width: 1),
                                ),
                                child: const Icon(Icons.water_drop_outlined,
                                    color: Color(0xFFF4C842), size: 24),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Ready to dive?',
                                style: TextStyle(
                                    color: Color(0xFFF4C842),
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Once you dive, today\'s log is sealed. Make sure your actions are correct.',
                                style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 13,
                                    height: 1.6),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => Navigator.pop(context),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                            color: Colors.white.withOpacity(0.2),
                                            width: 0.5),
                                        foregroundColor: Colors.white60,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                      ),
                                      child: const Text('Go back',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.5)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        OceanHaptics.diveIn();
                                        widget.onConfirm(selected.length, selected);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFFF4C842),
                                        foregroundColor:
                                            const Color(0xFF1A1A2E),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        elevation: 0,
                                      ),
                                      child: const Text('Dive in',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 1)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF4C842),
                    foregroundColor: const Color(0xFF1A1A2E),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'CONFIRM & DIVE',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        letterSpacing: 2),
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

// ─────────────────────────────────────────────
//  SETTINGS SHEET
// ─────────────────────────────────────────────
class SettingsSheet extends StatelessWidget {
  final List<String> categories;
  final Map<String, String> priorities;
  final void Function(List<String>) onCategoriesUpdated;
  final void Function(Map<String, String>) onPrioritiesUpdated;
  final VoidCallback onReset;

  const SettingsSheet({
    super.key,
    required this.categories,
    required this.priorities,
    required this.onCategoriesUpdated,
    required this.onPrioritiesUpdated,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A1929),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 0.5),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('SETTINGS',
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 12),

            _SettingsLink(
              icon: Icons.tune_rounded,
              iconColor: const Color(0xFFF4C842),
              label: 'Change Actions',
              subtitle: 'Add, remove or reorder your daily actions',
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ActionsScreen(
                    categories: categories,
                    priorities: priorities,
                    onCategoriesUpdated: onCategoriesUpdated,
                    onPrioritiesUpdated: onPrioritiesUpdated,
                    onReset: onReset,
                  ),
                ));
              },
            ),

            _SettingsLink(
              icon: Icons.calendar_month_rounded,
              iconColor: const Color(0xFF4FC3F7),
              label: 'Historical Log',
              subtitle: 'Calendar view of your daily progress',
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const HistoricalLogScreen(),
                ));
              },
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(color: Colors.white10, height: 1),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _SettingsLink extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsLink({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: Colors.white.withOpacity(0.07), width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconColor.withOpacity(0.12),
                border: Border.all(
                    color: iconColor.withOpacity(0.3), width: 0.5),
              ),
              child: Icon(icon, color: iconColor, size: 17),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  ACTIONS SCREEN
// ─────────────────────────────────────────────
class ActionsScreen extends StatefulWidget {
  final List<String> categories;
  final Map<String, String> priorities;
  final void Function(List<String>) onCategoriesUpdated;
  final void Function(Map<String, String>) onPrioritiesUpdated;
  final VoidCallback onReset;

  const ActionsScreen({
    super.key,
    required this.categories,
    required this.priorities,
    required this.onCategoriesUpdated,
    required this.onPrioritiesUpdated,
    required this.onReset,
  });

  @override
  State<ActionsScreen> createState() => _ActionsScreenState();
}

class _ActionsScreenState extends State<ActionsScreen> {
  late List<String> _cats;
  late Map<String, String> _priorities;

  @override
  void initState() {
    super.initState();
    _cats = List.from(widget.categories);
    _priorities = Map.from(widget.priorities);
  }

  void _cyclePriority(String cat) {
    OceanHaptics.priorityCycle();
    setState(() {
      final current = _priorities[cat] ?? 'mid';
      if (current == 'mid') _priorities[cat] = 'high';
      else if (current == 'high') _priorities[cat] = 'low';
      else _priorities[cat] = 'mid';
    });
    widget.onPrioritiesUpdated(_priorities);
  }

  Future<void> _addCategory() async {
    final ctrl = TextEditingController();
    String selectedPriority = 'mid';
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: const Color(0xFF0C1F35),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Custom Action',
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'e.g. Language Practice',
                  hintStyle: const TextStyle(color: Colors.white38),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.2), width: 0.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Color(0xFFF4C842), width: 1),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Priority',
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 8),
                  _PrioritySelector(
                    selected: selectedPriority,
                    onChanged: (p) => setLocal(() => selectedPriority = p),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.white54))),
            TextButton(
              onPressed: () {
                final val = ctrl.text.trim();
                if (val.isNotEmpty) {
                  if (_cats.contains(val)) {
                    showDialog(
                      context: context,
                      builder: (_) => Dialog(
                        backgroundColor: Colors.transparent,
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0C1F35),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                                color: Colors.redAccent.withOpacity(0.4),
                                width: 1),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.redAccent.withOpacity(0.12),
                                  border: Border.all(
                                      color: Colors.redAccent.withOpacity(0.4),
                                      width: 1),
                                ),
                                child: const Icon(Icons.do_not_disturb_on_outlined,
                                    color: Colors.redAccent, size: 24),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Already in the ocean',
                                style: TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '"$val" already exists in your actions. Each action must be unique.',
                                style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 13,
                                    height: 1.5),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 22),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                  ),
                                  child: const Text('Got it',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                    return;
                  }
                  setState(() {
                    _cats.add(val);
                    _priorities[val] = selectedPriority;
                  });
                  widget.onCategoriesUpdated(_cats);
                  widget.onPrioritiesUpdated(_priorities);
                }
                Navigator.pop(context);
              },
              child: const Text('Add',
                  style: TextStyle(color: Color(0xFFF4C842))),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1929),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withOpacity(0.14),
                            width: 0.5),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white60, size: 16),
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'CHANGE ACTIONS',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 34),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Your Actions',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _cats.length,
                onReorder: (oldI, newI) {
                  setState(() {
                    if (newI > oldI) newI--;
                    final cat = _cats.removeAt(oldI);
                    _cats.insert(newI, cat);
                  });
                  widget.onCategoriesUpdated(_cats);
                },
                itemBuilder: (_, i) {
                  final cat = _cats[i];
                  return Container(
                    key: ValueKey(cat),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.07), width: 0.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.drag_handle_rounded,
                            color: Colors.white24, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(cat,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 14))),
                        GestureDetector(
                          onTap: () => _cyclePriority(cat),
                          child: _PriorityBadge(
                            priority: _priorities[cat] ?? 'mid',
                            tappable: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() => _cats.removeAt(i));
                            widget.onCategoriesUpdated(_cats);
                          },
                          child: const Icon(
                              Icons.remove_circle_outline_rounded,
                              color: Colors.redAccent,
                              size: 18),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _addCategory,
                  icon: const Icon(Icons.add_circle_outline_rounded,
                      color: Color(0xFFF4C842), size: 18),
                  label: const Text('Add Custom Action'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                        color: Color(0xFFF4C842), width: 0.5),
                    foregroundColor: const Color(0xFFF4C842),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 0, 16, MediaQuery.of(context).padding.bottom + 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: const Color(0xFF0C1F35),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        title: const Text('Reset Everything?',
                            style: TextStyle(color: Colors.white)),
                        content: const Text(
                            'This will delete all your data and restart onboarding.',
                            style: TextStyle(color: Colors.white60)),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel',
                                  style: TextStyle(color: Colors.white54))),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              widget.onReset();
                            },
                            child: const Text('Reset',
                                style: TextStyle(color: Colors.redAccent)),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.restart_alt_rounded,
                      color: Colors.redAccent, size: 18),
                  label: const Text('Reset App'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                        color: Colors.redAccent, width: 0.5),
                    foregroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
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

// ─────────────────────────────────────────────
//  WEEKLY SUMMARY SCREEN
// ─────────────────────────────────────────────
class WeeklySummaryScreen extends StatefulWidget {
  final List<int> layers;
  final List<int> actionCounts;
  final List<int> coralChanges;
  final Map<String, int> activityMap;
  final int startLayer;
  final int endLayer;
  final int totalCorals;
  final int weeklyCoralStart;

  const WeeklySummaryScreen({
    super.key,
    required this.layers,
    required this.actionCounts,
    required this.coralChanges,
    required this.activityMap,
    required this.startLayer,
    required this.endLayer,
    required this.totalCorals,
    required this.weeklyCoralStart,
  });

  @override
  State<WeeklySummaryScreen> createState() => _WeeklySummaryScreenState();
}

class _WeeklySummaryScreenState extends State<WeeklySummaryScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _enterCtrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fade = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut));
    _enterCtrl.forward();
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  int get _bestLayer => widget.layers.isEmpty
      ? widget.startLayer
      : widget.layers.reduce(math.min);

  int get _worstLayer => widget.layers.isEmpty
      ? widget.startLayer
      : widget.layers.reduce(math.max);

  int get _netMovement => widget.startLayer - widget.endLayer;
  int get _totalActions => widget.actionCounts.fold(0, (a, b) => a + b);
  double get _avgActions => widget.actionCounts.isEmpty
      ? 0
      : _totalActions / widget.actionCounts.length;
  int get _productiveDays => widget.actionCounts.where((a) => a >= 4).length;

  String get _headline {
    if (_netMovement >= 3) return 'Outstanding week — you are rising fast.';
    if (_netMovement >= 1) return 'Solid progress — the island grows closer.';
    if (_netMovement == 0) return 'You held your ground — consistency is power.';
    if (_netMovement >= -2) return 'A tough week. The ocean tests the committed.';
    return 'The depths pulled you this week. Time to fight back.';
  }

  Color get _headlineColor {
    if (_netMovement >= 1) return const Color(0xFF4CAF50);
    if (_netMovement == 0) return const Color(0xFFF4C842);
    return Colors.redAccent;
  }

  List<MapEntry<String, int>> get _sortedActivities {
    final entries = widget.activityMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  int get _bgLayer => widget.endLayer.clamp(0, 10);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          RepaintBoundary(child: OceanBackground(layer: _bgLayer)),
          Container(color: Colors.black.withOpacity(0.55)),
          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.14),
                                    width: 0.5),
                              ),
                              child: const Icon(Icons.close_rounded,
                                  color: Colors.white60, size: 18),
                            ),
                          ),
                          const Spacer(),
                          const Text(
                            'WEEKLY SUMMARY',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(width: 34),
                        ],
                      ),
                    ),

                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                    color: _headlineColor.withOpacity(0.3),
                                    width: 1),
                              ),
                              child: Column(
                                children: [
                                  LayerIconWidget(layerIndex: _bgLayer, size: 64),
                                  const SizedBox(height: 12),
                                  Text(
                                    _headline,
                                    style: TextStyle(
                                      color: _headlineColor,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      height: 1.4,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Week complete — ${widget.layers.length} days logged',
                                    style: const TextStyle(
                                        color: Colors.white38, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            Row(
                              children: [
                                _summaryStatCard(
                                  icon: Icons.keyboard_arrow_up_rounded,
                                  color: const Color(0xFF4CAF50),
                                  value: _bestLayer == 0 ? 'Island' : 'L$_bestLayer',
                                  label: 'Best Layer',
                                ),
                                const SizedBox(width: 8),
                                _summaryStatCard(
                                  icon: Icons.keyboard_arrow_down_rounded,
                                  color: Colors.redAccent,
                                  value: 'L$_worstLayer',
                                  label: 'Worst Layer',
                                ),
                                const SizedBox(width: 8),
                                _summaryStatCard(
                                  icon: _netMovement > 0
                                      ? Icons.trending_up_rounded
                                      : _netMovement < 0
                                          ? Icons.trending_down_rounded
                                          : Icons.remove_rounded,
                                  color: _netMovement > 0
                                      ? const Color(0xFF4CAF50)
                                      : _netMovement < 0
                                          ? Colors.redAccent
                                          : const Color(0xFFF4C842),
                                  value: _netMovement > 0
                                      ? '+$_netMovement'
                                      : _netMovement < 0
                                          ? '$_netMovement'
                                          : '0',
                                  label: 'Net Layers',
                                ),
                                const SizedBox(width: 8),
                                _summaryStatCard(
                                  icon: Icons.bolt_rounded,
                                  color: const Color(0xFFF4C842),
                                  value: '$_productiveDays',
                                  label: 'Strong Days',
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            _sectionLabel('DAILY DEPTH CHART'),
                            const SizedBox(height: 10),
                            Container(
                              height: 200,
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.08),
                                    width: 0.5),
                              ),
                              child: CustomPaint(
                                painter: WeeklyBarChartPainter(
                                  layers: widget.layers,
                                  actionCounts: widget.actionCounts,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _legendDot(const Color(0xFF4FC3F7)),
                                const SizedBox(width: 4),
                                const Text('Depth level',
                                    style: TextStyle(
                                        color: Colors.white38, fontSize: 11)),
                                const SizedBox(width: 16),
                                _legendDot(const Color(0xFFF4C842)),
                                const SizedBox(width: 4),
                                const Text('Actions logged',
                                    style: TextStyle(
                                        color: Colors.white38, fontSize: 11)),
                              ],
                            ),

                            const SizedBox(height: 20),

                            _sectionLabel('ACTIONS THIS WEEK'),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.35),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.07),
                                    width: 0.5),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    '$_totalActions',
                                    style: const TextStyle(
                                        color: Color(0xFFF4C842),
                                        fontSize: 40,
                                        fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(width: 14),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('total actions',
                                          style: TextStyle(
                                              color: Colors.white60,
                                              fontSize: 14)),
                                      Text(
                                        '${_avgActions.toStringAsFixed(1)} avg per day',
                                        style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '$_productiveDays / ${widget.layers.length}',
                                        style: const TextStyle(
                                            color: Color(0xFF4CAF50),
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700),
                                      ),
                                      const Text('strong days',
                                          style: TextStyle(
                                              color: Colors.white38,
                                              fontSize: 11)),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            _sectionLabel('CORALS THIS WEEK'),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.35),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: const Color(0xFFFF7043).withOpacity(0.2),
                                    width: 0.5),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.spa_rounded,
                                      color: Color(0xFFFF7043), size: 28),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Builder(builder: (_) {
                                        final weeklyNet = widget.totalCorals - widget.weeklyCoralStart;
                                        final positive = weeklyNet >= 0;
                                        return Row(
                                          children: [
                                            Text(
                                              positive ? '+$weeklyNet' : '$weeklyNet',
                                              style: TextStyle(
                                                color: positive
                                                    ? const Color(0xFF4CAF50)
                                                    : Colors.redAccent,
                                                fontSize: 22,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            const Text(
                                              'this week',
                                              style: TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 13),
                                            ),
                                          ],
                                        );
                                      }),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Started at ${widget.weeklyCoralStart}',
                                        style: const TextStyle(
                                            color: Colors.white38, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${widget.totalCorals}',
                                        style: const TextStyle(
                                          color: Color(0xFFFF7043),
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const Text(
                                        'total corals',
                                        style: TextStyle(
                                            color: Colors.white38, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            if (_sortedActivities.isNotEmpty) ...[
                              _sectionLabel('ACTIVITY BREAKDOWN'),
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.35),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.07),
                                      width: 0.5),
                                ),
                                child: Column(
                                  children: _sortedActivities
                                      .map((e) => _activityRow(e.key, e.value))
                                      .toList(),
                                ),
                              ),
                            ],

                            const SizedBox(height: 20),

                            _sectionLabel('DAY BY DAY'),
                            const SizedBox(height: 10),
                            ...List.generate(widget.layers.length, (i) {
                              final layer = widget.layers[i];
                              final acts = i < widget.actionCounts.length
                                  ? widget.actionCounts[i]
                                  : 0;
                              final coralChange = i < widget.coralChanges.length
                                  ? widget.coralChanges[i]
                                  : 0;
                              final prev = i == 0
                                  ? widget.startLayer
                                  : widget.layers[i - 1];
                              final delta = prev - layer;
                              return _dayRow(i + 1, layer, acts, delta, coralChange);
                            }),

                            const SizedBox(height: 28),

                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF4C842),
                                  foregroundColor: const Color(0xFF1A1A2E),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'BACK TO THE OCEAN',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      letterSpacing: 1.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 0),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white38,
                fontSize: 10,
                letterSpacing: 2,
                fontWeight: FontWeight.w700)),
      );

  Widget _legendDot(Color color) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  Widget _summaryStatCard({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2), width: 0.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 5),
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: Colors.white38, fontSize: 9),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _activityRow(String name, int count) {
    final max = _sortedActivities.isEmpty ? 1 : _sortedActivities.first.value;
    final fraction = max == 0 ? 0.0 : count / max;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(name,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13)),
              ),
              Text('$count day${count != 1 ? 's' : ''}',
                  style: const TextStyle(
                      color: Color(0xFFF4C842),
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 5,
              backgroundColor: Colors.white.withOpacity(0.07),
              valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFFF4C842)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayRow(int day, int layer, int actions, int delta, int coralChange) {
    final ld = kLayers[layer];
    Color deltaColor;
    IconData deltaIcon;
    String deltaStr;
    if (delta > 0) {
      deltaColor = const Color(0xFF4CAF50);
      deltaIcon = Icons.keyboard_arrow_up_rounded;
      deltaStr = '+$delta';
    } else if (delta < 0) {
      deltaColor = Colors.redAccent;
      deltaIcon = Icons.keyboard_arrow_down_rounded;
      deltaStr = '$delta';
    } else {
      deltaColor = Colors.white38;
      deltaIcon = Icons.remove_rounded;
      deltaStr = '±0';
    }

    final coralColor = coralChange > 0
        ? const Color(0xFF4CAF50)
        : coralChange < 0
            ? Colors.redAccent
            : Colors.white38;
    final coralStr = coralChange > 0
        ? '+$coralChange'
        : coralChange < 0
            ? '$coralChange'
            : '0';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.07), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('$day',
                  style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ld.iconColor.withOpacity(0.12),
              border: Border.all(color: ld.iconColor.withOpacity(0.3), width: 1),
            ),
            child: Icon(ld.icon, color: ld.iconColor, size: 12),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(ld.name,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                overflow: TextOverflow.ellipsis),
          ),
          Text('$actions act.',
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(width: 6),
          const Icon(Icons.spa_rounded, color: Color(0xFFFF7043), size: 11),
          const SizedBox(width: 2),
          Text(coralStr,
              style: TextStyle(
                  color: coralColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Icon(deltaIcon, color: deltaColor, size: 15),
          Text(deltaStr,
              style: TextStyle(
                  color: deltaColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  WEEKLY BAR CHART PAINTER
// ─────────────────────────────────────────────
class WeeklyBarChartPainter extends CustomPainter {
  final List<int> layers;
  final List<int> actionCounts;

  WeeklyBarChartPainter({required this.layers, required this.actionCounts});

  @override
  void paint(Canvas canvas, Size size) {
    if (layers.isEmpty) return;

    final w = size.width;
    final h = size.height;
    final count = layers.length;
    final barGroupW = w / count;
    const barW = 10.0;
    const gap = 5.0;
    const labelH = 22.0;
    final chartH = h - labelH;

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..strokeWidth = 0.5;
    for (int i = 1; i <= 4; i++) {
      final y = chartH * (1 - i / 4);
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    final maxActions =
        actionCounts.isEmpty ? 1 : actionCounts.reduce(math.max).clamp(1, 999);

    for (int i = 0; i < count; i++) {
      final cx = barGroupW * i + barGroupW / 2;

      final layerFraction = (10 - layers[i]) / 10.0;
      final depthH = (chartH - 8) * layerFraction;
      final depthTop = chartH - depthH;
      final depthColor = Color.lerp(
        Colors.redAccent,
        const Color(0xFF4FC3F7),
        layerFraction,
      )!;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - gap / 2 - barW, depthTop, barW, depthH),
          const Radius.circular(4),
        ),
        Paint()..color = depthColor.withOpacity(0.85),
      );

      final actFraction = i < actionCounts.length
          ? actionCounts[i] / maxActions.toDouble()
          : 0.0;
      final actH = (chartH - 8) * actFraction;
      final actTop = chartH - actH;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx + gap / 2, actTop, barW, actH),
          const Radius.circular(4),
        ),
        Paint()..color = const Color(0xFFF4C842).withOpacity(0.85),
      );

      final tp = TextPainter(
        text: TextSpan(
          text: 'D${i + 1}',
          style: TextStyle(
              color: Colors.white.withOpacity(0.35),
              fontSize: 10,
              fontWeight: FontWeight.w500),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, chartH + 5));
    }
  }

  @override
  bool shouldRepaint(WeeklyBarChartPainter old) => false;
}

// ─────────────────────────────────────────────
//  LAYER MAP SCREEN
// ─────────────────────────────────────────────
class LayerMapScreen extends StatefulWidget {
  final int currentLayer;
  const LayerMapScreen({super.key, required this.currentLayer});

  @override
  State<LayerMapScreen> createState() => _LayerMapScreenState();
}

class _LayerMapScreenState extends State<LayerMapScreen>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _fade;

  static const double _cardH = 80.0;
  static const double _cardSpacing = 10.0;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    _scrollCtrl = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      final target = widget.currentLayer * (_cardH + _cardSpacing) - 120.0;
      _scrollCtrl.animateTo(
        target.clamp(0.0, _scrollCtrl.position.maxScrollExtent),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const RepaintBoundary(child: OceanBackground(layer: 8)),
          Container(color: Colors.black.withOpacity(0.60)),
          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.14),
                                  width: 0.5),
                            ),
                            child: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white60,
                                size: 16),
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'LAYER MAP',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(width: 34),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Explore every layer. This does not affect your position.',
                      style: TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          fontStyle: FontStyle.italic),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      itemCount: kLayers.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _LayerMapCard(
                          index: index,
                          data: kLayers[index],
                          isUser: index == widget.currentLayer,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  LAYER MAP CARD
// ─────────────────────────────────────────────
class _LayerMapCard extends StatefulWidget {
  final int index;
  final LayerData data;
  final bool isUser;

  const _LayerMapCard({
    required this.index,
    required this.data,
    required this.isUser,
  });

  @override
  State<_LayerMapCard> createState() => _LayerMapCardState();
}

class _LayerMapCardState extends State<_LayerMapCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final isUser = widget.isUser;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isUser
              ? d.iconColor.withOpacity(0.12)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUser
                ? d.iconColor.withOpacity(0.55)
                : Colors.white.withOpacity(0.08),
            width: isUser ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  SizedBox(
                    width: 26,
                    child: Text(
                      widget.index == 0 ? '✦' : '${widget.index}',
                      style: TextStyle(
                        color: d.iconColor.withOpacity(0.7),
                        fontSize: widget.index == 0 ? 15 : 12,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: d.iconColor.withOpacity(0.12),
                      border: Border.all(
                          color: d.iconColor.withOpacity(0.3), width: 1),
                    ),
                    child: Icon(d.icon, color: d.iconColor, size: 17),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              d.name,
                              style: TextStyle(
                                color: isUser ? d.iconColor : Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (isUser) ...[
                              const SizedBox(width: 7),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: d.iconColor.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: d.iconColor.withOpacity(0.5),
                                      width: 0.5),
                                ),
                                child: Text(
                                  'YOU',
                                  style: TextStyle(
                                    color: d.iconColor,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          d.subtitle,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.white24,
                    size: 18,
                  ),
                ],
              ),
            ),

            if (_expanded) ...[
              Container(
                height: 0.5,
                margin: const EdgeInsets.symmetric(horizontal: 14),
                color: Colors.white.withOpacity(0.08),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.water_rounded,
                            color: d.iconColor.withOpacity(0.65),
                            size: 14),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            d.description,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 13,
                              height: 1.55,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                        height: 0.5,
                        color: Colors.white.withOpacity(0.06)),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.person_outline_rounded,
                            color: d.iconColor.withOpacity(0.65),
                            size: 14),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            d.persona,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              height: 1.55,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  PRIORITY BADGE WIDGET
// ─────────────────────────────────────────────
class _PriorityBadge extends StatelessWidget {
  final String priority;
  final bool tappable;

  const _PriorityBadge({required this.priority, this.tappable = false});

  static const _kBadgeWidth = 62.0;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;

    switch (priority) {
      case 'high':
        color = const Color(0xFFEF5350);
        label = 'High';
        break;
      case 'low':
        color = const Color(0xFF4CAF50);
        label = 'Low';
        break;
      default:
        color = const Color(0xFFF4C842);
        label = 'Mid';
    }

    return Container(
      width: _kBadgeWidth,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.30), width: 0.5),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            shadows: [
              Shadow(
                color: color.withOpacity(0.55),
                blurRadius: 6,
              ),
              Shadow(
                color: color.withOpacity(0.25),
                blurRadius: 12,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  PRIORITY SELECTOR (segmented control)
// ─────────────────────────────────────────────
class _PrioritySelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _PrioritySelector({
    required this.selected,
    required this.onChanged,
  });

  static const _priorities = ['low', 'mid', 'high'];
  static const _labels = {'low': 'Low', 'mid': 'Mid', 'high': 'High'};

  static Color _color(String p) {
    if (p == 'high') return const Color(0xFFEF5350);
    if (p == 'low') return const Color(0xFF4CAF50);
    return const Color(0xFFF4C842);
  }

  @override
  Widget build(BuildContext context) {
    final selectedIdx = _priorities.indexOf(selected).clamp(0, 2);

    // Map index → Alignment.x:  0 → -1.0,  1 → 0.0,  2 → 1.0
    final alignX = selectedIdx.toDouble() - 1.0;

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Stack(
          children: [
            // Sliding highlight pill — no LayoutBuilder needed
            AnimatedAlign(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment(alignX, 0),
              child: FractionallySizedBox(
                widthFactor: 1 / 3,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: 30,
                  decoration: BoxDecoration(
                    color: _color(selected).withOpacity(0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _color(selected).withOpacity(0.45),
                      width: 0.5,
                    ),
                  ),
                ),
              ),
            ),
            // Segment labels
            Row(
              children: _priorities.map((p) {
                final isActive = p == selected;
                final c = _color(p);
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      OceanHaptics.selectionTick();
                      onChanged(p);
                    },
                    child: SizedBox(
                      height: 30,
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            color: isActive ? c : Colors.white30,
                            fontSize: 11,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w500,
                            letterSpacing: 0.6,
                            fontFamily: 'SF Pro Display',
                            shadows: isActive
                                ? [
                                    Shadow(
                                      color: c.withOpacity(0.55),
                                      blurRadius: 6,
                                    ),
                                    Shadow(
                                      color: c.withOpacity(0.25),
                                      blurRadius: 12,
                                    ),
                                  ]
                                : [],
                          ),
                          child: Text(_labels[p]!),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
// ─────────────────────────────────────────────
//  HISTORICAL LOG / CALENDAR HEATMAP
//
//  A scrollable month-by-month calendar where each day cell is coloured
//  by the coral delta recorded that day (green = gain, gold = hold,
//  red = loss, dim = no log). Tapping a cell reveals a detail card with
//  actions logged, layer movement, and coral totals.
//
//  Data comes from per-day JSON entries written in _saveDayLog() and
//  indexed by the 'logDates' string list in SharedPreferences.
// ─────────────────────────────────────────────

class HistoricalLogScreen extends StatefulWidget {
  const HistoricalLogScreen({super.key});

  @override
  State<HistoricalLogScreen> createState() => _HistoricalLogScreenState();
}

class _HistoricalLogScreenState extends State<HistoricalLogScreen>
    with SingleTickerProviderStateMixin {
  late DateTime _viewMonth;
  Map<String, Map<String, dynamic>> _logs = {};
  Set<String> _logDates = {};
  String? _selectedDate;
  late AnimationController _enterCtrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _viewMonth = DateTime(now.year, now.month);
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _loadLogs();
    _enterCtrl.forward();
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final dates = prefs.getStringList('logDates') ?? [];
    final Map<String, Map<String, dynamic>> loaded = {};
    for (final d in dates) {
      final raw = prefs.getString('log_$d');
      if (raw != null) {
        try {
          loaded[d] = Map<String, dynamic>.from(
              jsonDecode(raw) as Map);
        } catch (_) {}
      }
    }
    if (mounted) {
      setState(() {
        _logDates = dates.toSet();
        _logs = loaded;
      });
    }
  }

  void _prevMonth() {
    OceanHaptics.selectionTick();
    setState(() {
      _viewMonth = DateTime(_viewMonth.year, _viewMonth.month - 1);
      _selectedDate = null;
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(_viewMonth.year, _viewMonth.month + 1);
    if (next.isAfter(DateTime(now.year, now.month + 1))) return;
    OceanHaptics.selectionTick();
    setState(() {
      _viewMonth = next;
      _selectedDate = null;
    });
  }

  String _monthLabel(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  String _fmtDate(int y, int m, int d) =>
      '$y-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';

  // ── Heatmap colour logic ──────────────────────
  Color _cellColor(String dateStr) {
    if (!_logDates.contains(dateStr)) return Colors.white.withOpacity(0.03);
    final entry = _logs[dateStr];
    if (entry == null) return Colors.white.withOpacity(0.03);
    final delta = (entry['coralDelta'] as num?)?.toInt() ?? 0;
    if (delta > 30)  return const Color(0xFF4CAF50).withOpacity(0.50);
    if (delta > 0)   return const Color(0xFF4CAF50).withOpacity(0.28);
    if (delta == 0)  return const Color(0xFFF4C842).withOpacity(0.22);
    if (delta > -50) return const Color(0xFFEF5350).withOpacity(0.28);
    return const Color(0xFFEF5350).withOpacity(0.45);
  }

  Color _cellBorder(String dateStr) {
    if (!_logDates.contains(dateStr)) return Colors.white.withOpacity(0.06);
    final entry = _logs[dateStr];
    if (entry == null) return Colors.white.withOpacity(0.06);
    final delta = (entry['coralDelta'] as num?)?.toInt() ?? 0;
    if (delta > 0)  return const Color(0xFF4CAF50).withOpacity(0.45);
    if (delta == 0) return const Color(0xFFF4C842).withOpacity(0.35);
    return const Color(0xFFEF5350).withOpacity(0.40);
  }

  Color _dotColor(String dateStr) {
    final entry = _logs[dateStr];
    if (entry == null) return Colors.white24;
    final delta = (entry['coralDelta'] as num?)?.toInt() ?? 0;
    if (delta > 0)  return const Color(0xFF4CAF50);
    if (delta == 0) return const Color(0xFFF4C842);
    return const Color(0xFFEF5350);
  }

  // ── Monthly stats summary ─────────────────────
  Map<String, int> _monthStats() {
    int logged = 0, gains = 0, losses = 0, holds = 0, totalDelta = 0;
    final daysInMonth =
        DateTime(_viewMonth.year, _viewMonth.month + 1, 0).day;
    for (int d = 1; d <= daysInMonth; d++) {
      final key = _fmtDate(_viewMonth.year, _viewMonth.month, d);
      final entry = _logs[key];
      if (entry == null) continue;
      logged++;
      final delta = (entry['coralDelta'] as num?)?.toInt() ?? 0;
      totalDelta += delta;
      if (delta > 0) gains++;
      else if (delta < 0) losses++;
      else holds++;
    }
    return {
      'logged': logged,
      'gains': gains,
      'losses': losses,
      'holds': holds,
      'totalDelta': totalDelta,
    };
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysInMonth =
        DateTime(_viewMonth.year, _viewMonth.month + 1, 0).day;
    // Sunday = 0
    final firstWeekday =
        DateTime(_viewMonth.year, _viewMonth.month, 1).weekday % 7;

    final isCurrentMonth =
        _viewMonth.year == now.year && _viewMonth.month == now.month;

    final stats = _monthStats();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Ocean depth background — uses the Coral Reef layer for calm warmth
          const RepaintBoundary(child: OceanBackground(layer: 3)),
          Container(color: Colors.black.withOpacity(0.60)),
          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: Column(
                children: [
                  // ── Header ──────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            OceanHaptics.surfaceTap();
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.14),
                                  width: 0.5),
                            ),
                            child: const Icon(Icons.arrow_back_ios_new_rounded,
                                color: Colors.white60, size: 16),
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'HISTORICAL LOG',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(width: 34),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Month navigator ─────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: _prevMonth,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.10),
                                  width: 0.5),
                            ),
                            child: const Icon(Icons.chevron_left_rounded,
                                color: Colors.white54, size: 20),
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Text(
                            _monthLabel(_viewMonth),
                            key: ValueKey(_viewMonth),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: isCurrentMonth ? null : _nextMonth,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: isCurrentMonth ? 0.25 : 1.0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.10),
                                    width: 0.5),
                              ),
                              child: const Icon(Icons.chevron_right_rounded,
                                  color: Colors.white54, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),

                  // ── Month stats ribbon ──────────────────────
                  if (stats['logged']! > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.07),
                              width: 0.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _statPill('${stats['logged']}', 'days',
                                Colors.white54),
                            _statDivider(),
                            _statPill('${stats['gains']}', 'gains',
                                const Color(0xFF4CAF50)),
                            _statDivider(),
                            _statPill('${stats['holds']}', 'holds',
                                const Color(0xFFF4C842)),
                            _statDivider(),
                            _statPill('${stats['losses']}', 'losses',
                                const Color(0xFFEF5350)),
                            _statDivider(),
                            _statPill(
                              '${stats['totalDelta']! > 0 ? '+' : ''}${stats['totalDelta']}',
                              'corals',
                              stats['totalDelta']! > 0
                                  ? const Color(0xFF4CAF50)
                                  : stats['totalDelta']! < 0
                                      ? const Color(0xFFEF5350)
                                      : const Color(0xFFF4C842),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 6),

                  // ── Weekday headers ─────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                          .map((d) => Expanded(
                                child: Center(
                                  child: Text(d,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.30),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1,
                                      )),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // ── Calendar grid ───────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildCalendarGrid(
                        daysInMonth, firstWeekday, now),
                  ),

                  const SizedBox(height: 10),

                  // ── Legend row ──────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _legendDot(
                            const Color(0xFF4CAF50).withOpacity(0.50),
                            'Gain'),
                        const SizedBox(width: 16),
                        _legendDot(
                            const Color(0xFFF4C842).withOpacity(0.30),
                            'Hold'),
                        const SizedBox(width: 16),
                        _legendDot(
                            const Color(0xFFEF5350).withOpacity(0.40),
                            'Loss'),
                        const SizedBox(width: 16),
                        _legendDot(
                            Colors.white.withOpacity(0.06), 'No log'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ── Selected day detail card ────────────────
                  Expanded(child: _buildDayDetail()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Small helpers ────────────────────────────────

  Widget _statPill(String value, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            )),
        const SizedBox(height: 1),
        Text(label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.25),
              fontSize: 9,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            )),
      ],
    );
  }

  Widget _statDivider() {
    return Container(
      width: 0.5,
      height: 22,
      color: Colors.white.withOpacity(0.08),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border:
                Border.all(color: Colors.white.withOpacity(0.12), width: 0.5),
          ),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.35),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            )),
      ],
    );
  }

  // ── Calendar grid builder ──────────────────────

  Widget _buildCalendarGrid(int daysInMonth, int firstWeekday, DateTime now) {
    final totalCells = firstWeekday + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Column(
      children: List.generate(rows, (row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: List.generate(7, (col) {
              final idx = row * 7 + col;
              if (idx < firstWeekday || idx >= firstWeekday + daysInMonth) {
                return const Expanded(child: SizedBox(height: 44));
              }

              final day = idx - firstWeekday + 1;
              final dateStr =
                  _fmtDate(_viewMonth.year, _viewMonth.month, day);
              final isToday = _viewMonth.year == now.year &&
                  _viewMonth.month == now.month &&
                  day == now.day;
              final isFuture =
                  DateTime(_viewMonth.year, _viewMonth.month, day)
                      .isAfter(now);
              final hasLog = _logDates.contains(dateStr);
              final isSelected = _selectedDate == dateStr;

              return Expanded(
                child: GestureDetector(
                  onTap: isFuture
                      ? null
                      : () {
                          OceanHaptics.selectionTick();
                          setState(() {
                            _selectedDate =
                                _selectedDate == dateStr ? null : dateStr;
                          });
                        },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    height: 44,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: isFuture
                          ? Colors.white.withOpacity(0.015)
                          : _cellColor(dateStr),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFF4C842).withOpacity(0.70)
                            : isToday
                                ? const Color(0xFF4FC3F7).withOpacity(0.45)
                                : hasLog
                                    ? _cellBorder(dateStr)
                                    : Colors.white.withOpacity(0.04),
                        width: isSelected ? 1.5 : 0.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFFF4C842)
                                    .withOpacity(0.12),
                                blurRadius: 8,
                                spreadRadius: 0,
                              )
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$day',
                            style: TextStyle(
                              color: isFuture
                                  ? Colors.white.withOpacity(0.12)
                                  : isToday
                                      ? const Color(0xFF4FC3F7)
                                      : hasLog
                                          ? Colors.white.withOpacity(0.85)
                                          : Colors.white.withOpacity(0.30),
                              fontSize: 13,
                              fontWeight:
                                  isToday ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                          if (hasLog)
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _dotColor(dateStr),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  // ── Day detail card ────────────────────────────

  Widget _buildDayDetail() {
    if (_selectedDate == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.touch_app_rounded,
                  color: Colors.white.withOpacity(0.10), size: 32),
              const SizedBox(height: 10),
              Text(
                'Tap a day to view details',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.20),
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final entry = _logs[_selectedDate!];
    if (entry == null) {
      return Center(
        child: _detailCard(
          child: Row(
            children: [
              Icon(Icons.water_drop_outlined,
                  color: Colors.white.withOpacity(0.20), size: 16),
              const SizedBox(width: 10),
              Text(
                'No activity logged',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.30),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final actions =
        (entry['actions'] as List?)?.cast<String>() ?? [];
    final delta = (entry['coralDelta'] as num?)?.toInt() ?? 0;
    final layerBefore =
        (entry['layerBefore'] as num?)?.toInt().clamp(0, 10) ?? 4;
    final layerAfter =
        (entry['layerAfter'] as num?)?.toInt().clamp(0, 10) ?? 4;
    final coralsAfter =
        (entry['coralsAfter'] as num?)?.toInt() ?? 0;

    final deltaColor = delta > 0
        ? const Color(0xFF4CAF50)
        : delta == 0
            ? const Color(0xFFF4C842)
            : const Color(0xFFEF5350);
    final deltaSign = delta > 0 ? '+' : '';
    final layerData = kLayers[layerAfter];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: _detailCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Coral delta + total header ──
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: deltaColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: deltaColor.withOpacity(0.30), width: 0.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        delta > 0
                            ? Icons.arrow_upward_rounded
                            : delta < 0
                                ? Icons.arrow_downward_rounded
                                : Icons.remove_rounded,
                        color: deltaColor,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$deltaSign$delta corals',
                        style: TextStyle(
                          color: deltaColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  '$coralsAfter total',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.30),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Layer row ──
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: layerData.iconColor.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: layerData.iconColor.withOpacity(0.15),
                    width: 0.5),
              ),
              child: Row(
                children: [
                  Icon(layerData.icon,
                      color: layerData.iconColor, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      layerData.name,
                      style: TextStyle(
                        color: layerData.iconColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (layerBefore != layerAfter) ...[
                    Icon(
                      layerAfter < layerBefore
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      color: layerAfter < layerBefore
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFEF5350),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'from ${kLayers[layerBefore].name}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.25),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Action chips ──
            Text(
              'ACTIONS LOGGED',
              style: TextStyle(
                color: Colors.white.withOpacity(0.25),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: actions.map((a) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.10),
                        width: 0.5),
                  ),
                  child: Text(
                    a,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1929).withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: Colors.white.withOpacity(0.08), width: 0.5),
      ),
      child: child,
    );
  }
}