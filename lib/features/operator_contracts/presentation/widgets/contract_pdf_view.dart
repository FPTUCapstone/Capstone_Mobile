import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

/// The PDF is opened from authenticated, hash-checked bytes. No bearer token
/// or private document URL is passed to an external browser or renderer URL.
class ContractPdfView extends StatefulWidget {
  const ContractPdfView({
    required this.bytes,
    required this.onOpened,
    required this.onFailure,
    super.key,
  });
  final Uint8List bytes;
  final VoidCallback onOpened, onFailure;
  @override
  State<ContractPdfView> createState() => _ContractPdfViewState();
}

class _ContractPdfViewState extends State<ContractPdfView> {
  late PdfController _controller;
  int _page = 1, _pages = 0;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    _controller = PdfController(document: PdfDocument.openData(widget.bytes));
  }

  @override
  void didUpdateWidget(covariant ContractPdfView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.bytes, widget.bytes)) {
      _controller.dispose();
      _controller = PdfController(document: PdfDocument.openData(widget.bytes));
      _page = 1;
      _pages = 0;
      _failed = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: 460,
        child: PdfView(
          controller: _controller,
          onDocumentLoaded: (document) {
            if (!mounted) return;
            setState(() => _pages = document.pagesCount);
            widget.onOpened();
          },
          onDocumentError: (_) {
            if (!mounted) return;
            setState(() => _failed = true);
            widget.onFailure();
          },
          onPageChanged: (page) {
            if (mounted) setState(() => _page = page);
          },
          builders: PdfViewBuilders<DefaultBuilderOptions>(
            options: const DefaultBuilderOptions(),
            errorBuilder: (_, _) => const Center(
              child: Text('Không thể mở PDF. Vui lòng tải lại hợp đồng.'),
            ),
          ),
        ),
      ),
      if (!_failed)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Trang trước',
              onPressed: _page > 1
                  ? () => _controller.previousPage(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                    )
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text(_pages == 0 ? 'Đang mở PDF…' : 'Trang $_page / $_pages'),
            IconButton(
              tooltip: 'Trang sau',
              onPressed: _pages > 0 && _page < _pages
                  ? () => _controller.nextPage(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                    )
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
    ],
  );
}
