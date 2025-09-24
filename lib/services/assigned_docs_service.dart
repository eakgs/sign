// lib/services/assigned_docs_service.dart
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;

class AssignedDoc {
  final String id;
  final String title;
  final String assetPath; // demo uses assets for offline simplicity
  const AssignedDoc({
    required this.id,
    required this.title,
    required this.assetPath,
  });
}

class AssignedDocsService {
  // Demo data: add your sample PDFs to pubspec under assets/assigned/
  static const _docs = <AssignedDoc>[
    AssignedDoc(
      id: 'a1',
      title: 'Offer Letter',
      assetPath: 'assets/assigned/pdf1.pdf',
    ),
    AssignedDoc(
      id: 'a2',
      title: 'NDA Agreement',
      assetPath: 'assets/assigned/pdf2.pdf',
    ),
    AssignedDoc(
      id: 'a3',
      title: 'PO #10293',
      assetPath: 'assets/assigned/pdf3.pdf',
    ),
  ];

  Future<List<AssignedDoc>> listAssigned() async {
    // Simulate a network call if you like:
    // await Future.delayed(const Duration(milliseconds: 250));
    return _docs;
  }

  Future<Uint8List> loadBytes(AssignedDoc doc) async {
    final bd = await rootBundle.load(doc.assetPath);
    return bd.buffer.asUint8List();
  }
}
