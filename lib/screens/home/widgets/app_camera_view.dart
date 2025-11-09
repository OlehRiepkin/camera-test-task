import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:camera_test_task/screens/home/widgets/record_button.dart';
import 'package:camera_test_task/utils/utils.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_exif_rotation/flutter_exif_rotation.dart';
import 'package:flutter_image_gallery_saver/flutter_image_gallery_saver.dart';
import 'package:image_picker/image_picker.dart';

class AppCameraView extends StatefulWidget {
  const AppCameraView({required this.cameras, super.key});

  final List<CameraDescription> cameras;

  @override
  State<AppCameraView> createState() => _AppCameraViewState();
}

class _AppCameraViewState extends State<AppCameraView> {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  bool _isRecording = false;
  CameraLensDirection _currentLensDirection = CameraLensDirection.back;
  XFile? _overlayImageFile;

  @override
  void initState() {
    super.initState();

    final camera = widget.cameras.firstWhereOrNull(
      (camera) => camera.lensDirection == _currentLensDirection,
    );

    if (camera != null) {
      unawaited(_setupCamera(camera));
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        ErrorHandler.showError(context, _getNoCameraErrorMessage(_currentLensDirection));
      });
    }
  }

  @override
  void dispose() {
    unawaited(_controller?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (!_isCameraInitialized || controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final overlayImageFile = _overlayImageFile;

    return Stack(
      children: [
        CameraPreview(controller),
        if (overlayImageFile != null)
          Opacity(
            opacity: 0.8,
            child: Image.file(File(overlayImageFile.path)),
          ),
        if (_isCameraInitialized) _buildControls(),
      ],
    );
  }

  Widget _buildControls() {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                IconButton(
                  onPressed: _onSwitchCameraTap,
                  icon: const Icon(Icons.cameraswitch, color: Colors.white),
                ),
                IconButton(
                  onPressed: _onManageOverlayTap,
                  icon: Icon(
                    _overlayImageFile == null ? Icons.add_circle_outline : Icons.remove_circle_outline,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: RecordButton(isRecording: _isRecording, onTap: _onRecordTap),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: _onTakePhotoTap,
                icon: const Icon(Icons.image, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
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

  Future<void> _onSwitchCameraTap() async {
    final lensDirection = _currentLensDirection == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;

    final camera = widget.cameras.firstWhereOrNull(
      (camera) => camera.lensDirection == lensDirection,
    );

    if (camera != null) {
      setState(() {
        _isCameraInitialized = false;
        _currentLensDirection = lensDirection;
      });

      await _setupCamera(camera);
    } else {
      ErrorHandler.showError(context, _getNoCameraErrorMessage(lensDirection));
    }
  }

  String _getNoCameraErrorMessage(CameraLensDirection lensDirection) => switch (lensDirection) {
    CameraLensDirection.front => 'No front camera found.',
    CameraLensDirection.back => 'No back camera found.',
    CameraLensDirection.external => 'No external camera found.',
  };

  Future<void> _onManageOverlayTap() async {
    if (_overlayImageFile != null) {
      setState(() {
        _overlayImageFile = null;
      });
      return;
    }

    final picker = ImagePicker();
    XFile? pickedFile;

    try {
      pickedFile = await picker.pickImage(source: ImageSource.gallery);
    } on Exception catch (e) {
      if (mounted) ErrorHandler.showError(context, 'Pick image error: $e');
    }

    setState(() {
      _overlayImageFile = pickedFile;
    });
  }

  void _onRecordTap() {
    setState(() {
      _isRecording = !_isRecording;
    });
  }

  Future<void> _onTakePhotoTap() async {
    final controller = _controller;
    if (controller == null || !_isCameraInitialized || controller.value.isTakingPicture) {
      return;
    }

    try {
      final xFile = await controller.takePicture();
      final rotatedImageFile = await FlutterExifRotation.rotateImage(path: xFile.path);
      final bytes = await rotatedImageFile.readAsBytes();

      await FlutterImageGallerySaver.saveImage(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo saved to gallery'), backgroundColor: Colors.green),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, 'Camera error: $e');
      }
    }
  }
}
