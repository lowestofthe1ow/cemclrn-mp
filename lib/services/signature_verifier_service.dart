import 'dart:typed_data';
import 'dart:math';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_pytorch_lite/flutter_pytorch_lite.dart';
import 'package:path_provider/path_provider.dart';

class SignatureVerifierService {
  Module? _module;
  
  // Constants from your Python script
  static const double TRAIN_STD = 0.07225848734378815;
  static const double TRAIN_MEAN = 0.0; 
  static const double D_THRESHOLD = 0.20001120865345;
  static const int INPUT_WIDTH = 220; 
  static const int INPUT_HEIGHT = 155;

  Future<void> loadModel() async {
    try {
      _module = await FlutterPytorchLite.load('assets/base_model.ptl');
      print("Model loaded successfully from assets");
    } catch (e) {
      print("Failed to load from assets directly: $e");
      
      try {
        final Directory tempDir = await getTemporaryDirectory();
        final String modelPath = '${tempDir.path}/base_model.ptl';
        final File modelFile = File(modelPath);

        // Copy from assets to temp directory
        final ByteData data = await rootBundle.load('assets/base_model.ptl');
        final List<int> bytes = data.buffer.asUint8List();
        await modelFile.writeAsBytes(bytes);

        print("Model copied to: $modelPath");
        
        _module = await FlutterPytorchLite.load(modelPath);
        print("Model loaded successfully from temp directory");
      } catch (e2) {
        print("Failed to load model: $e2");
        rethrow;
      }
    }
  }

  /// Replicates: TRANSFORMS_EVAL
  Float32List _preprocess(Uint8List imageBytes) {
    // 1. Decode Image
    img.Image? original = img.decodeImage(imageBytes);
    if (original == null) throw Exception("Could not decode image");

    // 2. Grayscale (x.convert("L"))
    img.Image grayscale = img.grayscale(original);

    // 3. Resize (transform(x))
    img.Image resized = img.copyResize(
      grayscale, 
      width: INPUT_WIDTH, 
      height: INPUT_HEIGHT,
      interpolation: img.Interpolation.linear 
    );

    // 4. ToTensor + Normalize
    final floatList = Float32List(1 * 1 * INPUT_HEIGHT * INPUT_WIDTH);
    int index = 0;

    for (int y = 0; y < INPUT_HEIGHT; y++) {
      for (int x = 0; x < INPUT_WIDTH; x++) {
        double pixelVal = resized.getPixel(x, y).r / 255.0;
        double normalizedVal = (pixelVal - TRAIN_MEAN) / TRAIN_STD;
        floatList[index++] = normalizedVal;
      }
    }
    return floatList;
  }

  /// Replicates: F.pairwise_distance(y1, y2)
  double _calculateDistance(List<double> v1, List<double> v2) {
    double sum = 0.0;
    for (int i = 0; i < v1.length; i++) {
      double diff = v1[i] - v2[i];
      sum += diff * diff;
    }
    return sqrt(sum);
  }

  /// Main Inference Function
  Future<Map<String, dynamic>> verify(Uint8List bytes1, Uint8List bytes2) async {
    if (_module == null) await loadModel();

    // 1. Preprocess both images
    Float32List input1 = _preprocess(bytes1);
    Float32List input2 = _preprocess(bytes2);

    // 2. Define Shape [Batch, Channel, Height, Width]
    var shape = Int64List.fromList([1, 1, INPUT_HEIGHT, INPUT_WIDTH]);

    // 3. Create Tensors
    Tensor tensor1 = Tensor.fromBlobFloat32(input1, shape);
    Tensor tensor2 = Tensor.fromBlobFloat32(input2, shape);

    IValue result1 = await _module!.forward([IValue.from(tensor1)]);
    IValue result2 = await _module!.forward([IValue.from(tensor2)]);

    Tensor t1 = result1.toTensor();
    Tensor t2 = result2.toTensor();

    List<double> vector1 = List<double>.from(t1.dataAsFloat32List);
    List<double> vector2 = List<double>.from(t2.dataAsFloat32List);

    // 4. Calculate Distance
    double distance = _calculateDistance(vector1, vector2);

    // 5. Threshold
    bool isGenuine = distance <= D_THRESHOLD;

    return {
      "isGenuine": isGenuine,
      "distance": distance,
      "confidence": isGenuine ? (1.0 - distance) : distance
    };
  }
}
