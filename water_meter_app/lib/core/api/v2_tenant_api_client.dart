import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../models/home_dashboard.dart';
import '../models/tenant_config.dart';
import '../models/tenant_metadata.dart';
import '../models/user_profile.dart';
import '../auth/auth_service.dart';
import 'api_exceptions.dart';

class V2TenantApiClient {
  V2TenantApiClient({
    required AuthService authService,
    String? baseUrl,
    Dio? dio,
  }) : _dio = dio ??
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
          final token = await authService.getIdToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;

  Future<UserProfile> getMe() async {
    final data = await _get<Map<String, dynamic>>('/v2/users/me');
    return UserProfile.fromJson(data);
  }

  Future<UserProfile> registerUser({
    required String email,
    required String phone,
    required String firstName,
    required String lastName,
  }) async {
    final data = await _post<Map<String, dynamic>>('/v2/users', {
      'email': email,
      'phone': phone,
      'firstName': firstName,
      'lastName': lastName,
    });
    return UserProfile.fromJson(data);
  }

  Future<TenantConfig> getTenant(String tenantId) async {
    final data = await _get<Map<String, dynamic>>('/v2/tenants/$tenantId');
    return TenantConfig.fromJson(data);
  }

  Future<TenantConfig> createBuilding({
    required String tenantId,
    required String name,
    required TenantStructure structure,
  }) async {
    final data = await _post<Map<String, dynamic>>(
      '/v2/tenants/$tenantId/building',
      {
        'name': name,
        'structure': structure.toJson(),
      },
    );
    return TenantConfig.fromJson(data);
  }

  Future<String> getMetadataHash(String tenantId) async {
    final data = await _get<Map<String, dynamic>>(
      '/v2/tenants/$tenantId/metadata/hash',
    );
    return data['metadataHash'] as String;
  }

  Future<TenantMetadataResponse> getMetadata(String tenantId) async {
    final data = await _get<Map<String, dynamic>>(
      '/v2/tenants/$tenantId/metadata',
    );
    return TenantMetadataResponse.fromJson(data);
  }

  Future<HomeDashboardResponse> getDashboard(String tenantId) async {
    final data = await _get<Map<String, dynamic>>(
      '/v2/tenants/$tenantId/dashboard',
    );
    return HomeDashboardResponse.fromJson(data);
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
