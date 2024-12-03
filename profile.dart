mport 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tic_tactics/auth.dart';


class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _firebase = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  

  String? _username;
  String? _email;
  String? _imageUrl;
  int? _gamesPlayed;
  int? _winGames;
  int? _loseGames;
  double? _winLossRatio;
  int? _score;
  int? _highestScore;
  int? _globalRank;
  int? _friendsRank;
  List<String> _lastFiveGames = [];
  bool _isLoading = false;
  File? _pickedImageFile;

  @override
  void initState() {
    super.initState();
    _loadUserData();
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
      _email = userData['email'];
      _imageUrl = userData['image_url'];
      _gamesPlayed = userData['gamesPlayed'];
      _winGames = userData['winGames'];
      _loseGames = userData['loseGames'];
      _score = userData['score'];
      _highestScore = userData['highestScore'];
      _winLossRatio = (_winGames != null && _loseGames != null && _loseGames! > 0)
          ? (_winGames! / _loseGames!)
          : 0.0;
          _lastFiveGames = List<String>.from(userData['lastFiveGames'] ?? []);
    });

    await _loadLeaderboardRanks();
    setState(() {
      _isLoading = false;
    });
  }
  Future<void> _loadLeaderboardRanks() async {
  final user = _firebase.currentUser;
  if (user == null) return;

  try {
    // Fetch global leaderboard
    final globalLeaderboard = await _firestore
        .collection('users')
        .orderBy('score', descending: true)
        .get();

    final userSnapshot = await _firestore.collection('users').doc(user.uid).get();

    // Retrieve friend IDs from user's document
    List<String> friendIds = List<String>.from(userSnapshot.data()?['friends'] ?? []);
    print("Friend IDs: $friendIds");

    // Add current user's ID to the friends list for ranking purposes if not already there
    if (!friendIds.contains(user.uid)) {
      friendIds.add(user.uid);
    }

    if (friendIds.isNotEmpty) {
      List<QueryDocumentSnapshot> allFriendDocs = [];

      // Firestore whereIn limit of 10 workaround
      for (var i = 0; i < friendIds.length; i += 10) {
        var chunk = friendIds.sublist(i, i + 10 > friendIds.length ? friendIds.length : i + 10);
        final friendsChunk = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .orderBy('score', descending: true)
            .get();
        
        // Add each friend's document to the list
        allFriendDocs.addAll(friendsChunk.docs);
      }

      // Sort the combined list of friends by score
      allFriendDocs.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
      print("Friends leaderboard documents count: ${allFriendDocs.length}");

      // Find the user's rank among friends
      int friendsRankIndex = allFriendDocs.indexWhere((doc) => doc.id == user.uid);
      setState(() {
        _friendsRank = friendsRankIndex != -1 ? friendsRankIndex + 1 : null;
      });
      print("User's friend rank: $_friendsRank");
    } else {
      // Handle case where there are no friends
      setState(() {
        _friendsRank = null;
      });
      print("No friends found for user.");
    }

    // Find global rank
    int globalRankIndex = globalLeaderboard.docs.indexWhere((doc) => doc.id == user.uid);
    setState(() {
      _globalRank = globalRankIndex != -1 ? globalRankIndex + 1 : null;
    });
    print("User's global rank: $_globalRank");
  } catch (e) {
    print("Error loading leaderboard ranks: $e");
    setState(() {
      _friendsRank = null;
      _globalRank = null;
    });
  }
}

  Future<void> _pickImage() async {
    
    final ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose Image Source'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.photo_camera),
            label: const Text('Camera'),
            onPressed: () {
              Navigator.of(ctx).pop(ImageSource.camera);
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.photo_library),
            label: const Text('Gallery'),
            onPressed: () {
              Navigator.of(ctx).pop(ImageSource.gallery);
            },
          ),
        ],
      ),
    );

    if (source == null) return;

    final pickedImage = await ImagePicker().pickImage(
      source: source,
      imageQuality: 50, 
      maxWidth: 150, 
    );

    if (pickedImage == null) return;

    final newImageFile = File(pickedImage.path);
    
    setState(() {
      _pickedImageFile = newImageFile;
    });
    try {
    final user = _firebase.currentUser;
    if (user == null) return;

    final storageRef = FirebaseStorage.instance
        .ref()
        .child('user_images')
        .child('${user.uid}.jpg');

    await storageRef.putFile(newImageFile);
    final imageUrl = await storageRef.getDownloadURL();

    // Update Firestore with new image URL
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({
      'image_url': imageUrl,
    });

    // Update the UI with new image URL
    setState(() {
      _imageUrl = imageUrl;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile image updated successfully!')),
    );
  } catch (error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $error')),
    );
  }

  }
  // Show dialog to update username
  Future<void> _showUpdateUsernameDialog() async {
    final _usernameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Update Username'),
          content: Form(
            child: TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'New Username'),
              validator: (value) {
                if (value == null || value.isEmpty || value.length < 4) {
                  return 'Please enter a valid username (min 4 characters).';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_usernameController.text.isNotEmpty) {
                  bool isUsernameUnique =
                      await _isUsernameUnique(_usernameController.text);
                  if (!isUsernameUnique) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Username is already taken.')),
                    );
                  } else {
                    await _updateUsername(_usernameController.text);
                    Navigator.of(context).pop();
                  }
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }
  Future<bool> _isUsernameUnique(String username) async {
    final querySnapshot = await _firestore
        .collection('users')
        .where('username', isEqualTo: username)
        .get();

    return querySnapshot.docs.isEmpty;
  }
  Future<void> _updateUsername(String newUsername) async {
    final user = _firebase.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'username': newUsername,
      });

      setState(() {
        _username = newUsername;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username updated successfully!')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating username: $error')),
      );
    }
  }
  Future<void> _showUpdateEmailDialog() async {
  final _emailController = TextEditingController();
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Update Email'),
        content: Form(
          child: TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'New Email'),
            validator: (value) {
              if (value == null || !value.contains('@') || !value.contains('.com')) {
                return 'Please enter a valid email address.';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
                // Try updating the email and catch any errors
                await _updateEmail(_emailController.text);
                Navigator.of(context).pop(); 
            },
            child: const Text('Update'),
          ),
        ],
      );
    },
  );
}

  Future<void> _updateEmail(String newEmail) async {
  final user = _firebase.currentUser;
  if (user == null) return;

  try {
    // Step 1: Check if the email is already in use in Firestore
    final querySnapshot = await _firestore
        .collection('users')
        .where('email', isEqualTo: newEmail)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This email is already in use by another account.')),
      );
      return;
    }

    // Step 2: Try to update the email in Firebase Authentication
    await user.verifyBeforeUpdateEmail(newEmail);

    // Step 3: Sign the user out and ask for re-authentication
    await _firebase.signOut();

    // Step 4: Notify the user about the verification email
    

    // Step 5: Navigate to the authentication screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => AuthScreen()),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Verification email sent. Please verify and log in again.'),
      ),
    );

    // Step 6: After the user re-authenticates and logs in, update the email in Firestore
    await _firestore.collection('users').doc(user.uid).update({
      'email': newEmail,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Email updated successfully!')),
    );
  } on FirebaseAuthException catch (e) {
    if (e.code == 'email-already-in-use') {
      // Firebase Auth error for duplicate email
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This email is already in use.')),
      );
    } else if (e.code == 'requires-recent-login') {
      // Re-authentication required
      await _reauthenticateUser(user);
    } else {
      // Other Firebase Auth errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Failed to update email.')),
      );
    }
  } catch (error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $error')),
    );
  }
}
  Future<void> _resetPassword() async {
    final user = _firebase.currentUser;
    if (user == null) return;

    try {
      await _firebase.sendPasswordResetEmail(email: user.email!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent!')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    }
  }
 
// Function to reauthenticate the user before updating sensitive information
Future<void> _reauthenticateUser(User user) async {

  await FirebaseAuth.instance.signOut();

      // Navigate back to AuthScreen after account deletion
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => AuthScreen(),
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please reauthenticate and try again.')),
      );
}

  Future<void> _deleteAccount() async {
  final user = _firebase.currentUser;
  if (user == null) return;

  try {
    // Delete user profile image from Firebase Storage
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('user_images')
        .child('${user.uid}.jpg');
    await storageRef.delete(); 

    // Delete user document from Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .delete(); 

    // Delete the user from Firebase Authentication
    await user.delete(); 

    // Sign out the user locally
    await _firebase.signOut();

    // Navigate the user back to the login screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => AuthScreen(), 
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account deleted successfully.')),
    );
  } on FirebaseAuthException catch (e) {
    if (e.code == 'requires-recent-login') {
      await _reauthenticateUser(user);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.message}')),
      );
    }
  } catch (error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error deleting account: $error')),
    );
  }
}
// Additional Widget for Statistics Row
  Widget _buildStatisticsRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 18, color: Colors.white),
          ),
        ],
      ),
    );
  }
 
