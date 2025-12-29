// data_page.dart - STABLE VERSION with Fishing Probability Analysis
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:convert';
import 'dart:async';

import 'camera.dart';

// BLE UUID-ები
const String SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
const String CHARACTERISTIC_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

class DataPage extends StatefulWidget {
  final Map<String, String> initialData;
  final BluetoothDevice? device;

  const DataPage({super.key, required this.initialData, this.device});

  @override
  State<DataPage> createState() => _DataPageState();
}

class _DataPageState extends State<DataPage> {
  late Map<String, String> _data;
  int _fishingProbability = 0; // State variable for the calculated probability

  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  StreamSubscription<List<int>>? _dataSubscription;

  LatLng _DEFAULT_LOCATION = LatLng(42.0000, 43.0000);

  @override
  void initState() {
    super.initState();
    // INITIALIZATION FIX: Ensure all keys exist with safe defaults
    _data = {
      'temp': widget.initialData['temp'] ?? 'N/A',
      'pressure': widget.initialData['pressure'] ?? 'N/A',
      'altitude': widget.initialData['altitude'] ?? 'N/A',
      'tds_value': widget.initialData['tds_value'] ?? 'N/A',
      'hall_voltage': widget.initialData['hall_voltage'] ?? 'N/A',
    };
    // Calculate initial probability
    _fishingProbability = _calculateFishingProbability(_data);

    _getUserLocation();
    _subscribeToBLEData();
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    super.dispose();
  }

  // ********* FISHING ANALYSIS SYSTEM *********

  int _calculateFishingProbability(Map<String, String> data) {
    int score = 0;
    const int maxScore = 5;

    final temp = double.tryParse(data['temp'] ?? '');
    if (temp != null && temp >= 18.0 && temp <= 24.0) {
      score++;
    }

    final pressure = double.tryParse(data['pressure'] ?? '');
    if (pressure != null && pressure >= 99.0 && pressure <= 103.0) {
      score++;
    }

    final altitude = double.tryParse(data['altitude'] ?? '');
    if (altitude != null && altitude >= -100.0 && altitude <= 3000.0) {
      score++;
    }

    final tds = double.tryParse(data['tds_value'] ?? '');
    if (tds != null && tds >= 0 && tds <= 300.0) {
      score++;
    }

    final hallVoltage = double.tryParse(data['hall_voltage'] ?? '');
    if (hallVoltage != null && hallVoltage >= 0.1 && hallVoltage <= 3.0) {
      score++;
    }

    final probability = (score / maxScore) * 100;

    return probability.round().clamp(0, 100);
  }

