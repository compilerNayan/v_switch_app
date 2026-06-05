package com.vswitch.configure

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Bundle
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.lifecycle.lifecycleScope
import com.vswitch.configure.databinding.ActivityMainBinding
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.Dispatchers

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding
    private lateinit var devicePreferences: DevicePreferences
    private val wifiCredentialsClient = WifiCredentialsClient()

    private val locationPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) {
            configureWifi()
        } else {
            toast(R.string.error_location_permission)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        devicePreferences = DevicePreferences(applicationContext)

        lifecycleScope.launch {
            devicePreferences.serialNumber.collect { serial ->
                binding.savedSerialText.text = serial ?: getString(R.string.no_serial_saved)
            }
        }

        binding.configureWifiButton.setOnClickListener {
            if (!hasLocationPermission()) {
                locationPermissionLauncher.launch(Manifest.permission.ACCESS_FINE_LOCATION)
                return@setOnClickListener
            }
            configureWifi()
        }
    }

    private fun configureWifi() {
        if (!isConnectedToWifi()) {
            toast(R.string.error_not_on_wifi)
            return
        }

        val currentSsid = getCurrentWifiSsid()
        if (!currentSsid.startsWith(IOT_SSID_PREFIX)) {
            toast(R.string.error_wrong_hotspot)
            return
        }

        val serialNumber = currentSsid.removePrefix(IOT_SSID_PREFIX).trim()
        if (serialNumber.isEmpty()) {
            toast(R.string.error_wrong_hotspot)
            return
        }

        val homeWifiSsid = binding.usernameInput.text?.toString()?.trim().orEmpty()
        val homeWifiPassword = binding.passwordInput.text?.toString().orEmpty()
        if (homeWifiSsid.isEmpty() || homeWifiPassword.isEmpty()) {
            toast(R.string.error_empty_credentials)
            return
        }

        binding.configureWifiButton.isEnabled = false
        binding.configureWifiButton.text = getString(R.string.configuring)

        lifecycleScope.launch {
            val result = withContext(Dispatchers.IO) {
                wifiCredentialsClient.configureWifi(
                    homeWifiSsid = homeWifiSsid,
                    homeWifiPassword = homeWifiPassword,
                    deviceSerialNumber = serialNumber
                )
            }

            binding.configureWifiButton.isEnabled = true
            binding.configureWifiButton.text = getString(R.string.configure_wifi)

            when (result) {
                WifiCredentialsClient.Result.Success -> {
                    devicePreferences.saveSerialNumber(serialNumber)
                    toast(R.string.success_wifi_configured)
                }

                is WifiCredentialsClient.Result.HttpError -> {
                    toast(getString(R.string.error_configure_failed, result.code))
                }

                is WifiCredentialsClient.Result.NetworkError -> {
                    toast(R.string.error_network)
                }
            }
        }
    }

    private fun isConnectedToWifi(): Boolean {
        val connectivityManager =
            getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val network = connectivityManager.activeNetwork ?: return false
        val capabilities = connectivityManager.getNetworkCapabilities(network) ?: return false
        return capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)
    }

    @Suppress("DEPRECATION")
    private fun getCurrentWifiSsid(): String {
        val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        val rawSsid = wifiManager.connectionInfo?.ssid ?: return ""
        return rawSsid.trim('"')
    }

    private fun hasLocationPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun toast(messageResId: Int) {
        Toast.makeText(this, messageResId, Toast.LENGTH_SHORT).show()
    }

    private fun toast(message: String) {
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
    }

    companion object {
        private const val IOT_SSID_PREFIX = "IoT_"
    }
}
