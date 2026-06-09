import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/config/app_config.dart';
import 'core/providers/app_providers.dart';
import 'core/providers/unit_providers.dart';
import 'core/utils/onboarding_router.dart';
import 'features/alerts/alerts_screen.dart';
import 'features/audit/audit_log_screen.dart';
import 'features/auth/admin_invite_screen.dart';
import 'features/auth/confirm_sign_up_screen.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/auth/tenant_setup_screen.dart';
import 'features/building/building_home_screen.dart';
import 'features/control/control_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/devices/water_meter/water_meter_setup_screen.dart';
import 'features/insights/insights_screen.dart';
import 'features/policies/policies_screen.dart';
import 'features/reports/reports_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/units/edit_unit_screen.dart';
import 'features/usage/usage_screen.dart';

class WaterMeterApp extends ConsumerWidget {
  const WaterMeterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      theme: ref.watch(appThemeProvider),
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
        const protected = {'/', '/settings', '/alerts', '/reports', '/policies', '/audit'};
        if (protected.contains(state.matchedLocation) ||
            state.matchedLocation.startsWith('/devices/') ||
            state.matchedLocation.startsWith('/units/')) {
          return '/auth';
        }
        return null;
      }

      final tenantExists = AppConfig.useMockAuth
          ? (ref.read(preferencesStorageProvider).valueOrNull?.tenantExists ??
              false)
          : false;

      return OnboardingRouter.redirectForProfile(
        profileAsync.valueOrNull,
        state.matchedLocation,
        tenantExists: tenantExists,
      );
    },
    routes: [
      GoRoute(
        path: '/auth',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/auth/confirm',
        builder: (context, state) => const ConfirmSignUpScreen(),
      ),
      GoRoute(
        path: '/onboarding/building-setup',
        builder: (context, state) => const TenantSetupScreen(),
      ),
      GoRoute(
        path: '/onboarding/admin-invite',
        builder: (context, state) => const AdminInviteScreen(),
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
        path: '/alerts',
        builder: (context, state) => const AlertsScreen(),
      ),
      GoRoute(
        path: '/reports',
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: '/policies',
        builder: (context, state) => const PoliciesScreen(),
      ),
      GoRoute(
        path: '/audit',
        builder: (context, state) => const AuditLogScreen(),
      ),
      GoRoute(
        path: '/units/:unitId/edit',
        builder: (context, state) => EditUnitScreen(
          unitId: state.pathParameters['unitId']!,
        ),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const BuildingHomeScreen(),
      ),
      GoRoute(
        path: '/devices/add',
        redirect: (_, __) => '/devices/water-meter/setup',
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
              return _UnitShell(
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

class _UnitShell extends ConsumerStatefulWidget {
  const _UnitShell({
    required this.deviceId,
    required this.navigationShell,
  });

  final String deviceId;
  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<_UnitShell> createState() => _UnitShellState();
}

class _UnitShellState extends ConsumerState<_UnitShell> {
  @override
  void initState() {
    super.initState();
    ref.read(selectedRouteDeviceIdProvider.notifier).state = widget.deviceId;
  }

  @override
  void didUpdateWidget(covariant _UnitShell oldWidget) {
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
    const destinations = [
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
    ];

    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: widget.navigationShell.goBranch,
        destinations: destinations,
      ),
    );
  }
}
