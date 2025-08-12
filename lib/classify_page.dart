// classify_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'dart:math';

class ClassifyPage extends StatefulWidget {
  const ClassifyPage({super.key});

  @override
  State<ClassifyPage> createState() => _ClassifyPageState();
}

class _ClassifyPageState extends State<ClassifyPage> {
  File? _image;
  final picker = ImagePicker();
  bool _isProcessing = false;

  Interpreter? _interpreter;
  List<String>? _labels;
  List<Map<String, dynamic>>? _fishInfo;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }

  /// Loads the TFLite model and labels from assets.
  /// Loads the TFLite model and labels from assets.
  Future<void> _loadModel() async {
    try {
      // Using the unquantized model as requested.
      _interpreter = await Interpreter.fromAsset('assets/model/model_unquant.tflite');

      final labelsData = await rootBundle.loadString('assets/model/labels.txt');
      final labels = labelsData.split('\n');

      final fishInfoData = await rootBundle.loadString('assets/fish_info.json');
      final List<dynamic> jsonResult = json.decode(fishInfoData);
      _fishInfo = jsonResult.cast<Map<String, dynamic>>();

      setState(() {
        _labels = labels;
      });
      print('✅ model_unquant.tflite and labels loaded successfully');
    } catch (e) {
      print('❌ Error loading model: $e');
    }
  }

  /// Opens the camera to take a picture.
  Future<void> _takePicture() async {
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile == null) {
      return; // User canceled the camera
    }

    setState(() {
      _image = File(pickedFile.path);
      _isProcessing = true;
    });

    await _runModelOnImage(_image!);
  }

  /// Processes the image and runs the TFLite model.
  Future<void> _runModelOnImage(File imageFile) async {
    if (_interpreter == null || _labels == null) {
      print('❌ Model or labels not loaded yet.');
      return;
    }

    try {
      print("✅ Starting model run...");

      final imageBytes = await imageFile.readAsBytes();
      img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) return;

      print("⚙️ Preprocessing image...");
      img.Image resizedImage = img.copyResize(originalImage, width: 224, height: 224);

      var input = List.generate(1, (i) => List.generate(224, (j) => List.generate(224, (k) => [0.0, 0.0, 0.0])));
      for (var y = 0; y < 224; y++) {
        for (var x = 0; x < 224; x++) {
          var pixel = resizedImage.getPixel(x, y);
          input[0][y][x][0] = pixel.r / 255.0;
          input[0][y][x][1] = pixel.g / 255.0;
          input[0][y][x][2] = pixel.b / 255.0;
        }
      }

      int newClassCount = 21;
      var output = List.filled(1 * newClassCount, 0.0).reshape([1, newClassCount]);

      print("⚙️ Running inference...");
      _interpreter!.run(input, output);
      print("✅ Inference complete.");

      List<double> outputList = output[0];
      double maxScore = outputList.reduce(max);
      int predictedIndex = outputList.indexOf(maxScore);

      // Improvement: Safer way to parse labels
      String rawLabel = _labels![predictedIndex];
      String prediction = rawLabel.replaceAll(RegExp(r'^\d+\s'), ''); // Removes leading numbers and a space

      print("💡 Result: $prediction with confidence of ${maxScore.toStringAsFixed(3)}");

      setState(() {
        _isProcessing = false;
      });

      // Improvement: Pass the confidence score to the popup
      _showFishPopup(prediction, maxScore);

    } catch (e) {
      print("❌❌❌ An error occurred: $e");
      setState(() {
        _isProcessing = false;
      });
    }
  }

  /// Displays a popup with the identified fish name and confidence score.
  void _showFishPopup(String englishFishName, double confidence) {
    String georgianFishName = englishFishName; // Default to English if not found
    bool isInRedBook = false;

    if (_fishInfo != null) {
      final fishData = _fishInfo!.firstWhere(
            (fish) => fish['english'] == englishFishName,
        orElse: () => <String, dynamic>{}, // Return an empty map if not found
      );

      if (fishData.isNotEmpty) {
        georgianFishName = fishData['georgian'] ?? englishFishName;
        isInRedBook = fishData['in_red_book'] ?? false;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.8,
          builder: (_, controller) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: ListView(
                controller: controller,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Image.asset(
                    'assets/images/logo.png',
                    height: 80,
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'თევზის სახეობა:',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF3F266F),
                      fontSize: 28,
                      fontFamily: 'BPGNinoMtavruliBold',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    georgianFishName, // Display Georgian name
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFAC81FF),
                      fontFamily: 'BPGNinoMtavruliBold',
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    'Confidence: ${(confidence * 100).toStringAsFixed(1)}%',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 25),
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
            );
          },
        );
      },
    ).whenComplete(() {
      setState(() {
        _image = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('თევზის იდენტიფიკაცია'),
        backgroundColor: const Color(0xFFE5DDFE),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE5DDFE), Color(0xFF9675FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_image == null)
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  'დააჭირეთ კამერის ღილაკს სურათის გადასაღებად',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, color: Colors.white),
                ),
              )
            else
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.file(_image!,
                        width: 300, height: 300, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 20),
                  if (_isProcessing)
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(width: 15),
                        Text(
                          'მიმდინარეობს ანალიზი...',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        )
                      ],
                    )
                ],
              ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 80.0),
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _takePicture,
                icon: const Icon(Icons.camera_alt, size: 30),
                label: const Text('სურათის გადაღება', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9675FF),
                  foregroundColor: Colors.white,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}