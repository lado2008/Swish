// classify_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class ClassifyPageWithGoogleAPI extends StatefulWidget {
  const ClassifyPageWithGoogleAPI({super.key});

  @override
  State<ClassifyPageWithGoogleAPI> createState() => _ClassifyPageState();
}

class _ClassifyPageState extends State<ClassifyPageWithGoogleAPI> {
  File? _image;
  final picker = ImagePicker();
  bool _isProcessing = false;

  static const String _visionApiKey = 'AIzaSyBODgeBx4CY_ZshAF67XlGQK6yyqM-64Dc';

  /// Opens the camera to take a picture.
  Future<void> _takePicture() async {
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile == null) return;

    setState(() {
      _image = File(pickedFile.path);
      _isProcessing = true;
    });

    await _runVisionApi(_image!);
  }

  /// Processes the image using the Google Cloud Vision API.
  Future<void> _runVisionApi(File imageFile) async {
    print("✅ Starting Google Vision API call...");

    try {
      final imageBytes = await imageFile.readAsBytes();
      final String base64Image = base64Encode(imageBytes);

      final Uri uri = Uri.parse('https://vision.googleapis.com/v1/images:annotate?key=$_visionApiKey');

      final Map<String, dynamic> requestBody = {
        'requests': [
          {
            'image': {
              'content': base64Image,
            },
            'features': [
              {
                'type': 'LABEL_DETECTION',
                'maxResults': 20,
              }
            ],
          }
        ],
      };

      final http.Response response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic>? labels = responseData['responses'][0]['labelAnnotations'];

        String detectedSpecies = 'Unknown';
        double confidence = 0.0;

        // Log all returned labels
        if (labels != null && labels.isNotEmpty) {
          print('--- All Returned Labels ---');
          for (var label in labels) {
            print('${label['description']} (Confidence: ${label['score'].toStringAsFixed(3)})');
          }
          print('-------------------------');

          // Find the most specific fish-related label
          for (var label in labels) {
            String description = label['description'].toString().toLowerCase();

            // Check for keywords to find a specific species name
            if (description.contains('trout') || description.contains('salmon') || description.contains('bass') || description.contains('carp')) {
              detectedSpecies = description;
              confidence = label['score'];
              break;
            }
          }

          // If no specific species found, fallback to the top label if it's 'fish'
          if (detectedSpecies == 'Unknown' && labels[0]['description'].toString().toLowerCase().contains('fish')) {
            detectedSpecies = labels[0]['description'];
            confidence = labels[0]['score'];
          }
        }

        print("💡 Final Result: $detectedSpecies with confidence of ${confidence.toStringAsFixed(3)}");
        _showFishPopup(detectedSpecies, confidence);

      } else {
        print('❌ Vision API error: ${response.statusCode}');
        print('❌ Response body: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error communicating with the Vision API.')),
        );
      }
    } catch (e) {
      print('❌❌❌ An error occurred: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  /// Displays a popup with the identified fish name and confidence score.
  void _showFishPopup(String fishName, double confidence) {
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
                    fishName,
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
                  // This part is simplified since we don't have the Red Book data anymore.
                  // You can add a placeholder or remove it.
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
                      _saveToDatabase(fishName, confidence, _image!);
                      Navigator.pop(context);
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

  /// Placeholder function to save the fish data to a database.
  void _saveToDatabase(String fishName, double confidence, File image) {
    print('✅ Saved to database: $fishName, confidence: ${confidence.toStringAsFixed(3)}');
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
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
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