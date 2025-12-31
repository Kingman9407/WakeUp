import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceWakeDetector {
  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true, // eye open prob
      enableTracking: true,
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  Future<bool> isUserAwake(InputImage image) async {
    final faces = await _detector.processImage(image);

    if (faces.isEmpty) return false;

    final face = faces.first;

    final leftEye = face.leftEyeOpenProbability ?? 0;
    final rightEye = face.rightEyeOpenProbability ?? 0;

    final pitch = face.headEulerAngleX ?? 0;

    final eyesOpen = leftEye > 0.75 && rightEye > 0.75;
    final headStraight = pitch > -10 && pitch < 10;

    return eyesOpen && headStraight;
  }

  void dispose() {
    _detector.close();
  }
}
