mport 'package:flutter/material.dart';
import 'package:tic_tactics/auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:tic_tactics/splash.dart';
import 'firebase_options.dart';
import 'package:tic_tactics/lobby.dart';


void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tic Tactics',
      theme: ThemeData().copyWith(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color.fromARGB(255, 63, 17, 177)),
      ),
      home: StreamBuilder(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (ctx, snapshot) {
            if(snapshot.connectionState == ConnectionState.waiting){
              return splashScreen();
            }
            if (snapshot.hasData) {
              return LobbyScreen();
            }

            return const AuthScreen();
          }),
    );
  }
}
