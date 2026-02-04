import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:alz_mate/core/services/firestore_service.dart';

class FaceRecognitionService {
  // Singleton pattern
  static final FaceRecognitionService _instance =
      FaceRecognitionService._internal();
  factory FaceRecognitionService() => _instance;
  FaceRecognitionService._internal();

  FaceDetector? _faceDetector;
  Interpreter? _tfliteInterpreter;
  bool _isInitialized = false;
  bool _tfliteLoaded = false;
  final List<List<double>> _knownFaceEncodings = [];
  final List<String> _knownFaceNames = [];
  final List<String> _knownFaceIds = [];
  final List<String> _knownFaceRelationships = [];
  final FirestoreService _firestoreService = FirestoreService();
  
  // MobileFaceNet model constants
  static const int _inputSize = 112; // MobileFaceNet expects 112x112 input
  static const int _embeddingSize = 192; // MobileFaceNet outputs 192-dimensional embeddings (model-specific)

  // Stream controller for face recognition events
  final _faceRecognitionController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Getters
  Stream<Map<String, dynamic>> get faceRecognitionStream =>
      _faceRecognitionController.stream;
  bool get isAvailable => _isInitialized;

  // Initialize the face recognition service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Configure face detector options (for face detection)
      final options = FaceDetectorOptions(
        enableClassification: true,
        enableLandmarks: true,
        enableContours: true,
        enableTracking: false,
        minFaceSize: 0.1,
        performanceMode: FaceDetectorMode.accurate,
      );

      _faceDetector = FaceDetector(options: options);
      
      // Load TFLite model for face embedding extraction
      await _loadTFLiteModel();
      
