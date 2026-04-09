import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

// --- 1. STATE MANAGEMENT ---

final currentUserProvider = StateProvider<String?>((ref) => null);
final authProvider = StateProvider<bool>((ref) => false);
final navProvider = StateProvider<int>((ref) => 2);

final darkModeProvider = StateProvider<bool>((ref) => true);
final metricProvider = StateProvider<bool>((ref) => true);
final notificationProvider = StateProvider<bool>((ref) => true);
final biometricProvider = StateProvider<bool>((ref) => false);

class RunPost {
  final String id;
  final double distance;
  final int duration;
  final DateTime date;
  RunPost({required this.id, required this.distance, required this.duration, required this.date});
}

class FeedNotifier extends StateNotifier<List<RunPost>> {
  FeedNotifier() : super([]);
  void addPost(double dist, int dur) {
    state = [RunPost(id: DateTime.now().toString(), distance: dist, duration: dur, date: DateTime.now()), ...state];
  }
  void clearAll() => state = [];
}
final feedProvider = StateNotifierProvider<FeedNotifier, List<RunPost>>((ref) => FeedNotifier());

class WorkoutState {
  final List<LatLng> polyline;
  final LatLng? startPos, currentPos;
  final bool isTracking;
  final double totalDistance;
  final int duration;
  WorkoutState({required this.polyline, this.startPos, this.currentPos, required this.isTracking, required this.totalDistance, required this.duration});
}

class WorkoutNotifier extends StateNotifier<WorkoutState> {
  WorkoutNotifier(this.ref) : super(WorkoutState(polyline: [], isTracking: false, totalDistance: 0, duration: 0));
  final Ref ref; Timer? _timer;
  void toggleTracking() {
    if (state.isTracking) { _timer?.cancel(); state = WorkoutState(polyline: state.polyline, startPos: state.startPos, currentPos: state.currentPos, isTracking: false, totalDistance: state.totalDistance, duration: state.duration); }
    else { _timer = Timer.periodic(const Duration(seconds: 1), (t) => state = WorkoutState(polyline: state.polyline, startPos: state.startPos, currentPos: state.currentPos, isTracking: true, totalDistance: state.totalDistance, duration: state.duration + 1));
    state = WorkoutState(polyline: state.polyline, startPos: state.startPos ?? state.currentPos, currentPos: state.currentPos, isTracking: true, totalDistance: state.totalDistance, duration: state.duration); }
  }
  void resetAndPost() { if (state.totalDistance > 0) ref.read(feedProvider.notifier).addPost(state.totalDistance, state.duration);
  _timer?.cancel(); state = WorkoutState(polyline: [], startPos: null, currentPos: state.currentPos, isTracking: false, totalDistance: 0, duration: 0); }
  void updateLocation(Position p) {
    final newLoc = LatLng(p.latitude, p.longitude); double dist = state.totalDistance; List<LatLng> newPath = List.from(state.polyline);
    if (state.isTracking) { if (newPath.isNotEmpty) dist += Geolocator.distanceBetween(newPath.last.latitude, newPath.last.longitude, p.latitude, p.longitude); newPath.add(newLoc); }
    state = WorkoutState(polyline: newPath, startPos: state.startPos, currentPos: newLoc, isTracking: state.isTracking, totalDistance: dist, duration: state.duration);
  }
}
final workoutProvider = StateNotifierProvider<WorkoutNotifier, WorkoutState>((ref) => WorkoutNotifier(ref));

// --- 2. MAIN APP ---

void main() => runApp(const ProviderScope(child: RunningApp()));

class RunningApp extends ConsumerWidget {
  const RunningApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(authProvider);
    final isDark = ref.watch(darkModeProvider);
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      theme: CupertinoThemeData(brightness: isDark ? Brightness.dark : Brightness.light, primaryColor: Colors.orange),
      home: isLoggedIn ? const NavigationHub() : const LoginScreen(),
    );
  }
}

