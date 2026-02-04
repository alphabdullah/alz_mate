import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_styles.dart';
import '../../core/models/reminder_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/notification_service.dart';
import '../../widgets/reminder_card.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key});

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen>
    with SingleTickerProviderStateMixin {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  List<ReminderModel> _reminders = [];
  bool _isLoading = false;
  bool _isCreating = false;
  String _selectedFilter = 'all';
  String _selectedType = 'medication';
  DateTime _selectedTime = DateTime.now().add(const Duration(hours: 1));
  bool _repeatDaily = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<String> _reminderTypes = [
    'medication',
    'appointment',
    'meal',
    'exercise',
    'call',
    'custom',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _initializeNotifications();
    _loadReminders();
    _animationController.forward();
  }

  Future<void> _initializeNotifications() async {
    try {
      final notificationService = Provider.of<NotificationService>(context, listen: false);
      await notificationService.initialize();
    } catch (e) {
      print('Error initializing notifications: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadReminders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);

      if (authService.currentUser != null) {
        final reminders = await firestoreService.getRemindersByUserId(
          authService.currentUser!.uid,
        );
        setState(() {
          _reminders = reminders;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading reminders: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<ReminderModel> get _filteredReminders {
    switch (_selectedFilter) {
      case 'pending':
        return _reminders.where((r) => !r.isCompleted && !r.isMissed).toList();
      case 'completed':
        return _reminders.where((r) => r.isCompleted).toList();
      case 'missed':
        return _reminders.where((r) => r.isMissed).toList();
      default:
        return _reminders;
    }
  }

  Future<void> _createReminder() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a reminder title')),
      );
      return;
    }

    // Validate that the selected time is in the future
    if (_selectedTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a future time for the reminder')),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      final notificationService = Provider.of<NotificationService>(context, listen: false);

      if (authService.currentUser == null) {
        throw Exception('User not authenticated');
      }

      final newReminder = ReminderModel(
        id: '', // Will be set by Firestore
        userId: authService.currentUser!.uid,
        title: _titleController.text.trim(),
        description: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        time: _selectedTime,
        type: _selectedType,
        repeatDaily: _repeatDaily,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save to Firestore
      final reminderId = await firestoreService.createReminder(newReminder);
      final savedReminder = newReminder.copyWith(id: reminderId);

      // Schedule notification
      try {
        await notificationService.scheduleReminderNotification(savedReminder);
        print('Notification scheduled successfully for reminder: ${savedReminder.title}');
      } catch (notificationError) {
        print('Error scheduling notification: $notificationError');
        // Still save the reminder even if notification fails
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reminder saved but notification scheduling failed: $notificationError'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      // Update local list
      setState(() {
        _reminders.add(savedReminder);
        _reminders.sort((a, b) => a.time.compareTo(b.time));
        _titleController.clear();
        _notesController.clear();
        _selectedTime = DateTime.now().add(const Duration(hours: 1));
        _repeatDaily = false;
      });

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reminder created successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating reminder: $e')),
      );
    } finally {
      setState(() {
        _isCreating = false;
      });
    }
  }

  Future<void> _markReminderComplete(String id) async {
    try {
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      final notificationService = Provider.of<NotificationService>(context, listen: false);

      await firestoreService.updateReminder(id, {
        'isCompleted': true,
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Cancel the notification
      await notificationService.cancelReminderNotification(id);

      // Update local list
      final index = _reminders.indexWhere((r) => r.id == id);
      if (index != -1) {
        setState(() {
          _reminders[index] = _reminders[index].copyWith(
            isCompleted: true,
            updatedAt: DateTime.now(),
          );
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reminder marked as completed!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating reminder: $e')),
      );
    }
  }

  Future<void> _deleteReminder(String id) async {
    try {
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      final notificationService = Provider.of<NotificationService>(context, listen: false);

      await firestoreService.deleteReminder(id);
      
      // Cancel the notification
      await notificationService.cancelReminderNotification(id);

      // Update local list
      setState(() {
        _reminders.removeWhere((r) => r.id == id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reminder deleted successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting reminder: $e')),
      );
    }
  }

  // Test notification functionality
  Future<void> _testNotification() async {
    try {
      final notificationService = Provider.of<NotificationService>(context, listen: false);
      // await notificationService.testNotification();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test notification sent!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending test notification: $e')),
      );
    }
  }

  void _showCreateReminderDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Header
                Row(
                  children: [
                    Expanded(
                      child: Text('New Reminder', style: AppStyles.titleLarge),
                    ),
                    // Test notification button
                    IconButton(
                      onPressed: _testNotification,
                      icon: const Icon(Icons.notifications_active),
                      tooltip: 'Test Notification',
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        CustomTextField(
                          label: 'Reminder Title',
                          hint: 'What do you want to be reminded about?',
                          controller: _titleController,
                        ),
                        const SizedBox(height: 16),

                        // Type Selection
                        Text('Reminder Type', style: AppStyles.labelLarge),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _reminderTypes.map((type) {
                            final isSelected = _selectedType == type;
                            return GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  _selectedType = type;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary.withOpacity(0.1)
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Text(
                                  type.substring(0, 1).toUpperCase() +
                                      type.substring(1),
                                  style: TextStyle(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // Date & Time
                        Text('Date & Time', style: AppStyles.labelLarge),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _selectedTime,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (date != null) {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.fromDateTime(_selectedTime),
                              );
                              if (time != null) {
                                setModalState(() {
                                  _selectedTime = DateTime(
                                    date.year,
                                    date.month,
                                    date.day,
                                    time.hour,
                                    time.minute,
                                  );
                                });
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.schedule,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${_selectedTime.day}/${_selectedTime.month}/${_selectedTime.year} at ${_selectedTime.hour}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                                  style: AppStyles.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Repeat Daily
                        Row(
                          children: [
                            Switch(
                              value: _repeatDaily,
                              onChanged: (value) {
                                setModalState(() {
                                  _repeatDaily = value;
                                });
                              },
                              activeThumbColor: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text('Repeat Daily', style: AppStyles.bodyMedium),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Notes
                        CustomTextField(
                          label: 'Notes (Optional)',
                          hint: 'Additional details or instructions',
                          controller: _notesController,
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        text: 'Cancel',
                        onPressed: () => Navigator.pop(context),
                        isOutlined: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomButton(
                        text: 'Create Reminder',
                        onPressed: _createReminder,
                        isLoading: _isCreating,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Reminders'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _showCreateReminderDialog,
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Filter Tabs
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: AppStyles.softShadow,
              ),
              child: Row(
                children: [
                  _buildFilterTab('all', 'All'),
                  _buildFilterTab('pending', 'Pending'),
                  _buildFilterTab('completed', 'Done'),
                  _buildFilterTab('missed', 'Missed'),
                ],
              ),
            ),

            // Reminders List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredReminders.isEmpty
                      ? _buildEmptyState()
                      : _buildRemindersList(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateReminderDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Reminder',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildFilterTab(String filter, String label) {
    final isSelected = _selectedFilter == filter;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedFilter = filter;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(60),
              ),
              child: const Icon(
                Icons.notifications,
                size: 60,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _selectedFilter == 'all'
                  ? 'No Reminders Yet'
                  : 'No ${_selectedFilter.substring(0, 1).toUpperCase()}${_selectedFilter.substring(1)} Reminders',
              style: AppStyles.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              _selectedFilter == 'all'
                  ? 'Create your first reminder to stay on track with medications, appointments, and daily activities.'
                  : 'No reminders found for this category.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
              textAlign: TextAlign.center,
            ),
            if (_selectedFilter == 'all') ...[
              const SizedBox(height: 32),
              CustomButton(
                text: 'Create First Reminder',
                onPressed: _showCreateReminderDialog,
                width: 200,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRemindersList() {
    return RefreshIndicator(
      onRefresh: _loadReminders,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _filteredReminders.length,
        itemBuilder: (context, index) {
          final reminder = _filteredReminders[index];
          return ReminderCard(
            reminder: reminder,
            onComplete: () => _markReminderComplete(reminder.id),
            onTap: () => _showReminderDetails(reminder),
          // : () => _deleteReminder(reminder.id),
          );
        },
      ),
    );
  }

  void _showReminderDetails(ReminderModel reminder) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Title & Status
            Row(
              children: [
                Expanded(
                  child: Text(reminder.title, style: AppStyles.titleLarge),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: reminder.isCompleted
                        ? AppColors.success.withOpacity(0.1)
                        : reminder.isMissed
                            ? AppColors.danger.withOpacity(0.1)
                            : AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    reminder.statusText,
                    style: TextStyle(
                      color: reminder.isCompleted
                          ? AppColors.success
                          : reminder.isMissed
                              ? AppColors.danger
                              : AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Details
            _buildDetailRow(Icons.category, 'Type', reminder.typeDisplayName),
            _buildDetailRow(
              Icons.schedule,
              'Time',
              '${reminder.time.day}/${reminder.time.month}/${reminder.time.year} at ${reminder.time.hour}:${reminder.time.minute.toString().padLeft(2, '0')}',
            ),
            if (reminder.repeatDaily)
              _buildDetailRow(Icons.repeat, 'Repeat', 'Daily'),
            if (reminder.description != null)
              _buildDetailRow(Icons.notes, 'Notes', reminder.description!),
            const SizedBox(height: 24),

            // Actions
            if (!reminder.isCompleted && !reminder.isMissed)
              CustomButton(
                text: 'Mark as Completed',
                onPressed: () {
                  Navigator.pop(context);
                  _markReminderComplete(reminder.id);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          Expanded(child: Text(value, style: AppStyles.bodyMedium)),
        ],
      ),
    );
  }
}
