import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../models/user_profile.dart';
import '../auth/auth_service.dart';
import '../auth/mock_auth_service.dart';
import 'api_exceptions.dart';

class TenantApiClient {
  TenantApiClient({
    required AuthService authService,
    String? baseUrl,
    Dio? dio,
  })  : _authService = authService,
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

  Future<UserProfile> setRole(UserRole role) async {
    if (AppConfig.useMockAuth && _authService is MockAuthService) {
      final mock = _authService as MockAuthService;
      var user = await mock.setRole(role);
      if (role == UserRole.admin) {
        user = await mock.createTenant();
      }
      return user;
    }
    final data = await _post<Map<String, dynamic>>(
      '/users/role',
      {'role': role.toApiValue()},
    );
    await _authService.refreshProfile();
    final me = await getMe();
    if (data['tenantId'] != null) {
      return me.copyWith(
        tenantId: data['tenantId'] as String?,
        inviteCode: data['inviteCode'] as String?,
        onboardingComplete: true,
        role: role,
      );
    }
    return me.copyWith(role: role);
  }

  Future<UserProfile> createTenant() async {
    if (AppConfig.useMockAuth && _authService is MockAuthService) {
      return (_authService as MockAuthService).createTenant();
    }
    final data = await _post<Map<String, dynamic>>('/tenants', {});
    await _authService.refreshProfile();
    final me = await getMe();
    return me.copyWith(
      tenantId: data['tenantId'] as String?,
      inviteCode: data['inviteCode'] as String?,
      onboardingComplete: true,
      role: UserRole.admin,
    );
  }

  Future<UserProfile> joinTenant(String inviteCode) async {
    if (AppConfig.useMockAuth && _authService is MockAuthService) {
      try {
        return await (_authService as MockAuthService).joinTenant(inviteCode);
      } on TenantJoinException catch (e) {
        throw ApiException(
          statusCode: 404,
          error: ApiError(code: 'INVALID_INVITE', message: e.message),
        );
      }
    }
    final data = await _post<Map<String, dynamic>>(
      '/tenants/join',
      {'inviteCode': inviteCode.trim().toUpperCase()},
    );
    await _authService.refreshProfile();
    final me = await getMe();
    return me.copyWith(
      tenantId: data['tenantId'] as String?,
      onboardingComplete: true,
      role: UserRole.readonly,
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