      _isInitialized = true;
      print('Face recognition service initialized with Google ML Kit and TFLite MobileFaceNet');
    } catch (e) {
      print('Error initializing face recognition: $e');
      throw Exception('Failed to initialize face recognition: $e');
    }
  }
  
  // Load TFLite MobileFaceNet model
  Future<void> _loadTFLiteModel() async {
    try {
      if (_tfliteLoaded && _tfliteInterpreter != null) {
        return;
      }
      
      print('Loading TFLite MobileFaceNet model...');
      
      // Load model from assets
      final modelPath = 'assets/mobilefacenet.tflite';
      
      // Create interpreter options for better performance
      final interpreterOptions = InterpreterOptions()
        ..threads = 4;
      
      // Load the model (fromAsset returns Future, so we need to await)
      _tfliteInterpreter = await Interpreter.fromAsset(
        modelPath,
        options: interpreterOptions,
      );
      
      // Get input and output tensor shapes
      final inputTensor = _tfliteInterpreter!.getInputTensor(0);
      final outputTensor = _tfliteInterpreter!.getOutputTensor(0);
      
      print('TFLite model loaded successfully');
      print('Input shape: ${inputTensor.shape}');
      print('Output shape: ${outputTensor.shape}');
      
      _tfliteLoaded = true;
    } catch (e, stackTrace) {
      print('Error loading TFLite model: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Failed to load TFLite model: $e');
    }
  }

  // Initialize the service (alias for initialize)
  Future<void> init() async {
    await initialize();
  }

  // Detect faces from an image file path
  Future<List<Map<String, dynamic>>> detectFacesFromImage(
    String imagePath,
  ) async {
    try {
      if (!_isInitialized) await initialize();

      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist');
      }

      final inputImage = InputImage.fromFilePath(imagePath);
      final faces = await _faceDetector!.processImage(inputImage);

    final List<Map<String, dynamic>> detectedFaces = [];

      for (final face in faces) {
      detectedFaces.add({
          'id': 'face_${DateTime.now().millisecondsSinceEpoch}_${faces.indexOf(face)}',
        'boundingBox': {
            'x': face.boundingBox.left.toDouble(),
            'y': face.boundingBox.top.toDouble(),
            'width': face.boundingBox.width.toDouble(),
            'height': face.boundingBox.height.toDouble(),
          },
          'headEulerAngleY': face.headEulerAngleY,
          'headEulerAngleZ': face.headEulerAngleZ,
          'smilingProbability': face.smilingProbability,
          'leftEyeOpenProbability': face.leftEyeOpenProbability,
          'rightEyeOpenProbability': face.rightEyeOpenProbability,
      });
    }

    // Emit event to stream
    _faceRecognitionController.add({
      'event': 'faces_detected',
      'faces': detectedFaces,
      'timestamp': DateTime.now().toIso8601String(),
    });

    return detectedFaces;
    } catch (e) {
      print('Error detecting faces: $e');
      throw Exception('Failed to detect faces: $e');
    }
  }

  // Add a known face to the database
  Future<String> addKnownFace({
    required File imageFile,
    required String name,
    required String relationship,
    required String userId,
    String? imageUrl,
  }) async {
    try {
      if (!_isInitialized) await initialize();

      // Validate inputs
      if (name.trim().isEmpty) {
        throw Exception('Name cannot be empty');
      }

      if (userId.trim().isEmpty) {
        throw Exception('User ID cannot be empty');
      }

      // Validate image first
      final validation = await validateFaceImage(imageFile);
      final isValid = validation['isValid'] as bool? ?? false;
      if (!isValid) {
        final reason = validation['reason']?.toString() ?? 'Invalid image';
        throw Exception(reason);
      }

      // Generate a unique ID for this face
      final faceId = '${userId}_${DateTime.now().millisecondsSinceEpoch}';

      // Process the image and extract face encoding
      final encoding = await _extractFaceEncoding(imageFile);

      if (encoding == null || encoding.isEmpty) {
        throw Exception('Failed to extract face encoding. No face detected in the image.');
      }

      // Validate encoding
      if (encoding.length < 10) {
        throw Exception('Invalid face encoding extracted');
      }

      final trimmedName = name.trim();
      final trimmedRelationship = relationship.trim();

      _knownFaceEncodings.add(encoding);
      _knownFaceNames.add(trimmedName);
      _knownFaceIds.add(faceId);
      _knownFaceRelationships.add(trimmedRelationship);

      // Save to local storage (for offline access)
      try {
        await _saveFaceData(faceId, trimmedName, trimmedRelationship, encoding, userId);
      } catch (e) {
        print('Warning: Failed to save to local storage: $e');
        // Continue even if local save fails
      }

      // Save to Firebase Firestore (for sync across devices)
      try {
        print('Saving face embedding to Firebase: $faceId for user: $userId');
        await _firestoreService.saveFaceEmbedding(
          faceId: faceId,
          userId: userId,
          name: trimmedName,
          relationship: trimmedRelationship,
          embedding: encoding,
          imageUrl: imageUrl?.trim(),
        );
        print('✓ Face embedding successfully saved to Firebase: $faceId');
      } catch (e, stackTrace) {
        print('✗ Error saving face embedding to Firebase: $e');
        print('Stack trace: $stackTrace');
        print('Face saved locally only as backup');
        // Continue even if Firebase save fails - local storage is backup
      }

      // Emit event
      _faceRecognitionController.add({
        'event': 'face_added',
        'faceId': faceId,
        'name': trimmedName,
        'relationship': trimmedRelationship,
        'timestamp': DateTime.now().toIso8601String(),
      });

      return faceId;
    } catch (e) {
      print('Error adding known face: $e');
      throw Exception('Failed to add known face: ${e.toString()}');
    }
  }

  // Recognize faces in an image
  Future<List<Map<String, dynamic>>> recognizeFaces(File imageFile) async {
    try {
      if (!_isInitialized) await initialize();

      // Check if we have any known faces
      if (_knownFaceEncodings.isEmpty) {
        print('No known faces in database');
        return [];
      }

      final recognizedFaces = <Map<String, dynamic>>[];

      // Extract face encodings from the input image
      final faceEncodings = await _extractAllFaceEncodings(imageFile);
      
      if (faceEncodings.isEmpty) {
        print('No faces detected in the image');
        return [];
      }

      for (final encoding in faceEncodings) {
        if (encoding.isEmpty) continue;
        
        final match = await _findBestMatch(encoding);
        if (match != null && match.isNotEmpty) {
          // Get image URL from Firebase if available
          try {
            final faceId = match['id']?.toString();
            if (faceId != null && faceId.isNotEmpty) {
              final faceData = await _firestoreService.getFaceEmbeddingById(faceId);
              if (faceData != null && faceData['imageUrl'] != null) {
                match['imageUrl'] = faceData['imageUrl'].toString();
              }
            }
          } catch (e) {
            print('Error fetching image URL: $e');
            // Continue without image URL
          }
          
          recognizedFaces.add(match);
        }
      }

      // Emit event
      if (recognizedFaces.isNotEmpty) {
        _faceRecognitionController.add({
          'event': 'faces_recognized',
          'faces': recognizedFaces,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }

      return recognizedFaces;
    } catch (e) {
      print('Error recognizing faces: $e');
      throw Exception('Failed to recognize faces: $e');
    }
  }

  // Extract face encoding from an image using TFLite MobileFaceNet
  Future<List<double>?> _extractFaceEncoding(File imageFile) async {
    try {
      if (!_isInitialized) await initialize();
      if (!_tfliteLoaded || _tfliteInterpreter == null) {
        await _loadTFLiteModel();
      }

      // Step 1: Detect face using ML Kit to get bounding box
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final faces = await _faceDetector!.processImage(inputImage);

      if (faces.isEmpty) {
        return null;
      }

      // Use the first detected face
      final face = faces.first;
      final boundingBox = face.boundingBox;

      // Step 2: Load and process image
      final bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      if (image == null) {
        print('Failed to decode image');
        return null;
      }

      // Step 3: Crop face region with some padding
      final padding = 0.2; // 20% padding around face
      final cropX = (boundingBox.left - boundingBox.width * padding).clamp(0, image.width - 1).toInt();
      final cropY = (boundingBox.top - boundingBox.height * padding).clamp(0, image.height - 1).toInt();
      final cropWidth = ((boundingBox.width * (1 + 2 * padding)).clamp(0, image.width - cropX)).toInt();
      final cropHeight = ((boundingBox.height * (1 + 2 * padding)).clamp(0, image.height - cropY)).toInt();

      final croppedImage = img.copyCrop(
        image,
        x: cropX,
        y: cropY,
        width: cropWidth,
        height: cropHeight,
      );

      // Step 4: Resize to 112x112 (MobileFaceNet input size)
      final resizedImage = img.copyResize(
        croppedImage,
        width: _inputSize,
        height: _inputSize,
        interpolation: img.Interpolation.linear,
      );

      // Step 5: Convert to RGB and normalize to [-1, 1] range
      // MobileFaceNet typically expects normalized input in [-1, 1] range
      final inputBuffer = Float32List(_inputSize * _inputSize * 3);
      int index = 0;
      
        for (int y = 0; y < _inputSize; y++) {
          for (int x = 0; x < _inputSize; x++) {
            final pixel = resizedImage.getPixel(x, y);
            final r = pixel.r.toInt();
            final g = pixel.g.toInt();
            final b = pixel.b.toInt();
            
            // Normalize to [-1, 1] range: (pixel / 127.5) - 1.0
            inputBuffer[index++] = (r / 127.5) - 1.0;
            inputBuffer[index++] = (g / 127.5) - 1.0;
            inputBuffer[index++] = (b / 127.5) - 1.0;
          }
      }

      // Step 6: Prepare input tensor (reshape to [1, 112, 112, 3])
      final input = _reshapeInput(inputBuffer, 1, _inputSize, _inputSize, 3);
      
      // Step 7: Prepare output tensor
      final output = List.generate(1, (_) => List.filled(_embeddingSize, 0.0));

      // Step 8: Run inference
      _tfliteInterpreter!.run(input, output);

      // Step 9: Extract and normalize embedding
      final embedding = List<double>.from(output[0]);
      
      // Normalize the embedding vector (L2 normalization)
      return _normalizeEncoding(embedding);
    } catch (e, stackTrace) {
      print('Error extracting face encoding with TFLite: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  // Normalize encoding vector
  List<double> _normalizeEncoding(List<double> encoding) {
    if (encoding.isEmpty) return encoding;

    // Calculate magnitude
    double magnitude = 0.0;
    for (final value in encoding) {
      magnitude += value * value;
    }
    magnitude = sqrt(magnitude);

    if (magnitude == 0.0) return encoding;

    // Normalize
    return encoding.map((value) => value / magnitude).toList();
  }

  // Helper method to reshape Float32List to nested list for TFLite input
  List<List<List<List<double>>>> _reshapeInput(Float32List buffer, int batch, int height, int width, int channels) {
    final result = <List<List<List<double>>>>[];
    int index = 0;
    
    for (int b = 0; b < batch; b++) {
      final batchList = <List<List<double>>>[];
      for (int h = 0; h < height; h++) {
        final rowList = <List<double>>[];
        for (int w = 0; w < width; w++) {
          final channelList = <double>[];
          for (int c = 0; c < channels; c++) {
            channelList.add(buffer[index++]);
          }
          rowList.add(channelList);
        }
        batchList.add(rowList);
      }
      result.add(batchList);
    }
    
    return result;
  }

  // Extract all face encodings from an image using TFLite
  Future<List<List<double>>> _extractAllFaceEncodings(File imageFile) async {
    try {
      if (!_isInitialized) await initialize();
      if (!_tfliteLoaded || _tfliteInterpreter == null) {
        await _loadTFLiteModel();
      }

      final inputImage = InputImage.fromFilePath(imageFile.path);
      final faces = await _faceDetector!.processImage(inputImage);

      if (faces.isEmpty) {
        return [];
      }

      final encodings = <List<double>>[];

      // Load image once
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return [];

      // Process each detected face
      for (final face in faces) {
        final boundingBox = face.boundingBox;

        // Crop face region with padding
        final padding = 0.2;
        final cropX = (boundingBox.left - boundingBox.width * padding).clamp(0, image.width - 1).toInt();
        final cropY = (boundingBox.top - boundingBox.height * padding).clamp(0, image.height - 1).toInt();
        final cropWidth = ((boundingBox.width * (1 + 2 * padding)).clamp(0, image.width - cropX)).toInt();
        final cropHeight = ((boundingBox.height * (1 + 2 * padding)).clamp(0, image.height - cropY)).toInt();

        final croppedImage = img.copyCrop(
          image,
          x: cropX,
          y: cropY,
          width: cropWidth,
          height: cropHeight,
        );

        // Resize to 112x112
        final resizedImage = img.copyResize(
          croppedImage,
          width: _inputSize,
          height: _inputSize,
          interpolation: img.Interpolation.linear,
        );

        // Convert to RGB and normalize
        final inputBuffer = Float32List(_inputSize * _inputSize * 3);
        int index = 0;
        
        for (int y = 0; y < _inputSize; y++) {
          for (int x = 0; x < _inputSize; x++) {
            final pixel = resizedImage.getPixel(x, y);
            final r = pixel.r.toInt();
            final g = pixel.g.toInt();
            final b = pixel.b.toInt();
            
            inputBuffer[index++] = (r / 127.5) - 1.0;
            inputBuffer[index++] = (g / 127.5) - 1.0;
            inputBuffer[index++] = (b / 127.5) - 1.0;
          }
        }

        // Prepare input and output
        final input = _reshapeInput(inputBuffer, 1, _inputSize, _inputSize, 3);
        final output = List.generate(1, (_) => List.filled(_embeddingSize, 0.0));

        // Run inference
        _tfliteInterpreter!.run(input, output);

        // Extract and normalize embedding
        final embedding = List<double>.from(output[0]);
        encodings.add(_normalizeEncoding(embedding));
      }

      return encodings;
    } catch (e, stackTrace) {
      print('Error extracting all face encodings with TFLite: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  // Find the best match for a face encoding
  Future<Map<String, dynamic>?> _findBestMatch(List<double> encoding) async {
    try {
      if (_knownFaceEncodings.isEmpty) {
        return null;
      }

      if (encoding.isEmpty) {
        return null;
      }

      double bestDistance = double.infinity;
      int bestMatchIndex = -1;
      
      // Industry-standard thresholds for MobileFaceNet
      // More relaxed to allow for different lighting conditions and angles
      const maxDistance = 0.75; // Maximum allowed distance (allows for lighting variations)
      const minConfidence = 0.50; // Minimum 50% confidence required
      const minCosineSimilarity = 0.60; // Minimum cosine similarity threshold

      // CRITICAL: Normalize both encodings before comparison to ensure consistency
      // This ensures matching works regardless of whether embeddings were normalized when saved
      // Normalization is idempotent, so normalizing already-normalized vectors is safe
      final normalizedEncoding = _normalizeEncoding(encoding);

      for (int i = 0; i < _knownFaceEncodings.length; i++) {
        try {
          final knownEncoding = _knownFaceEncodings[i];
          if (knownEncoding.isEmpty) continue;

          // Ensure known encoding is also normalized before comparison
          // This guarantees both vectors are L2-normalized for accurate distance calculations
          final normalizedKnownEncoding = _normalizeEncoding(knownEncoding);

          // Calculate both Euclidean distance and cosine similarity for better accuracy
          final euclideanDistance = _calculateEuclideanDistance(
            normalizedEncoding,
            normalizedKnownEncoding,
          );
          
          final cosineSimilarity = _calculateCosineSimilarity(
            normalizedEncoding,
            normalizedKnownEncoding,
          );

          // Use combined metric: prefer matches with both low distance and high similarity
          // Weight: 60% cosine similarity, 40% distance
          final combinedScore = (cosineSimilarity * 0.6) + ((1.0 - (euclideanDistance / maxDistance)) * 0.4);
          
          // Only consider if distance is below threshold AND similarity meets minimum
          if (euclideanDistance < maxDistance && 
              cosineSimilarity > minCosineSimilarity && 
              combinedScore > minConfidence &&
              euclideanDistance < bestDistance) {
            bestDistance = euclideanDistance;
            bestMatchIndex = i;
          }
        } catch (e) {
          print('Error comparing with encoding $i: $e');
          continue;
        }
      }

      if (bestMatchIndex != -1 && bestMatchIndex < _knownFaceIds.length) {
        // Calculate final confidence using both metrics (both already normalized)
        final normalizedKnownEncoding = _normalizeEncoding(_knownFaceEncodings[bestMatchIndex]);
        final cosineSim = _calculateCosineSimilarity(
          normalizedEncoding,
          normalizedKnownEncoding,
        );
        
        // Confidence based on cosine similarity (more reliable for face recognition)
        // Map similarity (minCosineSimilarity-1.0) to confidence (0.0-1.0)
        final confidence = ((cosineSim - minCosineSimilarity) / (1.0 - minCosineSimilarity)).clamp(0.0, 1.0);
        
        // Only return if confidence meets minimum threshold
        if (confidence >= minConfidence) {
          return {
            'id': _knownFaceIds[bestMatchIndex],
            'name': _knownFaceNames[bestMatchIndex],
            'relationship': _knownFaceRelationships[bestMatchIndex],
            'confidence': confidence,
            'distance': bestDistance,
          };
        }
      }

      return null;
    } catch (e) {
      print('Error finding best match: $e');
      return null;
    }
  }

  // Calculate cosine similarity between two encodings (better for face recognition)
  double _calculateCosineSimilarity(
    List<double> encoding1,
    List<double> encoding2,
  ) {
    if (encoding1.length != encoding2.length) {
      throw Exception('Encodings must have the same length');
    }

    double dotProduct = 0.0;
    double magnitude1 = 0.0;
    double magnitude2 = 0.0;

    for (int i = 0; i < encoding1.length; i++) {
      dotProduct += encoding1[i] * encoding2[i];
      magnitude1 += encoding1[i] * encoding1[i];
      magnitude2 += encoding2[i] * encoding2[i];
    }

    magnitude1 = sqrt(magnitude1);
    magnitude2 = sqrt(magnitude2);

    if (magnitude1 == 0.0 || magnitude2 == 0.0) {
      return 0.0;
    }

    return dotProduct / (magnitude1 * magnitude2);
  }

  // Calculate Euclidean distance between two encodings
  double _calculateEuclideanDistance(
    List<double> encoding1,
    List<double> encoding2,
  ) {
    if (encoding1.length != encoding2.length) {
      throw Exception('Encodings must have the same length');
    }

    double sum = 0.0;
    for (int i = 0; i < encoding1.length; i++) {
      final diff = encoding1[i] - encoding2[i];
      sum += diff * diff;
    }

    return sqrt(sum);
  }

  // Save face data to local storage as JSON
  Future<void> _saveFaceData(
    String faceId,
    String name,
    String relationship,
    List<double> encoding,
    String userId,
  ) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/face_data_$faceId.json');

      final data = {
        'id': faceId,
        'name': name,
        'relationship': relationship,
        'encoding': encoding,
        'userId': userId,
        'createdAt': DateTime.now().toIso8601String(),
      };

      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      print('Error saving face data: $e');
      rethrow;
    }
  }

  // Load known faces from storage (Firebase first, then local fallback)
  Future<void> loadKnownFaces(String userId) async {
    try {
      _knownFaceEncodings.clear();
      _knownFaceNames.clear();
      _knownFaceIds.clear();
      _knownFaceRelationships.clear();

      // Try to load from Firebase first
      try {
        print('Attempting to load face embeddings from Firebase for user: $userId');
        final firebaseFaces = await _firestoreService.getFaceEmbeddings(userId);
        print('Firebase query returned ${firebaseFaces.length} face embeddings');
        
        if (firebaseFaces.isNotEmpty) {
          print('Loading ${firebaseFaces.length} face embeddings from Firebase');
          
          for (final faceData in firebaseFaces) {
            try {
              final encoding = faceData['embedding'] as List<double>;
              if (encoding.isEmpty) {
                print('Warning: Face ${faceData['id']} has empty embedding, skipping');
                continue;
              }
              
              _knownFaceIds.add(faceData['id'] as String);
              _knownFaceNames.add(faceData['name'] as String);
              _knownFaceRelationships.add(faceData['relationship'] as String);
              _knownFaceEncodings.add(encoding);
              
              // Also save to local storage for offline access
              await _saveFaceData(
                faceData['id'] as String,
                faceData['name'] as String,
                faceData['relationship'] as String,
                encoding,
                userId,
              );
            } catch (e) {
              print('Error processing face data ${faceData['id']}: $e');
            }
          }
          
          print('Successfully loaded ${_knownFaceNames.length} known faces from Firebase for user $userId');
          return;
        } else {
          print('No face embeddings found in Firebase for user $userId');
        }
      } catch (e, stackTrace) {
        print('Error loading from Firebase: $e');
        print('Stack trace: $stackTrace');
        print('Falling back to local storage...');
      }

      // Fallback to local storage if Firebase fails or has no data
      final directory = await getApplicationDocumentsDirectory();
      final files = directory
          .listSync()
          .whereType<File>()
          .where((file) =>
              file.path.contains('face_data_') &&
              file.path.endsWith('.json') &&
              file.path.contains(userId));

      for (final file in files) {
        try {
          final content = await file.readAsString();
          final data = jsonDecode(content) as Map<String, dynamic>;

          if (data['userId'] == userId) {
            final encoding = (data['encoding'] as List)
                .map((e) => (e as num).toDouble())
                .toList();

            _knownFaceIds.add(data['id'] as String);
            _knownFaceNames.add(data['name'] as String);
            _knownFaceRelationships.add(data['relationship'] as String);
            _knownFaceEncodings.add(encoding);
          }
        } catch (e) {
          print('Error loading face file ${file.path}: $e');
        }
      }

      print('Loaded ${_knownFaceNames.length} known faces from local storage for user $userId');
    } catch (e) {
      print('Error loading known faces: $e');
      rethrow;
    }
  }

  // Remove a known face
  Future<bool> removeKnownFace(String faceId) async {
    try {
      final index = _knownFaceIds.indexOf(faceId);
      if (index != -1) {
        _knownFaceIds.removeAt(index);
        _knownFaceNames.removeAt(index);
        _knownFaceEncodings.removeAt(index);
        _knownFaceRelationships.removeAt(index);

        // Remove from local storage
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/face_data_$faceId.json');
        if (await file.exists()) {
          await file.delete();
        }

        // Remove from Firebase
        try {
          await _firestoreService.deleteFaceEmbedding(faceId);
          print('Face embedding deleted from Firebase: $faceId');
        } catch (e) {
          print('Warning: Failed to delete from Firebase: $e');
          // Continue even if Firebase delete fails
        }

        // Emit event
        _faceRecognitionController.add({
          'event': 'face_removed',
          'faceId': faceId,
          'timestamp': DateTime.now().toIso8601String(),
        });

        return true;
      }
      return false;
    } catch (e) {
      print('Error removing known face: $e');
      return false;
    }
  }

  // Get all known faces for a user
  List<Map<String, dynamic>> getKnownFaces(String userId) {
    final userFaces = <Map<String, dynamic>>[];

    for (int i = 0; i < _knownFaceIds.length; i++) {
      if (_knownFaceIds[i].startsWith(userId)) {
        userFaces.add({
          'id': _knownFaceIds[i],
          'name': _knownFaceNames[i],
          'relationship': _knownFaceRelationships[i],
        });
      }
    }

    return userFaces;
  }

  // Update face information
  Future<bool> updateFaceInfo(
    String faceId,
    String newName,
    String newRelationship,
  ) async {
    try {
      final index = _knownFaceIds.indexOf(faceId);
      if (index != -1) {
        _knownFaceNames[index] = newName;
        _knownFaceRelationships[index] = newRelationship;

        // Update local storage
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/face_data_$faceId.json');

        if (await file.exists()) {
          final content = await file.readAsString();
          final data = jsonDecode(content) as Map<String, dynamic>;
          data['name'] = newName;
          data['relationship'] = newRelationship;
          data['updatedAt'] = DateTime.now().toIso8601String();
          await file.writeAsString(jsonEncode(data));
        }

        // Update Firebase
        try {
          await _firestoreService.updateFaceEmbedding(
            faceId,
            name: newName,
            relationship: newRelationship,
          );
          print('Face embedding updated in Firebase: $faceId');
        } catch (e) {
          print('Warning: Failed to update in Firebase: $e');
          // Continue even if Firebase update fails
        }

        // Emit event
        _faceRecognitionController.add({
          'event': 'face_updated',
          'faceId': faceId,
          'name': newName,
          'relationship': newRelationship,
          'timestamp': DateTime.now().toIso8601String(),
        });

        return true;
      }
      return false;
    } catch (e) {
      print('Error updating face info: $e');
      return false;
    }
  }

  // Get face recognition statistics
  Map<String, dynamic> getStatistics() {
    return {
      'totalKnownFaces': _knownFaceNames.length,
      'isInitialized': _isInitialized,
      'faceDetectorAvailable': _faceDetector != null,
    };
  }

  // Detect faces in camera preview
  Future<List<Map<String, dynamic>>> detectFacesInPreview(
    CameraImage image,
  ) async {
    try {
      if (!_isInitialized) await initialize();

      // Convert CameraImage to InputImage
      final inputImage = _cameraImageToInputImage(image);
      final faces = await _faceDetector!.processImage(inputImage);

      final List<Map<String, dynamic>> detectedFaces = [];

      for (final face in faces) {
        detectedFaces.add({
          'id': 'face_${DateTime.now().millisecondsSinceEpoch}_${faces.indexOf(face)}',
          'boundingBox': {
            'x': face.boundingBox.left.toDouble(),
            'y': face.boundingBox.top.toDouble(),
            'width': face.boundingBox.width.toDouble(),
            'height': face.boundingBox.height.toDouble(),
          },
        });
      }

      return detectedFaces;
    } catch (e) {
      print('Error detecting faces in preview: $e');
      return [];
    }
  }

  // Convert CameraImage to InputImage
  InputImage _cameraImageToInputImage(CameraImage cameraImage) {
    final allBytes = <int>[];
    for (final Plane plane in cameraImage.planes) {
      allBytes.addAll(plane.bytes);
    }
    final bytes = Uint8List.fromList(allBytes);

    final imageRotation = InputImageRotation.rotation0deg;

    final inputImageData = InputImageMetadata(
      size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
      rotation: imageRotation,
      format: InputImageFormat.nv21,
      bytesPerRow: cameraImage.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: inputImageData,
    );
  }

  // Validate face image quality
  Future<Map<String, dynamic>> validateFaceImage(File imageFile) async {
    try {
      if (!_isInitialized) await initialize();

      // Check if file exists
      if (!await imageFile.exists()) {
        return {'isValid': false, 'reason': 'Image file does not exist'};
      }

      final bytes = await imageFile.readAsBytes();
      if (bytes.isEmpty) {
        return {'isValid': false, 'reason': 'Image file is empty'};
      }

      final image = img.decodeImage(bytes);
      if (image == null) {
        return {'isValid': false, 'reason': 'Invalid image format. Please use JPG or PNG.'};
      }

      // Check image dimensions
      if (image.width < 100 || image.height < 100) {
        return {
          'isValid': false,
          'reason': 'Image too small (minimum 100x100 pixels)',
        };
      }

      // Check if face is detected
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final faces = await _faceDetector!.processImage(inputImage);

      if (faces.isEmpty) {
        return {
          'isValid': false,
          'reason': 'No face detected in image. Please ensure the face is clearly visible and well-lit.',
        };
      }

      // Check face quality (size relative to image)
      final face = faces.first;
      final faceArea = face.boundingBox.width * face.boundingBox.height;
      final imageArea = image.width * image.height;
      final faceRatio = faceArea / imageArea;

      if (faceRatio < 0.01) {
        return {
          'isValid': false,
          'reason': 'Face too small in image. Please move closer or zoom in.',
        };
      }

      // Check head pose
      final angleY = face.headEulerAngleY;
      if (angleY != null && (angleY < -30 || angleY > 30)) {
        return {
          'isValid': false,
          'reason': 'Face angle too extreme. Please face the camera directly.',
        };
      }

      // Check if multiple faces (warn but allow)
      if (faces.length > 1) {
        print('Warning: Multiple faces detected, using the first one');
      }

      return {
        'isValid': true,
        'width': image.width,
        'height': image.height,
        'hasFace': true,
        'faceCount': faces.length,
        'faceSize': faceRatio,
      };
    } catch (e) {
      print('Error validating face image: $e');
      return {
        'isValid': false,
        'reason': 'Error processing image: ${e.toString()}',
      };
    }
  }

  // Cleanup resources
  Future<void> dispose() async {
    try {
      await _faceDetector?.close();
      _faceDetector = null;
      _tfliteInterpreter?.close();
      _tfliteInterpreter = null;
      _tfliteLoaded = false;
      _knownFaceEncodings.clear();
      _knownFaceNames.clear();
      _knownFaceIds.clear();
      _knownFaceRelationships.clear();
      _isInitialized = false;
      await _faceRecognitionController.close();
    } catch (e) {
      print('Error disposing face recognition service: $e');
    }
  }
}
