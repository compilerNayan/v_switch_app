package com.vswitch.configure

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiManager
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import com.vswitch.configure.databinding.FragmentConfigurationsBinding
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class ConfigurationsFragment : Fragment() {

    private var _binding: FragmentConfigurationsBinding? = null
    private val binding get() = _binding!!

    private lateinit var devicePreferences: DevicePreferences
    private val wifiCredentialsClient = WifiCredentialsClient()
    private val enrollmentClient = EnrollmentClient()
    private lateinit var connectivityManager: ConnectivityManager
    private var savedSerialNumber: String? = null

    private val networkCallback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) = updateEnrollmentButtonState()

        override fun onLost(network: Network) = updateEnrollmentButtonState()

        override fun onCapabilitiesChanged(
            network: Network,
            networkCapabilities: NetworkCapabilities
        ) = updateEnrollmentButtonState()
    }

    private val locationPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) {
            configureWifi()
        } else {
            toast(R.string.error_location_permission)
        }
        updateEnrollmentButtonState()
    }

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentConfigurationsBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        devicePreferences = DevicePreferences(requireContext().applicationContext)
        connectivityManager =
            requireContext().getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

        viewLifecycleOwner.lifecycleScope.launch {
            devicePreferences.serialNumber.collect { serial ->
                savedSerialNumber = serial
                binding.savedSerialText.text = serial ?: getString(R.string.no_serial_saved)
                updateEnrollmentButtonState()
            }
        }

        binding.configureWifiButton.setOnClickListener {
            if (!hasLocationPermission()) {
                locationPermissionLauncher.launch(Manifest.permission.ACCESS_FINE_LOCATION)
                return@setOnClickListener
            }
            configureWifi()
        }

        binding.enrollButton.setOnClickListener {
            enrollDevice()
        }
    }

    override fun onStart() {
        super.onStart()
        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .build()
        connectivityManager.registerNetworkCallback(request, networkCallback)
        updateEnrollmentButtonState()
    }

    override fun onStop() {
        super.onStop()
        connectivityManager.unregisterNetworkCallback(networkCallback)
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }

    private fun enrollDevice() {
        val serialNumber = savedSerialNumber?.trim().orEmpty()
        if (serialNumber.isEmpty()) {
            toast(R.string.error_no_serial_for_enroll)
            return
        }
        if (!canEnableEnrollment()) {
            return
        }

        binding.enrollButton.isEnabled = false
        binding.enrollButton.text = getString(R.string.enrolling)

        viewLifecycleOwner.lifecycleScope.launch {
            val result = withContext(Dispatchers.IO) {
                enrollmentClient.enroll(serialNumber)
            }

            binding.enrollButton.text = getString(R.string.enroll)
            updateEnrollmentButtonState()

            when (result) {
                EnrollmentClient.Result.Success -> {
                    toast(R.string.success_enrolled)
                }

                is EnrollmentClient.Result.HttpError -> {
                    toast(getString(R.string.error_enroll_failed, result.code))
                }

                is EnrollmentClient.Result.NetworkError -> {
                    toast(R.string.error_enroll_network)
                }
            }
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

        viewLifecycleOwner.lifecycleScope.launch {
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
        val network = connectivityManager.activeNetwork ?: return false
        val capabilities = connectivityManager.getNetworkCapabilities(network) ?: return false
        return capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)
    }

    @Suppress("DEPRECATION")
    private fun getCurrentWifiSsid(): String {
        val wifiManager =
            requireContext().applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        val rawSsid = wifiManager.connectionInfo?.ssid ?: return ""
        val ssid = rawSsid.trim('"')
        if (ssid == WifiManager.UNKNOWN_SSID) {
            return ""
        }
        return ssid
    }

    private fun canEnableEnrollment(): Boolean {
        if (savedSerialNumber.isNullOrBlank()) {
            return false
        }
        if (!isConnectedToWifi()) {
            return false
        }
        if (!hasLocationPermission()) {
            return false
        }
        val currentSsid = getCurrentWifiSsid()
        if (currentSsid.isEmpty()) {
            return false
        }
        return !currentSsid.startsWith(IOT_SSID_PREFIX)
    }

    private fun updateEnrollmentButtonState() {
        if (_binding == null) {
            return
        }
        binding.enrollButton.isEnabled = canEnableEnrollment()
    }

    private fun hasLocationPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            requireContext(),
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun toast(messageResId: Int) {
        Toast.makeText(requireContext(), messageResId, Toast.LENGTH_SHORT).show()
    }

    private fun toast(message: String) {
        Toast.makeText(requireContext(), message, Toast.LENGTH_SHORT).show()
    }

    companion object {
        private const val IOT_SSID_PREFIX = "IoT_"
    }
}