class NavigationHub extends ConsumerWidget {
  const NavigationHub({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(navProvider);
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
          currentIndex: index,
          onTap: (i) => ref.read(navProvider.notifier).state = i,
          activeColor: Colors.orange,
          items: const [
            BottomNavigationBarItem(icon: Icon(CupertinoIcons.person_2_fill), label: 'Feed'),
            BottomNavigationBarItem(icon: Icon(CupertinoIcons.list_bullet), label: 'History'),
            BottomNavigationBarItem(icon: Icon(CupertinoIcons.map_fill), label: 'Record'),
            BottomNavigationBarItem(icon: Icon(CupertinoIcons.person_fill), label: 'You'),
            BottomNavigationBarItem(icon: Icon(CupertinoIcons.settings), label: 'Settings'),
          ]),
      tabBuilder: (context, i) => [
        const FeedScreen(),
        const HistoryScreen(),
        const MapScreen(),
        const ProfileScreen(),
        const SettingsScreen()
      ][i],
    );
  }
}

// --- 3. LOGIN SCREEN ---

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _u = TextEditingController(), _p = TextEditingController();
  bool _isObscured = true;

  final Map<String, String> users = {
    'matthew': '123456',
    'shanon': '123456',
    'marck': '123456',
    'admin': '123456'
  };

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF121212),
      child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(40.0), child: Column(children: [
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(CupertinoIcons.graph_circle_fill, size: 100, color: Colors.orange)),
        const SizedBox(height: 20),
        const Text("STARVA", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 4, color: Colors.white)),
        const Text("CONNECT & CONQUER", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 1.5, color: Colors.orange)),
        const SizedBox(height: 50),
        CupertinoTextField(controller: _u, placeholder: "Username", padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)), style: const TextStyle(color: Colors.white)),
        const SizedBox(height: 16),
        StatefulBuilder(builder: (context, setStateField) {
          return CupertinoTextField(
            controller: _p,
            placeholder: "Password",
            obscureText: _isObscured,
            padding: const EdgeInsets.all(18),
            style: const TextStyle(color: Colors.white),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
            suffix: CupertinoButton(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(_isObscured ? CupertinoIcons.eye_slash_fill : CupertinoIcons.eye_fill, color: Colors.white38, size: 20),
              onPressed: () => setStateField(() => _isObscured = !_isObscured),
            ),
          );
        }),
        const SizedBox(height: 32),
        Consumer(builder: (c, ref, _) => SizedBox(width: double.infinity, child: CupertinoButton.filled(onPressed: () {
          String inputUser = _u.text.toLowerCase().trim();
          if (users.containsKey(inputUser) && users[inputUser] == _p.text) {
            ref.read(currentUserProvider.notifier).state = inputUser;
            ref.read(authProvider.notifier).state = true;
          } else {
            showCupertinoDialog(context: context, builder: (ctx) => CupertinoAlertDialog(title: const Text("Invalid Login"), content: const Text("Username or password incorrect."), actions: [CupertinoDialogAction(child: const Text("OK"), onPressed: () => Navigator.pop(ctx))]));
          }
        }, child: const Text("LOG IN", style: TextStyle(fontWeight: FontWeight.bold))))),
      ]))),
    );
  }
}

