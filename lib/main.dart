import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

// ─────────────────────────────────────────────
//  ENTRY POINT
// ─────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  bool _loading = true;
  bool _onboarded = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final prefs = await SharedPreferences.getInstance();
    final cats = prefs.getStringList('categories');
    setState(() {
      _onboarded = cats != null && cats.isNotEmpty;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF030D20),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFF4C842)),
        ),
      );
    }
    return _onboarded
        ? const OceanScreen()
        : OnboardingScreen(onComplete: () => setState(() => _onboarded = true));
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
                            onTap: () => setState(() =>
                                sel ? _selected.remove(cat) : _selected.add(cat)),
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
// ─────────────────────────────────────────────
class OceanBackground extends StatefulWidget {
  final int layer;
  const OceanBackground({super.key, required this.layer});

  @override
  State<OceanBackground> createState() => _OceanBackgroundState();
}

class _OceanBackgroundState extends State<OceanBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 8))
          ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => CustomPaint(
        painter: OceanPainter(layer: widget.layer, time: _ctrl.value),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class OceanPainter extends CustomPainter {
  final int layer;
  final double time;
  OceanPainter({required this.layer, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final data = kLayers[layer];
    final w = size.width;
    final h = size.height;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [data.topColor, data.bottomColor],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    if (layer == 0) {
      _drawIsland(canvas, size);
    } else {
      _drawUnderwater(canvas, size);
    }
  }

  void _drawIsland(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Sun glow
    canvas.drawCircle(Offset(w * 0.78, h * 0.13), 50,
        Paint()..color = const Color(0xFFFFF176).withOpacity(0.14));
    canvas.drawCircle(Offset(w * 0.78, h * 0.13), 32,
        Paint()..color = const Color(0xFFFFF176).withOpacity(0.88));

    // Sea
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.48, w, h * 0.52),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFF5BBFE0), const Color(0xFF1A3A5C)],
        ).createShader(Rect.fromLTWH(0, h * 0.48, w, h * 0.52)),
    );

    // Wave
    final wave = Path()..moveTo(0, h * 0.48);
    for (double x = 0; x <= w; x++) {
      wave.lineTo(x,
          h * 0.48 + math.sin((x / w * 3 * math.pi) + time * 2 * math.pi) * 6);
    }
    wave
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
        wave, Paint()..color = const Color(0xFF5BBFE0).withOpacity(0.82));

    // Island mound
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w / 2, h * 0.476),
            width: w * 0.46,
            height: h * 0.07),
        Paint()..color = const Color(0xFF4CAF50));
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w / 2, h * 0.459),
            width: w * 0.3,
            height: h * 0.052),
        Paint()..color = const Color(0xFF66BB6A));

    // Palm trunk
    canvas.drawLine(
      Offset(w * 0.52, h * 0.456),
      Offset(w * 0.5, h * 0.32),
      Paint()
        ..color = const Color(0xFF795548)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );

    // Palm leaves
    void leaf(double angle, double len) => canvas.drawLine(
          Offset(w * 0.5, h * 0.32),
          Offset(w * 0.5 + math.cos(angle) * len,
              h * 0.32 + math.sin(angle) * len * 0.5),
          Paint()
            ..color = const Color(0xFF388E3C)
            ..strokeWidth = 2.8
            ..strokeCap = StrokeCap.round,
        );
    leaf(-1.2, w * 0.12);
    leaf(-0.3, w * 0.13);
    leaf(0.5, w * 0.11);
    leaf(-2.0, w * 0.10);

    // Birds
    for (int i = 0; i < 5; i++) {
      final bx =
          w * 0.1 + i * w * 0.17 + math.sin(time * math.pi + i) * 12;
      final by =
          h * 0.1 + i * 9 + math.cos(time * math.pi * 0.6 + i) * 5;
      final birdPath = Path()
        ..moveTo(bx - 6, by)
        ..quadraticBezierTo(bx, by - 4, bx + 6, by);
      canvas.drawPath(
          birdPath,
          Paint()
            ..color = Colors.black.withOpacity(0.45)
            ..strokeWidth = 1.4
            ..style = PaintingStyle.stroke);
    }
  }

  void _drawUnderwater(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Light rays (shallow)
    if (layer <= 4) {
      final alpha = (5 - layer) / 5 * 0.055;
      for (int i = 0; i < 5; i++) {
        final rx = w * 0.04 +
            i * w * 0.22 +
            math.sin(time * math.pi * 0.6 + i) * 18;
        final ray = Path()
          ..moveTo(rx, 0)
          ..lineTo(rx + 12, 0)
          ..lineTo(rx + 80, h)
          ..lineTo(rx + 60, h)
          ..close();
        canvas.drawPath(ray, Paint()..color = Colors.white.withOpacity(alpha));
      }
    }

    // Bubbles
    final bubbleCount = math.max(0, 24 - layer * 2);
    for (int i = 0; i < bubbleCount; i++) {
      final seed = i * 137.5;
      final px = (w * 0.05 +
              (seed % w) +
              math.sin(time * math.pi * 0.8 + i * 1.3) * 20) %
          w;
      final py =
          (h - ((time * h * 0.3 + i * h / math.max(1, bubbleCount) * 1.2) %
                  (h * 1.2))) %
              h;
      canvas.drawCircle(
        Offset(px, py),
        1.5 + math.sin(i * 2.1) * 1.2,
        Paint()
          ..color = Colors.white
              .withOpacity((0.18 - layer * 0.014).clamp(0.04, 0.18)),
      );
    }

    // Deep darkness overlay
    if (layer >= 8) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..color = Colors.black
              .withOpacity(((layer - 7) / 3.0).clamp(0.0, 0.65)),
      );
    }

    // Anglerfish glow
    if (layer == 10) {
      canvas.drawCircle(
        Offset(w / 2, h * 0.3),
        70,
        Paint()
          ..shader = RadialGradient(colors: [
            const Color(0xFF00E676).withOpacity(
                0.28 + math.sin(time * math.pi * 3) * 0.1),
            Colors.transparent,
          ]).createShader(Rect.fromCenter(
              center: Offset(w / 2, h * 0.3), width: 140, height: 140)),
      );
    }

    // Vignette
    if (layer > 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..shader = RadialGradient(
            colors: [Colors.transparent, Colors.black.withOpacity(0.32)],
            radius: 0.85,
          ).createShader(Rect.fromLTWH(0, 0, w, h)),
      );
    }
  }

  @override
  bool shouldRepaint(OceanPainter old) =>
      old.time != time || old.layer != layer;
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
  int rescueDayCounter = 0;   // counts logs; on 7th, rescue day activates
  bool rescueDayActive = false; // true only on the 7th day
  bool momentumBonusUsed = false;
  bool immunityUsed = false;
  int corals = 700;
  String lastLoggedDate = ''; // 'yyyy-MM-dd' of last log, empty = never
  List<String> categories = [];
  Map<String, String> priorities = {}; // 'high' | 'mid' | 'low'

  // ── Weekly tracking ──────────────────────────
  int weeklyLogCount = 0;
  int weeklyStartLayer = 4;
  int weeklyCoralStart = 700;
  List<int> weeklyLayers = [];
  List<int> weeklyActionCounts = [];
  List<int> weeklyCoralChanges = [];
  Map<String, int> weeklyActivityMap = {};

  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _load();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
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

      // Weekly
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

    // Weekly
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

  // Returns layer index for a given coral count
  int _layerFromCorals(int c) {
    for (int i = 0; i < kLayerThresholds.length; i++) {
      if (c >= kLayerThresholds[i]) return i;
    }
    return 10;
  }

  // Returns coral delta for today (+gain or -loss)
  // Returns coral delta for today's actions
  // Returns point value for a single action based on its priority
  double _priorityPoints(String action) {
    final p = priorities[action] ?? 'mid';
    if (p == 'high') return 3.0;
    if (p == 'low')  return 1.0;
    return 2.0; // mid
  }

  // Sums points for all selected actions
  double _computePoints(Set<String> selected) =>
      selected.fold(0.0, (sum, a) => sum + _priorityPoints(a));

  int _coralDelta(double points) {
    final rng = math.Random();

    // Base delta from points (same thresholds, applied to points instead of raw count)
    int base;
    if (points >= 8.0)      base = 49 + rng.nextInt(5);    // +49..+53
    else if (points >= 6.0) base = 0;
    else if (points >= 1.0) base = -(49 + rng.nextInt(7)); // -49..-55  (1–5 pts)
    else                    base = -(100 + rng.nextInt(4)); // -100..-103  (0 pts)

    // Apply streak bonuses only to positive gains
    if (base > 0) {
      // 3-day streak: double corals once per streak run
      if (streak >= 3 && !momentumBonusUsed) {
        base *= 2;
        momentumBonusUsed = true;
      }
      // 7-day streak: random chance to double (once per day, random)
      if (streak >= 7 && rng.nextBool()) {
        base *= 2;
      }
    }

    return base;
  }

  void _processActions(int actions, Set<String> selected) {
    // ── Rescue day counter ───────────────────
    // Clear previous day's active flag, then increment counter
    rescueDayActive = false;
    rescueDayCounter++;
    if (rescueDayCounter >= 7) {
      rescueDayCounter = 0;
      rescueDayActive = true;
      rescueAvailable = true; // restore the auto-protection for this week
    }

    final points = _computePoints(selected);
    int delta = _coralDelta(points);

    // 14-day streak immunity: get 0 instead of negative, once per streak run
    if (streak >= 14 && delta < 0 && !immunityUsed) {
      delta = 0;
      immunityUsed = true;
    }

    // Rescue Buoy: if active and delta is negative, clamp to 0 (rest day)
    if (rescueAvailable && delta < 0) {
      delta = 0;
      rescueAvailable = false;
      _save();
      _showInfoDialog(
        layerIndex: currentLayer,
        title: 'Rescue Buoy Used',
        message:
            'Your buoy held you in place today. No corals lost — rest well. The ocean will wait.',
        buttonText: 'Thank you',
        accentColor: const Color(0xFF4FC3F7),
      );
    }

    // Storm: 3 stagnant days → fixed -50 coral penalty
    if (delta == 0 && currentLayer > 0) {
      stormDays++;
      if (stormDays >= 3) {
        delta = -50;
        stormDays = 0;
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

    // ── Record weekly data ───────────────────
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

    // ── Stamp today's date ───────────────────
    lastLoggedDate = _todayString();

    final prev = currentLayer;
    setState(() {
      corals = newCorals;
      currentLayer = newLayer;
    });
    _save();

    // ── Trigger weekly summary on 7th log ────
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
    HapticFeedback.mediumImpact();

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
    if (_hasLoggedToday) return; // safety guard — button is hidden but just in case
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

  // ── UI Builders ─────────────────────────────

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

  Widget _statCard(
      IconData icon, Color color, String val, String label) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
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
        onTap: onTap,
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

  // ── Build ─────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final layer = kLayers[currentLayer];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 1000),
            child: OceanBackground(
                key: ValueKey(currentLayer), layer: currentLayer),
          ),

          // Storm border pulse
          if (stormDays >= 2 && currentLayer > 0)
            Positioned.fill(
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

          SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Left: title + coral count
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
                                '$corals Corals',
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
                        onTap: _openSettings,
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

                // Hero layer display
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

                        // Depth pill
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

                        // Rescue buoy
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
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
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

                        // Storm warning
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

                // Bottom panel
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
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        child: _hasLoggedToday
                            ? _buildLoggedTodayState()
                            : SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: ElevatedButton(
                                  onPressed: _openLogSheet,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        const Color(0xFFF4C842),
                                    foregroundColor:
                                        const Color(0xFF1A1A2E),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Priority',
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  Row(
                    children: ['low', 'mid', 'high'].map((p) {
                      final active = selectedPriority == p;
                      return GestureDetector(
                        onTap: () => setLocal(() => selectedPriority = p),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: active
                                ? _priorityColor(p).withOpacity(0.15)
                                : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: active
                                  ? _priorityColor(p).withOpacity(0.6)
                                  : Colors.white.withOpacity(0.1),
                              width: 0.5,
                            ),
                          ),
                          child: _PriorityBadge(priority: p),
                        ),
                      );
                    }).toList(),
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
                    // Duplicate — show error inline and don't dismiss
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

  static Color _priorityColor(String p) {
    if (p == 'high') return const Color(0xFFEF5350);
    if (p == 'low')  return const Color(0xFF4CAF50);
    return const Color(0xFFF4C842);
  }

  double _pointsFor(String action) {
    final p = _priorities[action] ?? 'mid';
    if (p == 'high') return 3.0;
    if (p == 'low')  return 1.0;
    return 2.0; // mid
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
            // Handle
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

            // Header
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

            // Movement prediction
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

            // Category list
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
                      HapticFeedback.selectionClick();
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
                          _PriorityBadge(priority: _priorities[cat] ?? 'mid'),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Confirm button
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
                                style: const TextStyle(
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
// ─────────────────────────────────────────────
//  SETTINGS SHEET  (links menu)
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
            // Handle
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

            // ── Link: Change Actions ─────────────
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

// ── Reusable link row ────────────────────────
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Priority',
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  Row(
                    children: ['low', 'mid', 'high'].map((p) {
                      final active = selectedPriority == p;
                      return GestureDetector(
                        onTap: () => setLocal(() => selectedPriority = p),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: active
                                ? _priorityColor(p).withOpacity(0.15)
                                : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: active
                                  ? _priorityColor(p).withOpacity(0.6)
                                  : Colors.white.withOpacity(0.1),
                              width: 0.5,
                            ),
                          ),
                          child: _PriorityBadge(priority: p),
                        ),
                      );
                    }).toList(),
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

  static Color _priorityColor(String p) {
    if (p == 'high') return const Color(0xFFEF5350);
    if (p == 'low')  return const Color(0xFF4CAF50);
    return const Color(0xFFF4C842);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1929),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
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

            // Reorderable action list
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

            // Add Custom Action
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

            // Reset App
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

  int get _totalActions =>
      widget.actionCounts.fold(0, (a, b) => a + b);

  double get _avgActions => widget.actionCounts.isEmpty
      ? 0
      : _totalActions / widget.actionCounts.length;

  int get _productiveDays =>
      widget.actionCounts.where((a) => a >= 4).length;

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
          OceanBackground(layer: _bgLayer),
          Container(color: Colors.black.withOpacity(0.55)),
          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: Column(
                  children: [
                    // Header
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
                            // Headline card
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

                            // Stats row
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

                            // Bar chart
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

                            // Total actions
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

                            // ── Coral summary ─────────────────
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
                                            Text(
                                              'this week',
                                              style: const TextStyle(
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

                            // Activity breakdown
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

                            // Day by day
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

                            // CTA
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
          // Day number
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
          // Layer icon
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
          // Layer name
          Expanded(
            child: Text(ld.name,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                overflow: TextOverflow.ellipsis),
          ),
          // Actions
          Text('$actions act.',
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(width: 6),
          // Coral change
          const Icon(Icons.spa_rounded, color: Color(0xFFFF7043), size: 11),
          const SizedBox(width: 2),
          Text(coralStr,
              style: TextStyle(
                  color: coralColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          // Layer delta arrow
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

    // Grid lines
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

      // Depth bar — higher bar = better (lower layer number)
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

      // Actions bar (gold)
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

      // Day label
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
          const OceanBackground(layer: 8),
          Container(color: Colors.black.withOpacity(0.60)),
          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: Column(
                children: [
                  // Header
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
            // Collapsed row
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

            // Expanded content
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
  final String priority; // 'high' | 'mid' | 'low'
  final bool tappable;

  const _PriorityBadge({required this.priority, this.tappable = false});

  @override
  Widget build(BuildContext context) {
    // Depth-meter style: 3 vertical bars like a water-depth signal
    // High = 3 bars (deepest/most urgent), Mid = 2, Low = 1
    // Bar heights increase left to right like a depth gauge
    final Color color;
    final int filled;

    switch (priority) {
      case 'high':
        color  = const Color(0xFFEF5350); // red
        filled = 3;
        break;
      case 'low':
        color  = const Color(0xFF4CAF50); // green
        filled = 1;
        break;
      default: // mid
        color  = const Color(0xFFF4C842); // gold
        filled = 2;
    }

    // Bar heights: shortest → tallest (left to right)
    const heights = [5.0, 8.0, 11.0];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withOpacity(0.40), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(3, (i) {
          final active = i < filled;
          return Container(
            width: 3.5,
            height: heights[i],
            margin: const EdgeInsets.symmetric(horizontal: 1.2),
            decoration: BoxDecoration(
              color: active ? color : color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(1.5),
            ),
          );
        }),
      ),
    );
  }
}