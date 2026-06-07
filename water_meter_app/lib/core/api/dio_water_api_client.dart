import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../models/current_reading.dart';
import '../models/daily_summary.dart';
import '../models/quota_config.dart';
import '../models/usage_response.dart';
import '../models/valve_state.dart';
import 'api_exceptions.dart';
import 'water_api_client.dart';

typedef AuthCredentialsProvider = Future<({String deviceId, String apiKey})?> Function();

class DioWaterApiClient implements WaterApiClient {
  DioWaterApiClient({
    required AuthCredentialsProvider credentialsProvider,
    String? baseUrl,
    Dio? dio,
  })  : _credentialsProvider = credentialsProvider,
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
          final creds = await _credentialsProvider();
          if (creds != null) {
            options.headers['Authorization'] = 'Bearer ${creds.apiKey}';
            if (creds.deviceId.isNotEmpty) {
              options.headers['X-Device-Id'] = creds.deviceId;
            }
          }
          handler.next(options);
        },
        onError: (error, handler) {
          handler.next(error);
        },
      ),
    );
  }

  final Dio _dio;
  final AuthCredentialsProvider _credentialsProvider;

  @override
  Future<CurrentReading> getCurrentReading(String deviceId) async {
    final data = await _get<Map<String, dynamic>>(
      '/devices/$deviceId/water/current',
    );
    return CurrentReading.fromJson(data);
  }

  @override
  Future<UsageResponse> getUsage({
    required String deviceId,
    required DateTime from,
    required DateTime to,
    required Granularity granularity,
    required String timezone,
  }) async {
    final data = await _get<Map<String, dynamic>>(
      '/devices/$deviceId/water/usage',
      queryParameters: {
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
        'granularity': granularity.apiValue,
        'timezone': timezone,
      },
    );
    return UsageResponse.fromJson(data);
  }

  @override
  Future<DailySummaryResponse> getDailySummary({
    required String deviceId,
    required DateTime from,
    required DateTime to,
    required String timezone,
  }) async {
    final data = await _get<Map<String, dynamic>>(
      '/devices/$deviceId/water/daily',
      queryParameters: {
        'from': _dateOnly(from),
        'to': _dateOnly(to),
        'timezone': timezone,
      },
    );
    return DailySummaryResponse.fromJson(data);
  }

  @override
  Future<ValveState> getValveState(String deviceId) async {
    final data = await _get<Map<String, dynamic>>(
      '/devices/$deviceId/water/valve',
    );
    return ValveState.fromJson(data);
  }

  @override
  Future<ValveState> setValvePressure(
    String deviceId,
    ValveUpdateRequest request,
  ) async {
    final data = await _put<Map<String, dynamic>>(
      '/devices/$deviceId/water/valve',
      body: request.toJson(),
    );
    return ValveState.fromJson(data);
  }

  @override
  Future<QuotaResponse> getQuota(String deviceId) async {
    final data = await _get<Map<String, dynamic>>(
      '/devices/$deviceId/water/quota',
    );
    return QuotaResponse.fromJson(data);
  }

  @override
  Future<QuotaResponse> updateQuota(
    String deviceId,
    QuotaUpdateRequest request,
  ) async {
    final data = await _put<Map<String, dynamic>>(
      '/devices/$deviceId/water/quota',
      body: request.toJson(),
    );
    return QuotaResponse.fromJson(data);
  }

  @override
  Future<HourlyPatternResponse> getHourlyPattern({
    required String deviceId,
    required DateTime from,
    required DateTime to,
    required String timezone,
  }) async {
    final data = await _get<Map<String, dynamic>>(
      '/devices/$deviceId/water/hourly-pattern',
      queryParameters: {
        'from': _dateOnly(from),
        'to': _dateOnly(to),
        'timezone': timezone,
      },
    );
    return HourlyPatternResponse.fromJson(data);
  }

  Future<T> _get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return _request<T>(
      () => _dio.get<T>(path, queryParameters: queryParameters),
    );
  }

  Future<T> _put<T>(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    return _request<T>(
      () => _dio.put<T>(path, data: body),
    );
  }

  Future<T> _request<T>(Future<Response<T>> Function() call) async {
    try {
      final response = await call();
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

  String _dateOnly(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