  Future<void> _subscribeToBLEData() async {
    if (widget.device == null) return;

    try {
      List<BluetoothService> services = await widget.device!.discoverServices();

      for (var service in services) {
        if (service.uuid.toString().toLowerCase() == SERVICE_UUID.toLowerCase()) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() == CHARACTERISTIC_UUID.toLowerCase()) {

              if (characteristic.properties.notify) {
                await characteristic.setNotifyValue(true);
              } else {
                print('Characteristic does not support Notify!');
                return;
              }

              // Set up the listener for continuous updates
              _dataSubscription = characteristic.value.listen(
                    (List<int> value) {
                  if (value.isNotEmpty) {
                    String jsonString = utf8.decode(value);
                    try {
                      final Map<String, dynamic> jsonData = jsonDecode(jsonString);

                      if (mounted) {
                        setState(() {
                          // Update raw data
                          _data = {
                            'temp': (jsonData['temp'] as num?)?.toString() ?? 'N/A',
                            'pressure': (jsonData['pressure'] as num?)?.toString() ?? 'N/A',
                            'altitude': (jsonData['altitude'] as num?)?.toString() ?? 'N/A',
                            'tds_value': jsonData['tds_value']?.toString() ?? 'N/A',
                            'hall_voltage': (jsonData['hall_voltage'] as num?)?.toString() ?? 'N/A',
                          };
                          // Recalculate and update probability state
                          _fishingProbability = _calculateFishingProbability(_data);
                        });
                      }
                    } catch (e) {
                      print('JSON Decode Error in DataPage: $e');
                    }
                  }
                },
                onError: (e) => print("BLE Stream Error: $e"),
                onDone: () => print("BLE Stream Done"),
              );
              return;
            }
          }
        }
      }
    } catch (e) {
      print('BLE Subscription Error: $e');
    }
  }

  Future<void> _getUserLocation() async {
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          _currentPosition = _DEFAULT_LOCATION;
        });
      }
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    if (mounted) {
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
    }

    _mapController?.animateCamera(CameraUpdate.newLatLng(_currentPosition!));
  }

  String _formatValue(String? value, {int decimalPlaces = 2}) {
    if (value == null || value == 'N/A') return 'N/A';

    final number = double.tryParse(value);

    if (number == null) return 'N/A';

    if (decimalPlaces == 0) return number.round().toString();

    return number.toStringAsFixed(decimalPlaces);
  }

  /// Helper widget to display the probability gauge
  Widget _buildProbabilityGauge(int probability) {
    Color color;
    String recommendation;

    if (probability >= 70) {
      color = Colors.green.shade600;
      recommendation = 'ძალიან კარგი';
    } else if (probability >= 40) {
      color = Colors.orange.shade600;
      recommendation = 'საშუალო';
    } else {
      color = Colors.red.shade600;
      recommendation = 'დაბალი';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20, top: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'თევზაობის ალბათობა:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                recommendation,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: color,
                  fontFamily: 'BPGNinoMtavruliBold',
                ),
              ),
            ],
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  value: probability / 100,
                  strokeWidth: 6,
                  backgroundColor: color.withOpacity(0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              Text(
                '$probability%',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    final displayData = {
      'ტემპერატურა (°C)': '${_formatValue(_data['temp'], decimalPlaces: 2)} °C',
      'ატმოსფერული წნევა (kPa)': '${_formatValue(_data['pressure'], decimalPlaces: 3)} kPa',
      'სიმაღლე (მ)': '${_formatValue(_data['altitude'], decimalPlaces: 2)} მ',
      'TDS (ppm)': '${_formatValue(_data['tds_value'], decimalPlaces: 0)} ppm',
      'Hall სენსორის ძაბვა (V)': '${_formatValue(_data['hall_voltage'], decimalPlaces: 3)} V',
    };

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('სენსორის მონაცემები', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE5DDFE), Color(0xFF9675FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 300,
              child: GoogleMap(
                onMapCreated: (controller) => _mapController = controller,
                initialCameraPosition: CameraPosition(
                  target: _currentPosition ?? _DEFAULT_LOCATION,
                  zoom: 14.0,
                ),
                myLocationEnabled: true,
                zoomControlsEnabled: false,
                markers: _currentPosition != null ? {
                  Marker(
                    markerId: const MarkerId('current_location'),
                    position: _currentPosition!,
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                  ),
                } : {},
              ),
            ),
            Positioned.fill(
              top: 250,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                padding: const EdgeInsets.only(top: 30, left: 30, right: 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // New probability gauge at the top of the data list
                    _buildProbabilityGauge(_fishingProbability),

                    const Text('მიმდინარე მონაცემები:', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFFAC81FF))),
                    const Divider(color: Color(0xFFAC81FF), thickness: 2, height: 20),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: displayData.entries.map((entry) {
                          return _buildDataRow(_getIconForLabel(entry.key), entry.key, entry.value);
                        }).toList(),
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 20.0, top: 10),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const CameraPage()));
                          },
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: const Color(0xFF9675FF),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 30),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForLabel(String label) {
    if (label.contains('ტემპერატურა')) return Icons.thermostat;
    if (label.contains('წნევა')) return Icons.speed;
    if (label.contains('სიმაღლე')) return Icons.terrain;
    if (label.contains('TDS')) return Icons.water_drop;
    if (label.contains('Hall')) return Icons.electric_bolt;
    return Icons.info_outline;
  }

  Widget _buildDataRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFAC81FF), size: 28),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                fontFamily: 'BPGNinoMtavruliBold',
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              fontFamily: 'BPGNinoMtavruliBold',
            ),
          ),
        ],
      ),
    );
  }
}
