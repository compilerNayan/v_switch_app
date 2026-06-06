package com.vswitch.configure

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import com.google.android.material.button.MaterialButton
import com.vswitch.configure.databinding.FragmentLocalCommandsBinding

class LocalCommandsFragment : Fragment() {

    private var _binding: FragmentLocalCommandsBinding? = null
    private val binding get() = _binding!!

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
        // API wiring will be added next.
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
