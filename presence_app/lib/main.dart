/// Point d'entrée Flutter - CONATEL Présence
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/kiosk_screen.dart';
import 'screens/history_screen.dart';
import 'screens/rh_dashboard_screen.dart';
import 'screens/employees_screen.dart';
import 'screens/leaves_screen.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const ProviderScope(child: ConatelPresenceApp()));
}

// ─── Router ────────────────────────────────────────────────────
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login',    builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/kiosk',    builder: (_, __) => const KioskScreen()),
      ShellRoute(
        builder: (_, __, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/home',      builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/history',   builder: (_, __) => const HistoryScreen()),
          GoRoute(path: '/dashboard', builder: (_, __) => const RHDashboardScreen()),
          GoRoute(path: '/employees', builder: (_, __) => const EmployeesScreen()),
          GoRoute(path: '/leaves',    builder: (_, __) => const LeavesScreen()),
        ],
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Page introuvable: ${state.error}')),
    ),
  );
});

// ─── App principale ────────────────────────────────────────────
class ConatelPresenceApp extends ConsumerWidget {
  const ConatelPresenceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'CONATEL Présence',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      routerConfig: router,
    );
  }
}

// ─── Shell avec navigation ─────────────────────────────────────
class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  String _role = 'employee';
  String _currentPath = '/home';

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final role = await ref.read(apiServiceProvider).getRole();
    if (mounted) setState(() => _role = role ?? 'employee');
  }

  bool get _isAdmin => _role == 'admin' || _role == 'rh';

  // Destinations selon le rôle
  List<({String path, IconData icon, IconData activeIcon, String label})> get _destinations {
    final base = [
      (path: '/home',    icon: Icons.home_outlined,    activeIcon: Icons.home,    label: 'Accueil'),
      (path: '/history', icon: Icons.history_outlined, activeIcon: Icons.history, label: 'Historique'),
      (path: '/leaves',  icon: Icons.beach_access_outlined, activeIcon: Icons.beach_access, label: 'Congés'),
    ];
    if (_isAdmin) {
      return [
        (path: '/dashboard',  icon: Icons.dashboard_outlined,  activeIcon: Icons.dashboard,  label: 'Dashboard'),
        (path: '/employees',  icon: Icons.people_outline,       activeIcon: Icons.people,     label: 'Employés'),
        ...base,
      ];
    }
    return base;
  }

  int _currentIndex() {
    final idx = _destinations.indexWhere((d) => d.path == _currentPath);
    return idx >= 0 ? idx : 0;
  }

  @override
  Widget build(BuildContext context) {
    // Suivre la route courante
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final location = GoRouterState.of(context).matchedLocation;
      if (location != _currentPath) {
        setState(() => _currentPath = location);
      }
    });

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, -3)),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex(),
          onDestinationSelected: (i) {
            final path = _destinations[i].path;
            setState(() => _currentPath = path);
            context.go(path);
          },
          backgroundColor: Colors.white,
          elevation: 0,
          height: 65,
          destinations: _destinations.map((d) => NavigationDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.activeIcon, color: AppTheme.primary),
            label: d.label,
          )).toList(),
        ),
      ),
    );
  }
}
