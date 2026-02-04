class DateTimeHelper {
  // Get time ago string (e.g., "2 hours ago")
  static String formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years year${years > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 7) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks week${weeks > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  // Format date (e.g., "15 Jan 2023")
  static String formatDate(DateTime dateTime) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}';
  }

  // Format time (e.g., "14:30")
  static String formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // Check if date is today
  static bool isToday(DateTime dateTime) {
    final now = DateTime.now();
    return dateTime.year == now.year &&
           dateTime.month == now.month &&
           dateTime.day == now.day;
  }

  // Check if date is yesterday
  static bool isYesterday(DateTime dateTime) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return dateTime.year == yesterday.year &&
           dateTime.month == yesterday.month &&
           dateTime.day == yesterday.day;
  }

  // Check if date is tomorrow
  static bool isTomorrow(DateTime dateTime) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return dateTime.year == tomorrow.year &&
           dateTime.month == tomorrow.month &&
           dateTime.day == tomorrow.day;
  }

  // Check if date is in the past
  static bool isPast(DateTime dateTime) {
    return dateTime.isBefore(DateTime.now());
  }

  // Check if date is in the future
  static bool isFuture(DateTime dateTime) {
    return dateTime.isAfter(DateTime.now());
  }

  // Get start of day
  static DateTime startOfDay(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }

  // Get end of day
  static DateTime endOfDay(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day, 23, 59, 59, 999);
  }

  // Get start of week (Monday)
  static DateTime startOfWeek(DateTime dateTime) {
    final day = dateTime.weekday;
    return DateTime(dateTime.year, dateTime.month, dateTime.day - day + 1);
  }

  // Get end of week (Sunday)
  static DateTime endOfWeek(DateTime dateTime) {
    final day = dateTime.weekday;
    return DateTime(dateTime.year, dateTime.month, dateTime.day + (7 - day), 23, 59, 59, 999);
  }

  // Get start of month
  static DateTime startOfMonth(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, 1);
  }

  // Get end of month
  static DateTime endOfMonth(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month + 1, 0, 23, 59, 59, 999);
  }

  // Get date range for this week
  static List<DateTime> datesInThisWeek() {
    final now = DateTime.now();
    final startOfWeek = DateTimeHelper.startOfWeek(now);
    
    return List.generate(7, (index) => 
      startOfWeek.add(Duration(days: index))
    );
  }

  // Get date range for this month
  static List<DateTime> datesInThisMonth() {
    final now = DateTime.now();
    final startOfMonth = DateTimeHelper.startOfMonth(now);
    final endOfMonth = DateTimeHelper.endOfMonth(now);
    final daysInMonth = endOfMonth.day;
    
    return List.generate(daysInMonth, (index) => 
      DateTime(now.year, now.month, index + 1)
    );
  }

  // Get date range between two dates
  static List<DateTime> dateRange(DateTime start, DateTime end) {
    final days = end.difference(start).inDays + 1;
    
    return List.generate(days, (index) => 
      start.add(Duration(days: index))
    );
  }

  // Get next occurrence of a day of week
  static DateTime nextDayOfWeek(int dayOfWeek) {
    final now = DateTime.now();
    final daysUntil = (dayOfWeek - now.weekday) % 7;
    return now.add(Duration(days: daysUntil == 0 ? 7 : daysUntil));
  }

  // Format date based on relative time
  static String formatRelativeDate(DateTime dateTime) {
    if (isToday(dateTime)) {
      return 'Today';
    } else if (isYesterday(dateTime)) {
      return 'Yesterday';
    } else if (isTomorrow(dateTime)) {
      return 'Tomorrow';
    } else {
      return formatDate(dateTime);
    }
  }

  // Format date and time based on relative time
  static String formatRelativeDateTime(DateTime dateTime) {
    final timeString = formatTime(dateTime);
    
    if (isToday(dateTime)) {
      return 'Today at $timeString';
    } else if (isYesterday(dateTime)) {
      return 'Yesterday at $timeString';
    } else if (isTomorrow(dateTime)) {
      return 'Tomorrow at $timeString';
    } else {
      return '${formatDate(dateTime)} at $timeString';
    }
  }

  // Calculate age from birth date
  static int calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    
    if (now.month < birthDate.month || 
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    
    return age;
  }

  // Get days until a date
  static int daysUntil(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);
    return difference.inDays;
  }

  // Get hours until a date
  static int hoursUntil(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);
    return difference.inHours;
  }

  // Get minutes until a date
  static int minutesUntil(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);
    return difference.inMinutes;
  }
}
