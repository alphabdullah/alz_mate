import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class QrCodeService {
  static final QrCodeService _instance = QrCodeService._internal();
  factory QrCodeService() => _instance;
  QrCodeService._internal();

  // Generate QR code data
  Future<String> generateQrCodeData(Map<String, dynamic> data) async {
    try {
      // Create a structured QR code data format
      final qrData = {
        'type': data['type'] ?? 'alzmate_info',
        'id': data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        'title': data['title'] ?? '',
        'description': data['description'] ?? '',
        'userId': data['userId'] ?? '',
        'timestamp': DateTime.now().toIso8601String(),
        'version': '1.0',
        ...data,
      };

      // Convert to JSON string for QR code
      return Uri.encodeComponent(jsonEncode(qrData));
    } catch (e) {
      throw Exception('Failed to generate QR code data: $e');
    }
  }

  // Parse QR code data
  Map<String, dynamic> parseQrCodeData(String qrData) {
    try {
      final decodedData = Uri.decodeComponent(qrData);
      final parsedMap = jsonDecode(decodedData);

      if (parsedMap is Map<String, dynamic>) {
        return {...parsedMap, 'isValid': true};
      } else {
        return {
          'type': 'unknown',
          'data': parsedMap,
          'isValid': false,
          'error': 'Invalid QR data structure',
        };
      }
    } catch (e) {
      return {
        'type': 'unknown',
        'data': qrData,
        'isValid': false,
        'error': e.toString(),
      };
    }
  }

  // Generate QR code widget
  Widget generateQrCodeWidget({
    required String data,
    double size = 200.0,
    Color foregroundColor = const Color(0xFF000000),
    Color backgroundColor = const Color(0xFFFFFFFF),
    int errorCorrectionLevel = QrErrorCorrectLevel.M,
  }) {
    return QrImageView(
      data: data,
      version: QrVersions.auto,
      size: size,
      foregroundColor: foregroundColor,
      backgroundColor: backgroundColor,
      errorCorrectionLevel: errorCorrectionLevel,
      padding: const EdgeInsets.all(10),
    );
  }

  // Generate QR code as image bytes
  Future<Uint8List> generateQrCodeBytes({
    required String data,
    double size = 200.0,
    Color foregroundColor = const Color(0xFF000000),
    Color backgroundColor = const Color(0xFFFFFFFF),
  }) async {
    try {
      final qrValidationResult = QrValidator.validate(
        data: data,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
      );

      if (qrValidationResult.status != QrValidationStatus.valid) {
        throw Exception('Invalid QR code data');
      }

      final qrCode = qrValidationResult.qrCode!;
      final painter = QrPainter(
        data: data,
        version: qrCode.moduleCount,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        color: foregroundColor,
        emptyColor: backgroundColor,
      );

      final picRecorder = ui.PictureRecorder();
      final canvas = Canvas(picRecorder);
      painter.paint(canvas, Size(size, size));

      final picture = picRecorder.endRecording();
      final image = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      return byteData!.buffer.asUint8List();
    } catch (e) {
      throw Exception('Failed to generate QR code bytes: $e');
    }
  }

  // Save QR code to device
  Future<String> saveQrCodeToDevice({
    required String data,
    required String fileName,
    double size = 200.0,
  }) async {
    try {
      final bytes = await generateQrCodeBytes(data: data, size: size);
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName.png');

      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      throw Exception('Failed to save QR code: $e');
    }
  }

  // Share QR code
  Future<void> shareQrCode({
    required String data,
    required String title,
    double size = 200.0,
  }) async {
    try {
      final filePath = await saveQrCodeToDevice(
        data: data,
        fileName: 'qr_code_${DateTime.now().millisecondsSinceEpoch}',
        size: size,
      );

      await Share.shareXFiles(
        [XFile(filePath)],
        text: title,
        subject: 'AlzMate QR Code',
      );
    } catch (e) {
      throw Exception('Failed to share QR code: $e');
    }
  }

  // Validate QR code data
  bool validateQrCodeData(String data) {
    try {
      if (data.isEmpty) return false;

      // Check if it's a valid AlzMate QR code
      final parsed = parseQrCodeData(data);
      return parsed['isValid'] == true;
    } catch (e) {
      return false;
    }
  }

  // Create medication QR code
  Future<String> createMedicationQrCode({
    required String medicationName,
    required String dosage,
    required String instructions,
    required String userId,
  }) async {
    final data = {
      'type': 'medication',
      'medicationName': medicationName,
      'dosage': dosage,
      'instructions': instructions,
      'userId': userId,
    };

    return await generateQrCodeData(data);
  }

  // Create emergency contact QR code
  Future<String> createEmergencyContactQrCode({
    required String name,
    required String phone,
    required String relationship,
    required String userId,
  }) async {
    final data = {
      'type': 'emergency_contact',
      'name': name,
      'phone': phone,
      'relationship': relationship,
      'userId': userId,
    };

    return await generateQrCodeData(data);
  }

  // Create location QR code
  Future<String> createLocationQrCode({
    required String locationName,
    required String address,
    required String instructions,
    required String userId,
  }) async {
    final data = {
      'type': 'location',
      'locationName': locationName,
      'address': address,
      'instructions': instructions,
      'userId': userId,
    };

    return await generateQrCodeData(data);
  }

  // Create medical info QR code
  Future<String> createMedicalInfoQrCode({
    required String patientName,
    required String bloodType,
    required String allergies,
    required String conditions,
    required String emergencyContact,
    required String userId,
  }) async {
    final data = {
      'type': 'medical_info',
      'patientName': patientName,
      'bloodType': bloodType,
      'allergies': allergies,
      'conditions': conditions,
      'emergencyContact': emergencyContact,
      'userId': userId,
    };

    return await generateQrCodeData(data);
  }

  // Get QR code type icon
  String getQrCodeTypeIcon(String type) {
    switch (type) {
      case 'medication':
        return '💊';
      case 'emergency_contact':
        return '🚨';
      case 'location':
        return '📍';
      case 'medical_info':
        return '🏥';
      case 'alzmate_info':
        return '🧠';
      default:
        return '📱';
    }
  }

  // Get QR code type description
  String getQrCodeTypeDescription(String type) {
    switch (type) {
      case 'medication':
        return 'Medication Information';
      case 'emergency_contact':
        return 'Emergency Contact';
      case 'location':
        return 'Location Information';
      case 'medical_info':
        return 'Medical Information';
      case 'alzmate_info':
        return 'AlzMate Information';
      default:
        return 'General Information';
    }
  }

  // Batch create QR codes
  Future<List<String>> createBatchQrCodes(
    List<Map<String, dynamic>> dataList,
  ) async {
    try {
      final qrCodes = <String>[];

      for (final data in dataList) {
        final qrCode = await generateQrCodeData(data);
        qrCodes.add(qrCode);
      }

      return qrCodes;
    } catch (e) {
      throw Exception('Failed to create batch QR codes: $e');
    }
  }

  // Print QR code (would integrate with printing service)
  Future<void> printQrCode({
    required String data,
    required String title,
    double size = 200.0,
  }) async {
    try {
      // In a real implementation, you would integrate with a printing service
      // For now, we'll save the QR code and show a message
      final filePath = await saveQrCodeToDevice(
        data: data,
        fileName: 'print_qr_${DateTime.now().millisecondsSinceEpoch}',
        size: size,
      );

      print('QR code saved for printing: $filePath');

      // You could integrate with platform-specific printing APIs here
      // For example, using the printing package for Flutter
    } catch (e) {
      throw Exception('Failed to print QR code: $e');
    }
  }

  // Get QR code statistics
  Map<String, dynamic> getQrCodeStats(List<Map<String, dynamic>> qrCodes) {
    try {
      final typeCount = <String, int>{};
      int totalScans = 0;

      for (final qr in qrCodes) {
        final type = qr['type'] ?? 'unknown';
        typeCount[type] = (typeCount[type] ?? 0) + 1;
        totalScans += (qr['scanCount'] ?? 0) as int;
      }

      return {
        'totalQrCodes': qrCodes.length,
        'totalScans': totalScans,
        'typeDistribution': typeCount,
        'averageScansPerCode': qrCodes.isNotEmpty
            ? totalScans / qrCodes.length
            : 0,
      };
    } catch (e) {
      return {
        'totalQrCodes': 0,
        'totalScans': 0,
        'typeDistribution': <String, int>{},
        'averageScansPerCode': 0,
      };
    }
  }
}
