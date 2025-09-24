// lib/pages/pdf_signing_screen.dart
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' show PdfDocument;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_signaturepad/signaturepad.dart';

import 'package:sign_min/services/file_helpers.dart';
import 'package:sign_min/services/pdf_sign_service.dart';
import 'package:sign_min/services/assigned_docs_service.dart';

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

  // Overlay state (top-left + size, in viewer px)
  bool _showOverlay = false;
  double _viewerW = 0, _viewerH = 0;
  double _overlayX = 100, _overlayY = 100;
  double _overlayW = 200, _overlayH = 80;

  // Gestures (scale-only API: used for both drag + pinch)
  late Offset _scaleStartFocal;
  late double _startX, _startY, _startW, _startH;

  bool _busy = false;
  String _status = 'Select a document to start';

  // Assigned PDFs
  final _assignedService = AssignedDocsService();
  late Future<List<AssignedDoc>> _assignedFuture = _assignedService
      .listAssigned();

  // ---------- Actions ----------

  Future<void> _pickPdf() async {
    final picked = await FileHelpers.pickPdfBytes();
    if (picked == null) return;
    setState(() {
      _pdfBytes = picked.bytes;
      _resetOverlay();
      _status = 'Place your signature and tap Apply';
    });
    _toast('PDF loaded');
  }

  void _openAssignedSheet() {
    // Do not return a Future from setState
    setState(() {
      _assignedFuture = _assignedService.listAssigned();
    });
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: FutureBuilder<List<AssignedDoc>>(
          future: _assignedFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('Failed to load: ${snap.error}'));
            }
            final items = snap.data ?? const [];
            if (items.isEmpty) {
              return const Center(child: Text('No assigned PDFs.'));
            }
            return RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  _assignedFuture = _assignedService.listAssigned();
                });
                await _assignedFuture;
              },
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final d = items[i];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF0FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.picture_as_pdf,
                          color: Color(0xFF2F6DF6),
                        ),
                      ),
                      title: Text(
                        d.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        'Tap to open • ${d.assetPath.split('/').last}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          // was .withOpacity(0.16)
                          color: const Color(
                            0xFF26D7AE,
                          ).withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          'Pending',
                          style: TextStyle(
                            color: Color(0xFF007A66),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      onTap: _busy
                          ? null
                          : () async {
                              Navigator.pop(context);
                              await _loadAssignedDoc(d);
                            },
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _loadAssignedDoc(AssignedDoc doc) async {
    setState(() {
      _busy = true;
      _status = 'Opening "${doc.title}"...';
    });
    try {
      final bytes = await _assignedService.loadBytes(doc);
      setState(() {
        _pdfBytes = bytes;
        _resetOverlay();
        _status = 'Loaded: ${doc.title}';
      });
      _toast('Loaded: ${doc.title}');
    } catch (e) {
      _toast('Failed to open: $e', error: true);
      setState(() => _status = 'Failed: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _showSignaturePadDialog() async {
    final padKey = GlobalKey<SfSignaturePadState>();
    Uint8List? resultPng;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Draw Signature'),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
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
      HapticFeedback.selectionClick();
      setState(() {
        _savedSignatures.add(resultPng!);
        _activeOverlayPng = resultPng;
        _showOverlay = true;
        // place near bottom for thumb reach
        _overlayW = 220;
        _overlayH = 90;
        _overlayX = 16;
        _overlayY = math.max(16, _viewerH - _overlayH - 96);
        _status = 'Signature ready. Drag or pinch to resize.';
      });
      _toast('Signature saved');
    }
  }

  void _openSavedSignatures() {
    if (_savedSignatures.isEmpty) {
      _toast('No saved signatures yet. Draw one first.');
      setState(() => _status = 'No saved signatures');
      return;
    }
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.2,
        ),
        itemCount: _savedSignatures.length,
        itemBuilder: (_, i) => InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _activeOverlayPng = _savedSignatures[i];
              _showOverlay = true;
              _status = 'Drag or pinch to resize. Tap Apply to sign.';
            });
            Navigator.pop(context);
          },
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Image.memory(_savedSignatures[i], fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _applyAndSign() async {
    if (_pdfBytes == null) {
      _toast('Upload or select a PDF first', error: true);
      setState(() => _status = 'Please upload a PDF first.');
      return;
    }
    if (!_showOverlay || _activeOverlayPng == null) {
      _toast('Place a signature first', error: true);
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
      pageNumber: pageNumber,
      reason: 'Approved',
      location: 'Malabe',
      contactInfo: 'Enadoc',
    );

    setState(() {
      _busy = false;
    });

    if (!result.success) {
      _toast('Signing failed', error: true);
      setState(() => _status = 'Failed: ${result.error}');
      return;
    }

    final outName = 'signed_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final path = await FileHelpers.saveBytesToAppSupport(result.bytes, outName);
    await FileHelpers.openPath(path);
    _toast('Signed ✓');
    setState(() => _status = 'Signed → $path');
  }

  // ---------- Scale-only gestures: drag + pinch in one handler ----------
  void _onOverlayScaleStart(ScaleStartDetails d) {
    _scaleStartFocal = d.focalPoint;
    _startX = _overlayX;
    _startY = _overlayY;
    _startW = _overlayW;
    _startH = _overlayH;
  }

  void _onOverlayScaleUpdate(ScaleUpdateDetails d) {
    // translation via focalPointDelta
    final dx = d.focalPoint.dx - _scaleStartFocal.dx;
    final dy = d.focalPoint.dy - _scaleStartFocal.dy;

    // scale (ignore tiny jitter)
    final scale = (d.scale == 0) ? 1.0 : d.scale;
    final newW = (_startW * scale).clamp(30.0, _viewerW);
    final newH = (_startH * scale).clamp(20.0, _viewerH);

    final newX = (_startX + dx).clamp(0.0, _viewerW - newW);
    final newY = (_startY + dy).clamp(0.0, _viewerH - newH);

    setState(() {
      _overlayX = newX;
      _overlayY = newY;
      _overlayW = newW;
      _overlayH = newH;
    });
  }

  // ---------- Helpers ----------
  void _resetOverlay() {
    _showOverlay = false;
    _activeOverlayPng = null;
    _overlayX = 100;
    _overlayY = 100;
    _overlayW = 200;
    _overlayH = 80;
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    final sb = SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? const Color(0xFFE53935) : null,
      duration: const Duration(seconds: 2),
    );
    ScaffoldMessenger.of(context).showSnackBar(sb);
  }

  // ---------- Build ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [ui.Color.fromARGB(255, 0, 194, 253), Color(0xFF1B4ACB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/brand/eviasign_logo.png',
                  height: 28,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 10),
                const Text(
                  'EviaSign — Sign PDF',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0),
                child: _RoundedIconButton(
                  icon: Icons.inbox,
                  label: 'Assigned',
                  onTap: _busy ? null : _openAssignedSheet,
                  light: true,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),

      body: Column(
        children: [
          if (_status.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF3FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD7E3FF)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 18,
                        color: Color(0xFF2F6DF6),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _status,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F8FC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E7F0)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: LayoutBuilder(
                    builder: (context, c) {
                      _viewerW = c.maxWidth;
                      _viewerH = c.maxHeight;

                      // clamp overlay inside viewer
                      _overlayX = _overlayX.clamp(
                        0.0,
                        (_viewerW - _overlayW).clamp(0.0, _viewerW),
                      );
                      _overlayY = _overlayY.clamp(
                        0.0,
                        (_viewerH - _overlayH).clamp(0.0, _viewerH),
                      );

                      return Stack(
                        children: [
                          Positioned.fill(
                            child: _pdfBytes == null
                                ? const Center(child: Text('No PDF selected'))
                                : SfPdfViewer.memory(
                                    _pdfBytes!,
                                    controller: _viewerController,
                                    canShowScrollHead: false,
                                    canShowPaginationDialog: true,
                                    enableTextSelection: true,
                                  ),
                          ),

                          // subtle watermark
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: Opacity(
                              opacity: 0.06,
                              child: Image.asset(
                                'assets/brand/eviasign_logo.png',
                                height: 64,
                              ),
                            ),
                          ),

                          if (_showOverlay && _activeOverlayPng != null)
                            Positioned(
                              left: _overlayX,
                              top: _overlayY,
                              child: GestureDetector(
                                onScaleStart: _onOverlayScaleStart,
                                onScaleUpdate: _onOverlayScaleUpdate,
                                child: Container(
                                  width: _overlayW,
                                  height: _overlayH,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: const Color(0xFF2F6DF6),
                                      width: 1,
                                    ),
                                    // was .withOpacity(0.22)
                                    color: Colors.white.withValues(alpha: 0.22),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Image.memory(
                                    _activeOverlayPng!,
                                    fit: BoxFit.contain,
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
            ),
          ),
        ],
      ),

      // Responsive bottom area: no overflow on narrow phones / large text
      bottomNavigationBar: SafeArea(
        child: _BottomActionArea(
          busy: _busy,
          onUpload: _pickPdf,
          onDraw: _showSignaturePadDialog,
          onSaved: _openSavedSignatures,
          onAssigned: _openAssignedSheet,
          onApply: _applyAndSign,
        ),
      ),
    );
  }
}

