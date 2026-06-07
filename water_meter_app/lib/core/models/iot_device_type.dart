import 'package:flutter/material.dart';

class IoTDeviceType {
  const IoTDeviceType({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    this.isSupported = false,
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;
  final bool isSupported;

  static const List<IoTDeviceType> catalog = [
    IoTDeviceType(
      id: 'switch',
      name: 'Switch',
      description: 'Control lights and appliances',
      icon: Icons.toggle_on_outlined,
    ),
    IoTDeviceType(
      id: 'smart_plug',
      name: 'Smart Plug',
      description: 'Monitor and control power outlets',
      icon: Icons.power_outlined,
    ),
    IoTDeviceType(
      id: 'robot',
      name: 'Robot',
      description: 'Vacuum and service robots',
      icon: Icons.smart_toy_outlined,
    ),
    IoTDeviceType(
      id: 'water_meter',
      name: 'Water Meter',
      description: 'Track water usage and flow',
      icon: Icons.water_drop_outlined,
      isSupported: true,
    ),
    IoTDeviceType(
      id: 'light',
      name: 'Light',
      description: 'Smart bulbs and lighting',
      icon: Icons.lightbulb_outline,
    ),
    IoTDeviceType(
      id: 'thermostat',
      name: 'Thermostat',
      description: 'Climate and temperature control',
      icon: Icons.thermostat_outlined,
    ),
    IoTDeviceType(
      id: 'camera',
      name: 'Camera',
      description: 'Security and monitoring cameras',
      icon: Icons.videocam_outlined,
    ),
    IoTDeviceType(
      id: 'door_lock',
      name: 'Door Lock',
      description: 'Smart locks and access control',
      icon: Icons.lock_outlined,
    ),
    IoTDeviceType(
      id: 'sensor',
      name: 'Sensor',
      description: 'Motion, temperature, and more',
      icon: Icons.sensors_outlined,
    ),
    IoTDeviceType(
      id: 'hub',
      name: 'Hub',
      description: 'Central gateway for devices',
      icon: Icons.router_outlined,
    ),
  ];
}
