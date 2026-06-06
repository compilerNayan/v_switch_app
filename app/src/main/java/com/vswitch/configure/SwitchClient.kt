package com.vswitch.configure

import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.IOException
import java.util.concurrent.TimeUnit

/**
 * Calls the ESP32 REST endpoints:
 * PUT http://<serial-number>.local:8080/switch/<id>/on
 * PUT http://<serial-number>.local:8080/switch/<id>/off
 */
class SwitchClient(
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

    fun setSwitchState(
        deviceSerialNumber: String,
        switchNumber: Int,
        turnOn: Boolean
    ): Result {
        val action = if (turnOn) "on" else "off"
        val request = Request.Builder()
            .url("http://$deviceSerialNumber.local:$port/switch/$switchNumber/$action")
            .put(EMPTY_BODY)
            .header("Accept", "*/*")
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
        private val EMPTY_BODY = ByteArray(0).toRequestBody(null)
    }
}
