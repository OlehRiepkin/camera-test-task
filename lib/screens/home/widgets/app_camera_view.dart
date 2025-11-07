import 'package:camera/camera.dart';
import 'package:camera_test_task/utils/utils.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class AppCameraView extends StatefulWidget {
  const AppCameraView({required this.cameras, super.key});

  final List<CameraDescription> cameras;

  @override
  State<AppCameraView> createState() => _AppCameraViewState();
}

class _AppCameraViewState extends State<AppCameraView> {
  CameraController? _controller;
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();

    final camera = widget.cameras.firstWhereOrNull(
      (camera) => camera.lensDirection == CameraLensDirection.back,
    );

    if (camera != null) {
      _setupCamera(camera);
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        ErrorHandler.showError(context, 'No back camera found.');
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (!_isCameraInitialized || controller == null) {
      return SizedBox.shrink();
    }

    return CameraPreview(controller);
  }

  Future<void> _setupCamera(CameraDescription camera) async {
    await _controller?.dispose();

    _controller = CameraController(camera, ResolutionPreset.high);

    try {
      await _controller!.initialize();
      setState(() {
        _isCameraInitialized = true;
      });
    } on CameraException catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, 'Camera error: ${e.description}');
      }
    }
  }
}
