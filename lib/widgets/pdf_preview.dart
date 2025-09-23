import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

/// Displays a PDF using Syncfusion's PDF viewer.
/// - If [bytes] is provided, it uses SfPdfViewer.memory(bytes).
/// - Else if [path] points to an existing file, it uses SfPdfViewer.file(File(path)).
/// - Otherwise shows a placeholder.
class PdfPreview extends StatefulWidget {
  final Uint8List? bytes;
  final String? path;

  const PdfPreview({super.key, this.bytes, this.path});

  @override
  State<PdfPreview> createState() => _PdfPreviewState();
}

class _PdfPreviewState extends State<PdfPreview> {
  final PdfViewerController _controller = PdfViewerController();
  String? _errorText;

  @override
  Widget build(BuildContext context) {
    if (widget.bytes == null && (widget.path == null || widget.path!.isEmpty)) {
      return const Center(child: Text('No PDF selected'));
    }

    Widget viewer;
    try {
      if (widget.bytes != null) {
        viewer = SfPdfViewer.memory(
          widget.bytes!,
          controller: _controller,
          canShowScrollHead: true,
          canShowPaginationDialog: true,
        );
      } else {
        final file = File(widget.path!);
        if (!file.existsSync()) {
          return const Center(child: Text('PDF file not found'));
        }
        viewer = SfPdfViewer.file(
          file,
          controller: _controller,
          canShowScrollHead: true,
          canShowPaginationDialog: true,
        );
      }
    } catch (e) {
      _errorText = 'Failed to load PDF: $e';
      viewer = Center(child: Text(_errorText!));
    }

    return Stack(
      children: [
        Positioned.fill(child: viewer),

        // Tiny top-right toolbar: reload & jump to page
        Positioned(
          top: 8,
          right: 8,
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Reload',
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    setState(() {
                      _errorText = null;
                    });
                    _controller.clearSelection();
                    // For memory/file viewers, reassigning the widget by setState
                    // is enough; the parent will rebuild this with same source.
                  },
                ),
                IconButton(
                  tooltip: 'First page',
                  icon: const Icon(Icons.first_page),
                  onPressed: () => _controller.jumpToPage(1),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
