// lib/pages/pdf_signing_screen.dart
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_signaturepad/signaturepad.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' show PdfDocument;

import 'package:sign_min/services/file_helpers.dart';
import 'package:sign_min/services/pdf_sign_service.dart';

class PdfSigningScreen extends StatefulWidget {
  const PdfSigningScreen({super.key});
  @override
  State<PdfSigningScreen> createState() => _PdfSigningScreenState();
}

class _PdfSigningScreenState extends State<PdfSigningScreen> {
  Uint8List? _pdfBytes;
  final PdfViewerController _viewerController = PdfViewerController();

  // Saved signatures (PNG bytes)
  final List<Uint8List> _savedSignatures = [];
  Uint8List? _activeOverlayPng;

  // Overlay state (drag/resize on viewer)
  bool _showOverlay = false;
  double _viewerW = 0, _viewerH = 0;
  double _overlayX = 100, _overlayY = 100;
  double _overlayW = 200, _overlayH = 80;

  bool _busy = false;
  String _status = 'Please select a PDF to sign.';

  // ---------- UI Actions ----------

  Future<void> _pickPdf() async {
    final picked = await FileHelpers.pickPdfBytes();
    if (picked == null) return;

    setState(() {
      _pdfBytes = picked.bytes;
      _showOverlay = false;
      _activeOverlayPng = null;
      _status = 'PDF loaded. Pick/draw a signature, place it, then Apply.';
    });
  }

