import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../models/home_dashboard.dart';
import '../models/tenant_config.dart';
import '../models/tenant_metadata.dart';
import '../models/user_profile.dart';
import '../models/valve_state.dart';
import '../models/water_unit.dart';
import 'enrollment_status_result.dart';
import '../auth/auth_service.dart';
import 'api_exceptions.dart';
import 'stream_valve_api_client.dart';

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
  final StreamValveApiClient _streamValveClient = StreamValveApiClient();

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

  Future<void> preEnrollDevice({
    required String tenantId,
    required String serialNumber,
  }) async {
    await _post<Map<String, dynamic>>(
      '/v2/tenants/$tenantId/devices/pre-enroll',
      {'serialNumber': serialNumber},
    );
  }

  Future<List<WaterUnit>> listUnits(String tenantId) async {
    final data = await _get<Map<String, dynamic>>('/v2/tenants/$tenantId/units');
    final unitsJson = data['units'] as List<dynamic>? ?? [];
    return unitsJson
        .map((entry) => WaterUnit.fromJson(entry as Map<String, dynamic>))
        .toList();
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
    final data = await _post<Map<String, dynamic>>(
      '/v2/tenants/$tenantId/units',
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
    final data = await _get<Map<String, dynamic>>(
      '/v2/tenants/$tenantId/devices/$deviceId/enrollment-status',
    );
    return EnrollmentStatusResult(
      enrolled: data['enrolled'] as bool? ?? false,
      status: data['status'] as String? ?? 'pending',
    );
  }

  Future<String> createAdminInvite(String tenantId) async {
    final data = await _post<Map<String, dynamic>>(
      '/v2/tenants/$tenantId/admin-invites',
      {},
    );
    return data['inviteCode'] as String;
  }

  Future<Map<String, dynamic>> joinAsAdmin(String inviteCode) async {
    return _post<Map<String, dynamic>>(
      '/v2/tenants/join/admin',
      {'inviteCode': inviteCode.trim().toUpperCase()},
    );
  }

  Future<ValveState> getValveState({
    required String tenantId,
    required String deviceId,
  }) async {
    return _streamValveClient.getValveState(deviceId);
  }

  Future<ValveState> setValvePressure({
    required String tenantId,
    required String deviceId,
    required ValveUpdateRequest request,
  }) async {
    return _streamValveClient.setValvePressure(deviceId, request);
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

  Future<HomeDashboardResponse> getDashboard(
    String tenantId, {
    String? timezone,
  }) async {
    final data = await _get<Map<String, dynamic>>(
      '/v2/tenants/$tenantId/dashboard',
      queryParameters:
          timezone != null && timezone.isNotEmpty ? {'timezone': timezone} : null,
    );
    return HomeDashboardResponse.fromJson(data);
  }

  Future<T> _get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get<T>(
        path,
        queryParameters: queryParameters,
      );
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
