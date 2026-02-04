import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:crypto/crypto.dart';

class StorageService {
  // Singleton pattern
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _cloudName = 'dkiqc4jru';
  static const String _apiKey = '659932293576982';
  static const String _apiSecret = '1f7M0nZpCLZ1F7ytj1CYwaV2xo8';
  static const String _uploadPreset =
      'alzMate'; // You must create one in Cloudinary settings!

  // Base URLs
  static const String _baseUrl = 'https://api.cloudinary.com/v1_1/$_cloudName';
  static const String _uploadUrl = '$_baseUrl/image/upload';
  static const String _videoUploadUrl = '$_baseUrl/video/upload';
  static const String _rawUploadUrl = '$_baseUrl/raw/upload';

  // Upload family member image
  Future<String> uploadFamilyMemberImage(String userId, File imageFile) async {
    return await uploadImage(imageFile, folder: 'family_members/$userId');
  }

  // Upload image to Cloudinary
  Future<String> uploadImage(File imageFile, {String? folder}) async {
    try {
      final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
      );

      final request = http.MultipartRequest('POST', url);

      // Add the image file
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      // Add upload parameters
      request.fields['upload_preset'] = _uploadPreset;
      if (folder != null) {
        request.fields['folder'] = folder;
      }
      request.fields['resource_type'] = 'image';

      // Send the request
      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final jsonData = json.decode(responseData);
        return jsonData['secure_url'] as String;
      } else {
        throw Exception('Failed to upload image: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Image upload failed: $e');
    }
  }

  // Upload image from bytes
  Future<String> uploadImageFromBytes(
    Uint8List imageBytes,
    String fileName, {
    String? folder,
  }) async {
    try {
      final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
      );

      final request = http.MultipartRequest('POST', url);

      // Add the image bytes
      request.files.add(
        http.MultipartFile.fromBytes('file', imageBytes, filename: fileName),
      );

      // Add upload parameters
      request.fields['upload_preset'] = _uploadPreset;
      if (folder != null) {
        request.fields['folder'] = folder;
      }
      request.fields['resource_type'] = 'image';

      // Send the request
      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final jsonData = json.decode(responseData);
        return jsonData['secure_url'] as String;
      } else {
        throw Exception('Failed to upload image: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Image upload failed: $e');
    }
  }

  // Upload video to Cloudinary
  Future<String> uploadVideo(File videoFile, {String? folder}) async {
    try {
      final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/video/upload',
      );

      final request = http.MultipartRequest('POST', url);

      // Add the video file
      request.files.add(
        await http.MultipartFile.fromPath('file', videoFile.path),
      );

      // Add upload parameters
      request.fields['upload_preset'] = _uploadPreset;
      if (folder != null) {
        request.fields['folder'] = folder;
      }
      request.fields['resource_type'] = 'video';

      // Send the request
      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final jsonData = json.decode(responseData);
        return jsonData['secure_url'] as String;
      } else {
        throw Exception('Failed to upload video: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Video upload failed: $e');
    }
  }

  // Upload face recognition image
  Future<String> uploadFaceRecognitionImage(
    String userId,
    File imageFile,
  ) async {
    return await uploadImage(imageFile, folder: 'face_recognition/$userId');
  }

  // Upload QR code image
  Future<String> uploadQrCodeImage(String userId, File imageFile) async {
    return await uploadImage(imageFile, folder: 'qr_codes/$userId');
  }

  // Upload audio to Cloudinary
  Future<String> uploadAudio(File audioFile, {String? folder}) async {
    try {
      final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/video/upload',
      );

      final request = http.MultipartRequest('POST', url);

      // Add the audio file
      request.files.add(
        await http.MultipartFile.fromPath('file', audioFile.path),
      );

      // Add upload parameters
      request.fields['upload_preset'] = _uploadPreset;
      if (folder != null) {
        request.fields['folder'] = folder;
      }
      request.fields['resource_type'] =
          'video'; // Audio is uploaded as video resource type

      // Send the request
      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final jsonData = json.decode(responseData);
        return jsonData['secure_url'] as String;
      } else {
        throw Exception('Failed to upload audio: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Audio upload failed: $e');
    }
  }

  // Upload profile image
  Future<String> uploadProfileImage(File imageFile, String userId) async {
    return await uploadImage(imageFile, folder: 'profiles/$userId');
  }

  // Upload journal media
  Future<String> uploadJournalMedia(
    File mediaFile,
    String userId,
    String entryId,
  ) async {
    final folder = 'journal/$userId/$entryId';

    // Determine file type and upload accordingly
    final extension = mediaFile.path.split('.').last.toLowerCase();

    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension)) {
      return await uploadImage(mediaFile, folder: folder);
    } else if (['mp4', 'mov', 'avi', 'mkv'].contains(extension)) {
      return await uploadVideo(mediaFile, folder: folder);
    } else if (['mp3', 'wav', 'aac', 'm4a'].contains(extension)) {
      return await uploadAudio(mediaFile, folder: folder);
    } else {
      throw Exception('Unsupported file format: $extension');
    }
  }

  // Delete file from Cloudinary
  Future<bool> deleteFile(String publicId) async {
    try {
      final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/destroy',
      );

      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final signature = _generateSignature(publicId, timestamp);

      final response = await http.post(
        url,
        body: {
          'public_id': publicId,
          'timestamp': timestamp.toString(),
          'api_key': _apiKey,
          'signature': signature,
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return jsonData['result'] == 'ok';
      } else {
        throw Exception('Failed to delete file: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('File deletion failed: $e');
    }
  }

  // Generate signature for authenticated requests
  String _generateSignature(String publicId, int timestamp) {
    final paramsToSign = 'public_id=$publicId&timestamp=$timestamp$_apiSecret';
    return sha1.convert(utf8.encode(paramsToSign)).toString();
  }

  // Get optimized image URL
  String getOptimizedImageUrl(
    String originalUrl, {
    int? width,
    int? height,
    String quality = 'auto',
    String format = 'auto',
  }) {
    if (!originalUrl.contains('cloudinary.com')) {
      return originalUrl;
    }

    final transformations = <String>[];

    if (width != null) transformations.add('w_$width');
    if (height != null) transformations.add('h_$height');
    transformations.add('q_$quality');
    transformations.add('f_$format');

    final transformationString = transformations.join(',');

    // Insert transformations into the URL
    return originalUrl.replaceFirst(
      '/upload/',
      '/upload/$transformationString/',
    );
  }

  // Get thumbnail URL
  String getThumbnailUrl(String originalUrl, {int size = 150}) {
    return getOptimizedImageUrl(
      originalUrl,
      width: size,
      height: size,
      quality: 'auto',
      format: 'auto',
    );
  }

  // Get file info from URL
  Map<String, String> getFileInfoFromUrl(String url) {
    final uri = Uri.parse(url);
    final pathSegments = uri.pathSegments;

    if (pathSegments.length >= 3) {
      final publicId = pathSegments.sublist(2).join('/').split('.').first;
      final format = pathSegments.last.split('.').last;

      return {
        'publicId': publicId,
        'format': format,
        'resourceType': pathSegments[1], // image, video, etc.
      };
    }

    return {};
  }

  // Check if URL is from Cloudinary
  bool isCloudinaryUrl(String url) {
    return url.contains('cloudinary.com');
  }

  // Generate upload signature (should be done on backend in production)
  Map<String, String> generateUploadSignature({
    String? folder,
    String? publicId,
    Map<String, String>? additionalParams,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final params = <String, String>{
      'timestamp': timestamp.toString(),
      'upload_preset': _uploadPreset,
    };

    if (folder != null) params['folder'] = folder;
    if (publicId != null) params['public_id'] = publicId;
    if (additionalParams != null) params.addAll(additionalParams);

    // In production, generate proper signature on backend
    params['signature'] = 'signature_placeholder';
    params['api_key'] = _apiKey;

    return params;
  }
}
