# Backend Integration Guide

This guide explains how to integrate the Python backend with the Flutter app.

## Setup

### 1. Backend Configuration

Update the backend URL in `lib/core/constants/api_config.dart`:

```dart
static const String backendBaseUrl = 'http://10.0.2.2:8000'; // Android emulator
// For iOS simulator: 'http://localhost:8000'
// For physical device: 'http://YOUR_COMPUTER_IP:8000'
// For production: 'https://your-backend-url.com'
```

### 2. Start the Backend Server

```bash
cd BackendModel
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### 3. Configure Firebase

Make sure your backend has Firebase credentials configured (see BackendModel/README.md).

## Integration Points

### Journal Entry Creation

The journal entry creation in `journal_screen.dart` now automatically calls the emotion analysis API after creating an entry. The analysis happens asynchronously and doesn't block the UI.

### Using Emotion Analysis Service

```dart
import 'package:alz_mate/core/services/emotion_analysis_service.dart';

final emotionService = EmotionAnalysisService();

// Analyze emotion
final result = await emotionService.analyzeEmotion(
  patientId: 'user123',
  journalText: 'I feel sad today...',
  timestamp: DateTime.now().toIso8601String(),
  journalEntryId: 'entry123', // Optional
);

print('Primary emotion: ${result.analysis.primaryEmotion.emotion}');
print('Intensity: ${result.analysis.primaryEmotion.intensity}');
print('Mood risk: ${result.analysis.moodRisk}');
```

### Using Progress Tracking Service

```dart
import 'package:alz_mate/core/services/progress_tracking_service.dart';

final progressService = ProgressTrackingService();

// Get weekly score
final weeklyScore = await progressService.getWeeklyScore('user123');
print('Weekly score: ${weeklyScore.score}');
print('Patient state: ${weeklyScore.patientState}');

// Get weekly report
final report = await progressService.getWeeklyReport('user123');
print('Trend: ${report.trend}');
print('Decline detected: ${report.declineDetection.declineDetected}');
```

### Using Combined Analysis Service

```dart
import 'package:alz_mate/core/services/combined_analysis_service.dart';

final combinedService = CombinedAnalysisService();

// Get combined report
final report = await combinedService.getCombinedWeeklyReport('user123');
print('Combined risk: ${report.combinedRiskAssessment.combinedRiskLevel}');
print('Recommendation: ${report.combinedRiskAssessment.recommendation}');
```

## API Endpoints Available

### Emotion Analysis
- `POST /analyze-emotion` - Analyze emotion from text
- `POST /analyze-emotion-with-audio` - Analyze with audio upload
- `GET /emotion-entries/{patient_id}` - Get emotion entries
- `GET /emotion-trends/{patient_id}` - Get emotion trends
- `GET /daily-summary/{patient_id}` - Get daily summary
- `GET /weekly-summary/{patient_id}` - Get weekly summary
- `GET /emotion/shift-detection/{patient_id}` - Detect emotion shift
- `GET /emotion/persistent-negative/{patient_id}` - Check persistent negative emotions
- `GET /emotion/volatility/{patient_id}` - Detect volatility
- `GET /emotion/trend-summary/{patient_id}` - Get trend summary

### Progress Tracking
- `GET /progress/weekly-score/{patient_id}` - Get weekly score
- `GET /progress/weekly-report/{patient_id}` - Get weekly report
- `GET /progress/decline-detection/{patient_id}` - Check decline

### Combined Analysis
- `GET /combined/weekly-report/{patient_id}` - Get combined report

## Error Handling

All services include try-catch blocks. If the backend is unavailable, the app will continue to work with local sentiment analysis as a fallback.

## Testing

1. Start the backend server
2. Create a journal entry in the Flutter app
3. Check the backend logs to see the emotion analysis request
4. View emotion trends in the app (if you add UI for it)

## Next Steps

1. Add UI screens to display:
   - Emotion trends and charts
   - Weekly progress reports
   - Combined risk assessments
   - Caregiver notifications

2. Set up scheduled tasks to:
   - Generate weekly reports automatically
   - Check for decline and send notifications
   - Monitor persistent negative emotions

3. Add notification listeners to display backend notifications in the app

