import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../models/tenant_config.dart';
import '../models/user_profile.dart';
import '../models/water_unit.dart';
import '../auth/auth_service.dart';
import '../auth/mock_auth_service.dart';
import '../storage/preferences_storage.dart';
import 'api_exceptions.dart';
import 'enrollment_status_result.dart';

class TenantApiClient {
  TenantApiClient({
    required AuthService authService,
    required Future<PreferencesStorage> Function() prefsProvider,
    String? baseUrl,
    Dio? dio,
  })  : _authService = authService,
        _prefsProvider = prefsProvider,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
                headers: {'Accept': 'application/json'},
              ),
            ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _authService.getIdToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  final AuthService _authService;
  final Future<PreferencesStorage> Function() _prefsProvider;

  Future<UserProfile> getMe() async {
    if (AppConfig.useMockAuth && _authService is MockAuthService) {
      final user = await _authService.getCurrentUser();
      if (user == null) throw Exception('Not authenticated');
      return user;
    }
    final data = await _get<Map<String, dynamic>>('/users/me');
    final profile = UserProfile.fromJson(data);
    final token = await _authService.getIdToken();
    return profile.copyWith(idToken: token);
  }

  Future<UserProfile> registerUser({
    required String email,
    required String phone,
    required String firstName,
    required String lastName,
    required String tenantName,
  }) async {
    if (AppConfig.useMockAuth && _authService is MockAuthService) {
      final prefs = await _prefsProvider();
      return (_authService as MockAuthService).registerUser(
        email: email,
        phone: phone,
        firstName: firstName,
        lastName: lastName,
        tenantName: tenantName,
        prefs: prefs,
      );
    }
    final data = await _post<Map<String, dynamic>>('/users', {
      'email': email,
      'phone': phone,
      'firstName': firstName,
      'lastName': lastName,
      'tenantName': tenantName,
    });
    final profile = UserProfile.fromJson(data);
    final token = await _authService.getIdToken();
    return profile.copyWith(idToken: token);
  }

  Future<void> preEnrollDevice({
    required String tenantId,
    required String serialNumber,
  }) async {
    if (AppConfig.useMockApi) {
      return;
    }
    await _post<Map<String, dynamic>>(
      '/tenants/$tenantId/devices/pre-enroll',
      {'serialNumber': serialNumber},
    );
  }

  Future<bool> tenantExists() async {
    if (AppConfig.useMockAuth) {
      final prefs = await _prefsProvider();
      return prefs.tenantExists;
    }
    final data = await _get<Map<String, dynamic>>('/tenants/exists');
    return data['exists'] as bool? ?? false;
  }

  Future<UserProfile> createTenant({
    required String name,
    required TenantStructure structure,
  }) async {
    if (AppConfig.useMockAuth && _authService is MockAuthService) {
      final prefs = await _prefsProvider();
      return (_authService as MockAuthService).createTenant(
        name: name,
        structure: structure,
        prefs: prefs,
      );
    }
    final data = await _post<Map<String, dynamic>>('/tenants', {
      'name': name,
      'structure': structure.toJson(),
    });
    await _authService.refreshProfile();
    final me = await getMe();
    return me.copyWith(
      tenantId: data['tenantId'] as String?,
      onboardingComplete: true,
      isTenantOwner: data['isTenantOwner'] as bool? ?? true,
    );
  }

  Future<TenantConfig> getTenant(String tenantId) async {
    if (AppConfig.useMockAuth) {
      final prefs = await _prefsProvider();
      final config = prefs.getTenantConfig();
      if (config == null || config.tenantId != tenantId) {
        throw ApiException(
          statusCode: 404,
          error: const ApiError(code: 'NOT_FOUND', message: 'Tenant not found'),
        );
      }
      return config;
    }
    final data = await _get<Map<String, dynamic>>('/tenants/$tenantId');
    return TenantConfig.fromJson(data);
  }

  Future<TenantConfig> createBuilding({
    required String tenantId,
    required String name,
    required TenantStructure structure,
  }) async {
    if (AppConfig.useMockAuth && _authService is MockAuthService) {
      final prefs = await _prefsProvider();
      return (_authService as MockAuthService).createBuilding(
        tenantId: tenantId,
        name: name,
        structure: structure,
        prefs: prefs,
      );
    }
    final data = await _post<Map<String, dynamic>>(
      '/tenants/$tenantId/building',
      {
        'name': name,
        'structure': structure.toJson(),
      },
    );
    await _authService.refreshProfile();
    return TenantConfig.fromJson(data);
  }

  Future<TenantConfig> updateStructure({
    required String tenantId,
    required TenantStructure structure,
  }) async {
    if (AppConfig.useMockAuth) {
      final prefs = await _prefsProvider();
      final existing = prefs.getTenantConfig();
      if (existing == null) {
        throw ApiException(
          statusCode: 404,
          error: const ApiError(code: 'NOT_FOUND', message: 'Tenant not found'),
        );
      }
      final updated = existing.copyWith(structure: structure);
      await prefs.setTenantConfig(updated);
      return updated;
    }
    final data = await _put<Map<String, dynamic>>(
      '/tenants/$tenantId/structure',
      {'structure': structure.toJson()},
    );
    return TenantConfig.fromJson(data);
  }

  Future<WaterUnit> createUnit({
    required String tenantId,
    required String deviceId,
    required String name,
    required String flatNumber,
    required String floor,
    required String block,
    required String wing,
    required String residentName,
    required String phoneNumber,
    String? notes,
  }) async {
    if (AppConfig.useMockApi) {
      final prefs = await _prefsProvider();
      final unit = WaterUnit(
        id: 'wm-$deviceId',
        name: name,
        deviceId: deviceId,
        flatNumber: flatNumber,
        floor: floor,
        block: block,
        wing: wing,
        residentName: residentName,
        phoneNumber: phoneNumber,
        notes: notes,
        enrollmentStatus: UnitEnrollmentStatus.pending,
      );
      return prefs.addWaterUnit(unit);
    }
    final data = await _post<Map<String, dynamic>>(
      '/tenants/$tenantId/units',
      {
        'deviceId': deviceId,
        'name': name,
        'flatNumber': flatNumber,
        'floor': floor,
        'block': block,
        'wing': wing,
        'residentName': residentName,
        'phoneNumber': phoneNumber,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    return WaterUnit.fromJson(data);
  }

  Future<EnrollmentStatusResult> getEnrollmentStatus({
    required String tenantId,
    required String deviceId,
  }) async {
    if (AppConfig.useMockApi) {
      return const EnrollmentStatusResult(enrolled: true, status: 'enrolled');
    }
    final data = await _get<Map<String, dynamic>>(
      '/tenants/$tenantId/devices/$deviceId/enrollment-status',
    );
    return EnrollmentStatusResult(
      enrolled: data['enrolled'] as bool? ?? false,
      status: data['status'] as String? ?? 'pending',
    );
  }

  Future<String> createAdminInvite(String tenantId) async {
    if (AppConfig.useMockAuth && _authService is MockAuthService) {
      final prefs = await _prefsProvider();
      return (_authService as MockAuthService).generateAdminInvite(prefs);
    }
    final data = await _post<Map<String, dynamic>>(
      '/tenants/$tenantId/admin-invites',
      {},
    );
    return data['inviteCode'] as String;
  }

  Future<UserProfile> joinAsAdmin(String inviteCode) async {
    if (AppConfig.useMockAuth && _authService is MockAuthService) {
      final prefs = await _prefsProvider();
      try {
        return await (_authService as MockAuthService).joinAsAdmin(
          inviteCode: inviteCode,
          prefs: prefs,
        );
      } on TenantJoinException catch (e) {
        throw ApiException(
          statusCode: 404,
          error: ApiError(code: 'INVALID_INVITE', message: e.message),
        );
      }
    }
    final data = await _post<Map<String, dynamic>>(
      '/tenants/join/admin',
      {'inviteCode': inviteCode.trim().toUpperCase()},
    );
    await _authService.refreshProfile();
    final me = await getMe();
    return me.copyWith(
      tenantId: data['tenantId'] as String?,
      onboardingComplete: true,
      isTenantOwner: false,
    );
  }

  Future<T> _get<T>(String path) async {
    try {
      final response = await _dio.get<T>(path);
      return response.data as T;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<T> _post<T>(String path, Map<String, dynamic> body) async {
    try {
      final response = await _dio.post<T>(path, data: body);
      return response.data as T;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<T> _put<T>(String path, Map<String, dynamic> body) async {
    try {
      final response = await _dio.put<T>(path, data: body);
      return response.data as T;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Exception _mapError(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return NetworkException(e.message ?? 'Network error');
    }
    final status = e.response?.statusCode ?? 0;
    final body = e.response?.data;
    if (body is Map<String, dynamic>) {
      return ApiException(statusCode: status, error: ApiError.fromJson(body));
    }
    return NetworkException(e.message ?? 'Request failed');
  }
}
