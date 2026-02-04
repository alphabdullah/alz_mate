import 'dart:async';
import 'package:alz_mate/core/services/notification_service.dart%20copy/notification_services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/sos_alert_model.dart';
import '../models/user_model.dart';
import 'firestore_service.dart';
import 'location_service.dart';
import 'notification_service.dart';
import 'auth_service.dart';

class SosService {
  // Singleton pattern
  static final SosService _instance = SosService._internal();
  factory SosService() => _instance;
  SosService._internal();

  final FirestoreService _firestoreService = FirestoreService();
  final LocationService _locationService = LocationService();
  final NotificationService _notificationService = NotificationService();
  final AuthService _authService = AuthService();

  bool _isEmergencyActive = false;
  SOSAlertModel? _activeAlert;
  Timer? _emergencyTimer;

  // Getters
  bool get isEmergencyActive => _isEmergencyActive;
  SOSAlertModel? get activeAlert => _activeAlert;

  // Stream controller for SOS events
  final _sosEventController = StreamController<SOSAlertModel>.broadcast();

  // Getters
  Stream<SOSAlertModel> get sosEventStream => _sosEventController.stream;

  // Initialize SOS service
  Future<void> init() async {
    try {
      await _locationService.init();
      await _notificationService.init();
    } catch (e) {
      print('Failed to initialize SOS service: $e');
    }
  }

