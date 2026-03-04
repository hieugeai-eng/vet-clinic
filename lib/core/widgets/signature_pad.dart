import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

import '../constants/app_colors.dart';

/// Signature pad widget for capturing customer/clinic signatures
class SignaturePadWidget extends StatefulWidget {
  final String? label;
  final String? initialSignature; // Base64 encoded
  final void Function(String?)? onSaved;
  final double height;
  final Color backgroundColor;
  final Color penColor;

  const SignaturePadWidget({
    super.key,
    this.label,
    this.initialSignature,
    this.onSaved,
    this.height = 150,
    this.backgroundColor = Colors.white,
    this.penColor = AppColors.textPrimary,
  });

  @override
  State<SignaturePadWidget> createState() => _SignaturePadWidgetState();
}

class _SignaturePadWidgetState extends State<SignaturePadWidget> {
  late SignatureController _controller;
  bool _hasSignature = false;

  @override
  void initState() {
    super.initState();
    _controller = SignatureController(
      penStrokeWidth: 2,
      penColor: widget.penColor,
      exportBackgroundColor: widget.backgroundColor,
    );

    // Load initial signature if provided
    if (widget.initialSignature != null &&
        widget.initialSignature!.isNotEmpty) {
      _hasSignature = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveSignature() async {
    if (_controller.isEmpty) {
      widget.onSaved?.call(null);
      return;
    }

    final Uint8List? data = await _controller.toPngBytes();
    if (data != null) {
      final base64 = base64Encode(data);
      widget.onSaved?.call(base64);
      setState(() => _hasSignature = true);
    }
  }

  void _clearSignature() {
    _controller.clear();
    setState(() => _hasSignature = false);
    widget.onSaved?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              widget.label!,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            children: [
              // Show initial signature if exists and not modified
              if (widget.initialSignature != null &&
                  widget.initialSignature!.isNotEmpty &&
                  _controller.isEmpty)
                Positioned.fill(
                  child: Image.memory(
                    base64Decode(widget.initialSignature!),
                    fit: BoxFit.contain,
                  ),
                ),

              // Signature pad
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Signature(
                  controller: _controller,
                  backgroundColor: Colors.transparent,
                ),
              ),

              // Clear button
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_hasSignature || _controller.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: _clearSignature,
                        tooltip: 'Xóa',
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surface,
                          foregroundColor: AppColors.error,
                        ),
                      ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.check, size: 20),
                      onPressed: _saveSignature,
                      tooltip: 'Lưu chữ ký',
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        foregroundColor: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),

              // Placeholder text
              if (_controller.isEmpty && widget.initialSignature == null)
                const Positioned.fill(
                  child: Center(
                    child: Text(
                      'Ký tên tại đây',
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
