import 'dart:typed_data';
import 'package:flutter/material.dart';

typedef OnPickSignature = void Function(Uint8List bytes);

class SignatureGallery extends StatelessWidget {
  final List<Uint8List> saved;
  final OnPickSignature onPick;
  const SignatureGallery({
    super.key,
    required this.saved,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    if (saved.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(8),
        itemCount: saved.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => onPick(saved[i]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(saved[i]),
          ),
        ),
      ),
    );
  }
}
