// api_config.dart
class ApiConfig {
  // Backend API base URL
  // For local development: 'http://localhost:8000'
  // For Android emulator: 'http://10.0.2.2:8000'
  // For iOS simulator: 'http://localhost:8000'
  // For production: 'https://your-backend-url.com'
  
  static const String backendBaseUrl = 'http://10.0.2.2:8000'; // Android emulator default
  
  // Enable/disable backend integration
  static const bool enableBackendIntegration = true;
  
  // Timeout duration for API calls
  static const Duration apiTimeout = Duration(seconds: 30);
}

