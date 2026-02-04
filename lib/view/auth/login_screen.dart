import 'package:alz_mate/core/services/notification_service.dart%20copy/notification_services.dart';
import 'package:alz_mate/view/patient/patient_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_styles.dart';
import '../../core/services/auth_service.dart';
import '../../core/models/user_model.dart';
import '../../core/utils/validators.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../caregiver/caregiver_dashboard_screen.dart';
import '../caregiver/caregiver_verification_status_screen.dart';
import '../../admin/widgets/admin_shell.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  String? fcmToken;

  NotificationServices notificationServices = NotificationServices();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
          ),
        );

    _animationController.forward();

    notificationServices.requestNotificationPermission();
    notificationServices.firebaseInit(context);
    notificationServices.getNotificationToken().then((value) {
      print("Device Token: $value");
      fcmToken = value;
    });
    notificationServices.setupInteractMessage(context);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = await authService.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fcmToken: fcmToken!,
      );

      final userData = await AuthService().getCurrentUserData();

      // Check if email is verified (skip for admin users)
      if (userData != null && userData.role.toLowerCase() == 'admin') {
        // Admin users don't need email verification
        if (mounted) {
          _navigateToHome(userData.role, userData);
        }
      } else if (!authService.isEmailVerified) {
        setState(() {
          _errorMessage =
              'Email is not verified. Please verify your email first.';
        });
        _showEmailVerificationDialog();
      } else if (mounted) {
        _navigateToHome(userData!.role, userData);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showEmailVerificationDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Email Not Verified'),
          content: const Text(
            'Your email is not verified. Please check your inbox for the verification email or click below to resend the verification link.',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final authService = Provider.of<AuthService>(
                  context,
                  listen: false,
                );
                await authService.sendEmailVerification();
                Navigator.of(context).pop();
              },
              child: const Text('Resend Verification Link'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = await authService.signInWithGoogle();

      final userData = await AuthService().getCurrentUserData();
      if (mounted) {
        _navigateToHome(userData!.role, userData);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToHome(String role, UserModel? userData) {
    if (role.toLowerCase() == 'admin') {
      // Navigate to admin panel
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const AdminShell(),
        ),
      );
    } else if (role.toLowerCase() == 'patient') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const PatientDashboardScreen()),
      );
    } else if (role.toLowerCase() == 'caregiver') {
      // Check caregiver verification status
      final verificationStatus = userData?.caregiverVerificationStatus;
      if (verificationStatus == 'pending' || verificationStatus == 'rejected') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => CaregiverVerificationStatusScreen(
              userId: userData!.id,
              verificationStatus: verificationStatus ?? 'pending',
            ),
          ),
        );
      } else if (verificationStatus == 'approved') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const CaregiverDashboardScreen(),
          ),
        );
      } else {
        // Default to pending if status is null
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => CaregiverVerificationStatusScreen(
              userId: userData!.id,
              verificationStatus: 'pending',
            ),
          ),
        );
      }
    } else {
      // Default fallback
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const CaregiverDashboardScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),

                  // Header Section
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: AppColors.primaryGradient,
                            ),
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.favorite,
                            size: 50,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Welcome Back!',
                          style: AppStyles.displayMedium.copyWith(
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sign in to continue your AlzMate journey',
                          style: AppStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Login Form
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: AppStyles.elevatedCard,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sign In', style: AppStyles.titleLarge),
                          const SizedBox(height: 24),

                          // Email Field
                          CustomTextField(
                            label: 'Email Address',
                            hint: 'Enter your email',
                            controller: _emailController,
                            prefixIcon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: Validators.validateEmail,
                          ),
                          const SizedBox(height: 16),

                          // Password Field
                          CustomTextField(
                            label: 'Password',
                            hint: 'Enter your password',
                            controller: _passwordController,
                            prefixIcon: Icons.lock_outline,
                            suffixIcon: _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            onSuffixTap: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            obscureText: _obscurePassword,
                            validator: Validators.validatePassword,
                          ),

                          // Forgot Password
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const ForgotPasswordScreen(),
                                  ),
                                );
                              },
                              child: Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Error Message
                          if (_errorMessage != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: AppColors.danger.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.danger.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: AppColors.danger,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: TextStyle(
                                        color: AppColors.danger,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Sign In Button
                          CustomButton(
                            text: 'Sign In',
                            onPressed: _signInWithEmail,
                            isLoading: _isLoading,
                          ),

                          const SizedBox(height: 16),

                          // // Divider
                          // Row(
                          //   children: [
                          //     Expanded(
                          //       child: Container(
                          //         height: 1,
                          //         color: AppColors.border,
                          //       ),
                          //     ),
                          //     Padding(
                          //       padding: const EdgeInsets.symmetric(
                          //         horizontal: 16,
                          //       ),
                          //       child: Text(
                          //         'OR',
                          //         style: TextStyle(
                          //           color: AppColors.textSecondary,
                          //           fontWeight: FontWeight.w500,
                          //         ),
                          //       ),
                          //     ),
                          //     Expanded(
                          //       child: Container(
                          //         height: 1,
                          //         color: AppColors.border,
                          //       ),
                          //     ),
                          //   ],
                          // ),

                          // const SizedBox(height: 16),

                          // Google Sign In Button
                          // CustomButton(
                          //   text: 'Continue with Google',
                          //   onPressed: _signInWithGoogle,
                          //   isOutlined: true,
                          //   icon: Icons.g_mobiledata,
                          //   isLoading: _isLoading,
                          // ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Sign Up Link
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Don\'t have an account? ',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RegisterScreen(),
                              ),
                            );
                          },
                          child: Text(
                            'Sign Up',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Demo Info (can be removed in production)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.info.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: AppColors.info,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Getting Started',
                              style: TextStyle(
                                color: AppColors.info,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create a new account to get started with AlzMate.',
                          style: TextStyle(color: AppColors.info, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
