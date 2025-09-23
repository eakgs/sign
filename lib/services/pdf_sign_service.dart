// lib/services/pdf_sign_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;
import 'package:sign_min/services/rsa_external_signer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as pdf;

class PdfSignResult {
  final Uint8List bytes;
  final bool success;
  final String? error;
  final List<String> warnings;
  PdfSignResult({
    required this.bytes,
    required this.success,
    this.error,
    this.warnings = const [],
  });
}

class PdfSignService {
  /// Signs a PDF and draws the user's visible signature PNG at the given position.
  static Future<PdfSignResult> signPdf({
    required Uint8List pdfBytes,
    required Uint8List signaturePng,
    required ui.Rect viewerRectPx,
    required ui.Size viewerSizePx,
    required int pageNumber, // 1-based
    String? reason,
    String? location,
    String? contactInfo,

    // Assets (DEV ONLY – for UAT tests; do NOT ship real prod keys)
    String privateKeyAsset = 'assets/privatekey.pem',
    String leafCertAssetPem = 'assets/cert.pem',
    String? intermediateCertAssetPem = 'assets/intermediate.pem',
  }) async {
    final warnings = <String>[];

    try {
      // -------- 1) Open PDF & clamp target page --------
      final document = pdf.PdfDocument(inputBytes: pdfBytes);
      final clampedPage = pageNumber.clamp(1, document.pages.count);
      final page = document.pages[clampedPage - 1];

      // -------- 2) Map viewer pixels → PDF points --------
      final bounds = _viewerToPdfBounds(
        viewerRectPx,
        viewerSizePx,
        ui.Size(page.size.width, page.size.height),
      );

      // -------- 3) Create signature field + visual appearance --------
      final fieldName =
          'SignatureField_${DateTime.now().millisecondsSinceEpoch}';
      final field = pdf.PdfSignatureField(page, fieldName, bounds: bounds);

      field.appearance.normal = pdf.PdfTemplate(bounds.width, bounds.height)
        ..graphics!.drawImage(
          pdf.PdfBitmap(signaturePng),
          ui.Rect.fromLTWH(0, 0, bounds.width, bounds.height),
        );

      // -------- 4) Configure CAdES + SHA-256 --------
      final sig = pdf.PdfSignature(
        contactInfo: contactInfo,
        locationInfo: location,
        reason: reason,
        digestAlgorithm: pdf.DigestAlgorithm.sha256,
        cryptographicStandard: pdf.CryptographicStandard.cades,
      );

      // -------- 5) Build the full chain (leaf → intermediate(s)), exclude root --------
      final chainDer = <List<int>>[
        _pemCertToDer(
          await rootBundle.loadString(leafCertAssetPem),
        ), // leaf first
        if (intermediateCertAssetPem != null)
          _pemCertToDer(await rootBundle.loadString(intermediateCertAssetPem)),
      ];
      if (chainDer.length < 2) {
        // Not fatal, but Acrobat may say "unknown" if intermediate is missing
        warnings.add(
          'No intermediate certificate embedded. Embed leaf + intermediate(s).',
        );
      }

      // -------- 6) External signer (DEV ONLY – local PEM). Initialize key. --------
      final signer = RsaExternalSigner(privateKeyAssetPath: privateKeyAsset);
      await signer.initialize();

      // -------- 7) Attach signature & save --------
      field.signature = sig;
      sig.addExternalSigner(signer, chainDer);
      document.form.fields.add(field);

      final out = await document.save();
      document.dispose();

      return PdfSignResult(
        bytes: Uint8List.fromList(out),
        success: true,
        warnings: warnings,
      );
    } catch (e, st) {
      final msg = 'signPdf failed: $e\n$st';
      // ignore: avoid_print
      print(msg);
      return PdfSignResult(
        bytes: Uint8List(0),
        success: false,
        error: msg,
        warnings: warnings,
      );
    }
  }

  // ---------- helpers ----------

  static List<int> _pemCertToDer(String pem) {
    const begin = '-----BEGIN CERTIFICATE-----';
    const end = '-----END CERTIFICATE-----';
    final body = pem.split(begin).last.split(end).first;
    return base64.decode(body.replaceAll(RegExp(r'\s'), ''));
  }

  /// Map viewer pixels → PDF points (PDF origin is bottom-left).
  static ui.Rect _viewerToPdfBounds(
    ui.Rect viewerRectPx,
    ui.Size viewerSizePx,
    ui.Size pageSizePts,
  ) {
    final sx = pageSizePts.width / viewerSizePx.width;
    final sy = pageSizePts.height / viewerSizePx.height;

    final leftPts = viewerRectPx.left * sx;
    final rightPts = viewerRectPx.right * sx;
    final bottomPts = (viewerSizePx.height - viewerRectPx.bottom) * sy;
    final heightPts = (viewerRectPx.height) * sy;

    return ui.Rect.fromLTWH(leftPts, bottomPts, rightPts - leftPts, heightPts);
  }
}
