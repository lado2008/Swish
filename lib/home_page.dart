// home_page.dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:swish_app/classify_page.dart';
import 'package:swish_app/data_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:swish_app/welcome_page.dart';
import 'package:swish_app/profile_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:geocoding/geocoding.dart';

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
  final FocusNode _searchFocusNode = FocusNode(); // Add FocusNode

  late final AnimationController _cameraButtonController;
  late final Animation<double> _cameraButtonScaleAnimation;

  // Add a listener to handle keyboard visibility
  late bool _isKeyboardVisible;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    _cameraButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _cameraButtonScaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _cameraButtonController,
        curve: Curves.easeOut,
      ),
    );

    // Add listener to the FocusNode to detect keyboard visibility
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
    _searchFocusNode.removeListener(_onFocusChange); // Remove the listener
    _searchFocusNode.dispose(); // Dispose the FocusNode
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

  Future<void> _getUserLocation() async {
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
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

    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('fishes')
        .get();

    Set<Marker> newMarkers = {};
    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      final locationString = data['location'] as String;

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

    setState(() {
      _markers = newMarkers;
    });
  }

  Future<void> _searchLocation() async {
    final String searchText = _searchController.text;
    if (searchText.isEmpty) {
      return;
    }

    // Unfocus the TextField to hide the keyboard
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
                const Text(
                  'თევზის სახეობა',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  englishName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3F266F),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'დათარიღება: $formattedDate',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFAC81FF),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 5,
                  ),
                  child: const Text(
                    'დახურვა',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
                    Image.asset(
                      'assets/images/pin.png',
                      height: 100,
                    ),
                    const SizedBox(height: 40),
                    const Text(
                      'გსურთ ამ ლოკაციაზე თევზაობის დაწყება?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 21,
                        fontFamily: 'BPGNinoMtavruliBold',
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const DataPage()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB794F6),
                        padding: const EdgeInsets.symmetric(horizontal: 86, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text(
                        'ანალიზი',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
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
        title: const Text(
          'მთავარი გვერდი',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        elevation: 0,
        centerTitle: true,
        actions: const [],
      ),
      body: _currentPosition == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
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
                        focusNode: _searchFocusNode, // Connect the FocusNode
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
                            child: const Icon(
                              Icons.camera_alt,
                              color: Color(0xFFAC81FF),
                              size: 35,
                            ),
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