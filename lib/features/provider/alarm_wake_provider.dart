import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class AlarmWakeProvider extends ChangeNotifier {
  CameraController? _cameraController;
  CameraDescription? _camera;
  late final FaceDetector _faceDetector;

  bool _isAwake = false;
  bool _isDisposed = false;
  bool _isProcessing = false;

  String? _errorMessage;
  Rect? _faceRect;

  int _faceDetectedCount = 0;

  // ================= GETTERS =================

  CameraController? get cameraController => _cameraController;
  bool get isAwake => _isAwake;
  String? get errorMessage => _errorMessage;
  Rect? get faceRect => _faceRect;
  int get faceDetectedCount => _faceDetectedCount;

  // ================= CONSTRUCTOR =================

  AlarmWakeProvider() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableTracking: false,
        performanceMode: FaceDetectorMode.fast,
        minFaceSize: 0.1,
      ),
    );
    _initCamera();
  }

  // ================= CAMERA INIT =================

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        _errorMessage = 'No cameras found';
        notifyListeners();
        return;
      }

      _camera = cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        _camera!,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();
      if (_isDisposed) return;

      notifyListeners();

      await Future.delayed(const Duration(milliseconds: 300));
      await _cameraController!.startImageStream(_processImage);
    } catch (e) {
      _errorMessage = 'Camera error: $e';
      notifyListeners();
    }
  }

  // ================= IMAGE PROCESSING =================

  int _frameCount = 0;

  Future<void> _processImage(CameraImage image) async {
    _frameCount++;

    // Process every 15th frame (~2 per second)
    if (_frameCount % 15 != 0) return;
    if (_isProcessing || _isAwake || _isDisposed) return;

    _isProcessing = true;

    try {
      final inputImage = _buildInputImage(image);
      if (inputImage == null) {
        _isProcessing = false;
        return;
      }

      final faces = await _faceDetector.processImage(inputImage);
      if (_isDisposed) return;

      if (faces.isNotEmpty) {
        final face = faces.first;
        _faceRect = face.boundingBox;

        // Check if eyes are open
        final leftEye = face.leftEyeOpenProbability ?? 0.0;
        final rightEye = face.rightEyeOpenProbability ?? 0.0;
        final eyesOpen = (leftEye + rightEye) / 2 > 0.5;

        if (eyesOpen) {
          _faceDetectedCount++;
          debugPrint('✅ Eyes open! Count: $_faceDetectedCount');

          // Need 3 detections with open eyes
          if (_faceDetectedCount >= 3) {
            _isAwake = true;
            debugPrint('🎉 USER AWAKE!');
          }
        }
      } else {
        _faceRect = null;
      }
    } catch (e) {
      debugPrint('⚠️ Error: $e');
    } finally {
      _isProcessing = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  // ================= INPUT IMAGE BUILDER =================

  InputImage? _buildInputImage(CameraImage image) {
    if (_camera == null) return null;

    try {
      final WriteBuffer buffer = WriteBuffer();
      for (final plane in image.planes) {
        buffer.putUint8List(plane.bytes);
      }

      final bytes = buffer.done().buffer.asUint8List();

      final rotation = _camera!.lensDirection == CameraLensDirection.front
          ? InputImageRotation.rotation270deg
          : InputImageRotation.rotation90deg;

      final format = image.format.group == ImageFormatGroup.yuv420
          ? InputImageFormat.yuv420
          : InputImageFormat.nv21;

      final metadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      );

      return InputImage.fromBytes(bytes: bytes, metadata: metadata);
    } catch (e) {
      debugPrint('❌ InputImage error: $e');
      return null;
    }
  }

  // ================= DISPOSE =================

  @override
  void dispose() {
    _isDisposed = true;

    try {
      if (_cameraController?.value.isStreamingImages == true) {
        _cameraController?.stopImageStream();
      }
      _cameraController?.dispose();
      _faceDetector.close();
    } catch (e) {
      debugPrint('Dispose error: $e');
    }

    super.dispose();
  }
}