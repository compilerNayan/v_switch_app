import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/config/app_config.dart';
import 'core/providers/app_providers.dart';
import 'core/providers/device_providers.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/onboarding_router.dart';
import 'features/auth/join_tenant_screen.dart';
import 'features/auth/role_selection_screen.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/control/control_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/devices/add_device_screen.dart';
import 'features/devices/devices_home_screen.dart';
import 'features/devices/water_meter/water_meter_setup_screen.dart';
import 'features/insights/insights_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/usage/usage_screen.dart';

class WaterMeterApp extends ConsumerWidget {
  const WaterMeterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      theme: AppTheme.light(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final authListenable = ref.watch(authListenableProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authListenable,
    redirect: (context, state) {
      final profileAsync = ref.read(userProfileProvider);
      if (profileAsync.isLoading) {
        const protected = {'/', '/settings'};
        if (protected.contains(state.matchedLocation) ||
            state.matchedLocation.startsWith('/devices/')) {
          return '/auth';
        }
        return null;
      }

      return OnboardingRouter.redirectForProfile(
        profileAsync.valueOrNull,
        state.matchedLocation,
      );
    },
    routes: [
      GoRoute(
        path: '/auth',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/onboarding/role',
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: '/onboarding/join',
        builder: (context, state) => const JoinTenantScreen(),
      ),
      GoRoute(
        path: '/devices/add',
        builder: (context, state) => const AddDeviceScreen(),
      ),
      GoRoute(
        path: '/devices/water-meter/setup',
        builder: (context, state) => const WaterMeterSetupScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const DevicesHomeScreen(),
      ),
      GoRoute(
        path: '/devices/:deviceId',
        redirect: (context, state) {
          final deviceId = state.pathParameters['deviceId']!;
          if (state.uri.path == '/devices/$deviceId') {
            return '/devices/$deviceId/dashboard';
          }
          return null;
        },
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, navigationShell) {
              final deviceId = state.pathParameters['deviceId']!;
              return _DeviceShell(
                deviceId: deviceId,
                navigationShell: navigationShell,
              );
            },
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: 'dashboard',
                    builder: (context, state) => const DashboardScreen(),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: 'usage',
                    builder: (context, state) => const UsageScreen(),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: 'insights',
                    builder: (context, state) => const InsightsScreen(),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: 'control',
                    builder: (context, state) => const ControlScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class _DeviceShell extends ConsumerStatefulWidget {
  const _DeviceShell({
    required this.deviceId,
    required this.navigationShell,
  });

  final String deviceId;
  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<_DeviceShell> createState() => _DeviceShellState();
}

class _DeviceShellState extends ConsumerState<_DeviceShell> {
  @override
  void initState() {
    super.initState();
    ref.read(selectedRouteDeviceIdProvider.notifier).state = widget.deviceId;
  }

  @override
  void didUpdateWidget(covariant _DeviceShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deviceId != widget.deviceId) {
      ref.read(selectedRouteDeviceIdProvider.notifier).state = widget.deviceId;
    }
  }

  @override
  void dispose() {
    ref.read(selectedRouteDeviceIdProvider.notifier).state = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: widget.navigationShell.goBranch,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Usage',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Insights',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: 'Control',
          ),
        ],
      ),
    );
  }
}
