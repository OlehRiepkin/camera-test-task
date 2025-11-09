import 'package:flutter/material.dart';

class RecordButton extends StatelessWidget {
  const RecordButton({
    required this.isRecording,
    required this.onTap,
    super.key,
  });

  final bool isRecording;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const size = 60.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: Colors.white, width: 4),
        ),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isRecording ? size / 3 : size,
            height: isRecording ? size / 3 : size,
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(isRecording ? 4 : size),
            ),
          ),
        ),
      ),
    );
  }
}
