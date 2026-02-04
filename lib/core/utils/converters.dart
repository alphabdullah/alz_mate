import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class Converters {
  // Convert Firestore Timestamp to DateTime
  static DateTime fromTimestamp(Timestamp ts) {
    return ts.toDate();
  }

  // Convert DateTime to Firestore Timestamp
  static Timestamp toTimestamp(DateTime dt) {
    return Timestamp.fromDate(dt);
  }

  // Convert enum to string
  static String enumToString(Object? value) {
    return value.toString().split('.').last;
  }

  // Format time (24-hour format)
  static String formatTime(DateTime time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }

  // Format time (12-hour format)
  static String formatTime12Hour(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return "${hour.toString()}:${time.minute.toString().padLeft(2, '0')} $period";
  }

  // Format date (DD/MM/YYYY)
  static String formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  // Format date (Month DD, YYYY)
  static String formatDateLong(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return "${months[date.month - 1]} ${date.day}, ${date.year}";
  }

  // Format date and time
  static String formatDateTime(DateTime dateTime) {
    return "${formatDate(dateTime)} ${formatTime(dateTime)}";
  }

  // Format date and time (long format)
  static String formatDateTimeLong(DateTime dateTime) {
    return "${formatDateLong(dateTime)} at ${formatTime12Hour(dateTime)}";
  }

  // Format duration in hours and minutes
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours > 0) {
      return "$hours hr${hours > 1 ? 's' : ''} $minutes min${minutes > 1 ? 's' : ''}";
    } else {
      return "$minutes minute${minutes > 1 ? 's' : ''}";
    }
  }

  // Format duration in minutes and seconds
  static String formatDurationMinSec(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  // Format file size
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return "$bytes B";
    } else if (bytes < 1024 * 1024) {
      final kb = bytes / 1024;
      return "${kb.toStringAsFixed(1)} KB";
    } else if (bytes < 1024 * 1024 * 1024) {
      final mb = bytes / (1024 * 1024);
      return "${mb.toStringAsFixed(1)} MB";
    } else {
      final gb = bytes / (1024 * 1024 * 1024);
      return "${gb.toStringAsFixed(1)} GB";
    }
  }

  // Format percentage
  static String formatPercentage(double value) {
    return "${(value * 100).toStringAsFixed(1)}%";
  }

  // Format currency
  static String formatCurrency(double amount, {String symbol = '\$'}) {
    return "$symbol${amount.toStringAsFixed(2)}";
  }

  // Convert string to int
  static int? stringToInt(String? value) {
    if (value == null || value.isEmpty) return null;
    return int.tryParse(value);
  }

  // Convert string to double
  static double? stringToDouble(String? value) {
    if (value == null || value.isEmpty) return null;
    return double.tryParse(value);
  }

  // Convert string to DateTime
  static DateTime? stringToDateTime(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  // Convert string to boolean
  static bool stringToBool(String value) {
    return value.toLowerCase() == 'true';
  }

  // Convert map to JSON string
  static String mapToJson(Map<String, dynamic> map) {
    return jsonEncode(map);
  }

  // Convert JSON string to map
  static Map<String, dynamic> jsonToMap(String jsonString) {
    return jsonDecode(jsonString) as Map<String, dynamic>;
  }

  // Convert list to JSON string
  static String listToJson(List<dynamic> list) {
    return jsonEncode(list);
  }

  // Convert JSON string to list
  static List<dynamic> jsonToList(String jsonString) {
    return jsonDecode(jsonString) as List<dynamic>;
  }

  // Convert hex color string to Color
  static int hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return int.parse(buffer.toString(), radix: 16);
  }

  // Convert coordinates to string
  static String coordinatesToString(double latitude, double longitude) {
    return "${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}";
  }
}
