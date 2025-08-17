// profile_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:swish_app/welcome_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  List<Map<String, dynamic>>? _fishInfo;

  @override
  void initState() {
    super.initState();
    _loadFishInfo();
  }

  Future<void> _loadFishInfo() async {
    try {
      final fishInfoData = await rootBundle.loadString('assets/fish_info.json');
      final List<dynamic> jsonResult = json.decode(fishInfoData);
      setState(() {
        _fishInfo = jsonResult.cast<Map<String, dynamic>>();
      });
    } catch (e) {
      print('❌ Error loading fish_info.json: $e');
    }
  }

  String _getGeorgianName(String englishName) {
    if (_fishInfo == null) return englishName;
    final fishData = _fishInfo!.firstWhere(
          (fish) => fish['english'] == englishName,
      orElse: () => <String, dynamic>{},
    );
    return fishData['georgian'] ?? englishName;
  }

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const FirstPage()),
          (Route<dynamic> route) => false,
    );
  }

  Future<void> _deleteFish(BuildContext context, String docId, String imageUrl) async {
    try {
      final bool confirmDelete = await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text(
              'წაშლა',
              style: TextStyle(fontFamily: 'BPGNinoMtavruliBold', color: Color(0xFF3F266F)),
            ),
            content: const Text(
              'დარწმუნებული ხართ, რომ გსურთ ამ ფოტოს წაშლა?',
              style: TextStyle(color: Colors.grey),
            ),
            actions: <Widget>[
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFAC81FF),
                ),
                child: const Text('გაუქმება'),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                child: const Text('წაშლა', style: TextStyle(color: Colors.white)),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          );
        },
      ) ?? false;

      if (!confirmDelete) {
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('fishes')
          .doc(docId)
          .delete();

      final storageRef = FirebaseStorage.instance.refFromURL(imageUrl);
      await storageRef.delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ფოტო წარმატებით წაიშალა')),
      );

    } catch (e) {
      print('Error deleting fish: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ფოტოს წაშლა ვერ მოხერხდა: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('User not logged in.'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'პროფილი',
          style: TextStyle(
            color: Color(0xFF3F266F),
            fontFamily: 'BPGNinoMtavruliBold',
          ),
        ),
        backgroundColor: const Color(0xFFE5DDFE),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF3F266F)),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout, color: Color(0xFFAC81FF)),
            label: const Text(
              'გასვლა',
              style: TextStyle(
                color: Color(0xFFAC81FF),
                fontFamily: 'BPGNinoMtavruliBold',
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('User data not found.'));
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final username = userData['username'] ?? 'N/A';
          final email = userData['email'] ?? 'N/A';

          return Container(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                  margin: const EdgeInsets.only(top: 20, left: 20, right: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5DDFE),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFAC81FF).withOpacity(0.5), width: 2), // ბორდერის სისქე
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: const Color(0xFFAC81FF).withOpacity(0.5),
                        child: const Icon(
                          Icons.person,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            username,
                            style: const TextStyle(
                              fontSize: 22,
                              color: Color(0xFF3F266F),
                              fontWeight: FontWeight.bold,
                              fontFamily: 'BPGNinoMtavruliBold',
                            ),
                          ),
                          Text(
                            email,
                            style: TextStyle(
                              fontSize: 14,
                              color: const Color(0xFF3F266F).withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text(
                    'გალერეა',
                    style: TextStyle(
                      fontSize: 24,
                      color: Color(0xFF3F266F),
                      fontFamily: 'BPGNinoMtavruliBold',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('fishes')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, fishSnapshot) {
                      if (fishSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (fishSnapshot.hasError) {
                        return Center(child: Text('Error: ${fishSnapshot.error}'));
                      }
                      if (!fishSnapshot.hasData || fishSnapshot.data!.docs.isEmpty) {
                        return const Center(child: Text('გალერეა ცარიელია.', style: TextStyle(color: Colors.grey)));
                      }

                      final fishDocs = fishSnapshot.data!.docs;

                      return GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5), // padding-ის გაზრდა
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 20, // ინტერვალის გაზრდა
                          mainAxisSpacing: 20, // ინტერვალის გაზრდა
                          childAspectRatio: 0.7, // ზომის გაზრდა (0.8-დან 0.7-მდე)
                        ),
                        itemCount: fishDocs.length,
                        itemBuilder: (context, index) {
                          final doc = fishDocs[index];
                          final fishData = doc.data() as Map<String, dynamic>;
                          final imageUrl = fishData['imageUrl'];
                          final englishName = fishData['englishName'] ?? 'N/A';

                          String georgianName = _getGeorgianName(englishName);

                          return Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(25), // კუთხეების მომრგვალება
                                  border: Border.all(color: const Color(0xFFAC81FF), width: 2), // ლამაზი ბორდერი
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      spreadRadius: 2,
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(22), // შიდა სურათის კუთხეები
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: CachedNetworkImage(
                                          imageUrl: imageUrl,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                                          errorWidget: (context, url, error) => const Icon(Icons.error),
                                        ),
                                      ),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                                        color: Colors.white,
                                        child: Text(
                                          georgianName,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Color(0xFF3F266F),
                                            fontFamily: 'BPGNinoMtavruliBold',
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 10,
                                right: 10,
                                child: GestureDetector(
                                  onTap: () => _deleteFish(context, doc.id, imageUrl),
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.delete,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}