Widget _buildLastFiveGamesRow() {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Last 5 Games:',
          style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
        ),
        Row(
          children: _lastFiveGames.isEmpty
              ? [const Text("No games played", style: TextStyle(color: Colors.white))]
              : _lastFiveGames.map((result) {
                  Color color;
                  String label;

                  // Set color and label based on the result
                  if (result == "Win") {
                    color = Colors.green;
                    label = 'W';
                  } else if (result == "Loss") {
                    color = Colors.red;
                    label = 'L';
                  } else {
                    color = Colors.yellow;
                    label = 'D';
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: color,
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }).toList(),
        ),
      ],
    ),
  );
}


  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: const Text('Profile', style: TextStyle(color: Colors.white)),
        iconTheme: IconThemeData(
          color: const Color.fromARGB(255, 255, 255, 255), 
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: _pickedImageFile != null
                          ? FileImage(_pickedImageFile!)
                          : _imageUrl != null
                              ? NetworkImage(_imageUrl!) as ImageProvider
                              : null,
                    ),
                    TextButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(
                        Icons.image,
                        color: Color.fromARGB(255, 255, 255, 255),
                      ),
                      label: const Text(
                        'Change Profile Image',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color.fromARGB(255, 255, 255, 255), 
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _username != null ? '$_username' : 'Username',
                          style: const TextStyle(fontSize: 20, color: Colors.white),
                        ),
                        ElevatedButton(
                          onPressed: _showUpdateUsernameDialog,
                          child: const Text('Change'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _email != null ? '$_email' : 'Email',
                          style: const TextStyle(fontSize: 20, color: Colors.white),
                        ),
                        ElevatedButton(
                          onPressed: _showUpdateEmailDialog,
                          child: const Text('Change'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _resetPassword,
                      child: const Text('Reset Password'),
                    ),
                    ElevatedButton(
                      onPressed: _deleteAccount,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('Delete Account'),
                    ),
                    
                    // New Statistics Section
                    const Divider(color: Colors.white),
                    const SizedBox(height: 10),
                    const Text(
                      'Statistics',
                      style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    _buildStatisticsRow('Games Played:', _gamesPlayed?.toString() ?? '0'),
                    _buildStatisticsRow('Win Games:', _winGames?.toString() ?? '0'),
                    _buildStatisticsRow('Lose Games:', _loseGames?.toString() ?? '0'),
                    _buildStatisticsRow('W/L Ratio:', _winLossRatio != null ? _winLossRatio!.toStringAsFixed(2) : '0.0'),
                    _buildStatisticsRow('current Score:', _score?.toString() ?? '0'),
                    _buildStatisticsRow('Highest Score:', _highestScore?.toString() ?? '0'),
                    _buildStatisticsRow('Global Rank:', _globalRank?.toString() ?? 'N/A'),
                    _buildStatisticsRow('Friends Rank:', _friendsRank?.toString() ?? 'No friends'),
                    _buildLastFiveGamesRow(),
                  ],
                ),
              ),
            ),
    );
  }
}
