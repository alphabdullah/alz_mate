class AppKeys {
  // Firestore Collection Keys
  static const String usersCollection = "users";
  static const String remindersCollection = "reminders";
  static const String journalCollection = "journal_entries";
  static const String sosCollection = "sos_alerts";
  static const String moodsCollection = "mood_logs";
  static const String scoresCollection = "brain_scores";
  static const String facesCollection = "recognized_faces";
  static const String settingsCollection = "user_settings";
  static const String notificationsCollection = "notifications";
  
  // Document Field Keys
  static const String uid = "uid";
  static const String name = "name";
  static const String email = "email";
  static const String role = "role";
  static const String linkedUserId = "linkedUserId";
  static const String createdAt = "createdAt";
  static const String updatedAt = "updatedAt";
  static const String isActive = "isActive";
  
  // Reminder Field Keys
  static const String reminderId = "id";
  static const String reminderTitle = "title";
  static const String reminderTime = "time";
  static const String reminderType = "type";
  static const String isCompleted = "isCompleted";
  static const String isMissed = "isMissed";
  static const String reminderNotes = "notes";
  static const String repeatDaily = "repeatDaily";
  
  // Journal Field Keys
  static const String journalId = "id";
  static const String journalContent = "content";
  static const String journalTimestamp = "timestamp";
  static const String journalType = "type";
  static const String mediaUrl = "mediaUrl";
  static const String sentimentScore = "sentimentScore";
  static const String tags = "tags";
  
  // Mood Field Keys
  static const String moodId = "id";
  static const String mood = "mood";
  static const String moodScore = "score";
  static const String moodTimestamp = "timestamp";
  static const String moodNotes = "notes";
  static const String triggers = "triggers";
  
  // SOS Field Keys
  static const String sosId = "id";
  static const String sosTimestamp = "timestamp";
  static const String latitude = "latitude";
  static const String longitude = "longitude";
  static const String address = "address";
  static const String isResolved = "isResolved";
  static const String responseTime = "responseTime";
  
  // Game Score Field Keys
  static const String scoreId = "id";
  static const String gameName = "gameName";
  static const String gameScore = "score";
  static const String playedAt = "playedAt";
  static const String duration = "duration";
  static const String difficulty = "difficulty";
  static const String achievements = "achievements";
  
  // Face Recognition Field Keys
  static const String faceId = "id";
  static const String faceName = "faceName";
  static const String relationship = "relationship";
  static const String confidence = "confidence";
  static const String lastSeen = "lastSeen";
  static const String photoUrl = "photoUrl";
  
  // Settings Field Keys
  static const String language = "language";
  static const String notifications = "notifications";
  static const String emergencyContacts = "emergencyContacts";
  static const String privacySettings = "privacySettings";
  static const String theme = "theme";
  
  // Local Storage Keys
  static const String userToken = "user_token";
  static const String userRole = "user_role";
  static const String isFirstLaunch = "is_first_launch";
  static const String lastSyncTime = "last_sync_time";
  static const String offlineData = "offline_data";
  static const String userPreferences = "user_preferences";
  
  // Notification Keys
  static const String reminderNotificationChannel = "reminder_notifications";
  static const String sosNotificationChannel = "sos_notifications";
  static const String generalNotificationChannel = "general_notifications";
  
  // API Keys (for external services)
  static const String googleMapsApiKey = "google_maps_api_key";
  static const String sentimentApiKey = "sentiment_api_key";
  static const String faceRecognitionApiKey = "face_recognition_api_key";
  
  // Error Messages
  static const String networkError = "network_error";
  static const String authError = "authentication_error";
  static const String permissionError = "permission_error";
  static const String dataError = "data_error";
  
  // Success Messages
  static const String dataUpdated = "data_updated";
  static const String reminderSet = "reminder_set";
  static const String journalSaved = "journal_saved";
  static const String sosTriggered = "sos_triggered";
  
  // User Roles
  static const String patientRole = "patient";
  static const String caregiverRole = "caregiver";
  static const String adminRole = "admin";
  
  // Journal Types
  static const String textJournal = "text";
  static const String voiceJournal = "voice";
  static const String imageJournal = "image";
  static const String videoJournal = "video";
  
  // Reminder Types
  static const String medicationReminder = "medication";
  static const String appointmentReminder = "appointment";
  static const String mealReminder = "meal";
  static const String exerciseReminder = "exercise";
  static const String callReminder = "call";
  static const String customReminder = "custom";
  
  // Game Types
  static const String memoryGame = "memory";
  static const String logicGame = "logic";
  static const String speedGame = "speed";
  static const String creativityGame = "creativity";
  static const String languageGame = "language";
  static const String patternGame = "pattern";
  
  // Mood Types
  static const String happyMood = "happy";
  static const String sadMood = "sad";
  static const String anxiousMood = "anxious";
  static const String confusedMood = "confused";
  static const String contentMood = "content";
  static const String neutralMood = "neutral";
  static const String angryMood = "angry";
  static const String excitedMood = "excited";
}