// --- 4. SETTINGS SCREEN ---

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text("Settings")),
      child: SafeArea(
        child: ListView(
          children: [
            _section("APPEARANCE"),
            _tile("Dark Mode", CupertinoSwitch(value: ref.watch(darkModeProvider), onChanged: (v) => ref.read(darkModeProvider.notifier).state = v)),
            _section("PREFERENCES"),
            _tile("Use Metric Units", CupertinoSwitch(value: ref.watch(metricProvider), onChanged: (v) => ref.read(metricProvider.notifier).state = v)),
            _tile("Run Notifications", CupertinoSwitch(value: ref.watch(notificationProvider), onChanged: (v) => ref.read(notificationProvider.notifier).state = v)),
            _section("SECURITY & DATA"),
            _tile("Biometric Lock", CupertinoSwitch(value: ref.watch(biometricProvider), onChanged: (v) => ref.read(biometricProvider.notifier).state = v)),
            _actionTile("Clear All Data", Colors.red, () {
              showCupertinoDialog(context: context, builder: (c) => CupertinoAlertDialog(
                title: const Text("Clear Data?"),
                content: const Text("This will permanently delete all your run history."),
                actions: [
                  CupertinoDialogAction(child: const Text("Cancel"), onPressed: () => Navigator.pop(c)),
                  CupertinoDialogAction(isDestructiveAction: true, child: const Text("Clear"), onPressed: () {
                    ref.read(feedProvider.notifier).clearAll(); Navigator.pop(c);
                  }),
                ],
              ));
            }),
            _section("ACCOUNT"),
            _actionTile("Sign Out", Colors.orange, () {
              ref.read(currentUserProvider.notifier).state = null;
              ref.read(authProvider.notifier).state = false;
            }),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(padding: const EdgeInsets.fromLTRB(16, 20, 16, 8), child: Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)));
  Widget _tile(String title, Widget trailing) => Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title), trailing]));
  Widget _actionTile(String title, Color color, VoidCallback tap) => CupertinoButton(padding: EdgeInsets.zero, onPressed: tap, child: Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5))), child: Text(title, style: TextStyle(color: color))));
}

