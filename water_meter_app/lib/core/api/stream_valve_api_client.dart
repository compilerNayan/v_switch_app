import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../models/valve_state.dart';
import 'api_exceptions.dart';

/// Valve GET/PUT against water_meter_data_injection_service over the device TCP stream.
class StreamValveApiClient {
  StreamValveApiClient({
    String? baseUrl,
    Dio? dio,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 30),
                headers: {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
              ),
            );

  final Dio _dio;

  Future<ValveState> getValveState(String deviceSerial) async {
    final data = await _get<Map<String, dynamic>>(
      '/stream/devices/$deviceSerial/valve',
    );
    return ValveState.fromStreamApiJson(data, deviceId: deviceSerial);
  }

  Future<ValveState> setValvePressure(
    String deviceSerial,
    ValveUpdateRequest request,
  ) async {
    final pressurePercent = request.pressurePercent;
    if (pressurePercent == null) {
      throw const ApiException(
        statusCode: 400,
        error: ApiError(
          code: 'INVALID_REQUEST',
          message: 'pressurePercent is required for stream valve control',
        ),
      );
    }

    final data = await _put<Map<String, dynamic>>(
      '/stream/devices/$deviceSerial/valve',
      body: {'pressurePercent': pressurePercent.round()},
    );
    return ValveState.fromStreamApiJson(data, deviceId: deviceSerial);
  }

  Future<T> _get<T>(String path) async {
    return _request<T>(() => _dio.get<T>(path));
  }

  Future<T> _put<T>(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    return _request<T>(() => _dio.put<T>(path, data: body));
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
}
