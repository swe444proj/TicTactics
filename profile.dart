import 'dart:io';
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
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();

  String? _username;
  String? _email;
  String? _imageUrl;
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
      _isLoading = false;
    });
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
      imageQuality: 50, // Adjust image quality
      maxWidth: 150, // Adjust max width
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
                Navigator.of(context).pop(); // Close dialog after updating
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
          builder: (context) => AuthScreen(), // Replace this with your auth screen widget
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
    await storageRef.delete(); // Delete the user's image file from Storage

    // Delete user document from Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .delete(); // Delete the user's document in Firestore

    // Delete the user from Firebase Authentication
    await user.delete(); // Delete the user account from Firebase Authentication

    // Sign out the user locally
    await _firebase.signOut();

    // Navigate the user back to the login screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => AuthScreen(), // Navigate back to Auth Screen
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


  
  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Theme.of(context).colorScheme.primary,
    appBar: AppBar(
      backgroundColor: Theme.of(context).colorScheme.primary,
      title: const Text('Profile', style: TextStyle(color: Colors.white),
      ),
      iconTheme: IconThemeData(
    color: const Color.fromARGB(255, 255, 255, 255), // Change this to the desired color
  ),
  ),
    body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Display User's Profile Image
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
    color: Color.fromARGB(255, 255, 255, 255), // Adding color to the icon
  ),
  label: const Text(
    'Change Profile Image',
    style: TextStyle(
      fontSize: 16,
      color: Color.fromARGB(255, 255, 255, 255), // Text color matches the icon
    ),
  ),
),
                  const SizedBox(height: 16),

                  // Username in Row with Change Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _username != null ? 'Username: $_username' : 'Username',
                        style: const TextStyle(fontSize: 20, color: Colors.white),
                      ),
                      ElevatedButton(
                        onPressed: _showUpdateUsernameDialog,
                        child: const Text('Change'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Email in Row with Change Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _email != null ? 'Email: $_email' : 'Email',
                        style: const TextStyle(fontSize: 20, color: Colors.white),
                      ),
                      ElevatedButton(
                        onPressed: _showUpdateEmailDialog,
                        child: const Text('Change'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Reset Password Button
                  ElevatedButton(
                    onPressed: _resetPassword,
                    child: const Text('Reset Password'),
                  ),
                  
                  // Delete Account Button
                  ElevatedButton(
                    onPressed: _deleteAccount,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('Delete Account'),
                  ),
                ],
              ),
            ),
          ),
  );
}
}

