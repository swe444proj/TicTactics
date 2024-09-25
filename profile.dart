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

  void _updateProfile() async {
    final user = _firebase.currentUser;
    if (user == null || !_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();

    try {
      if (_pickedImageFile != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('user_images')
            .child('${user.uid}.jpg');

        await storageRef.putFile(_pickedImageFile!);
        _imageUrl = await storageRef.getDownloadURL();
      }

      if (_email != user.email) {
      await _updateEmail(user);
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'username': _username,
        'email': _email,
        'image_url': _imageUrl,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
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
  Future<void> _updateEmail(User user) async {
  try {
    // Send verification to the new email before updating
    await user.verifyBeforeUpdateEmail(_email!);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Verification email sent. Please verify the new email to complete the update.')),
    );
  } on FirebaseAuthException catch (e) {
    if (e.code == 'email-already-in-use') {
      // Handle case where the email is already in use
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('This email is already in use by another account.')),
      );
    } else if (e.code == 'requires-recent-login') {
      // Handle reauthentication requirement
      await _reauthenticateUser(user); // Reauthenticate user and retry email update
    } else {
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
  try {
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      // Delete user from Firebase Auth
      await currentUser.delete();

      // Sign out the user
      await FirebaseAuth.instance.signOut();

      // Navigate back to AuthScreen after account deletion
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => AuthScreen(), // Replace this with your auth screen widget
        ),
      );
    } else {
      print('No user logged in');
    }
  } on FirebaseAuthException catch (e) {
    print('Error deleting user: ${e.message}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e.message ?? 'Failed to delete account.'),
      ),
    );
  } catch (e) {
    print('Error: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('An error occurred. Please try again.'),
      ),
    );
    }
  }


  Future<void> _pickImage() async {
    // Show an AlertDialog to choose between Camera and Gallery
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

    // If the user cancels the dialog, return early
    if (source == null) {
      return;
    }

    // Pick the image using the selected source (Camera or Gallery)
    final pickedImage = await ImagePicker().pickImage(
      source: source,
      imageQuality: 50, // Adjust image quality
      maxWidth: 150, // Adjust max width
    );

    // If no image is picked, return early
    if (pickedImage == null) {
      return;
    }

    final newImageFile = File(pickedImage.path);

    // Update the state with the new image
    setState(() {
      _pickedImageFile = newImageFile;
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
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
                        icon: const Icon(Icons.image),
                        label: const Text('Change Profile Image'),
                      ),
                      TextFormField(
                        initialValue: _username,
                        decoration: const InputDecoration(labelText: 'Username'),
                        validator: (value) {
                          if (value == null || value.isEmpty || value.length < 4) {
                            return 'Please enter a valid username.';
                          }
                          return null;
                        },
                        onSaved: (value) {
                          _username = value!;
                        },
                      ),
                      TextFormField(
                        initialValue: _email,
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (value) {
                          if (value == null || !value.contains('@')) {
                            return 'Please enter a valid email address.';
                          }
                          return null;
                        },
                        onSaved: (value) {
                          _email = value!;
                        },
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _updateProfile,
                        child: const Text('Update Profile'),
                      ),
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
                    ],
                  ),
                ),
              ),
            ),
    );
  }
  }

