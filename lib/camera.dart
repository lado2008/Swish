import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'dart:math';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  late CameraController _cameraController;
  bool _isCameraInitialized = false;

  // AI Model Variables
  Interpreter? _interpreter;
  List<String>? _labels;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Initializes the camera
    _initializeCamera();
    // Loads the TFLite model and labels
    _loadModel();
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _interpreter?.close(); // Important: release the model resources
    super.dispose();
  }

  /// Initializes the camera controller.
  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    // Using the back camera by default
    final backCamera = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first);

    _cameraController = CameraController(
      backCamera,
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

  /// Loads the TFLite model and labels from assets.
  Future<void> _loadModel() async {
    try {
      // Load the model
      _interpreter = await Interpreter.fromAsset('assets/model/model_unquant.tflite');
      // Load the labels
      final labelsData = await rootBundle.loadString('assets/model/labels.txt');

      // Split labels by newline
      final labels = labelsData.split('\n');

      setState(() {
        _labels = labels;
      });
      print('✅ Model and labels loaded successfully');
    } catch (e) {
      print('❌ Error loading model: $e');
    }
  }

  /// Takes a picture, processes it, and runs the prediction.
  Future<void> _takePictureAndPredict() async {
    if (!_isCameraInitialized || _isProcessing || _interpreter == null || _labels == null) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    final XFile imageFile = await _cameraController.takePicture();

    // Preprocess the image
    final imageBytes = await imageFile.readAsBytes();
    img.Image? originalImage = img.decodeImage(imageBytes);
    if (originalImage == null) {
      setState(() => _isProcessing = false);
      return;
    }

    // Teachable Machine models expect 224x224 input
    img.Image resizedImage = img.copyResize(originalImage, width: 224, height: 224);

    // Convert image to a 4D list of [1, 224, 224, 3] and normalize pixel values
    var input = List.generate(1, (i) => List.generate(224, (j) => List.generate(224, (k) => [0.0, 0.0, 0.0])));

    //
    // ▼▼▼ THIS IS THE CORRECTED PART ▼▼▼
    //
    for (var y = 0; y < 224; y++) {
      for (var x = 0; x < 224; x++) {
        var pixel = resizedImage.getPixel(x, y);
        input[0][y][x][0] = pixel.r / 255.0;
        input[0][y][x][1] = pixel.g / 255.0;
        input[0][y][x][2] = pixel.b / 255.0;
      }
    }
    // ▲▲▲ END OF CORRECTION ▲▲▲
    //

    // Define the output tensor shape [1, 25] for your 25 fish classes
    var output = List.filled(1 * 25, 0.0).reshape([1, 25]);

    // Run inference
    _interpreter!.run(input, output);

    // Process the output to find the predicted class
    List<double> outputList = output[0];
    double maxScore = outputList.reduce(max);
    int predictedIndex = outputList.indexOf(maxScore);

    // Get the label. We use substring(2) to remove "0 ", "1 ", etc., from Teachable Machine labels.
    String prediction = _labels![predictedIndex].substring(2);

    setState(() {
      _isProcessing = false;
    });

    // Show the result in a popup
    _showFishPopup(prediction);
  }

  /// Displays a popup with the identified fish name.
  void _showFishPopup(String fishName) {
    // Note: The "Red Book" logic here is hardcoded. You can expand this.
    bool isInRedBook = fishName == 'ქართული კალმახი';

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
          backgroundColor: Colors.transparent, // Allows the background to be dimmed
          body: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              height: MediaQuery.of(context).size.height * 0.8, // Adjust height as needed
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 35),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // This is a handle for the bottom sheet
                  Container(
                    width: 50,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 40),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
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
                  Text(
                    fishName, // <-- DYNAMIC FISH NAME
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFAC81FF),
                      fontFamily: 'BPGNinoMtavruliBold',
                    ),
                  ),
                  const Spacer(),
                  if (isInRedBook)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                  const SizedBox(height: 20),
                ],
              ),
            ),
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
          // Show camera preview if initialized, otherwise a loading indicator
          _isCameraInitialized
              ? SizedBox.expand(child: CameraPreview(_cameraController))
              : const Center(child: CircularProgressIndicator()),

          // Show a processing indicator
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),

          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 30), // Adjusted padding
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'დააფიქსირე თევზი კადრში',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Main button row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildCircleButton(
                          icon: Icons.flash_off,
                          onTap: () => print('Flash button pressed'),
                        ),
                        // This button now calls the prediction function
                        _buildCircleButton(
                          icon: Icons.camera_alt,
                          large: true,
                          onTap: _takePictureAndPredict, // <-- UPDATED ACTION
                        ),
                        _buildCircleButton(
                          icon: Icons.flip_camera_ios,
                          onTap: _switchCamera,
                        ),
                      ],
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

  /// Switches between front and back cameras.
  Future<void> _switchCamera() async {
    final cameras = await availableCameras();
    CameraDescription newCamera;

    if (_cameraController.description.lensDirection == CameraLensDirection.front) {
      newCamera = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cameras.first);
    } else {
      newCamera = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => cameras.last);
    }

    await _cameraController.dispose();
    _cameraController = CameraController(newCamera, ResolutionPreset.high, enableAudio: false);
    await _cameraController.initialize();
    if(mounted) setState(() {});
  }

  /// Helper widget for creating circular buttons.
  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    bool large = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: large ? 80 : 60,
        height: large ? 80 : 60,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.3),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: large ? 3 : 2),
        ),
        child: Icon(icon, size: large ? 40 : 28, color: Colors.white),
      ),
    );
  }
}