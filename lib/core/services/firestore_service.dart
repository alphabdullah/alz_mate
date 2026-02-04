import 'dart:async';
import 'dart:developer';
import 'package:alz_mate/core/models/family_member_model.dart';
import 'package:alz_mate/core/services/notification_service.dart%20copy/notification_services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/reminder_model.dart';
import '../models/journal_entry_model.dart';
import '../models/sos_alert_model.dart';
import '../models/mood_entry_model.dart';
import '../models/game_score_model.dart';
import '../models/caregiver_request_model.dart';
import '../models/caregiver_application_model.dart';

class FirestoreService {
  // Singleton pattern
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collections
  static const String usersCollection = 'users';
  static const String remindersCollection = 'reminders';
  static const String journalEntriesCollection = 'journal_entries';
  static const String sosAlertsCollection = 'sos_alerts';
  static const String moodEntriesCollection = 'mood_entries';
  static const String gameScoresCollection = 'game_scores';
  static const String notificationsCollection = 'notifications';
  static const String faceRecognitionCollection = 'face_recognition';
  static const String caregiverApplicationsCollection = 'caregiver_applications';

  // Initialize the service
  Future<void> init() async {
    try {
      await _firestore.enablePersistence();
    } catch (e) {
      print('Firestore persistence error: $e');
    }
  }

  // ==================== USER CRUD OPERATIONS ====================

  // Create user
  Future<void> createUser(UserModel user) async {
    try {
      await _firestore
          .collection(usersCollection)
          .doc(user.id)
          .set(user.toJson());
    } catch (e) {
      throw Exception('Failed to create user: $e');
    }
  }

  // Read user by ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      final doc = await _firestore
          .collection(usersCollection)
          .doc(userId)
          .get();
      log(doc.data().toString());
      if (!doc.exists) return null;

