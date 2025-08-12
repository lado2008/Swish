import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import 'camera.dart';
import 'home_page.dart';

class DataPage extends StatefulWidget {
  const DataPage({super.key});

  @override
  State<DataPage> createState() => _DataPageState();
}

class _DataPageState extends State<DataPage> {
  final Map<String, String> _data = {
    'ტემპერატურა': '21',
    'მჟავიანობა': '7.5',
    'ატმოსფერული წნევა': '12',
    'წყლის წნევა': '2.3',
  };

  GoogleMapController? _mapController;
  LatLng? _currentPosition;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
    });

    _mapController?.animateCamera(CameraUpdate.newLatLng(_currentPosition!));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE5DDFE), Color(0xFF9675FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: kToolbarHeight + 40),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Color(0xFFAC81FF),
                      width: 3,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildDataRow(Icons.thermostat, 'ტემპერატურა', _data['ტემპერატურა']!),
                      _buildDataRow(Icons.science_outlined, 'მჟავიანობა', _data['მჟავიანობა']!),
                      _buildDataRow(Icons.air, 'ატმოსფერული წნევა', _data['ატმოსფერული წნევა']!),
                      _buildDataRow(Icons.waves, 'წყლის წნევა', _data['წყლის წნევა']!),
                      const SizedBox(height: 20),
                      const Text(
                        'თევზის დაჭერის ალბათობა',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'BPGNinoMtavruliBold',
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '70%',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'BPGNinoMtavruliBold',
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: _currentPosition == null
                              ? const Center(child: CircularProgressIndicator())
                              : GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: _currentPosition!,
                              zoom: 14,
                            ),
                            myLocationEnabled: true,
                            myLocationButtonEnabled: false,
                            zoomControlsEnabled: false,
                            onMapCreated: (controller) {
                              _mapController = controller;
                              _mapController?.animateCamera(CameraUpdate.newLatLng(_currentPosition!));
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SafeArea(
              top: false,
              child: Container(
                height: 90,
                decoration: const BoxDecoration(
                  color: Color(0xFF363636),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.home_outlined, color: Colors.white),
                            onPressed: () {
                              Navigator.push(context,
                                MaterialPageRoute(builder: (context) => const HomePage()),
                              );
                            },
                          ),
                          const SizedBox(width: 70),
                          IconButton(
                            icon: const Icon(Icons.person_outline, color: Colors.white),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: 15,
                      child: GestureDetector(
                        onTap: () {
                          // Navigator.push(
                          //     context,
                          //     MaterialPageRoute(builder: (context) => const CameraPage())
                          // );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Color(0xFFAC81FF),
                            size: 30,
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

  Widget _buildDataRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Color(0xFFAC81FF), size: 28),
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