  Future<void> _showSignaturePadDialog() async {
    final padKey = GlobalKey<SfSignaturePadState>();
    Uint8List? resultPng;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Draw Signature'),
        content: SizedBox(
          width: 420,
          height: 240,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SfSignaturePad(
              key: padKey,
              backgroundColor: Colors.white,
              minimumStrokeWidth: 1,
              maximumStrokeWidth: 4,
              strokeColor: Colors.black87,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => padKey.currentState?.clear(),
            child: const Text('Clear'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final img = await padKey.currentState!.toImage(pixelRatio: 3);
              final bd = await img.toByteData(format: ui.ImageByteFormat.png);
              if (bd != null) resultPng = bd.buffer.asUint8List();
              if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.save),
            label: const Text('Save'),
          ),
        ],
      ),
    );

    if (resultPng != null) {
      setState(() {
        _savedSignatures.add(resultPng!);
        _activeOverlayPng = resultPng;
        _showOverlay = true;
        _status = 'Signature saved. Drag and place it on the PDF.';
      });
    }
  }

  void _openSavedSignatures() {
    if (_savedSignatures.isEmpty) {
      setState(
        () => _status =
            'No saved signatures yet. Use “Draw & Save Signature” first.',
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _savedSignatures.map((sig) {
            return GestureDetector(
              onTap: () {
                setState(() {
                  _activeOverlayPng = sig;
                  _showOverlay = true;
                  _status = 'Drag and place the signature on the PDF.';
                });
                Navigator.pop(context);
              },
              child: Image.memory(
                sig,
                width: 140,
                height: 70,
                fit: BoxFit.contain,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _applyAndSign() async {
    if (_pdfBytes == null) {
      setState(() => _status = 'Please upload a PDF first.');
      return;
    }
    if (!_showOverlay || _activeOverlayPng == null) {
      setState(() => _status = 'Place a signature first.');
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Signing...';
    });

    // Clamp page number to actual page count
    final doc = PdfDocument(inputBytes: _pdfBytes!);
    final pageCount = doc.pages.count;
    doc.dispose();
    int pageNumber = _viewerController.pageNumber;
    if (pageNumber < 1) pageNumber = 1;
    if (pageNumber > pageCount) pageNumber = pageCount;

    final result = await PdfSignService.signPdf(
      pdfBytes: _pdfBytes!,
      signaturePng: _activeOverlayPng!,
      viewerRectPx: ui.Rect.fromLTWH(
        _overlayX,
        _overlayY,
        _overlayW,
        _overlayH,
      ),
      viewerSizePx: ui.Size(_viewerW, _viewerH),
      pageNumber: pageNumber, // 1-based
      reason: 'Approved',
      location: 'Malabe',
      contactInfo: 'Enadoc',
      // assets/privatekey.pem, assets/cert.pem, assets/intermediate.pem
      // are used by the service. Update paths if you changed them.
    );

    setState(() {
      _busy = false;
    });

    if (!result.success) {
      setState(() => _status = 'Failed: ${result.error}');
      return;
    }

    final outName = 'signed_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final path = await FileHelpers.saveBytesToAppSupport(result.bytes, outName);
    await FileHelpers.openPath(path);
    setState(() => _status = 'Signed → $path');
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign PDF')),
      body: Column(
        children: [
          // Top action bar (4 buttons)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ElevatedButton.icon(
                  onPressed: _busy ? null : _pickPdf,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload'),
                ),
                ElevatedButton.icon(
                  onPressed: _busy ? null : _showSignaturePadDialog,
                  icon: const Icon(Icons.brush),
                  label: const Text('Draw & Save'),
                ),
                ElevatedButton.icon(
                  onPressed: _busy ? null : _openSavedSignatures,
                  icon: const Icon(Icons.collections),
                  label: const Text('Saved'),
                ),
                FilledButton.icon(
                  onPressed: _busy ? null : _applyAndSign,
                  icon: const Icon(Icons.verified),
                  label: const Text('Apply'),
                ),
              ],
            ),
          ),

          // PDF viewer + draggable/resizeable signature overlay
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: LayoutBuilder(
                builder: (context, c) {
                  _viewerW = c.maxWidth;
                  _viewerH = c.maxHeight;

                  // keep overlay in-bounds if the layout changes
                  _overlayX = _overlayX.clamp(
                    0,
                    (_viewerW - _overlayW).clamp(0, _viewerW),
                  );
                  _overlayY = _overlayY.clamp(
                    0,
                    (_viewerH - _overlayH).clamp(0, _viewerH),
                  );

                  return Stack(
                    children: [
                      Positioned.fill(
                        child: _pdfBytes == null
                            ? const Center(child: Text('No PDF selected'))
                            : SfPdfViewer.memory(
                                _pdfBytes!,
                                controller: _viewerController,
                                canShowScrollHead: true,
                                canShowPaginationDialog: true,
                                enableTextSelection: true,
                              ),
                      ),

                      if (_showOverlay && _activeOverlayPng != null)
                        Positioned(
                          left: _overlayX,
                          top: _overlayY,
                          child: GestureDetector(
                            onPanUpdate: (d) => setState(() {
                              _overlayX = (_overlayX + d.delta.dx).clamp(
                                0,
                                _viewerW - _overlayW,
                              );
                              _overlayY = (_overlayY + d.delta.dy).clamp(
                                0,
                                _viewerH - _overlayH,
                              );
                            }),
                            child: Stack(
                              children: [
                                Container(
                                  width: _overlayW,
                                  height: _overlayH,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.blueAccent,
                                      width: 1,
                                    ),
                                    color: Colors.white.withOpacity(0.25),
                                  ),
                                  child: Image.memory(
                                    _activeOverlayPng!,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onPanUpdate: (d) => setState(() {
                                      _overlayW = (_overlayW + d.delta.dx)
                                          .clamp(30, _viewerW - _overlayX);
                                      _overlayH = (_overlayH + d.delta.dy)
                                          .clamp(20, _viewerH - _overlayY);
                                    }),
                                    child: Container(
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        color: Colors.blueAccent,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: const Icon(
                                        Icons.drag_handle,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Status chip
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white70,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Text(
                              _status,
                              style: TextStyle(
                                color: _status.startsWith('Failed')
                                    ? Colors.red
                                    : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