      return UserModel.fromJson({'id': userId, ...doc.data()!});
    } catch (e) {
      throw Exception('Failed to get user: $e');
    }
  }

  // Read user by email
  Future<UserModel?> getUserByEmail(String email) async {
    try {
      final query = await _firestore
          .collection(usersCollection)
          .where('email', isEqualTo: email.toLowerCase())
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;

      final doc = query.docs.first;
      return UserModel.fromJson({'id': doc.id, ...doc.data()});
    } catch (e) {
      throw Exception('Failed to get user by email: $e');
    }
  }

  // Read all users by role
  Future<List<UserModel>> getUsersByRole(String role) async {
    try {
      final query = await _firestore
          .collection(usersCollection)
          .where('role', isEqualTo: role.toLowerCase())
          .get();

      return query.docs
          .map((doc) => UserModel.fromJson({'id': doc.id, ...doc.data()}))
          .toList();
    } catch (e) {
      throw Exception('Failed to get users by role: $e');
    }
  }

  // Update user
  Future<void> updateUser(String userId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection(usersCollection).doc(userId).update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  // Delete user
  Future<void> deleteUser(String userId) async {
    try {
      final batch = _firestore.batch();

      // Delete user document
      batch.delete(_firestore.collection(usersCollection).doc(userId));

      // Delete all user's reminders
      final reminders = await _firestore
          .collection(remindersCollection)
          .where('userId', isEqualTo: userId)
          .get();
      for (final doc in reminders.docs) {
        batch.delete(doc.reference);
      }

      // Delete all user's journal entries
      final journalEntries = await _firestore
          .collection(journalEntriesCollection)
          .where('userId', isEqualTo: userId)
          .get();
      for (final doc in journalEntries.docs) {
        batch.delete(doc.reference);
      }

      // Delete all user's mood entries
      final moodEntries = await _firestore
          .collection(moodEntriesCollection)
          .where('userId', isEqualTo: userId)
          .get();
      for (final doc in moodEntries.docs) {
        batch.delete(doc.reference);
      }

      // Delete all user's game scores
      final gameScores = await _firestore
          .collection(gameScoresCollection)
          .where('userId', isEqualTo: userId)
          .get();
      for (final doc in gameScores.docs) {
        batch.delete(doc.reference);
      }

      // Delete all user's SOS alerts
      final sosAlerts = await _firestore
          .collection(sosAlertsCollection)
          .where('userId', isEqualTo: userId)
          .get();
      for (final doc in sosAlerts.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }

  // Get user stream
  Stream<UserModel?> getUserStream(String userId) {
    return _firestore.collection(usersCollection).doc(userId).snapshots().map((
      doc,
    ) {
      if (!doc.exists) return null;
      return UserModel.fromJson({'id': userId, ...doc.data()!});
    });
  }

  // Link patient and caregiver
  Future<void> linkPatientCaregiver(
    String patientId,
    String caregiverId,
  ) async {
    try {
      final batch = _firestore.batch();

      // Add caregiver to patient's caregiverIds
      final patientRef = _firestore.collection(usersCollection).doc(patientId);
      batch.update(patientRef, {
        'caregiverIds': FieldValue.arrayUnion([caregiverId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Add patient to caregiver's patientIds
      final caregiverRef = _firestore
          .collection(usersCollection)
          .doc(caregiverId);
      batch.update(caregiverRef, {
        'patientIds': FieldValue.arrayUnion([patientId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to link patient and caregiver: $e');
    }
  }

  // Get patient's caregivers
  Future<List<UserModel>> getPatientCaregivers(String patientId) async {
    try {
      final patientDoc = await _firestore
          .collection(usersCollection)
          .doc(patientId)
          .get();

      if (!patientDoc.exists) return [];

      final caregiverIds = List<String>.from(
        patientDoc.data()?['caregiverIds'] ?? [],
      );

      if (caregiverIds.isEmpty) return [];

      final caregivers = <UserModel>[];
      for (final caregiverId in caregiverIds) {
        final caregiver = await getUserById(caregiverId);
        if (caregiver != null) {
          caregivers.add(caregiver);
        }
      }

      return caregivers;
    } catch (e) {
      throw Exception('Failed to get patient caregivers: $e');
    }
  }

  // Get patient's family members
  Future<List<UserModel>> getPatientFamilyMembers(String patientId) async {
    try {
      final query = await _firestore
          .collection(usersCollection)
          .where('role', isEqualTo: 'family')
          .where('patientId', isEqualTo: patientId)
          .get();

      return query.docs
          .map((doc) => UserModel.fromJson({'id': doc.id, ...doc.data()}))
          .toList();
    } catch (e) {
      throw Exception('Failed to get patient family members: $e');
    }
  }

  // ==================== REMINDER CRUD OPERATIONS ====================

  // Create reminder
  Future<String> createReminder(ReminderModel reminder) async {
    try {
      final docRef = await _firestore
          .collection(remindersCollection)
          .add(reminder.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create reminder: $e');
    }
  }

  Future<void> checkAndLogMissedReminders(
    String userId, {
    bool markAsMissed = true,
  }) async {
    try {
      final now = DateTime.now();
      final reminders = await getRemindersByUserId(userId);
      final currentUser = await getUserById(userId);

      for (final reminder in reminders) {
        // Skip if completed, missed, or already notified
        if (reminder.isCompleted ||
            reminder.isMissed ||
            (reminder.toMap()['missedNotified'] == true)) {
          continue;
        }

        // If reminder is in the past and not completed
        if (reminder.time.isBefore(now)) {
          log('⏰ Missed Reminder Detected');
          log('ID: ${reminder.id}');
          log('Title: ${reminder.title}');
          log('Time: ${reminder.time}');
          log('Type: ${reminder.type}');
          log('User ID: ${reminder.userId}');

          // Optional: mark reminder as missed in Firestore
          if (markAsMissed) {
            await updateReminder(reminder.id, {
              'isMissed': true,
              'missedAt': FieldValue.serverTimestamp(),
            });
          }

          // Notify caregivers
          final caregivers = await getPatientCaregivers(userId);
          final token = await NotificationServices().getAccessToken();

          for (UserModel caregiver in caregivers) {
            await NotificationServices().sendNotification(
              caregiver.fcmToken ?? '',
              token,
              '${currentUser?.name ?? "Patient"} missed a reminder for ${reminder.type} at ${reminder.time}',
              'Missed Reminder Alert',
            );
          }

          log("Reminder Id : ${reminder.id}");
          // ✅ Mark as notification sent
          await updateReminder(reminder.id, {'missedNotified': true});
        }
      }
    } catch (e) {
      log('❌ Error checking missed reminders: $e');
    }
  }

  // Read reminder by ID
  Future<ReminderModel?> getReminderById(String reminderId) async {
    try {
      final doc = await _firestore
          .collection(remindersCollection)
          .doc(reminderId)
          .get();

      if (!doc.exists) return null;

      return ReminderModel.fromMap(reminderId, doc.data()!);
    } catch (e) {
      throw Exception('Failed to get reminder: $e');
    }
  }

  // Read all reminders for user
  Future<List<ReminderModel>> getRemindersByUserId(String userId) async {
    try {
      final query = await _firestore
          .collection(remindersCollection)
          .where('userId', isEqualTo: userId)
          .get();

      return query.docs
          .map((doc) => ReminderModel.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get reminders: $e');
    }
  }

  // Read reminders by type
  Future<List<ReminderModel>> getRemindersByType(
    String userId,
    String type,
  ) async {
    try {
      final query = await _firestore
          .collection(remindersCollection)
          .where('userId', isEqualTo: userId)
          .where('type', isEqualTo: type)
          .get();

      return query.docs
          .map((doc) => ReminderModel.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get reminders by type: $e');
    }
  }

  // Read today's reminders
  Future<List<ReminderModel>> getTodaysReminders(String userId) async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final query = await _firestore
          .collection(remindersCollection)
          .where('userId', isEqualTo: userId)
          // .where('time', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          // .where('time', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      return query.docs
          .map((doc) => ReminderModel.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get today\'s reminders: $e');
    }
  }

  // Read overdue reminders
  Future<List<ReminderModel>> getOverdueReminders(String userId) async {
    try {
      final now = DateTime.now();

      final query = await _firestore
          .collection(remindersCollection)
          .where('userId', isEqualTo: userId)
          .where('isCompleted', isEqualTo: false)
          .where('isMissed', isEqualTo: false)
          .where('time', isLessThan: Timestamp.fromDate(now))
          .get();

      return query.docs
          .map((doc) => ReminderModel.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get overdue reminders: $e');
    }
  }

  // Update reminder
  Future<void> updateReminder(
    String reminderId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _firestore.collection(remindersCollection).doc(reminderId).update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update reminder: $e');
    }
  }

  // Delete reminder
  Future<void> deleteReminder(String reminderId) async {
    try {
      await _firestore.collection(remindersCollection).doc(reminderId).delete();
    } catch (e) {
      throw Exception('Failed to delete reminder: $e');
    }
  }

  // Get reminders stream
  Stream<List<ReminderModel>> getRemindersStream(String userId) {
    return _firestore
        .collection(remindersCollection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ReminderModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  // Mark reminder as completed
  Future<void> markReminderCompleted(String reminderId) async {
    try {
      await updateReminder(reminderId, {
        'isCompleted': true,
        'completedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to mark reminder as completed: $e');
    }
  }

  // Mark reminder as missed
  Future<void> markReminderMissed(String reminderId) async {
    try {
      await updateReminder(reminderId, {
        'isMissed': true,
        'missedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to mark reminder as missed: $e');
    }
  }

  // ==================== JOURNAL ENTRY CRUD OPERATIONS ====================

  // Create journal entry
  Future<String> createJournalEntry(JournalEntryModel entry) async {
    try {
      final docRef = await _firestore
          .collection(journalEntriesCollection)
          .add(entry.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create journal entry: $e');
    }
  }

  // Read journal entry by ID
  Future<JournalEntryModel?> getJournalEntryById(String entryId) async {
    try {
      final doc = await _firestore
          .collection(journalEntriesCollection)
          .doc(entryId)
          .get();

      if (!doc.exists) return null;

      return JournalEntryModel.fromMap({'id': entryId, ...doc.data()!});
    } catch (e) {
      throw Exception('Failed to get journal entry: $e');
    }
  }

  Future<List<ReminderModel>> getMissedReminders(String userId) async {
    final now = DateTime.now();
    final snap = await _firestore
        .collection(remindersCollection)
        .where('userId', isEqualTo: userId)
        .where('isCompleted', isEqualTo: false)
        .where('time', isLessThan: Timestamp.fromDate(now))
        .get();

    return snap.docs.map((d) => ReminderModel.fromMap(d.id, d.data())).toList();
  }

  // Read all journal entries for user
  Future<List<JournalEntryModel>> getJournalEntriesByUserId(
    String userId,
  ) async {
    try {
      final query = await _firestore
          .collection(journalEntriesCollection)
          .where('userId', isEqualTo: userId)
          .get();

      return query.docs
          .map(
            (doc) => JournalEntryModel.fromMap({'id': doc.id, ...doc.data()}),
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to get journal entries: $e');
    }
  }

  // Read journal entries by type
  Future<List<JournalEntryModel>> getJournalEntriesByType(
    String userId,
    String type,
  ) async {
    try {
      final query = await _firestore
          .collection(journalEntriesCollection)
          .where('userId', isEqualTo: userId)
          .where('type', isEqualTo: type)
          .get();

      return query.docs
          .map(
            (doc) => JournalEntryModel.fromMap({'id': doc.id, ...doc.data()}),
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to get journal entries by type: $e');
    }
  }

  // Read journal entries by date range
  Future<List<JournalEntryModel>> getJournalEntriesByDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final query = await _firestore
          .collection(journalEntriesCollection)
          .where('userId', isEqualTo: userId)
          .where(
            'timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          )
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      return query.docs
          .map(
            (doc) => JournalEntryModel.fromMap({'id': doc.id, ...doc.data()}),
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to get journal entries by date range: $e');
    }
  }

  // Read journal entries with pagination
  Future<List<JournalEntryModel>> getJournalEntriesWithPagination(
    String userId, {
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      Query query = _firestore
          .collection(journalEntriesCollection)
          .where('userId', isEqualTo: userId)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final result = await query.get();

      return result.docs
          .map(
            (doc) => JournalEntryModel.fromMap({
              'id': doc.id,
              ...doc.data() as Map<String, dynamic>,
            }),
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to get journal entries with pagination: $e');
    }
  }

  // Update journal entry
  Future<void> updateJournalEntry(
    String entryId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _firestore.collection(journalEntriesCollection).doc(entryId).update(
        {...updates, 'updatedAt': FieldValue.serverTimestamp()},
      );
    } catch (e) {
      throw Exception('Failed to update journal entry: $e');
    }
  }

  // Delete journal entry
  Future<void> deleteJournalEntry(String entryId) async {
    try {
      await _firestore
          .collection(journalEntriesCollection)
          .doc(entryId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete journal entry: $e');
    }
  }

  // Get journal entries stream
  Stream<List<JournalEntryModel>> getJournalEntriesStream(String userId) {
    return _firestore
        .collection(journalEntriesCollection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) =>
                    JournalEntryModel.fromMap({'id': doc.id, ...doc.data()}),
              )
              .toList(),
        );
  }

  // Search journal entries
  Future<List<JournalEntryModel>> searchJournalEntries(
    String userId,
    String searchQuery,
  ) async {
    try {
      // Note: This is a basic implementation. For better search, consider using Algolia
      final entries = await getJournalEntriesByUserId(userId);

      if (searchQuery.isEmpty) return entries;

      return entries.where((entry) {
        final content = entry.content.toLowerCase();
        final query = searchQuery.toLowerCase();
        return content.contains(query);
      }).toList();
    } catch (e) {
      throw Exception('Failed to search journal entries: $e');
    }
  }

  // ==================== SOS ALERT CRUD OPERATIONS ====================

  // Create SOS alert
  Future<String> createSosAlert(SOSAlertModel alert) async {
    try {
      final docRef = await _firestore
          .collection(sosAlertsCollection)
          .add(alert.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create SOS alert: $e');
    }
  }

  // Read SOS alert by ID
  Future<SOSAlertModel?> getSosAlertById(String alertId) async {
    try {
      final doc = await _firestore
          .collection(sosAlertsCollection)
          .doc(alertId)
          .get();

      if (!doc.exists) return null;

      return SOSAlertModel.fromMap(alertId, {'id': alertId, ...doc.data()!});
    } catch (e) {
      throw Exception('Failed to get SOS alert: $e');
    }
  }

  // Read all SOS alerts for user
  Future<List<SOSAlertModel>> getSosAlertsByUserId(String userId) async {
    try {
      final query = await _firestore
          .collection(sosAlertsCollection)
          .where('userId', isEqualTo: userId)
          .get();

      return query.docs
          .map(
            (doc) =>
                SOSAlertModel.fromMap(doc.id, {'id': doc.id, ...doc.data()}),
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to get SOS alerts: $e');
    }
  }

  // Read active SOS alerts
  Future<List<SOSAlertModel>> getActiveSosAlerts(String userId) async {
    try {
      final query = await _firestore
          .collection(sosAlertsCollection)
          .where('userId', isEqualTo: userId)
          .where('isResolved', isEqualTo: false)
          .get();

      return query.docs
          .map(
            (doc) =>
                SOSAlertModel.fromMap(doc.id, {'id': doc.id, ...doc.data()}),
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to get active SOS alerts: $e');
    }
  }

  // Read SOS alerts for caregiver
  Future<List<SOSAlertModel>> getSosAlertsForCaregiver(
    String caregiverId,
  ) async {
    try {
      // First get the caregiver's patients
      final caregiverDoc = await _firestore
          .collection(usersCollection)
          .doc(caregiverId)
          .get();

      if (!caregiverDoc.exists) return [];

      final patientIds = List<String>.from(
        caregiverDoc.data()?['patientIds'] ?? [],
      );

      if (patientIds.isEmpty) return [];

      final query = await _firestore
          .collection(sosAlertsCollection)
          .where('userId', whereIn: patientIds)
          .get();

      return query.docs
          .map(
            (doc) =>
                SOSAlertModel.fromMap(doc.id, {'id': doc.id, ...doc.data()}),
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to get SOS alerts for caregiver: $e');
    }
  }

  // Update SOS alert
  Future<void> updateSosAlert(
    String alertId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _firestore.collection(sosAlertsCollection).doc(alertId).update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update SOS alert: $e');
    }
  }

  // Delete SOS alert
  Future<void> deleteSosAlert(String alertId) async {
    try {
      await _firestore.collection(sosAlertsCollection).doc(alertId).delete();
    } catch (e) {
      throw Exception('Failed to delete SOS alert: $e');
    }
  }

  // Get SOS alerts stream
  Stream<List<SOSAlertModel>> getSosAlertsStream(String userId) {
    return _firestore
        .collection(sosAlertsCollection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => SOSAlertModel.fromMap(doc.id, {
                  'id': doc.id,
                  ...doc.data(),
                }),
              )
              .toList(),
        );
  }

  // Resolve SOS alert
  Future<void> resolveSosAlert(String alertId, String resolvedBy) async {
    try {
      await updateSosAlert(alertId, {
        'isResolved': true,
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedBy': resolvedBy,
      });
    } catch (e) {
      throw Exception('Failed to resolve SOS alert: $e');
    }
  }

  // ==================== MOOD ENTRY CRUD OPERATIONS ====================

  // Create mood entry
  Future<String> createMoodEntry(MoodEntryModel mood) async {
    try {
      final docRef = await _firestore
          .collection(moodEntriesCollection)
          .add(mood.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create mood entry: $e');
    }
  }

  // Read mood entry by ID
  Future<MoodEntryModel?> getMoodEntryById(String entryId) async {
    try {
      final doc = await _firestore
          .collection(moodEntriesCollection)
          .doc(entryId)
          .get();

      if (!doc.exists) return null;

      return MoodEntryModel.fromMap({'id': entryId, ...doc.data()!});
    } catch (e) {
      throw Exception('Failed to get mood entry: $e');
    }
  }

  // Read all mood entries for user
  Future<List<MoodEntryModel>> getMoodEntriesByUserId(String userId) async {
    try {
      final query = await _firestore
          .collection(moodEntriesCollection)
          .where('userId', isEqualTo: userId)
          .get();

      return query.docs
          .map((doc) => MoodEntryModel.fromMap({'id': doc.id, ...doc.data()}))
          .toList();
    } catch (e) {
      throw Exception('Failed to get mood entries: $e');
    }
  }

  // Read mood entries by date range
  Future<List<MoodEntryModel>> getMoodEntriesByDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final query = await _firestore
          .collection(moodEntriesCollection)
          .where('userId', isEqualTo: userId)
          .where(
            'timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          )
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      return query.docs
          .map((doc) => MoodEntryModel.fromMap({'id': doc.id, ...doc.data()}))
          .toList();
    } catch (e) {
      throw Exception('Failed to get mood entries by date range: $e');
    }
  }

  // Read mood entries by mood type
  Future<List<MoodEntryModel>> getMoodEntriesByMood(
    String userId,
    String mood,
  ) async {
    try {
      final query = await _firestore
          .collection(moodEntriesCollection)
          .where('userId', isEqualTo: userId)
          .where('mood', isEqualTo: mood)
          .get();

      return query.docs
          .map((doc) => MoodEntryModel.fromMap({'id': doc.id, ...doc.data()}))
          .toList();
    } catch (e) {
      throw Exception('Failed to get mood entries by mood: $e');
    }
  }

  // Update mood entry
  Future<void> updateMoodEntry(
    String entryId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _firestore.collection(moodEntriesCollection).doc(entryId).update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update mood entry: $e');
    }
  }

  // Delete mood entry
  Future<void> deleteMoodEntry(String entryId) async {
    try {
      await _firestore.collection(moodEntriesCollection).doc(entryId).delete();
    } catch (e) {
      throw Exception('Failed to delete mood entry: $e');
    }
  }

  // Get mood entries stream
  Stream<List<MoodEntryModel>> getMoodEntriesStream(String userId) {
    return _firestore
        .collection(moodEntriesCollection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => MoodEntryModel.fromMap({'id': doc.id, ...doc.data()}),
              )
              .toList(),
        );
  }

  // Get mood statistics
  Future<Map<String, dynamic>> getMoodStatistics(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final entries = await getMoodEntriesByDateRange(
        userId,
        startDate,
        endDate,
      );

      if (entries.isEmpty) {
        return {
          'totalEntries': 0,
          'averageScore': 0.0,
          'moodDistribution': <String, int>{},
          'positiveCount': 0,
          'negativeCount': 0,
          'neutralCount': 0,
        };
      }

      final moodDistribution = <String, int>{};
      double totalScore = 0.0;
      int positiveCount = 0;
      int negativeCount = 0;
      int neutralCount = 0;

      for (final entry in entries) {
        // Count mood distribution
        moodDistribution[entry.mood] = (moodDistribution[entry.mood] ?? 0) + 1;

        // Sum scores
        totalScore += entry.score;

        // Count sentiment
        if (entry.isPositive) {
          positiveCount++;
        } else if (entry.isNegative) {
          negativeCount++;
        } else {
          neutralCount++;
        }
      }

      return {
        'totalEntries': entries.length,
        'averageScore': totalScore / entries.length,
        'moodDistribution': moodDistribution,
        'positiveCount': positiveCount,
        'negativeCount': negativeCount,
        'neutralCount': neutralCount,
      };
    } catch (e) {
      throw Exception('Failed to get mood statistics: $e');
    }
  }

  // ==================== GAME SCORE CRUD OPERATIONS ====================

  // Create game score
  Future<String> createGameScore(GameScoreModel score) async {
    try {
      final docRef = await _firestore
          .collection(gameScoresCollection)
          .add(score.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create game score: $e');
    }
  }

  // Read game score by ID
  Future<GameScoreModel?> getGameScoreById(String scoreId) async {
    try {
      final doc = await _firestore
          .collection(gameScoresCollection)
          .doc(scoreId)
          .get();

      if (!doc.exists) return null;

      return GameScoreModel.fromMap({'id': scoreId, ...doc.data()!});
    } catch (e) {
      throw Exception('Failed to get game score: $e');
    }
  }

  // Read all game scores for user
  Future<List<GameScoreModel>> getGameScoresByUserId(String userId) async {
    try {
      final query = await _firestore
          .collection(gameScoresCollection)
          .where('userId', isEqualTo: userId)
          .get();

      return query.docs
          .map((doc) => GameScoreModel.fromMap({'id': doc.id, ...doc.data()}))
          .toList();
    } catch (e) {
      throw Exception('Failed to get game scores: $e');
    }
  }

  // Read game scores by game name
  Future<List<GameScoreModel>> getGameScoresByGameName(
    String userId,
    String gameName,
  ) async {
    try {
      final query = await _firestore
          .collection(gameScoresCollection)
          .where('userId', isEqualTo: userId)
          .where('gameName', isEqualTo: gameName)
          .get();

      return query.docs
          .map((doc) => GameScoreModel.fromMap({'id': doc.id, ...doc.data()}))
          .toList();
    } catch (e) {
      throw Exception('Failed to get game scores by game name: $e');
    }
  }

  // Read high scores for a game
  Future<List<GameScoreModel>> getHighScores(
    String gameName, {
    int limit = 10,
  }) async {
    try {
      final query = await _firestore
          .collection(gameScoresCollection)
          .where('gameName', isEqualTo: gameName)
          .limit(limit)
          .get();

      return query.docs
          .map((doc) => GameScoreModel.fromMap({'id': doc.id, ...doc.data()}))
          .toList();
    } catch (e) {
      throw Exception('Failed to get high scores: $e');
    }
  }

  // Update game score
  Future<void> updateGameScore(
    String scoreId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _firestore.collection(gameScoresCollection).doc(scoreId).update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update game score: $e');
    }
  }

  // Delete game score
  Future<void> deleteGameScore(String scoreId) async {
    try {
      await _firestore.collection(gameScoresCollection).doc(scoreId).delete();
    } catch (e) {
      throw Exception('Failed to delete game score: $e');
    }
  }

  // Get game scores stream
  Stream<List<GameScoreModel>> getGameScoresStream(String userId) {
    return _firestore
        .collection(gameScoresCollection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => GameScoreModel.fromMap({'id': doc.id, ...doc.data()}),
              )
              .toList(),
        );
  }

  // Get game statistics
  Future<Map<String, dynamic>> getGameStatistics(String userId) async {
    try {
      final scores = await getGameScoresByUserId(userId);

      if (scores.isEmpty) {
        return {
          'totalGamesPlayed': 0,
          'averageScore': 0.0,
          'highestScore': 0,
          'favoriteGame': null,
          'totalPlayTime': 0,
          'gameTypeDistribution': <String, int>{},
        };
      }

      final gameTypeDistribution = <String, int>{};
      final gameNameCount = <String, int>{};
      int totalScore = 0;
      int highestScore = 0;
      int totalPlayTime = 0;

      for (final score in scores) {
        // Count game types
        gameTypeDistribution[score.gameType] =
            (gameTypeDistribution[score.gameType] ?? 0) + 1;

        // Count game names
        gameNameCount[score.gameName] =
            (gameNameCount[score.gameName] ?? 0) + 1;

        // Sum scores
        totalScore += score.score;

        // Track highest score
        if (score.score > highestScore) {
          highestScore = score.score;
        }

        // Sum play time
        totalPlayTime += score.duration.inSeconds;
      }

      // Find favorite game
      String? favoriteGame;
      int maxCount = 0;
      gameNameCount.forEach((game, count) {
        if (count > maxCount) {
          maxCount = count;
          favoriteGame = game;
        }
      });

      return {
        'totalGamesPlayed': scores.length,
        'averageScore': totalScore / scores.length,
        'highestScore': highestScore,
        'favoriteGame': favoriteGame,
        'totalPlayTime': totalPlayTime,
        'gameTypeDistribution': gameTypeDistribution,
      };
    } catch (e) {
      throw Exception('Failed to get game statistics: $e');
    }
  }

  // ==================== UTILITY METHODS ====================

  // Get dashboard statistics
  Future<Map<String, dynamic>> getDashboardStats(String userId) async {
    try {
      final futures = await Future.wait([
        getRemindersByUserId(userId),
        getJournalEntriesByUserId(userId),
        getSosAlertsByUserId(userId),
        getMoodEntriesByUserId(userId),
        getGameScoresByUserId(userId),
      ]);

      final reminders = futures[0] as List<ReminderModel>;
      final journalEntries = futures[1] as List<JournalEntryModel>;
      final sosAlerts = futures[2] as List<SOSAlertModel>;
      final moodEntries = futures[3] as List<MoodEntryModel>;
      final gameScores = futures[4] as List<GameScoreModel>;

      // Calculate today's data
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final todayReminders = reminders
          .where((r) => r.time.isAfter(startOfDay) && r.time.isBefore(endOfDay))
          .length;
      final todayJournalEntries = journalEntries
          .where(
            (j) =>
                j.timestamp.isAfter(startOfDay) &&
                j.timestamp.isBefore(endOfDay),
          )
          .length;
      final todayMoodEntries = moodEntries
          .where(
            (m) =>
                m.timestamp.isAfter(startOfDay) &&
                m.timestamp.isBefore(endOfDay),
          )
          .length;

      return {
        'totalReminders': reminders.length,
        'pendingReminders': reminders
            .where((r) => !r.isCompleted && !r.isMissed)
            .length,
        'completedReminders': reminders.where((r) => r.isCompleted).length,
        'missedReminders': reminders.where((r) => r.isMissed).length,
        'todayReminders': todayReminders,

        'totalJournalEntries': journalEntries.length,
        'todayJournalEntries': todayJournalEntries,

        'totalSosAlerts': sosAlerts.length,
        'activeSosAlerts': sosAlerts.where((a) => !a.isResolved).length,
        'resolvedSosAlerts': sosAlerts.where((a) => a.isResolved).length,

        'totalMoodEntries': moodEntries.length,
        'todayMoodEntries': todayMoodEntries,
        'positiveMoodEntries': moodEntries.where((m) => m.isPositive).length,
        'negativeMoodEntries': moodEntries.where((m) => m.isNegative).length,

        'totalGamesPlayed': gameScores.length,
        'averageGameScore': gameScores.isNotEmpty
            ? gameScores.map((g) => g.score).reduce((a, b) => a + b) /
                  gameScores.length
            : 0.0,
      };
    } catch (e) {
      throw Exception('Failed to get dashboard stats: $e');
    }
  }

  // Batch operations
  WriteBatch getBatch() => _firestore.batch();

  Future<void> commitBatch(WriteBatch batch) async {
    try {
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to commit batch: $e');
    }
  }

  // Transaction operations
  Future<T> runTransaction<T>(
    Future<T> Function(Transaction transaction) updateFunction,
  ) async {
    try {
      return await _firestore.runTransaction(updateFunction);
    } catch (e) {
      throw Exception('Transaction failed: $e');
    }
  }

  // Bulk operations
  Future<void> bulkCreateReminders(List<ReminderModel> reminders) async {
    try {
      final batch = getBatch();

      for (final reminder in reminders) {
        final docRef = _firestore.collection(remindersCollection).doc();
        batch.set(docRef, reminder.toMap());
      }

      await commitBatch(batch);
    } catch (e) {
      throw Exception('Failed to bulk create reminders: $e');
    }
  }

  Future<void> bulkDeleteReminders(List<String> reminderIds) async {
    try {
      final batch = getBatch();

      for (final id in reminderIds) {
        batch.delete(_firestore.collection(remindersCollection).doc(id));
      }

      await commitBatch(batch);
    } catch (e) {
      throw Exception('Failed to bulk delete reminders: $e');
    }
  }

  // Data export
  Future<Map<String, dynamic>> exportUserData(String userId) async {
    try {
      final futures = await Future.wait([
        getUserById(userId),
        getRemindersByUserId(userId),
        getJournalEntriesByUserId(userId),
        getSosAlertsByUserId(userId),
        getMoodEntriesByUserId(userId),
        getGameScoresByUserId(userId),
      ]);

      return {
        'user': (futures[0] as UserModel?)?.toJson(),

        'reminders': (futures[1] as List<ReminderModel>)
            .map((r) => r.toMap())
            .toList(),
        'journalEntries': (futures[2] as List<JournalEntryModel>)
            .map((j) => j.toMap())
            .toList(),
        'sosAlerts': (futures[3] as List<SOSAlertModel>)
            .map((s) => s.toMap())
            .toList(),
        'moodEntries': (futures[4] as List<MoodEntryModel>)
            .map((m) => m.toMap())
            .toList(),
        'gameScores': (futures[5] as List<GameScoreModel>)
            .map((g) => g.toMap())
            .toList(),
        'exportedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      throw Exception('Failed to export user data: $e');
    }
  }

  // Data cleanup
  Future<void> cleanupOldData(String userId, Duration maxAge) async {
    try {
      final cutoffDate = DateTime.now().subtract(maxAge);
      final batch = getBatch();

      // Clean old journal entries
      final oldJournalEntries = await _firestore
          .collection(journalEntriesCollection)
          .where('userId', isEqualTo: userId)
          .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();

      for (final doc in oldJournalEntries.docs) {
        batch.delete(doc.reference);
      }

      // Clean old mood entries
      final oldMoodEntries = await _firestore
          .collection(moodEntriesCollection)
          .where('userId', isEqualTo: userId)
          .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();

      for (final doc in oldMoodEntries.docs) {
        batch.delete(doc.reference);
      }

      // Clean old game scores
      final oldGameScores = await _firestore
          .collection(gameScoresCollection)
          .where('userId', isEqualTo: userId)
          .where('playedAt', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();

      for (final doc in oldGameScores.docs) {
        batch.delete(doc.reference);
      }

      await commitBatch(batch);
    } catch (e) {
      throw Exception('Failed to cleanup old data: $e');
    }
  }

  // Additional methods for caregiver functionality
  Future<List<UserModel>> getCaregiverPatients(String caregiverId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'patient')
          .where('caregiverIds', arrayContains: caregiverId)
          .get();

      return snapshot.docs
          .map((doc) => UserModel.fromJson({'id': doc.id, ...doc.data()}))
          .toList();
    } catch (e) {
      print('Error fetching caregiver patients: $e');
      return [];
    }
  }

  Future<List<SOSAlertModel>> getSOSAlerts(String patientId) async {
    try {
      final snapshot = await _firestore
          .collection('sos_alerts')
          .where('userId', isEqualTo: patientId)
          .get();

      log("Id: ${snapshot.docs.first.id}");
      return snapshot.docs
          .map(
            (doc) =>
                SOSAlertModel.fromMap(doc.id, {'id': doc.id, ...doc.data()}),
          )
          .toList();
    } catch (e) {
      log('Error fetching SOS alerts for $patientId: $e');
      return [];
    }
  }

  Future<void> resolveSOSAlert(String alertId) async {
    try {
      await _firestore.collection('sos_alerts').doc(alertId).update({
        'isResolved': true,
        'resolvedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      log('Error resolving SOS alert: $e');
    }
  }

  Future<List<MoodEntryModel>> getRecentMoodEntries(
    String userId,
    int limit,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('mood_entries')
          .where('userId', isEqualTo: userId)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => MoodEntryModel.fromMap({'id': doc.id, ...doc.data()}))
          .toList();
    } catch (e) {
      print('Error getting recent mood entries: $e');
      return [];
    }
  }

  Future<List<FamilyMemberModel>> getFamilyMembers(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('family_members')
          // .where('userId', isEqualTo: userId)
          .get();

      return snapshot.docs.map((doc) {
        return FamilyMemberModel.fromMap(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      print('Error getting family members: $e');
      return [];
    }
  }

  Future<void> addFamilyMember(FamilyMemberModel member) async {
    try {
      await _firestore.collection('family_members').add(member.toMap());
    } catch (e) {
      print('Error adding family member: $e');
      rethrow;
    }
  }

  // ==================== FACE RECOGNITION EMBEDDINGS ====================

  // Save face embedding to Firestore
  Future<void> saveFaceEmbedding({
    required String faceId,
    required String userId,
    required String name,
    required String relationship,
    required List<double> embedding,
    String? imageUrl,
  }) async {
    try {
      print('Saving face embedding to Firestore - Collection: $faceRecognitionCollection');
      print('FaceId: $faceId, UserId: $userId, Name: $name, Embedding size: ${embedding.length}');
      
      await _firestore
          .collection(faceRecognitionCollection)
          .doc(faceId)
          .set({
        'userId': userId,
        'name': name,
        'relationship': relationship,
        'embedding': embedding,
        'imageUrl': imageUrl ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      print('✓ Face embedding successfully saved to Firestore: $faceId');
    } catch (e, stackTrace) {
      print('✗ Error saving face embedding to Firestore: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Failed to save face embedding: $e');
    }
  }

  // Get all face embeddings for a user
  Future<List<Map<String, dynamic>>> getFaceEmbeddings(String userId) async {
    try {
      print('Querying Firestore for face embeddings - Collection: $faceRecognitionCollection, userId: $userId');
      final query = await _firestore
          .collection(faceRecognitionCollection)
          .where('userId', isEqualTo: userId)
          .get();

      print('Firestore query returned ${query.docs.length} documents');
      
      final embeddings = query.docs.map((doc) {
        try {
          final data = doc.data();
          final embedding = data['embedding'];
          
          if (embedding == null) {
            print('Warning: Document ${doc.id} has no embedding field');
            return null;
          }
          
          final embeddingList = List<double>.from(embedding as List);
          if (embeddingList.isEmpty) {
            print('Warning: Document ${doc.id} has empty embedding');
            return null;
          }
          
          return {
            'id': doc.id,
            'name': data['name'] ?? '',
            'relationship': data['relationship'] ?? '',
            'embedding': embeddingList,
            'imageUrl': data['imageUrl'] ?? '',
            'createdAt': data['createdAt']?.toDate()?.toIso8601String() ?? '',
            'updatedAt': data['updatedAt']?.toDate()?.toIso8601String() ?? '',
          };
        } catch (e) {
          print('Error processing document ${doc.id}: $e');
          return null;
        }
      }).where((item) => item != null).cast<Map<String, dynamic>>().toList();
      
      print('Successfully processed ${embeddings.length} face embeddings');
      return embeddings;
    } catch (e, stackTrace) {
      print('Error getting face embeddings from Firestore: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Failed to get face embeddings: $e');
    }
  }

  // Get face embedding by ID
  Future<Map<String, dynamic>?> getFaceEmbeddingById(String faceId) async {
    try {
      final doc = await _firestore
          .collection(faceRecognitionCollection)
          .doc(faceId)
          .get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      return {
        'id': doc.id,
        'userId': data['userId'] ?? '',
        'name': data['name'] ?? '',
        'relationship': data['relationship'] ?? '',
        'embedding': List<double>.from(data['embedding'] ?? []),
        'imageUrl': data['imageUrl'] ?? '',
        'createdAt': data['createdAt']?.toDate()?.toIso8601String() ?? '',
        'updatedAt': data['updatedAt']?.toDate()?.toIso8601String() ?? '',
      };
    } catch (e) {
      throw Exception('Failed to get face embedding: $e');
    }
  }

  // Update face embedding
  Future<void> updateFaceEmbedding(
    String faceId, {
    String? name,
    String? relationship,
    List<double>? embedding,
    String? imageUrl,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (name != null) updates['name'] = name;
      if (relationship != null) updates['relationship'] = relationship;
      if (embedding != null) updates['embedding'] = embedding;
      if (imageUrl != null) updates['imageUrl'] = imageUrl;

      await _firestore
          .collection(faceRecognitionCollection)
          .doc(faceId)
          .update(updates);
    } catch (e) {
      throw Exception('Failed to update face embedding: $e');
    }
  }

  // Delete face embedding
  Future<void> deleteFaceEmbedding(String faceId) async {
    try {
      await _firestore
          .collection(faceRecognitionCollection)
          .doc(faceId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete face embedding: $e');
    }
  }

  // Delete all face embeddings for a user
  Future<void> deleteAllFaceEmbeddings(String userId) async {
    try {
      final query = await _firestore
          .collection(faceRecognitionCollection)
          .where('userId', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      for (final doc in query.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to delete all face embeddings: $e');
    }
  }

  Future<void> deleteFamilyMember(String memberId) async {
    try {
      await _firestore.collection('family_members').doc(memberId).delete();
    } catch (e) {
      print('Error deleting family member: $e');
      rethrow;
    }
  }

  // QR Code methods
  Future<String> createQrCode(Map<String, dynamic> qrCodeData) async {
    final docRef = await FirebaseFirestore.instance
        .collection('qr_codes')
        .add(qrCodeData);
    return docRef.id;
  }

  Future<void> deleteQrCode(String qrCodeId) async {
    await FirebaseFirestore.instance
        .collection('qr_codes')
        .doc(qrCodeId)
        .delete();
  }

  Future<Map<String, dynamic>?> getQrCodeById(String qrCodeId) async {
    final docSnapshot = await FirebaseFirestore.instance
        .collection('qr_codes')
        .doc(qrCodeId)
        .get();

    if (docSnapshot.exists) {
      final data = docSnapshot.data()!;
      data['id'] = docSnapshot.id;
      return data;
    } else {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getQrCodes(String userId) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('qr_codes')
        .where('userId', isEqualTo: userId)
        .get();

    return querySnapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  // ==================== CAREGIVER REQUEST OPERATIONS ====================

  // Create caregiver request
  Future<String> createCaregiverRequest(CaregiverRequestModel request) async {
    try {
      final docRef = await _firestore
          .collection('caregiver_requests')
          .add(request.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create caregiver request: $e');
    }
  }

  // Get caregiver requests for patient
  Future<List<CaregiverRequestModel>> getCaregiverRequestsForPatient(
    String patientId,
  ) async {
    try {
      final query = await _firestore
          .collection('caregiver_requests')
          .where('patientId', isEqualTo: patientId)
          .get();

      return query.docs
          .map(
            (doc) =>
                CaregiverRequestModel.fromMap({'id': doc.id, ...doc.data()}),
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to get caregiver requests: $e');
    }
  }

  // Get caregiver requests for caregiver
  Future<List<CaregiverRequestModel>> getCaregiverRequestsForCaregiver(
    String caregiverId,
  ) async {
    try {
      final query = await _firestore
          .collection('caregiver_requests')
          .where('caregiverId', isEqualTo: caregiverId)
          .get();

      return query.docs
          .map(
            (doc) =>
                CaregiverRequestModel.fromMap({'id': doc.id, ...doc.data()}),
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to get caregiver requests: $e');
    }
  }

  // Update caregiver request status
  Future<void> updateCaregiverRequestStatus(
    String requestId,
    String status,
    String? responseMessage,
  ) async {
    try {
      await _firestore.collection('caregiver_requests').doc(requestId).update({
        'status': status,
        'respondedAt': FieldValue.serverTimestamp(),
        'responseMessage': responseMessage,
      });

      // If accepted, link patient and caregiver
      if (status == 'accepted') {
        final requestDoc = await _firestore
            .collection('caregiver_requests')
            .doc(requestId)
            .get();

        if (requestDoc.exists) {
          final data = requestDoc.data()!;
          await linkPatientCaregiver(data['patientId'], data['caregiverId']);
        }
      }
    } catch (e) {
      throw Exception('Failed to update caregiver request: $e');
    }
  }

  // Check if caregiver request exists
  Future<bool> caregiverRequestExists(
    String patientId,
    String caregiverId,
  ) async {
    try {
      final query = await _firestore
          .collection('caregiver_requests')
          .where('patientId', isEqualTo: patientId)
          .where('caregiverId', isEqualTo: caregiverId)
          .where('status', isEqualTo: 'pending')
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Get available caregivers (not already connected to patient)
  Future<List<UserModel>> getAvailableCaregivers(String patientId) async {
    try {
      // Get all caregivers
      final allCaregivers = await getUsersByRole('caregiver');

      // Get patient's current caregivers
      final currentCaregivers = await getPatientCaregivers(patientId);
      final currentCaregiverIds = currentCaregivers.map((c) => c.id).toSet();

      // Get pending requests
      final pendingRequests = await getCaregiverRequestsForPatient(patientId);
      final pendingCaregiverIds = pendingRequests
          .where((r) => r.isPending)
          .map((r) => r.caregiverId)
          .toSet();

      // Filter out already connected and pending caregivers
      return allCaregivers
          .where(
            (caregiver) =>
                !currentCaregiverIds.contains(caregiver.id) &&
                !pendingCaregiverIds.contains(caregiver.id),
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to get available caregivers: $e');
    }
  }

  // ==================== CAREGIVER APPLICATION OPERATIONS ====================

  // Create caregiver application
  Future<String> createCaregiverApplication(
    CaregiverApplicationModel application,
  ) async {
    try {
      final docRef = await _firestore
          .collection(caregiverApplicationsCollection)
          .add(application.toJson());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create caregiver application: $e');
    }
  }

  // Get caregiver application by user ID
  Future<CaregiverApplicationModel?> getCaregiverApplicationByUserId(
    String userId,
  ) async {
    try {
      final query = await _firestore
          .collection(caregiverApplicationsCollection)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;

      final doc = query.docs.first;
      return CaregiverApplicationModel.fromJson({
        'id': doc.id,
        ...doc.data(),
      });
    } catch (e) {
      throw Exception('Failed to get caregiver application: $e');
    }
  }

  // Get all pending caregiver applications
  Future<List<CaregiverApplicationModel>> getPendingCaregiverApplications() async {
    try {
      final query = await _firestore
          .collection(caregiverApplicationsCollection)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get();

      return query.docs
          .map((doc) => CaregiverApplicationModel.fromJson({
                'id': doc.id,
                ...doc.data(),
              }))
          .toList();
    } catch (e) {
      throw Exception('Failed to get pending caregiver applications: $e');
    }
  }

  // Get all caregiver applications
  Future<List<CaregiverApplicationModel>> getAllCaregiverApplications() async {
    try {
      final query = await _firestore
          .collection(caregiverApplicationsCollection)
          .orderBy('createdAt', descending: true)
          .get();

      return query.docs
          .map((doc) => CaregiverApplicationModel.fromJson({
                'id': doc.id,
                ...doc.data(),
              }))
          .toList();
    } catch (e) {
      throw Exception('Failed to get caregiver applications: $e');
    }
  }

  // Update caregiver application exam results
  Future<void> updateCaregiverApplicationExamResults(
    String userId,
    int score,
    int totalQuestions,
    double percentage,
    List<Map<String, dynamic>> answers,
  ) async {
    try {
      final application = await getCaregiverApplicationByUserId(userId);
      if (application == null) {
        throw Exception('Caregiver application not found');
      }

      await _firestore
          .collection(caregiverApplicationsCollection)
          .doc(application.id)
          .update({
        'examScore': score,
        'examTotalQuestions': totalQuestions,
        'examPercentage': percentage,
        'examCompletedAt': FieldValue.serverTimestamp(),
        'examAnswers': answers,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update exam results: $e');
    }
  }

  // Approve caregiver application
  Future<void> approveCaregiverApplication(
    String applicationId,
    String reviewedBy,
  ) async {
    try {
      final batch = _firestore.batch();

      // Update application status
      final applicationRef =
          _firestore.collection(caregiverApplicationsCollection).doc(applicationId);
      batch.update(applicationRef, {
        'status': 'approved',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': reviewedBy,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Get application to update user
      final applicationDoc = await applicationRef.get();
      if (applicationDoc.exists) {
        final data = applicationDoc.data()!;
        final userId = data['userId'] as String;

        // Update user verification status
        final userRef = _firestore.collection(usersCollection).doc(userId);
        batch.update(userRef, {
          'caregiverVerificationStatus': 'approved',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to approve caregiver application: $e');
    }
  }

  // Reject caregiver application
  Future<void> rejectCaregiverApplication(
    String applicationId,
    String reviewedBy,
    String rejectionReason,
  ) async {
    try {
      final batch = _firestore.batch();

      // Update application status
      final applicationRef =
          _firestore.collection(caregiverApplicationsCollection).doc(applicationId);
      batch.update(applicationRef, {
        'status': 'rejected',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': reviewedBy,
        'rejectionReason': rejectionReason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Get application to update user
      final applicationDoc = await applicationRef.get();
      if (applicationDoc.exists) {
        final data = applicationDoc.data()!;
        final userId = data['userId'] as String;

        // Update user verification status
        final userRef = _firestore.collection(usersCollection).doc(userId);
        batch.update(userRef, {
          'caregiverVerificationStatus': 'rejected',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to reject caregiver application: $e');
    }
  }

  // Get caregiver application by ID
  Future<CaregiverApplicationModel?> getCaregiverApplicationById(
    String applicationId,
  ) async {
    try {
      final doc = await _firestore
          .collection(caregiverApplicationsCollection)
          .doc(applicationId)
          .get();

      if (!doc.exists) return null;

      return CaregiverApplicationModel.fromJson({
        'id': doc.id,
        ...doc.data()!,
      });
    } catch (e) {
      throw Exception('Failed to get caregiver application: $e');
    }
  }
}
