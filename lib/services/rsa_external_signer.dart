import 'dart:convert';
import 'dart:typed_data';

import 'package:asn1lib/asn1lib.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pointycastle/export.dart' as pc;
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// A production-ready external signer for Syncfusion PDF that uses an
/// unencrypted RSA private key (PKCS#1 or PKCS#8) from a PEM asset.
///
/// This implementation correctly signs the raw message bytes provided by the
/// PDF library using the 'SHA-256/RSA' algorithm, which handles hashing,
/// DigestInfo creation, and PKCS#1 v1.5 padding automatically. This prevents
/// the common "Document has been altered" error in Adobe Acrobat.
class RsaExternalSigner extends IPdfExternalSigner {
  final String privateKeyAssetPath;
  late final pc.RSAPrivateKey _privateKey;

  RsaExternalSigner({required this.privateKeyAssetPath});

  /// Pre-loads and parses the private key. Call this before signing.
  Future<void> initialize() async {
    final pemText = await rootBundle.loadString(privateKeyAssetPath);
    _privateKey = _parseRsaPrivateKeyFromPem(pemText);
  }

  @override
  DigestAlgorithm get hashAlgorithm => DigestAlgorithm.sha256;

  @override
  Future<SignerResult> sign(List<int> message) async {
    // The `message` from Syncfusion is the raw data to be signed.
    // The `Signer` instance will handle hashing it with SHA-256 internally.
    final signer = pc.Signer('SHA-256/RSA');
    signer.init(true, pc.PrivateKeyParameter<pc.RSAPrivateKey>(_privateKey));

    final pc.Signature signature = signer.generateSignature(
      Uint8List.fromList(message),
    );

    // Return the signature bytes.
    return SignerResult((signature as pc.RSASignature).bytes);
  }

  /// Parses a PEM string containing an unencrypted PKCS#1 or PKCS#8 RSA private key.
  pc.RSAPrivateKey _parseRsaPrivateKeyFromPem(String pem) {
    final pemBody = _extractPemBody(pem);
    if (pemBody == null) {
      throw ArgumentError(
        'No valid RSA PRIVATE KEY or PRIVATE KEY block found in PEM asset.',
      );
    }
    final derBytes = base64.decode(pemBody);
    final asn1Parser = ASN1Parser(derBytes);
    final topLevelSeq = asn1Parser.nextObject() as ASN1Sequence;

    // Check for PKCS#8 format
    if (topLevelSeq.elements.length == 3 &&
        topLevelSeq.elements[0] is ASN1Integer) {
      final privateKeyAsn1 = ASN1Parser(
        (topLevelSeq.elements[2] as ASN1OctetString).valueBytes(),
      );
      final pkcs1Seq = privateKeyAsn1.nextObject() as ASN1Sequence;
      return _parsePkcs1Sequence(pkcs1Seq);
    }
    // Assume PKCS#1 format
    else {
      return _parsePkcs1Sequence(topLevelSeq);
    }
  }

  /// Extracts the Base64-encoded body from a PEM string.
  String? _extractPemBody(String pem) {
    final lines = pem
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('-----'))
        .join('');
    return lines.isEmpty ? null : lines;
  }

  /// Parses a PKCS#1 ASN.1 sequence into a PointyCastle RSAPrivateKey.
  pc.RSAPrivateKey _parsePkcs1Sequence(ASN1Sequence seq) {
    final modulus = (seq.elements[1] as ASN1Integer).valueAsBigInteger;
    final privateExponent = (seq.elements[3] as ASN1Integer).valueAsBigInteger;
    final p = (seq.elements[4] as ASN1Integer).valueAsBigInteger;
    final q = (seq.elements[5] as ASN1Integer).valueAsBigInteger;
    return pc.RSAPrivateKey(modulus, privateExponent, p, q);
  }
}
