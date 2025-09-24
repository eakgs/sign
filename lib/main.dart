// lib/main.dart
import 'package:flutter/material.dart';
import 'package:sign_min/pages/pdf_signing_screen.dart';
import 'package:sign_min/theme/brand_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EviaDemoApp());
}

class EviaDemoApp extends StatelessWidget {
  const EviaDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EviaSign Demo',
      debugShowCheckedModeBanner: false,
      theme: eviaTheme(context),
      home: const PdfSigningScreen(),
    );
  }
}
