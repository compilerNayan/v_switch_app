package com.vswitch.configure

import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.io.IOException
import java.util.concurrent.TimeUnit

/**
 * Calls the ESP32 REST endpoint:
 * POST http://192.168.4.1:8080/wifi-credentials
 * Body: {"ssid":"<home wifi ssid>","password":"<home wifi password>"}
 */
class WifiCredentialsClient(
    private val port: Int = 8080,
    private val gatewayHost: String = "192.168.4.1"
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

    fun configureWifi(
        homeWifiSsid: String,
        homeWifiPassword: String,
        deviceSerialNumber: String
    ): Result {
        val payload = JSONObject()
            .put("ssid", homeWifiSsid)
            .put("password", homeWifiPassword)
            .toString()

        val requestBody = payload.toRequestBody(JSON_MEDIA_TYPE)
        val hosts = listOf(gatewayHost, "$deviceSerialNumber.local")

        var lastHttpCode = -1
        var lastNetworkError: String? = null

        for (host in hosts) {
            val request = Request.Builder()
                .url("http://$host:$port/wifi-credentials")
                .post(requestBody)
                .header("Content-Type", "application/json")
                .build()

            try {
                httpClient.newCall(request).execute().use { response ->
                    if (response.isSuccessful) {
                        return Result.Success
                    }
                    lastHttpCode = response.code
                }
            } catch (error: IOException) {
                lastNetworkError = error.message ?: error.javaClass.simpleName
            }
        }

        return when {
            lastHttpCode > 0 -> Result.HttpError(lastHttpCode)
            else -> Result.NetworkError(lastNetworkError ?: "Unknown network error")
        }
    }

    companion object {
        private val JSON_MEDIA_TYPE = "application/json; charset=utf-8".toMediaType()
    }
}