// --- small UI helpers ---

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _ActionPill({
    Key? key,
    required this.icon,
    required this.label,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final showText = label.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: showText ? 14 : 10,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: disabled ? const Color(0xFFEFF3FA) : const Color(0xFFF6F8FC),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFE2E7F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: disabled ? Colors.grey : const Color(0xFF2F6DF6),
            ),
            if (showText) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: disabled ? Colors.grey : const Color(0xFF0E1C2B),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoundedIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool light;
  const _RoundedIconButton({
    Key? key,
    required this.icon,
    required this.label,
    this.onTap,
    this.light = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final fg = light ? Colors.white : Theme.of(context).colorScheme.onPrimary;
    final bg = light
        // was .withOpacity(0.12)
        ? Colors.white.withValues(alpha: 0.12)
        : Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: fg, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// Responsive footer: wraps pills on small screens, keeps full-width Apply CTA
class _BottomActionArea extends StatelessWidget {
  final bool busy;
  final VoidCallback? onUpload;
  final VoidCallback? onDraw;
  final VoidCallback? onSaved;
  final VoidCallback? onAssigned;
  final VoidCallback? onApply;

  const _BottomActionArea({
    Key? key,
    required this.busy,
    this.onUpload,
    this.onDraw,
    this.onSaved,
    this.onAssigned,
    this.onApply,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth;
        final mq = MediaQuery.of(context);

        // Consider very small width or big text scale
        final scale = mq.textScaler.scale(1);
        final isVeryTight = width < 340 || scale > 1.3;
        final isTight = width < 400 || scale > 1.15;

        // Compact paddings on tight screens
        final horizontalPad = isTight ? 10.0 : 12.0;
        final verticalPadTop = isTight ? 6.0 : 8.0;
        final ctaTopGap = isTight ? 8.0 : 10.0;

        final pills = <Widget>[
          _ActionPill(
            icon: Icons.upload_file,
            label: isVeryTight ? '' : 'Upload',
            onTap: busy ? null : onUpload,
          ),
          _ActionPill(
            icon: Icons.brush,
            label: isVeryTight ? '' : 'Draw',
            onTap: busy ? null : onDraw,
          ),
          _ActionPill(
            icon: Icons.collections,
            label: isVeryTight ? '' : 'Saved',
            onTap: busy ? null : onSaved,
          ),
        ];

        return Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPad,
            verticalPadTop,
            horizontalPad,
            12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Wrap prevents horizontal overflow; pills flow to next line when needed
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                children: pills
                    .map(
                      (w) => ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 72),
                        child: w,
                      ),
                    )
                    .toList(),
              ),
              SizedBox(height: ctaTopGap),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    // Change the Apply button color here if needed:
                    backgroundColor: const Color(0xFF1B4ACB),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: isTight ? 14 : 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: busy ? null : onApply,
                  child: Text(
                    'Apply',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: isVeryTight ? 14 : 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