// --- 5. PROFILE SCREEN ---

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(feedProvider);
    final userName = ref.watch(currentUserProvider) ?? "Runner";
    final now = DateTime.now();

    String getPace(double m, int s) {
      if (m <= 0) return "0:00";
      double paceDecimal = (s / 60) / (m / 1000);
      int min = paceDecimal.floor();
      int sec = ((paceDecimal - min) * 60).round();
      return "$min:${sec.toString().padLeft(2, '0')}";
    }

    int totalStreak = posts.isEmpty ? 0 : posts.map((p) => p.date.day).toSet().length;
    double allTimeDist = posts.fold(0.0, (sum, p) => sum + p.distance) / 1000;
    double pbDist = posts.isEmpty ? 0 : posts.map((p) => p.distance).reduce((a, b) => a > b ? a : b) / 1000;

    var weeklyPosts = posts.where((p) => now.difference(p.date).inDays < 7).toList();
    double weekDist = weeklyPosts.fold(0.0, (sum, p) => sum + p.distance) / 1000;
    int weekDur = weeklyPosts.fold(0, (sum, p) => sum + p.duration);
    String weekPace = getPace(weekDist * 1000, weekDur);

    var monthlyPosts = posts.where((p) => p.date.month == now.month && p.date.year == now.year).toList();
    double monthDist = monthlyPosts.fold(0.0, (sum, p) => sum + p.distance) / 1000;
    int monthDur = monthlyPosts.fold(0, (sum, p) => sum + p.duration);
    String monthPace = getPace(monthDist * 1000, monthDur);

    Map<int, double> dailyStats = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};
    for (var p in weeklyPosts) dailyStats[p.date.weekday] = (dailyStats[p.date.weekday] ?? 0) + (p.distance / 1000);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text("Personal Performance")),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          children: [
            Row(children: [
              const CircleAvatar(backgroundColor: Colors.orange, child: Icon(CupertinoIcons.person_fill, color: Colors.white)),
              const SizedBox(width: 15),
              Text(userName.toUpperCase(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 30),
            const Text("ALL-TIME PROGRESS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 12),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
              _motoCard("Streak", "$totalStreak Days", CupertinoIcons.flame_fill, Colors.orange),
              const SizedBox(width: 10),
              _motoCard("Total KM", "${allTimeDist.toStringAsFixed(2)} km", CupertinoIcons.globe, Colors.green),
              const SizedBox(width: 10),
              _motoCard("Personal Best", "${pbDist.toStringAsFixed(2)} km", CupertinoIcons.rosette, Colors.yellow),
            ])),
            const SizedBox(height: 30),
            const Text("WEEKLY SUMMARY", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 12),
            _summaryGrid(weekDist, weekDur, weekPace, weeklyPosts.length),
            const SizedBox(height: 30),
            const Text("MONTHLY SUMMARY", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 12),
            _summaryGrid(monthDist, monthDur, monthPace, monthlyPosts.length, color: Colors.blue),
            const SizedBox(height: 30),
            const Text("DAILY BREAKDOWN (THIS WEEK)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 15),
            Container(decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(15)), child: Table(
              border: TableBorder.symmetric(inside: const BorderSide(color: Colors.white10)),
              children: [
                const TableRow(children: [_Cell("Day", isH: true), _Cell("KM", isH: true)]),
                _dayRow("Mon", dailyStats[1]!), _dayRow("Tue", dailyStats[2]!), _dayRow("Wed", dailyStats[3]!),
                _dayRow("Thu", dailyStats[4]!), _dayRow("Fri", dailyStats[5]!), _dayRow("Sat", dailyStats[6]!), _dayRow("Sun", dailyStats[7]!),
              ],
            )),
          ],
        ),
      ),
    );
  }

  Widget _summaryGrid(double dist, int dur, String pace, int count, {Color color = Colors.orange}) => Column(children: [
    Row(children: [
      _summaryBox("DISTANCE", "${dist.toStringAsFixed(2)}", "km", CupertinoIcons.map, color),
      const SizedBox(width: 10),
      _summaryBox("DURATION", "${(dur / 60).floor()}:${(dur % 60).toString().padLeft(2, '0')}", "mins", CupertinoIcons.stopwatch, color),
    ]),
    const SizedBox(height: 10),
    Row(children: [
      _summaryBox("AVG PACE", pace, "/km", CupertinoIcons.gauge, color),
      const SizedBox(width: 10),
      _summaryBox("RUNS", "$count", "count", CupertinoIcons.infinite, color),
    ]),
  ]);

  Widget _motoCard(String t, String v, IconData i, Color c) => Container(
    width: 140, padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(18)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(i, color: c, size: 22), const SizedBox(height: 8), Text(t, style: const TextStyle(fontSize: 11, color: Colors.grey)), Text(v, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
  );

  Widget _summaryBox(String l, String v, String u, IconData i, Color c) => Expanded(child: Container(
    padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(15), border: Border.all(color: c.withOpacity(0.2))),
    child: Column(children: [Icon(i, color: c, size: 20), const SizedBox(height: 8), Text(v, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text("$l ($u)", style: const TextStyle(fontSize: 9, color: Colors.grey))]),
  ));

  TableRow _dayRow(String d, double km) => TableRow(children: [_Cell(d), _Cell("${km.toStringAsFixed(2)} km", c: Colors.orange)]);
}

class _Cell extends StatelessWidget {
  final String t; final bool isH; final Color? c;
  const _Cell(this.t, {this.isH = false, this.c});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(12), child: Text(t, textAlign: TextAlign.center, style: TextStyle(fontWeight: isH ? FontWeight.bold : FontWeight.normal, color: isH ? Colors.grey : (c ?? Colors.white))));
}

