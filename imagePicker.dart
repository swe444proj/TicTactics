import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class UserImagePicker extends StatefulWidget {
  const UserImagePicker({
    super.key,
    required this.onPickImage,
  });

  final void Function(File pickedImage) onPickImage;

  @override
  State<UserImagePicker> createState() {
    return _UserImagePickerState();
  }
}

class _UserImagePickerState extends State<UserImagePicker> {
  File? _pickedImageFile;

  void _pickImage() async {
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

  if (source == null) {
    return; // User canceled the dialog.
  }

  final pickedImage = await ImagePicker().pickImage(
    source: source, // Use the source chosen by the user.
    imageQuality: 50,
    maxWidth: 150,
  );

  if (pickedImage == null) {
    return; // User didn't pick an image.
  }

  setState(() {
    _pickedImageFile = File(pickedImage.path);
  });

  widget.onPickImage(_pickedImageFile!);
}

@override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: Colors.grey,
          foregroundImage:
              _pickedImageFile != null ? FileImage(_pickedImageFile!) : null,
        ),
        TextButton.icon(
          onPressed: _pickImage,
          icon: const Icon(Icons.image),
          label: Text(
            'Add Image',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        )
      ],
    );
  }
}