import 'package:flutter/material.dart';

import 'backup.dart';
import 'calendar_screen.dart';
import 'map_screen.dart';
import 'more_screen.dart';
import 'notifications.dart';
import 'regions_screen.dart';
import 'store.dart';
import 'theme.dart';
import 'trips_screen.dart';
import 'updater.dart' as updater;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PoppyApp());
}

class PoppyApp extends StatefulWidget {
  const PoppyApp({super.key});
  @override
  State<PoppyApp> createState() => _PoppyAppState();
}

class _PoppyAppState extends State<PoppyApp> {
  @override
  void initState() {
    super.initState();
    AppState.instance.addListener(_onChange);
    _boot();
  }

  Future<void> _boot() async {
    await AppState.instance.load();
    await Backup.instance.init();
    await Notifier.instance.init();
    await Notifier.instance.reschedule();
  }

  void _onChange() => setState(() {});

  @override
  void dispose() {
    AppState.instance.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Poppy',
      debugShowCheckedModeBanner: false,
      theme: poppyTheme(Brightness.light),
      darkTheme: poppyTheme(Brightness.dark),
      themeMode:
          AppState.instance.darkMode ? ThemeMode.dark : ThemeMode.light,
      home: AppState.instance.ready ? const NavShell() : const _Splash(),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: P.bgL,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: Alignment(-0.3, -0.3),
                colors: [Color(0xFFFF8A3D), P.poppy],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Poppy', style: serif(context, size: 30, color: P.inkL)),
        ]),
      ),
    );
  }
}

class NavShell extends StatefulWidget {
  const NavShell({super.key});
  @override
  State<NavShell> createState() => _NavShellState();
}

class _NavShellState extends State<NavShell> {
  int _tab = 0;
  bool _checkedUpdate = false;
  bool _offeredTripDay = false;

  @override
  Widget build(BuildContext context) {
    if (!_checkedUpdate) {
      _checkedUpdate = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        updater.autoCheck(context);
        _maybeOfferTripDay();
      });
    }
    return Scaffold(
      backgroundColor: context.bg,
      body: IndexedStack(
        index: _tab,
        children: const [
          MapScreen(),
          RegionsScreen(),
          CalendarScreen(),
          TripsScreen(),
          MoreScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: context.card,
        indicatorColor: P.gold,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
              icon: Text('🗺️', style: TextStyle(fontSize: 18)),
              label: 'Map'),
          NavigationDestination(
              icon: Text('🏞️', style: TextStyle(fontSize: 18)),
              label: 'Regions'),
          NavigationDestination(
              icon: Text('📅', style: TextStyle(fontSize: 18)),
              label: 'Calendar'),
          NavigationDestination(
              icon: Text('🧭', style: TextStyle(fontSize: 18)),
              label: 'Trips'),
          NavigationDestination(
              icon: Text('🎒', style: TextStyle(fontSize: 18)),
              label: 'More'),
        ],
      ),
    );
  }

  /// On a planned trip's day, open straight into Trip Day mode.
  void _maybeOfferTripDay() {
    if (_offeredTripDay) return;
    _offeredTripDay = true;
    final plan = AppState.instance.activePlan;
    if (plan == null) return;
    final t = AppState.instance.trip(plan.tripId);
    if (t == null) return;
    Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TripDayPage(tripId: t.id)));
  }
}