// --- 6. REMAINING SCREENS ---

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(feedProvider);
    return CupertinoPageScaffold(navigationBar: const CupertinoNavigationBar(middle: Text("Recent Logs")), child: SafeArea(child: ListView.builder(itemCount: posts.length, itemBuilder: (context, i) {
      final p = posts[i];
      return Container(margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(15)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Run on ${p.date.month}/${p.date.day}", style: const TextStyle(fontWeight: FontWeight.bold)), Text("${(p.distance/1000).toStringAsFixed(2)} km", style: const TextStyle(color: Colors.orange))]),
        Text("${p.duration}s", style: const TextStyle(color: Colors.grey)),
      ]));
    })));
  }
}

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(feedProvider);
    return CupertinoPageScaffold(navigationBar: const CupertinoNavigationBar(middle: Text("Activity Feed")), child: posts.isEmpty ? const Center(child: Text("No runs yet.")) : ListView.builder(itemCount: posts.length, itemBuilder: (context, index) {
      final post = posts[index];
      return Container(margin: const EdgeInsets.all(12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(15)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [CircleAvatar(radius: 15, backgroundColor: Colors.orange, child: Icon(Icons.person, size: 18, color: Colors.white)), SizedBox(width: 12), Text("Runner", style: TextStyle(fontWeight: FontWeight.bold))]),
        const SizedBox(height: 15),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_fStat("Distance", "${(post.distance / 1000).toStringAsFixed(2)} km"), _fStat("Time", "${post.duration}s"), _fStat("Date", "${post.date.day}/${post.date.month}")]),
      ]));
    }));
  }
  Widget _fStat(String l, String v) => Column(children: [Text(l, style: const TextStyle(fontSize: 12, color: Colors.grey)), Text(v, style: const TextStyle(fontWeight: FontWeight.bold))]);
}

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _positionStream;
  bool _isInitialMoveDone = false;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    LocationPermission p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();

    // UPDATED FOR IOS BACKGROUND COMPATIBILITY
    _positionStream = Geolocator.getPositionStream(
      locationSettings: AppleSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
        showBackgroundLocationIndicator: true,
      ),
    ).listen((pos) {
      final latLng = LatLng(pos.latitude, pos.longitude);
      ref.read(workoutProvider.notifier).updateLocation(pos);
      if (!_isInitialMoveDone) {
        _mapController.move(latLng, 18);
        _isInitialMoveDone = true;
      }
    });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workout = ref.watch(workoutProvider);
    final time = Duration(seconds: workout.duration);
    return CupertinoPageScaffold(child: Stack(children: [
      FlutterMap(mapController: _mapController, options: const MapOptions(initialCenter: LatLng(15.148, 120.762), initialZoom: 18), children: [
        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.strava.thesis', tileProvider: CancellableNetworkTileProvider()),
        PolylineLayer<Polyline>(polylines: [Polyline(points: workout.polyline, color: Colors.orange, strokeWidth: 6.0)]),
        MarkerLayer(markers: [if (workout.currentPos != null) Marker(point: workout.currentPos!, child: const Icon(CupertinoIcons.circle_fill, color: Colors.blue, size: 18))]),
      ]),
      Positioned(bottom: 30, left: 20, right: 20, child: Container(height: 180, decoration: BoxDecoration(color: const Color(0xFF1C1C1E).withOpacity(0.9), borderRadius: BorderRadius.circular(25)), padding: const EdgeInsets.all(20), child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_s("TIME", "${time.inMinutes}:${(time.inSeconds % 60).toString().padLeft(2, '0')}"), _s("KM", (workout.totalDistance / 1000).toStringAsFixed(2))]),
        const Spacer(),
        Row(children: [
          if (!workout.isTracking && workout.polyline.isNotEmpty) Expanded(child: Padding(padding: const EdgeInsets.only(right: 10), child: CupertinoButton(color: Colors.grey[800], padding: EdgeInsets.zero, onPressed: () => ref.read(workoutProvider.notifier).resetAndPost(), child: const Text("POST")))),
          Expanded(flex: 2, child: CupertinoButton(color: workout.isTracking ? Colors.red : Colors.orange, padding: EdgeInsets.zero, onPressed: () => ref.read(workoutProvider.notifier).toggleTracking(), child: Text(workout.isTracking ? "STOP" : "START"))),
        ]),
      ])))
    ]));
  }
  Widget _s(String l, String v) => Column(children: [Text(l, style: const TextStyle(color: Colors.grey, fontSize: 11)), Text(v, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold))]);
}