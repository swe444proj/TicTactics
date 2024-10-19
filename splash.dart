import 'package:flutter/material.dart';

class splashScreen extends StatelessWidget {
  splashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tic Tactics'),
      ),
      body: const Center(
        child: Text('Loading...', style: TextStyle(fontSize: 30),),
      ),
    );
  }
}
