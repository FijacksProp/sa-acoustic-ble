import 'dart:async';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class AutoFaceCaptureResult {
  const AutoFaceCaptureResult({
    required this.base64Image,
    required this.filePath,
    required this.brightness,
  });

  final String base64Image;
  final String filePath;
  final double brightness;
}

class AutoFaceCaptureScreen extends StatefulWidget {
  const AutoFaceCaptureScreen({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  State<AutoFaceCaptureScreen> createState() => _AutoFaceCaptureScreenState();
}

class _AutoFaceCaptureScreenState extends State<AutoFaceCaptureScreen> {
  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableLandmarks: true,
    ),
  );

  CameraController? _controller;
  bool _initializing = true;
  bool _processingFrame = false;
  bool _capturing = false;
  String? _error;
  String _status = 'Align your face with the guide.';
  int _stableFrames = 0;
  int _frameCounter = 0;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    unawaited(_controller?.dispose());
    _detector.close();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final selected = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      await controller.initialize();
      await controller.startImageStream(_processFrame);
      if (!mounted) {
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _initializing = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _processFrame(CameraImage image) async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _processingFrame ||
        _capturing) {
      return;
    }
    _frameCounter += 1;
    if (_frameCounter % 4 != 0) {
      return;
    }

    _processingFrame = true;
    try {
      final inputImage = _toInputImage(controller, image);
      if (inputImage == null) {
        return;
      }
      final faces = await _detector.processImage(inputImage);
      final brightness = _estimateBrightness(image);
      if (faces.length != 1) {
        _stableFrames = 0;
        _setStatus(
          faces.isEmpty ? 'No face detected yet.' : 'Only one face should be in view.',
        );
        return;
      }

      final readiness = _evaluateFaceReadiness(
        image: image,
        face: faces.first,
        brightness: brightness,
      );
      if (!readiness.ready) {
        _stableFrames = 0;
        _setStatus(readiness.message);
        return;
      }

      _stableFrames += 1;
      _setStatus('Face locked. Hold steady...');
      if (_stableFrames >= 3) {
        await _captureStill(brightness);
      }
    } catch (_) {
      _stableFrames = 0;
    } finally {
      _processingFrame = false;
    }
  }

  void _setStatus(String value) {
    if (!mounted) {
      return;
    }
    setState(() {
      _status = value;
    });
  }

  Future<void> _captureStill(double brightness) async {
    final controller = _controller;
    if (controller == null || _capturing) {
      return;
    }

    _capturing = true;
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      final photo = await controller.takePicture();
      final bytes = await photo.readAsBytes();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(
        AutoFaceCaptureResult(
          base64Image: base64Encode(bytes),
          filePath: photo.path,
          brightness: brightness,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Automatic capture could not be completed. Check camera permission and try again.';
      });
    } finally {
      _capturing = false;
    }
  }

  InputImage? _toInputImage(CameraController controller, CameraImage image) {
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    final rotation = InputImageRotationValue.fromRawValue(
      controller.description.sensorOrientation,
    );
    if (format == null || rotation == null) {
      return null;
    }

    final writeBuffer = WriteBuffer();
    for (final plane in image.planes) {
      writeBuffer.putUint8List(plane.bytes);
    }
    final bytes = writeBuffer.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  double _estimateBrightness(CameraImage image) {
    final luminance = image.planes.first.bytes;
    if (luminance.isEmpty) {
      return 0;
    }
    final step = (luminance.length / 180).floor().clamp(1, luminance.length);
    var total = 0;
    var count = 0;
    for (var index = 0; index < luminance.length; index += step) {
      total += luminance[index];
      count += 1;
    }
    return count == 0 ? 0 : total / count;
  }

  _Readiness _evaluateFaceReadiness({
    required CameraImage image,
    required Face face,
    required double brightness,
  }) {
    final widthRatio = face.boundingBox.width / image.width;
    final heightRatio = face.boundingBox.height / image.height;
    final centerX = face.boundingBox.center.dx / image.width;
    final centerY = face.boundingBox.center.dy / image.height;
    final yaw = face.headEulerAngleY?.abs() ?? 0;
    final roll = face.headEulerAngleZ?.abs() ?? 0;

    if (brightness < 85) {
      return const _Readiness(false, 'Need a brighter view before capture.');
    }
    if (widthRatio < 0.22 || heightRatio < 0.22) {
      return const _Readiness(false, 'Move a little closer to the camera.');
    }
    if ((centerX - 0.5).abs() > 0.18 || (centerY - 0.5).abs() > 0.2) {
      return const _Readiness(false, 'Center your face inside the guide.');
    }
    if (yaw > 16 || roll > 12) {
      return const _Readiness(false, 'Keep your face straight for capture.');
    }
    return const _Readiness(true, 'Face is ready.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(widget.subtitle),
                    ),
                    Expanded(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_controller != null) CameraPreview(_controller!),
                          Container(
                            width: 240,
                            height: 320,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white, width: 3),
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            _status,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _capturing
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _Readiness {
  const _Readiness(this.ready, this.message);

  final bool ready;
  final String message;
}
