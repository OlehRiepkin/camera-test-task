import 'dart:async';

import 'package:camera/camera.dart';
import 'package:camera_test_task/screens/home/widgets/widgets.dart';
import 'package:camera_test_task/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

enum HomeStatus { initial, noPermission, error, ready }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  HomeStatus _homeStatus = HomeStatus.initial;

  List<CameraDescription>? _cameras;
  String? _errorMessage;
  var _needReinitializeCamera = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    unawaited(_initializeCamera());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text(
          'Camera test task',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: switch (_homeStatus) {
        HomeStatus.initial => _buildInitialUI(),
        HomeStatus.noPermission => _buildNoPermissionUI(),
        HomeStatus.error => _buildErrorUI(),
        HomeStatus.ready => _buildReadyUI(),
      },
    );
  }

  Widget _buildInitialUI() => const Center(child: CircularProgressIndicator());

  Widget _buildNoPermissionUI() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: [
        const Text(
          'No camera or microphone permission. Please grant permission in app settings.',
          textAlign: TextAlign.center,
        ),
        ElevatedButton(
          onPressed: _onOpenAppSettingsTap,
          child: const Text('Open App Settings'),
        ),
      ],
    ),
  );

  Widget _buildErrorUI() => Center(child: Text(_errorMessage ?? 'An error occurred'));

  Widget _buildReadyUI() {
    final cameras = _cameras;
    if (cameras == null || cameras.isEmpty) {
      return _buildErrorUI();
    }

    return Center(child: AppCameraView(cameras: cameras));
  }

  Future<void> _initializeCamera() async {
    final permissionsStatus = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    if (!permissionsStatus[Permission.camera]!.isGranted || !permissionsStatus[Permission.microphone]!.isGranted) {
      setState(() {
        _homeStatus = HomeStatus.noPermission;
      });
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() {
          _homeStatus = HomeStatus.error;
          _errorMessage = 'Camera not available on this device.';
        });
        return;
      }

      setState(() {
        _homeStatus = HomeStatus.ready;
      });
    } on CameraException catch (e) {
      setState(() {
        _homeStatus = HomeStatus.error;
        _errorMessage = 'Error: ${e.description}';
      });
    }
  }

  Future<void> _onOpenAppSettingsTap() async {
    try {
      final isOpened = await openAppSettings();

      if (isOpened) {
        _needReinitializeCamera = true;
        return;
      }

      if (mounted) {
        ErrorHandler.showError(context, 'Failed to open app settings.');
      }
    } on Exception catch (e) {
      if (mounted) {
        ErrorHandler.showError(
          context,
          'Failed to open app settings. $e',
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed && _needReinitializeCamera) {
      _needReinitializeCamera = false;
      unawaited(_initializeCamera());
    }
  }
}
