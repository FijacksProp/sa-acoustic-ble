import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';

class FaceVerificationResult {
  const FaceVerificationResult({
    required this.score,
    required this.matched,
    required this.reason,
  });

  final double score;
  final bool matched;
  final String reason;
}

class FaceVerificationService {
  Future<FaceVerificationResult> compareFaces({
    required String enrolledBase64,
    required String liveBase64,
  }) async {
    final detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableLandmarks: true,
      ),
    );

    File? enrolledFile;
    File? liveFile;
    try {
      enrolledFile = await _writeTempImage('enrolled_face', enrolledBase64);
      liveFile = await _writeTempImage('live_face', liveBase64);

      final enrolledFaces = await detector.processImage(
        InputImage.fromFilePath(enrolledFile.path),
      );
      final liveFaces = await detector.processImage(
        InputImage.fromFilePath(liveFile.path),
      );

      if (enrolledFaces.length != 1 || liveFaces.length != 1) {
        return const FaceVerificationResult(
          score: 0,
          matched: false,
          reason: 'A single clear face was not detected in both images.',
        );
      }

      final score = _computeSimilarity(enrolledFaces.first, liveFaces.first);
      return FaceVerificationResult(
        score: score,
        matched: score >= 0.78,
        reason: score >= 0.78
            ? 'Live face matched the enrolled face strongly enough.'
            : 'Live face did not match the enrolled face strongly enough.',
      );
    } catch (error) {
      return FaceVerificationResult(
        score: 0,
        matched: false,
        reason: 'Face comparison failed: $error',
      );
    } finally {
      await detector.close();
      if (enrolledFile != null && await enrolledFile.exists()) {
        await enrolledFile.delete();
      }
      if (liveFile != null && await liveFile.exists()) {
        await liveFile.delete();
      }
    }
  }

  Future<File> _writeTempImage(String prefix, String base64Image) async {
    final tempDir = await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}${Platform.pathSeparator}$prefix-${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(base64Decode(base64Image));
    return file;
  }

  double _computeSimilarity(Face enrolled, Face live) {
    final landmarkTypes = <FaceLandmarkType>[
      FaceLandmarkType.leftEye,
      FaceLandmarkType.rightEye,
      FaceLandmarkType.noseBase,
      FaceLandmarkType.leftCheek,
      FaceLandmarkType.rightCheek,
      FaceLandmarkType.bottomMouth,
    ];

    final distances = <double>[];
    for (final type in landmarkTypes) {
      final enrolledPoint = enrolled.landmarks[type]?.position;
      final livePoint = live.landmarks[type]?.position;
      if (enrolledPoint == null || livePoint == null) {
        continue;
      }
      final enrolledNormalized = _normalize(enrolled.boundingBox, enrolledPoint);
      final liveNormalized = _normalize(live.boundingBox, livePoint);
      distances.add((enrolledNormalized - liveNormalized).distance);
    }

    if (distances.length < 3) {
      return 0.25;
    }

    final averageDistance =
        distances.reduce((a, b) => a + b) / distances.length;
    final landmarkScore = _clamp01(1 - (averageDistance * 2.4));

    final enrolledAspect =
        enrolled.boundingBox.width / math.max(enrolled.boundingBox.height, 1);
    final liveAspect =
        live.boundingBox.width / math.max(live.boundingBox.height, 1);
    final ratioScore = _clamp01(1 - (enrolledAspect - liveAspect).abs() / 0.35);

    final yawScore = _clamp01(
      1 -
          ((enrolled.headEulerAngleY ?? 0) - (live.headEulerAngleY ?? 0)).abs() /
              30,
    );
    final rollScore = _clamp01(
      1 -
          ((enrolled.headEulerAngleZ ?? 0) - (live.headEulerAngleZ ?? 0)).abs() /
              25,
    );

    return _clamp01(
      (landmarkScore * 0.7) +
          (ratioScore * 0.15) +
          (((yawScore + rollScore) / 2) * 0.15),
    );
  }

  Offset _normalize(Rect bounds, math.Point<int> point) {
    final safeWidth = bounds.width == 0 ? 1.0 : bounds.width;
    final safeHeight = bounds.height == 0 ? 1.0 : bounds.height;
    return Offset(
      (point.x - bounds.left) / safeWidth,
      (point.y - bounds.top) / safeHeight,
    );
  }

  double _clamp01(double value) {
    if (value < 0) {
      return 0;
    }
    if (value > 1) {
      return 1;
    }
    return value;
  }
}
