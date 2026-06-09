import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'api_exceptions.dart';
import 'building_api_client.dart';

typedef AuthTokenProvider = Future<String?> Function();

class DioBuildingApiClient implements BuildingApiClient {
  DioBuildingApiClient({
    required AuthTokenProvider authTokenProvider,
    String? baseUrl,
    Dio? dio,
  })  : _authTokenProvider = authTokenProvider,
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
          final token = await _authTokenProvider();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  final AuthTokenProvider _authTokenProvider;

  @override
  Future<BuildingSummary> getSummary({required String tenantId}) async {
    final data = await _get<Map<String, dynamic>>(
      '/tenants/$tenantId/building/summary',
    );

    final rankings = await getRankings(
      tenantId: tenantId,
      period: 'today',
      limit: 3,
    );

    return BuildingSummary(
      totalTodayLiters: (data['totalTodayLiters'] as num).toDouble(),
      totalMonthLiters: (data['totalMonthLiters'] as num).toDouble(),
      unitsOnline: data['unitsOnline'] as int,
      unitsOffline: data['unitsOffline'] as int,
      unitsTotal: data['unitsTotal'] as int,
      activeAlerts: data['activeAlerts'] as int? ?? 0,
      topConsumers: rankings
          .map((r) => (unitId: r.unitId, name: r.name, liters: r.liters))
          .toList(),
    );
  }

  @override
  Future<List<BuildingRanking>> getRankings({
    required String tenantId,
    required String period,
    String groupBy = 'overall',
    String? blockId,
    int limit = 10,
  }) async {
    final data = await _get<Map<String, dynamic>>(
      '/tenants/$tenantId/building/rankings',
      queryParameters: {
        'period': period,
        'groupBy': groupBy,
        if (blockId != null && blockId.isNotEmpty) 'blockId': blockId,
        'limit': limit,
      },
    );

    final list = data['rankings'] as List<dynamic>? ?? [];
    return list.map((entry) {
      final json = entry as Map<String, dynamic>;
      return BuildingRanking(
        unitId: json['unitId'] as String,
        name: json['name'] as String,
        liters: (json['liters'] as num).toDouble(),
        quotaPercent: json['quotaPercent'] == null
            ? null
            : (json['quotaPercent'] as num).toDouble(),
      );
    }).toList();
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
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        throw NetworkException(e.message ?? 'Network error');
      }
      final status = e.response?.statusCode ?? 0;
      final body = e.response?.data;
      if (body is Map<String, dynamic>) {
        throw ApiException(
          statusCode: status,
          error: ApiError.fromJson(body),
        );
      }
      throw NetworkException(e.message ?? 'Request failed');
    }
  }
}
