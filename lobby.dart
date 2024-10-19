import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tic_tactics/profile.dart';
import 'vs_ai_screen.dart'; 
import 'localdevice.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class LobbyScreen extends StatefulWidget {
  @override
  _LobbyScreenState createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final _firebase = FirebaseAuth.instance;
  String? _username;
  String? _imageUrl;
  bool _isLoading = false;
  void setupPushNotifications() async {
    final fcm = FirebaseMessaging.instance;

    await fcm.requestPermission();

    //final token = await fcm.getToken();
    //print(token);

    fcm.subscribeToTopic('users');
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
    setupPushNotifications();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    final user = _firebase.currentUser;
    if (user == null) return;

    final userData = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    setState(() {
      _username = userData['username'];
      _imageUrl = userData['image_url'];
      _isLoading = false;
    });
  }

  // Navigate to game mode screens based on selection
  void _navigateToGameMode(String mode) {
    if (mode == 'Online') {
       // Handle Online mode navigation
    } else if (mode == 'VS AI') {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (ctx) => VsAiScreen(), // Navigate to VS AI screen
      ));
    } else if (mode == 'Local Device') {
      // Handle Local Device mode navigation
      Navigator.of(context).push(MaterialPageRoute(
        builder: (ctx) => LocalDeviceGameScreen(),
      ));
    }else if (mode == 'Leaderboard') {
      // Handle Leaderboard navigation
    }
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Theme.of(context).colorScheme.primary, // Match auth screen background
    appBar: AppBar(
  backgroundColor: Theme.of(context).colorScheme.primary,
  title: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      // Profile section with image and username on the left
      if (!_isLoading && _username != null && _imageUrl != null)
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (ctx) => ProfileScreen(),
            ));
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: NetworkImage(_imageUrl!),
              ),
              const SizedBox(width: 8),
              Text(
                _username ?? '',
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
            ],
          ),
        ),

      // "Tic Tactics" title in the center
      Expanded(
        child: Center(
          child: const Text(
            'Tic Tactics',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    ],
  ),
  
  // Actions with add friend and logout icons
  actions: [
    IconButton(
      icon: Icon(Icons.person_add, color: Colors.white),
      onPressed: () {
        // Add friend functionality
      },
    ),
    IconButton(
      onPressed: () {
        FirebaseAuth.instance.signOut(); // Logout functionality
      },
      icon: Icon(
        Icons.exit_to_app,
        color: Colors.white,
      ),
    ),
  ],
),
    body: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: ListView(
            scrollDirection: Axis.vertical, // Allow vertical scrolling
            children: [
              _buildGameModeSquare('Online', const Color.fromARGB(255, 65, 162, 241), const Color.fromARGB(255, 8, 35, 83)),
              _buildGameModeSquare('VS AI', const Color.fromARGB(255, 167, 81, 182), const Color.fromARGB(255, 37, 17, 73)),
              _buildGameModeSquare('Local Device', const Color.fromARGB(255, 99, 173, 101), const Color.fromARGB(255, 2, 67, 61)),
              _buildGameModeSquare('Leaderboard', const Color.fromARGB(255, 241, 104, 94), const Color.fromARGB(255, 86, 3, 3)),
            ],
          ),
        ),
      ],
    ),
  );
}

// Function to build large square buttons with a gradient background
Widget _buildGameModeSquare(String mode, Color startColor, Color endColor) {
  return GestureDetector(
    onTap: () => _navigateToGameMode(mode),
    child: Container(
      margin: const EdgeInsets.all(20),
      width: double.infinity,  // Full-width square to fill the row
      height: 150,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [startColor, endColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.7),
            spreadRadius: 4,
            blurRadius: 15,
            offset: Offset(9, 7), // Shadow position
          ),
        ],
      ),
      child: Center(
        child: Text(
          mode,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}
}
