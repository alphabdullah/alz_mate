class Validators {
  // Email validation
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    
    // Regular expression for email validation
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    
    if (!emailRegex.hasMatch(value)) {
      return 'Enter a valid email address';
    }
    
    return null;
  }

  // Password validation
static String? validatePassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Password is required';
  }

  // Check if password length is at least 6 characters
  if (value.length < 8) {
    return 'Password must be at least 8 characters';
  }

  // Check for at least one lowercase letter
  if (!RegExp(r'[a-z]').hasMatch(value)) {
    return 'Password must contain at least one lowercase letter';
  }

  // Check for at least one uppercase letter
  if (!RegExp(r'[A-Z]').hasMatch(value)) {
    return 'Password must contain at least one uppercase letter';
  }

  // Check for at least one special character
  if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
    return 'Password must contain at least one special character';
  }

  return null;
}


  // Name validation
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }
    
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    
    return null;
  }

  // Phone number validation
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Phone is optional
    }
    
    // Regular expression for phone validation (simple version)
    final phoneRegex = RegExp(r'^\+?[0-9]{10,15}$');
    
    if (!phoneRegex.hasMatch(value)) {
      return 'Enter a valid phone number';
    }
    
    return null;
  }

  // Required field validation
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    
    return null;
  }

  // Reminder title validation
  static String? validateReminderTitle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Reminder title is required';
    }
    
    if (value.trim().length < 3) {
      return 'Title must be at least 3 characters';
    }
    
    if (value.trim().length > 50) {
      return 'Title must be less than 50 characters';
    }
    
    return null;
  }

  // Journal entry validation
  static String? validateJournalEntry(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Journal entry cannot be empty';
    }
    
    return null;
  }

  // Date validation (must be in the future)
  static String? validateFutureDate(DateTime? value) {
    if (value == null) {
      return 'Date is required';
    }
    
    if (value.isBefore(DateTime.now())) {
      return 'Date must be in the future';
    }
    
    return null;
  }

  // Date validation (must be in the past)
  static String? validatePastDate(DateTime? value) {
    if (value == null) {
      return 'Date is required';
    }
    
    if (value.isAfter(DateTime.now())) {
      return 'Date must be in the past';
    }
    
    return null;
  }

  // Numeric validation
  static String? validateNumeric(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    
    if (double.tryParse(value) == null) {
      return '$fieldName must be a number';
    }
    
    return null;
  }

  // Integer validation
  static String? validateInteger(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    
    if (int.tryParse(value) == null) {
      return '$fieldName must be a whole number';
    }
    
    return null;
  }

  // Range validation
  static String? validateRange(double? value, double min, double max, String fieldName) {
    if (value == null) {
      return '$fieldName is required';
    }
    
    if (value < min || value > max) {
      return '$fieldName must be between $min and $max';
    }
    
    return null;
  }
}
