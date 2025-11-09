import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:camera_test_task/screens/home/widgets/record_button.dart';
import 'package:camera_test_task/screens/home/widgets/widgets.dart';
import 'package:camera_test_task/utils/utils.dart';
import 'package:camera_test_task/widgets/widgets.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_exif_rotation/flutter_exif_rotation.dart';
import 'package:flutter_image_gallery_saver/flutter_image_gallery_saver.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

class AppCameraView extends StatefulWidget {
  const AppCameraView({required this.cameras, super.key});

  final List<CameraDescription> cameras;

  @override
  State<AppCameraView> createState() => _AppCameraViewState();
}

class _AppCameraViewState extends State<AppCameraView> with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  bool _isRecording = false;
  CameraLensDirection _currentLensDirection = CameraLensDirection.back;
  XFile? _overlayImageFile;
  bool _overlaySelection = false;

  bool get isTakingPicture => _controller?.value.isTakingPicture ?? false;
  bool get isRecordingVideo => _controller?.value.isRecordingVideo ?? false;
  bool get isCapturing => isTakingPicture || isRecordingVideo;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

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
    WidgetsBinding.instance.removeObserver(this);

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
            child: Image.file(
              File(overlayImageFile.path),
              fit: BoxFit.cover,
            ),
          ),
        if (_isRecording) const Positioned(top: 16, right: 16, child: RecordingIndicator()),
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
                Disabled(
                  disabled: isCapturing,
                  child: IconButton(
                    onPressed: _onSwitchCameraTap,
                    icon: const Icon(Icons.cameraswitch, color: Colors.white),
                  ),
                ),
                Disabled(
                  disabled: isCapturing && _overlayImageFile == null,
                  child: IconButton(
                    onPressed: _onManageOverlayTap,
                    icon: Icon(
                      _overlayImageFile == null ? Icons.add_circle_outline : Icons.remove_circle_outline,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Disabled(
                disabled: isTakingPicture,
                child: RecordButton(
                  isRecording: _isRecording,
                  onTap: _onRecordTap,
                ),
              ),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Disabled(
                disabled: isCapturing,
                child: IconButton(
                  onPressed: _onTakePhotoTap,
                  icon: const Icon(Icons.image, color: Colors.white),
                ),
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

    _overlaySelection = true;
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

  Future<void> _onRecordTap() async {
    if (_isRecording) {
      await _stopVideoRecording();
    } else {
      await _startVideoRecording();
    }
  }

  Future<void> _startVideoRecording() async {
    final controller = _controller;
    if (controller == null || !_isCameraInitialized || _isRecording) return;

    try {
      await controller.startVideoRecording();
      setState(() {
        _isRecording = true;
      });
    } on CameraException catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, 'Start video recording error: ${e.description}');
      }
    }
  }

  Future<void> _stopVideoRecording({bool saveFile = true}) async {
    final controller = _controller;
    if (controller == null || !_isRecording) return;

    try {
      final xFile = await controller.stopVideoRecording();
      setState(() {
        _isRecording = false;
      });

      if (!saveFile) {
        return;
      }

      await FlutterImageGallerySaver.saveFile(xFile.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video saved to gallery'), backgroundColor: Colors.green),
        );
      }
    } on CameraException catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, 'Stop video recording error: ${e.description}');
      }
    }
  }

  Future<void> _onTakePhotoTap() async {
    final controller = _controller;
    if (controller == null || !_isCameraInitialized || controller.value.isTakingPicture) {
      return;
    }

    try {
      final xFile = await controller.takePicture();
      final rotatedImageFile = await FlutterExifRotation.rotateImage(path: xFile.path);
      var bytes = await rotatedImageFile.readAsBytes();

      if (controller.description.lensDirection == CameraLensDirection.front) {
        final originalImage = img.decodeImage(bytes);
        if (originalImage != null) {
          final mirrored = img.flipHorizontal(originalImage);
          bytes = Uint8List.fromList(img.encodeJpg(mirrored));
        }
      }

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      if (_overlaySelection) {
        return;
      }

      unawaited(_stopVideoRecording(saveFile: false).whenComplete(controller.dispose));
      return;
    }

    if (state == AppLifecycleState.resumed) {
      if (_overlaySelection) {
        _overlaySelection = false;
        return;
      }

      final camera = widget.cameras.firstWhereOrNull(
        (camera) => camera.lensDirection == _currentLensDirection,
      );
      if (camera != null) {
        unawaited(_setupCamera(camera));
      }
    }
  }
}
