package com.vswitch.configure

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Toast
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import com.google.android.material.button.MaterialButton
import com.vswitch.configure.databinding.FragmentLocalCommandsBinding
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class LocalCommandsFragment : Fragment() {

    private var _binding: FragmentLocalCommandsBinding? = null
    private val binding get() = _binding!!

    private lateinit var devicePreferences: DevicePreferences
    private val switchClient = SwitchClient()
    private var savedSerialNumber: String? = null
    private var switchRequestInFlight = false

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentLocalCommandsBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        devicePreferences = DevicePreferences(requireContext().applicationContext)

        viewLifecycleOwner.lifecycleScope.launch {
            devicePreferences.serialNumber.collect { serial ->
                savedSerialNumber = serial
            }
        }

        bindSwitchButton(binding.turnOnSwitch1Button, switchNumber = 1, turnOn = true)
        bindSwitchButton(binding.turnOffSwitch1Button, switchNumber = 1, turnOn = false)
        bindSwitchButton(binding.turnOnSwitch2Button, switchNumber = 2, turnOn = true)
        bindSwitchButton(binding.turnOffSwitch2Button, switchNumber = 2, turnOn = false)
        bindSwitchButton(binding.turnOnSwitch3Button, switchNumber = 3, turnOn = true)
        bindSwitchButton(binding.turnOffSwitch3Button, switchNumber = 3, turnOn = false)
        bindSwitchButton(binding.turnOnSwitch4Button, switchNumber = 4, turnOn = true)
        bindSwitchButton(binding.turnOffSwitch4Button, switchNumber = 4, turnOn = false)
    }

    private fun bindSwitchButton(button: MaterialButton, switchNumber: Int, turnOn: Boolean) {
        button.setOnClickListener {
            onSwitchCommand(switchNumber, turnOn)
        }
    }

    private fun onSwitchCommand(switchNumber: Int, turnOn: Boolean) {
        if (switchRequestInFlight) {
            return
        }

        val serialNumber = savedSerialNumber?.trim().orEmpty()
        if (serialNumber.isEmpty()) {
            toast(R.string.error_no_serial_for_switch)
            return
        }

        switchRequestInFlight = true
        setSwitchButtonsEnabled(false)

        viewLifecycleOwner.lifecycleScope.launch {
            val result = withContext(Dispatchers.IO) {
                switchClient.setSwitchState(
                    deviceSerialNumber = serialNumber,
                    switchNumber = switchNumber,
                    turnOn = turnOn
                )
            }

            switchRequestInFlight = false
            setSwitchButtonsEnabled(true)

            when (result) {
                SwitchClient.Result.Success -> {
                    if (turnOn) {
                        toast(getString(R.string.success_switch_on, switchNumber))
                    } else {
                        toast(getString(R.string.success_switch_off, switchNumber))
                    }
                }

                is SwitchClient.Result.HttpError -> {
                    toast(getString(R.string.error_switch_failed, result.code))
                }

                is SwitchClient.Result.NetworkError -> {
                    toast(R.string.error_switch_network)
                }
            }
        }
    }

    private fun setSwitchButtonsEnabled(enabled: Boolean) {
        if (_binding == null) {
            return
        }

        binding.turnOnSwitch1Button.isEnabled = enabled
        binding.turnOffSwitch1Button.isEnabled = enabled
        binding.turnOnSwitch2Button.isEnabled = enabled
        binding.turnOffSwitch2Button.isEnabled = enabled
        binding.turnOnSwitch3Button.isEnabled = enabled
        binding.turnOffSwitch3Button.isEnabled = enabled
        binding.turnOnSwitch4Button.isEnabled = enabled
        binding.turnOffSwitch4Button.isEnabled = enabled
    }

    private fun toast(messageResId: Int) {
        Toast.makeText(requireContext(), messageResId, Toast.LENGTH_SHORT).show()
    }

    private fun toast(message: String) {
        Toast.makeText(requireContext(), message, Toast.LENGTH_SHORT).show()
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
