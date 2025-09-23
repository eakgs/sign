import 'package:flutter/material.dart';
import 'pages/pdf_signing_screen.dart';

void main() {
  // If you have a Syncfusion license, you can register it here:
  // SyncfusionLicense.registerLicense('YOUR_LICENSE_KEY');
  runApp(const SignMinApp());
}

class SignMinApp extends StatelessWidget {
  const SignMinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sign Min',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const PdfSigningScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
