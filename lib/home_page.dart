// home_page.dart - FIXED VERSION (Synchronous Navigation Fix)
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:convert';
import 'dart:async';

import 'package:swish_app/classify_page.dart';
import 'package:swish_app/data_page.dart';
import 'package:swish_app/profile_page.dart';

// BLE UUID-ები
const String SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
const String CHARACTERISTIC_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
const String DEVICE_NAME = "ESP32_AQUASENSE";

// დეფოლტ ლოკაცია
const LatLng _DEFAULT_LOCATION = LatLng(42.0000, 43.0000);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  GoogleMapController? mapController;
  LatLng? _currentPosition;
  Set<Marker> _markers = {};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  late final AnimationController _cameraButtonController;
  late final Animation<double> _cameraButtonScaleAnimation;

  late bool _isKeyboardVisible;

  BluetoothDevice? _esp32Device;

  @override
  void initState() {
    super.initState();
    _getUserLocation();

    _cameraButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _cameraButtonScaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      _cameraButtonController,
    );

    _isKeyboardVisible = false;
    _searchFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() {
      _isKeyboardVisible = _searchFocusNode.hasFocus;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.removeListener(_onFocusChange);
    _searchFocusNode.dispose();
    _cameraButtonController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ModalRoute.of(context)?.isCurrent == true) {
      _loadFishLocations();
    }
  }

  // ********* ლოკაციის მეთოდები (უცვლელია) *********
  Future<void> _getUserLocation() async {
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      setState(() {
        _currentPosition = _DEFAULT_LOCATION;
      });
      _loadFishLocations();
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
    });

    if (mapController != null && _currentPosition != null) {
      mapController!.animateCamera(CameraUpdate.newLatLng(_currentPosition!));
    }

    _loadFishLocations();
  }

  Future<void> _loadFishLocations() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('fishes')
          .get();

      Set<Marker> newMarkers = {};
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final locationString = data['location'] as String? ?? 'Unknown';

        if (locationString == 'Unknown' || !locationString.contains('Lat:')) {
          continue;
        }

        final parts = locationString.split(', ');
        final lat = double.tryParse(parts[0].split(': ')[1]);
        final lng = double.tryParse(parts[1].split(': ')[1]);

        if (lat != null && lng != null) {
          final markerId = MarkerId(doc.id);
          final marker = Marker(
            markerId: markerId,
            position: LatLng(lat, lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            onTap: () {
              _showFishDetailsPopup(data);
            },
          );
          newMarkers.add(marker);
        }
      }

      if (mounted) {
        setState(() {
          _markers = newMarkers;
        });
      }
    } catch (e) {
      print("Error loading fish locations: $e");
    }
  }

  Future<void> _searchLocation() async {
    final String searchText = _searchController.text;
    if (searchText.isEmpty) {
      return;
    }
    _searchFocusNode.unfocus();
    try {
      List<Location> locations = await locationFromAddress(searchText);
      if (locations.isNotEmpty) {
        final firstLocation = locations.first;
        final LatLng newPosition = LatLng(firstLocation.latitude, firstLocation.longitude);
        mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: newPosition, zoom: 14),
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('გადავიდა: ${firstLocation.latitude.toStringAsFixed(4)}, ${firstLocation.longitude.toStringAsFixed(4)}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ლოკაცია ვერ მოიძებნა.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('შეცდომა: $e')),
      );
    }
  }

  void _showFishDetailsPopup(Map<String, dynamic> fishData) {
    String englishName = fishData['englishName'] ?? 'Unknown';
    String imageUrl = fishData['imageUrl'] ?? '';
    Timestamp? timestamp = fishData['timestamp'];
    final formattedDate = timestamp != null
        ? DateFormat('yyyy-MM-dd HH:mm').format(timestamp.toDate())
        : 'N/A';
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                if (imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.network(
                      imageUrl,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(height: 20),
                const Text('თევზის სახეობა', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 5),
                Text(
                  englishName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF3F266F)),
                ),
                const SizedBox(height: 10),
                Text('დათარიღება: $formattedDate', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFAC81FF),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 5,
                  ),
                  child: const Text('დახურვა', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ********* BLE მეთოდები *********

  Future<Map<String, String>> _connectAndReadBLE() async {

    // Check if the device is already connected and active
    if (_esp32Device != null) {
      final state = await _esp32Device!.connectionState.first;
      if (state == BluetoothConnectionState.connected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('BLE: მოწყობილობა უკვე დაკავშირებულია.')),
        );
        // If connected, just read the current characteristic value once
        return await _readInitialData(_esp32Device!);
      }
      // If the state is not connected, clear the device and proceed to scan
      _esp32Device = null;
    }

    // Scanning and Connecting Logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('BLE: ვეძებთ ESP32 მოწყობილობას...')),
    );

    var subscription = FlutterBluePlus.onScanResults.listen((results) {
      for (ScanResult r in results) {
        if (r.device.platformName == DEVICE_NAME) {
          FlutterBluePlus.stopScan();
          _esp32Device = r.device;
          break;
        }
      }
    });

    await FlutterBluePlus.startScan(
        withNames: [DEVICE_NAME],
        timeout: const Duration(seconds: 4)
    );
    await FlutterBluePlus.isScanning.where((val) => val == false).first;
    subscription.cancel();

    if (_esp32Device == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('BLE: მოწყობილობა ვერ მოიძებნა. (შეამოწმეთ ESP32) ')),
      );
      return {};
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('BLE: ნაპოვნია! ვუკავშირდებით ${DEVICE_NAME}')),
      );
      // Attempt connection
      await _esp32Device!.connect();
      await _esp32Device!.connectionState.where((state) => state == BluetoothConnectionState.connected).first;

      // Read initial data from the now connected device
      return await _readInitialData(_esp32Device!);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('BLE: კავშირის/წაკითხვის შეცდომა: $e')),
      );
      // Ensure device is nullified on connection/read error
      _esp32Device = null;
      return {};
    }
  }

  Future<Map<String, String>> _readInitialData(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();

    for (var service in services) {
      if (service.uuid.toString().toLowerCase() == SERVICE_UUID.toLowerCase()) {
        for (var characteristic in service.characteristics) {
          if (characteristic.uuid.toString().toLowerCase() == CHARACTERISTIC_UUID.toLowerCase()) {

            if (characteristic.properties.notify) {
              await characteristic.setNotifyValue(true);

              try {
                // FIX: Use .timeout on the Future from .firstWhere
                final List<int> initialValue = await characteristic.value.firstWhere(
                      (value) => value.isNotEmpty,
                  orElse: () => const <int>[],
                ).timeout(
                    const Duration(seconds: 5),
                    onTimeout: () {
                      // This onTimeout works for Future<List<int>>
                      throw TimeoutException("BLE data read timeout.");
                    }
                );

                if (initialValue.isNotEmpty) {
                  String jsonString = utf8.decode(initialValue);
                  final Map<String, dynamic> jsonData = jsonDecode(jsonString);
                  print("Data received from BLE: $jsonData");
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('BLE: მონაცემები წარმატებით მიღებულია!')),
                  );

                  return {
                    'temp': jsonData['temp']?.toString() ?? 'N/A',
                    'pressure': jsonData['pressure']?.toString() ?? 'N/A',
                    'altitude': jsonData['altitude']?.toString() ?? 'N/A',
                    'tds_value': jsonData['tds_value']?.toString() ?? 'N/A',
                    'hall_voltage': jsonData['hall_voltage']?.toString() ?? 'N/A',
                  };
                }
              } on TimeoutException {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('BLE: მონაცემები ვერ მივიღეთ (Timeout).')),
                );
                return {};
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('JSON გაანალიზების შეცდომა: $e')),
                );
                return {};
              }
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('BLE: Characteristic-ს არ აქვს NOTIFY თვისება!')),
              );
              return {};
            }
          }
        }
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('BLE: სერვისი ან Characteristic-ი ვერ მოიძებნა.')),
    );
    return {};
  }

  Future<void> _disconnectBLE() async {
    if (_esp32Device != null) {
      try {
        await _esp32Device!.disconnect().timeout(const Duration(seconds: 2));
      } catch (e) {
        // Ignore: already disconnected
      }
      _esp32Device = null;
    }
  }

  void _showLocationPopup() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                margin: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/images/pin.png', height: 100),
                    const SizedBox(height: 40),
                    const Text('გსურთ ამ ლოკაციაზე თევზაობის დაწყება?', textAlign: TextAlign.center, style: TextStyle(fontSize: 21, fontFamily: 'BPGNinoMtavruliBold', color: Colors.black87)),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      //
                      // VVV FIX APPLIED HERE VVV
                      //
                      onPressed: () async {
                        // 1. Show a simple loading indicator in a temporary dialog
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const Center(
                            child: CircularProgressIndicator(color: Color(0xFFB794F6)),
                          ),
                        );

                        // 2. Await the BLE process and initial data read
                        Map<String, String> initialData = await _connectAndReadBLE();

                        // 3. Dismiss the temporary loading indicator
                        Navigator.pop(context);

                        // 4. Check for success (device is connected and data is not empty)
                        // Note: _esp32Device is set to null in _connectAndReadBLE on failure.
                        if (_esp32Device != null && initialData.isNotEmpty) {
                          // Success: Dismiss the main popup and navigate
                          Navigator.pop(context);

                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => DataPage(
                              initialData: initialData,
                              device: _esp32Device,
                            )),
                          );
                        } else {
                          // Failure: Just dismiss the main popup (The error SnackBar
                          // from _connectAndReadBLE already informed the user).
                          Navigator.pop(context);
                        }

                      },
                      //
                      // ^^^ END OF FIX ^^^
                      //
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB794F6),
                        padding: const EdgeInsets.symmetric(horizontal: 86, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: const Text('ანალიზი', style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 10,
                right: 0,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.black54),
                  onPressed: () => Navigator.pop(context),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentPosition == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFAC81FF), Color(0xFF9675FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text('მთავარი გვერდი', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
        elevation: 0,
        centerTitle: true,
        actions: const [],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentPosition!,
                zoom: 14,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              onMapCreated: (controller) => mapController = controller,
              onTap: (_) => _showLocationPopup(),
              markers: _markers,
            ),
          ),
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        decoration: const InputDecoration(
                          hintText: 'მოძებნე ლოკაცია',
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onSubmitted: (value) => _searchLocation(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search, color: Color(0xFFAC81FF)),
                    onPressed: _searchLocation,
                  ),
                ],
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            bottom: _isKeyboardVisible ? -100 : 20,
            left: 15,
            right: 15,
            child: AnimatedOpacity(
              opacity: _isKeyboardVisible ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: SafeArea(
                top: false,
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF363636),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.home_outlined, color: Colors.white, size: 30),
                        onPressed: () {},
                      ),
                      ScaleTransition(
                        scale: _cameraButtonScaleAnimation,
                        child: GestureDetector(
                          onTapDown: (_) => _cameraButtonController.forward(),
                          onTapUp: (_) => _cameraButtonController.reverse(),
                          onTapCancel: () => _cameraButtonController.reverse(),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ClassifyPage()),
                            );
                            _loadFishLocations();
                          },
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.camera_alt, color: Color(0xFFAC81FF), size: 35),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.person_outline, color: Colors.white, size: 30),
                        onPressed: () {
                          Navigator.push(context,
                            MaterialPageRoute(builder: (context) => const ProfilePage()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}