import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_styles.dart';
import '../../core/models/user_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../widgets/custom_text_field.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<UserModel> _caregivers = [];
  List<UserModel> _familyMembers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );

      if (authService.currentUser != null) {
        final caregivers = await firestoreService.getPatientCaregivers(
          authService.currentUser!.uid,
        );
        final family = await firestoreService.getPatientFamilyMembers(
          authService.currentUser!.uid,
        );

        setState(() {
          _caregivers = caregivers;
          _familyMembers = family;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading contacts: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Messages'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_caregivers.isNotEmpty) ...[
                    Text('My Caregivers', style: AppStyles.titleMedium),
                    const SizedBox(height: 16),
                    ...(_caregivers.map(
                      (caregiver) => _buildContactCard(caregiver, 'caregiver'),
                    )),
                    const SizedBox(height: 24),
                  ],
                  if (_familyMembers.isNotEmpty) ...[
                    Text('Family Members', style: AppStyles.titleMedium),
                    const SizedBox(height: 16),
                    ...(_familyMembers.map(
                      (family) => _buildContactCard(family, 'family'),
                    )),
                  ],
                  if (_caregivers.isEmpty && _familyMembers.isEmpty)
                    Center(
                      child: Column(
                        children: [
                          const SizedBox(height: 100),
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 80,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No contacts available',
                            style: AppStyles.titleMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your caregivers and family members will appear here',
                            style: AppStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildContactCard(UserModel contact, String type) {
    final color = type == 'caregiver' ? AppColors.success : AppColors.accent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        tileColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: color.withOpacity(0.1),
          backgroundImage: contact.profileImageUrl != null
              ? NetworkImage(contact.profileImageUrl!)
              : null,
          child: contact.profileImageUrl == null
              ? Text(
                  contact.name[0].toUpperCase(),
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                )
              : null,
        ),
        title: Text(
          contact.name,
          style: AppStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (type == 'caregiver' && contact.specialization != null)
              Text(contact.specialization!, style: AppStyles.bodySmall),
            if (type == 'family' && contact.relationshipToPatient != null)
              Text(contact.relationshipToPatient!, style: AppStyles.bodySmall),
            Text(
              contact.isActive ? 'Online' : 'Last seen recently',
              style: AppStyles.bodySmall.copyWith(
                color: contact.isActive
                    ? AppColors.success
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
        trailing: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: contact.isActive
                ? AppColors.success
                : AppColors.textSecondary,
            shape: BoxShape.circle,
          ),
        ),
        onTap: () => _openChat(contact),
      ),
    );
  }

  void _openChat(UserModel contact) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatDetailScreen(contact: contact)),
    );
  }
}

class ChatDetailScreen extends StatefulWidget {
  final UserModel contact;

  const ChatDetailScreen({super.key, required this.contact});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _loadMessages() {
    // Simulate loading messages
    setState(() {
      _messages.addAll([
        {
          'id': '1',
          'text': 'Hello! How are you feeling today?',
          'isMe': false,
          'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
        },
        {
          'id': '2',
          'text': 'I\'m doing well, thank you for asking!',
          'isMe': true,
          'timestamp': DateTime.now().subtract(const Duration(hours: 1)),
        },
        {
          'id': '3',
          'text':
              'That\'s great to hear. Remember to take your medication at 3 PM.',
          'isMe': false,
          'timestamp': DateTime.now().subtract(const Duration(minutes: 30)),
        },
      ]);
    });
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final message = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'text': _messageController.text.trim(),
      'isMe': true,
      'timestamp': DateTime.now(),
    };

    setState(() {
      _messages.add(message);
      _messageController.clear();
    });

    // Simulate response after a delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        final responses = [
          'Thank you for letting me know!',
          'I\'ll make a note of that.',
          'Is there anything else I can help you with?',
          'Take care and let me know if you need anything.',
        ];
        final response = {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'text': responses[DateTime.now().second % responses.length],
          'isMe': false,
          'timestamp': DateTime.now(),
        };

        setState(() {
          _messages.add(response);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              backgroundImage: widget.contact.profileImageUrl != null
                  ? NetworkImage(widget.contact.profileImageUrl!)
                  : null,
              child: widget.contact.profileImageUrl == null
                  ? Text(
                      widget.contact.name[0].toUpperCase(),
                      style: const TextStyle(color: AppColors.primary),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.contact.name,
                    style: AppStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    widget.contact.isActive ? 'Online' : 'Last seen recently',
                    style: AppStyles.bodySmall.copyWith(
                      color: widget.contact.isActive
                          ? AppColors.success
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Calling ${widget.contact.name}...')),
              );
            },
            icon: const Icon(Icons.phone, color: AppColors.primary),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isMe = message['isMe'] as bool;
    final timestamp = message['timestamp'] as DateTime;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              backgroundImage: widget.contact.profileImageUrl != null
                  ? NetworkImage(widget.contact.profileImageUrl!)
                  : null,
              child: widget.contact.profileImageUrl == null
                  ? Text(
                      widget.contact.name[0].toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomLeft: isMe
                      ? const Radius.circular(20)
                      : const Radius.circular(4),
                  bottomRight: isMe
                      ? const Radius.circular(4)
                      : const Radius.circular(20),
                ),
                boxShadow: AppStyles.softShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message['text'],
                    style: TextStyle(
                      color: isMe ? Colors.white : AppColors.text,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: isMe ? Colors.white70 : AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: CustomTextField(
              label: 'Enter Message',
              controller: _messageController,
              hint: 'Type a message...',
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _sendMessage,
              icon: const Icon(Icons.send, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
