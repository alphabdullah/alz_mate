import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/models/user_model.dart';
import 'pages/unauthorized_page.dart';
import 'widgets/admin_shell.dart';

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserModel?>();
    final isAdmin = user != null && user.role.toLowerCase() == 'admin';

    return MaterialApp(
      title: 'AlzMate Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF6A5AE0),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Colors.white),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedItemColor: Color(0xFF6A5AE0),
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
        ),
        drawerTheme: const DrawerThemeData(
          backgroundColor: Colors.white,
        ),
      ),
      home: isAdmin ? const AdminShell() : const UnauthorizedPage(),
    );
  }
}

