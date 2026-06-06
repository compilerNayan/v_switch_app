package com.vswitch.configure

import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.IOException
import java.util.concurrent.TimeUnit

/**
 * Calls the ESP32 REST endpoint:
 * POST http://<serial-number>.local:8080/enrollment/enroll
 * Content-Type: text/plain
 */
class EnrollmentClient(
    private val port: Int = 8080
) {

    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .writeTimeout(15, TimeUnit.SECONDS)
        .build()

    sealed class Result {
        data object Success : Result()
        data class HttpError(val code: Int) : Result()
        data class NetworkError(val message: String) : Result()
    }

    fun enroll(deviceSerialNumber: String): Result {
        val requestBody = "".toRequestBody(TEXT_PLAIN_MEDIA_TYPE)
        val request = Request.Builder()
            .url("http://$deviceSerialNumber.local:$port/enrollment/enroll")
            .post(requestBody)
            .header("Content-Type", "text/plain")
            .build()

        return try {
            httpClient.newCall(request).execute().use { response ->
                if (response.isSuccessful) {
                    Result.Success
                } else {
                    Result.HttpError(response.code)
                }
            }
        } catch (error: IOException) {
            Result.NetworkError(error.message ?: error.javaClass.simpleName)
        }
    }

    companion object {
        private val TEXT_PLAIN_MEDIA_TYPE = "text/plain".toMediaType()
    }
}