  // Trigger SOS alert
  Future<SOSAlertModel> triggerSosAlert({
    String? notes,
    String priority = 'critical',
  }) async {
    try {
      if (_authService.currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Prevent multiple active alerts
      if (_isEmergencyActive) {
        throw Exception('Emergency alert already active');
      }

      _isEmergencyActive = true;

      // Get current location
      final locationInfo = await _locationService.getEmergencyLocation();

      // Create SOS alert
      final alert = SOSAlertModel(
        id: '', // Will be set by Firestore
        userId: _authService.currentUser!.uid,
        timestamp: DateTime.now(),
        latitude: locationInfo['latitude'],
        longitude: locationInfo['longitude'],
        address: locationInfo['address'],
        notes: notes,
        priority: priority,
        createdAt: DateTime.now(),
        metadata: {
          'accuracy': locationInfo['accuracy'],
          'isLastKnown': locationInfo['isLastKnown'] ?? false,
          'deviceInfo': await _getDeviceInfo(),
        },
      );

      // Save to Firestore
      final alertId = await _firestoreService.createSosAlert(alert);
      _activeAlert = alert.copyWith(id: alertId);

      // Notify emergency contacts
      await _notifyEmergencyContacts(_activeAlert!);

      // Start emergency monitoring
      _startEmergencyMonitoring();

      // Send local notification
      await _notificationService.showNotification(
        title: 'SOS Alert Sent',
        body: 'Emergency alert has been sent to your contacts',
        payload: 'sos_channel',
      );

      return _activeAlert!;
    } catch (e) {
      _isEmergencyActive = false;
      throw Exception('Failed to trigger SOS alert: $e');
    }
  }

  // Cancel SOS alert
  Future<void> cancelSosAlert(String alertId, {String? reason}) async {
    try {
      await _firestoreService.updateSosAlert(alertId, {
        'isResolved': true,
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedBy': _authService.currentUser?.uid,
        'resolutionReason': reason ?? 'Cancelled by user',
      });

      _isEmergencyActive = false;
      _activeAlert = null;
      _emergencyTimer?.cancel();

      // Notify contacts about cancellation
      await _notifyAlertCancellation(alertId);

      await _notificationService.showNotification(
        title: 'SOS Alert Cancelled',
        body: 'Emergency alert has been cancelled',
      );
    } catch (e) {
      throw Exception('Failed to cancel SOS alert: $e');
    }
  }

  // Resolve SOS alert (by caregiver)
  Future<void> resolveSosAlert(
    String alertId,
    String resolvedBy, {
    String? notes,
  }) async {
    try {
      await _firestoreService.updateSosAlert(alertId, {
        'isResolved': true,
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedBy': resolvedBy,
        'resolutionNotes': notes,
      });

      if (_activeAlert?.id == alertId) {
        _isEmergencyActive = false;
        _activeAlert = null;
        _emergencyTimer?.cancel();
      }
    } catch (e) {
      throw Exception('Failed to resolve SOS alert: $e');
    }
  }

  // Get SOS alerts for user
  Future<List<SOSAlertModel>> getSosAlerts(String userId) async {
    try {
      return await _firestoreService.getSosAlertsByUserId(userId);
    } catch (e) {
      throw Exception('Failed to get SOS alerts: $e');
    }
  }

  // Get active SOS alerts for caregiver
  Future<List<SOSAlertModel>> getActiveSosAlertsForCaregiver(
    String caregiverId,
  ) async {
    try {
      return await _firestoreService.getSosAlertsForCaregiver(caregiverId);
    } catch (e) {
      throw Exception('Failed to get active SOS alerts: $e');
    }
  }

  // Get SOS alerts stream
  Stream<List<SOSAlertModel>> getSosAlertsStream(String userId) {
    return _firestoreService.getSosAlertsStream(userId);
  }

  // Update alert location
  Future<void> updateAlertLocation(String alertId) async {
    try {
      final locationInfo = await _locationService.getLocationInfo();

      await _firestoreService.updateSosAlert(alertId, {
        'latitude': locationInfo['latitude'],
        'longitude': locationInfo['longitude'],
        'address': locationInfo['address'],
        'lastLocationUpdate': FieldValue.serverTimestamp(),
        'locationAccuracy': locationInfo['accuracy'],
      });
    } catch (e) {
      print('Failed to update alert location: $e');
    }
  }

  // Add response to alert
  Future<void> addAlertResponse(
    String alertId,
    String responderId,
    String response,
  ) async {
    try {
      await _firestoreService.updateSosAlert(alertId, {
        'responses': FieldValue.arrayUnion([
          {
            'responderId': responderId,
            'response': response,
            'timestamp': FieldValue.serverTimestamp(),
          },
        ]),
      });
    } catch (e) {
      throw Exception('Failed to add alert response: $e');
    }
  }

  // Notify emergency contacts
  Future<void> _notifyEmergencyContacts(SOSAlertModel alert) async {
    try {
      final user = await _authService.getCurrentUserData();
      if (user == null) return;

      // Get emergency contacts
      final contacts = await _getEmergencyContacts(user);

      // Send notifications to contacts
      await _notificationService.sendSosAlertNotification(alert, contacts);

      // Update alert with notified contacts
      await _firestoreService.updateSosAlert(alert.id, {
        'notifiedContacts': contacts.map((c) => c.id).toList(),
        'notificationSentAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Failed to notify emergency contacts: $e');
    }
  }

  // Get emergency contacts
  Future<List<UserModel>> _getEmergencyContacts(UserModel user) async {
    try {
      final contacts = <UserModel>[];

      // Get caregivers
      if (user.caregiverIds != null) {
        for (final caregiverId in user.caregiverIds!) {
          final caregiver = await _firestoreService.getUserById(caregiverId);
          if (caregiver != null) {
            contacts.add(caregiver);
          }
        }
      }

      // Get family members (if any)
      // This would depend on your data structure

      return contacts;
    } catch (e) {
      print('Failed to get emergency contacts: $e');
      return [];
    }
  }

  // Start emergency monitoring
  void _startEmergencyMonitoring() {
    _emergencyTimer = Timer.periodic(const Duration(minutes: 2), (timer) async {
      if (_activeAlert != null && !_activeAlert!.isResolved) {
        try {
          // Update location
          await updateAlertLocation(_activeAlert!.id);

          // Check if alert is still active (not resolved by caregiver)
          final updatedAlert = await _firestoreService.getSosAlertById(
            _activeAlert!.id,
          );
          if (updatedAlert?.isResolved == true) {
            _isEmergencyActive = false;
            _activeAlert = null;
            timer.cancel();
          }
        } catch (e) {
          print('Error in emergency monitoring: $e');
        }
      } else {
        timer.cancel();
      }
    });
  }

  // Notify alert cancellation
  Future<void> _notifyAlertCancellation(String alertId) async {
    try {
      final user = await _authService.getCurrentUserData();
      if (user == null) return;

      // Get contacts (caregivers, family, etc.)
      final contacts = await _getEmergencyContacts(user);

       final token = await NotificationServices().getAccessToken();
      for (final contact in contacts) {
      await NotificationServices().sendNotification(token, contact.fcmToken!, '${user.name ?? 'A user'} has cancelled their emergency SOS alert.', 'SOS Alert Cancelled');
        // await _notificationService.sendCustomNotification(
        //   userId: contact.id,
        //   title: 'SOS Alert Cancelled',
        //   body:
        //       '${user.name ?? 'A user'} has cancelled their emergency SOS alert.',
        //   data: {'type': 'sos_cancellation', 'alertId': alertId},
        // );
      }

      // Optionally update the alert in Firestore
      await _firestoreService.updateSosAlert(alertId, {
        'cancellationNotifiedAt': FieldValue.serverTimestamp(),
      });

      print('Cancellation notifications sent for alert: $alertId');
    } catch (e) {
      print('Failed to notify alert cancellation: $e');
    }
  }

  // Get device info for emergency context
  Future<Map<String, dynamic>> _getDeviceInfo() async {
    try {
      return {
        'platform': defaultTargetPlatform.name,
        'timestamp': DateTime.now().toIso8601String(),
        'appVersion': '1.0.0', // You would get this from package_info
      };
    } catch (e) {
      return {'error': 'Failed to get device info'};
    }
  }

  // Test SOS system
  Future<bool> testSosSystem() async {
    try {
      // Test location service
      await _locationService.getCurrentLocation();

      // Test notification service
      await _notificationService.showNotification(
        title: 'SOS Test',
        body: 'SOS system test successful',
      );

      return true;
    } catch (e) {
      print('SOS system test failed: $e');
      return false;
    }
  }

  // Get SOS statistics
  Future<Map<String, dynamic>> getSosStatistics(String userId) async {
    try {
      final alerts = await getSosAlerts(userId);

      final stats = {
        'totalAlerts': alerts.length,
        'resolvedAlerts': alerts.where((a) => a.isResolved).length,
        'activeAlerts': alerts.where((a) => !a.isResolved).length,
        'averageResponseTime': _calculateAverageResponseTime(alerts),
        'alertsByPriority': _groupAlertsByPriority(alerts),
        'alertsByMonth': _groupAlertsByMonth(alerts),
      };

      return stats;
    } catch (e) {
      throw Exception('Failed to get SOS statistics: $e');
    }
  }

  // Calculate average response time
  double _calculateAverageResponseTime(List<SOSAlertModel> alerts) {
    final resolvedAlerts = alerts.where(
      (a) => a.isResolved && a.resolvedAt != null,
    );

    if (resolvedAlerts.isEmpty) return 0.0;

    double totalMinutes = 0.0;
    for (final alert in resolvedAlerts) {
      final responseTime = alert.resolvedAt!
          .difference(alert.timestamp)
          .inMinutes;
      totalMinutes += responseTime;
    }

    return totalMinutes / resolvedAlerts.length;
  }

  // Group alerts by priority
  Map<String, int> _groupAlertsByPriority(List<SOSAlertModel> alerts) {
    final groups = <String, int>{};

    for (final alert in alerts) {
      groups[alert.priority] = (groups[alert.priority] ?? 0) + 1;
    }

    return groups;
  }

  // Group alerts by month
  Map<String, int> _groupAlertsByMonth(List<SOSAlertModel> alerts) {
    final groups = <String, int>{};

    for (final alert in alerts) {
      final monthKey =
          '${alert.timestamp.year}-${alert.timestamp.month.toString().padLeft(2, '0')}';
      groups[monthKey] = (groups[monthKey] ?? 0) + 1;
    }

    return groups;
  }

  // Dispose resources
  void dispose() {
    _emergencyTimer?.cancel();

    _sosEventController.close();
  }
}
