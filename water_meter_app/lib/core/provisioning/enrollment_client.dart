import 'package:dio/dio.dart';

sealed class EnrollmentResult {
  const EnrollmentResult();
}

class EnrollmentSuccess extends EnrollmentResult {
  const EnrollmentSuccess();
}

class EnrollmentHttpError extends EnrollmentResult {
  const EnrollmentHttpError(this.code);
  final int code;
}

class EnrollmentNetworkError extends EnrollmentResult {
  const EnrollmentNetworkError(this.message);
  final String message;
}

class EnrollmentClient {
  EnrollmentClient({Dio? dio, this.port = 8080})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
                sendTimeout: const Duration(seconds: 15),
              ),
            );

  final Dio _dio;
  final int port;

  Future<EnrollmentResult> enroll(String deviceSerialNumber) async {
    try {
      final response = await _dio.post<String>(
        'http://$deviceSerialNumber.local:$port/enrollment/enroll',
        data: '',
        options: Options(contentType: 'text/plain'),
      );
      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        return const EnrollmentSuccess();
      }
      return EnrollmentHttpError(response.statusCode ?? -1);
    } on DioException catch (error) {
      if (error.response?.statusCode != null) {
        return EnrollmentHttpError(error.response!.statusCode!);
      }
      return EnrollmentNetworkError(error.message ?? error.type.name);
    } catch (error) {
      return EnrollmentNetworkError(error.toString());
    }
  }
}
