import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  late CameraController _cameraController;
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.first;

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _cameraController.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } on CameraException catch (e) {
      print("Camera Error: ${e.description}");
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  void _showFishPopup() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fish Info',
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(animation),
          child: child,
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return Scaffold(
          backgroundColor: Colors.black.withOpacity(0.5),
          body: Stack(
            children: [
              Container(
                width: double.infinity,
                height: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 35),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(0),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60), // spacing below close icon
                    Image.asset(
                      'assets/images/logo.png',
                      height: 80,
                    ),
                    const SizedBox(height: 50),
                    const Text(
                      'თევზის სახეობა:',
                      style: TextStyle(
                        color: Color(0xFF3F266F),
                        fontSize: 28,
                        fontFamily: 'BPGNinoMtavruliBold',
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'ქართული კალმახი',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFAC81FF),
                        fontFamily: 'BPGNinoMtavruliBold',
                      ),
                    ),
                    const SizedBox(height: 60),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 16),
                      child: const Text(
                        'მოცემული თევზი იმყოფება წითელ წიგნში',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontFamily: 'BPGNinoMtavruliBold',
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                    OutlinedButton(
                      onPressed: () {
                        print('Save pressed');
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFAC81FF)),
                        padding: const EdgeInsets.symmetric(horizontal: 75, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text(
                        'დაამატე გალერეაში',
                        style: TextStyle(
                          color: Color(0xFFAC81FF),
                          fontSize: 16,
                          fontFamily: 'BPGNinoMtavruliBold',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 20,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.black87, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _isCameraInitialized
              ? SizedBox.expand(child: CameraPreview(_cameraController))
              : const Center(child: CircularProgressIndicator()),

          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 80),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildCircleButton(
                      icon: Icons.flash_off,
                      onTap: () => print('Flash button pressed'),
                    ),
                    _buildCircleButton(
                      icon: Icons.camera_alt,
                      large: true,
                      onTap: _showFishPopup,
                    ),
                    _buildCircleButton(
                      icon: Icons.flip_camera_ios,
                      onTap: _switchCamera,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _switchCamera() async {
    final cameras = await availableCameras();
    CameraDescription newCamera;

    if (_cameraController.description.lensDirection == CameraLensDirection.front) {
      newCamera = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back);
    } else {
      newCamera = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front);
    }

    await _cameraController.dispose();
    _cameraController = CameraController(newCamera, ResolutionPreset.high, enableAudio: false);
    await _cameraController.initialize();
    setState(() {});
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    bool large = false,
  }) {
    return Container(
      width: large ? 80 : 60,
      height: large ? 80 : 60,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        shape: BoxShape.circle,
        border: large ? Border.all(color: Colors.white, width: 3) : null,
      ),
      child: IconButton(
        icon: Icon(icon, size: large ? 40 : 30, color: Colors.black87),
        onPressed: onTap,
      ),
    );
  }
}
