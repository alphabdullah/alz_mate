import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import 'firestore_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirestoreService _firestoreService = FirestoreService();

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  Stream<UserModel?> get userModelStream =>
      _auth.authStateChanges().asyncMap((user) async {
        if (user == null) return null;
        return await _firestoreService.getUserById(user.uid);
      });

  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String role,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      if (credential.user != null) {
        await credential.user!.updateDisplayName(name);

        final userModel = UserModel(
          id: credential.user!.uid,
          name: name.trim(),
          email: email.trim().toLowerCase(),
          role: role.toLowerCase(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isVerified: false,
          profileImageUrl: null,
          metadata: additionalData, // ✅ Ensure UserModel supports this
        );

        await _firestoreService.createUser(userModel);
        await credential.user!.sendEmailVerification();
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Sign up failed: $e');
    }
  }

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
    required String fcmToken,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      if (credential.user != null) {
        await _firestoreService.updateUser(credential.user!.uid, {
          'lastActive': DateTime.now().toIso8601String(),
          'fcm_token': fcmToken
        });
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Sign in failed: $e');
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      final GoogleSignInAuthentication googleAuth =
          await googleUser!.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.additionalUserInfo?.isNewUser == true &&
          userCredential.user != null) {
        final userModel = UserModel(
          id: userCredential.user!.uid,
          name: userCredential.user!.displayName ?? 'User',
          email: userCredential.user!.email!.toLowerCase(),
          role: 'patient',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isVerified: userCredential.user!.emailVerified,
          profileImageUrl: userCredential.user!.photoURL,
        );

        await _firestoreService.createUser(userModel);
      } else if (userCredential.user != null) {
        await _firestoreService.updateUser(userCredential.user!.uid, {
          'lastActive': DateTime.now().toIso8601String(),
        });
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Google sign in failed: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
    } catch (e) {
      throw Exception('Sign out failed: $e');
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Password reset failed: $e');
    }
  }

  Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Email verification failed: $e');
    }
  }

  Future<void> reloadUser() async {
    try {
      await _auth.currentUser?.reload();
    } catch (e) {
      throw Exception('Reload user failed: $e');
    }
  }

  Future<void> updatePassword(String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.updatePassword(newPassword);
        await _firestoreService.updateUser(user.uid, {
          'lastPasswordChange': DateTime.now().toIso8601String(),
        });
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Password update failed: $e');
    }
  }

  Future<void> updateEmail(String newEmail) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.updateEmail(newEmail.trim().toLowerCase());
        await _firestoreService.updateUser(user.uid, {
          'email': newEmail.trim().toLowerCase(),
        });
        await user.sendEmailVerification();
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Email update failed: $e');
    }
  }

  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestoreService.deleteUser(user.uid);
        await user.delete();
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Account deletion failed: $e');
    }
  }

  Future<void> reauthenticateWithPassword(String password) async {
    try {
      final user = _auth.currentUser;
      if (user != null && user.email != null) {
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: password,
        );
        await user.reauthenticateWithCredential(credential);
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Reauthentication failed: $e');
    }
  }

  Future<UserModel?> getCurrentUserData() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        return await _firestoreService.getUserById(user.uid);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user data: $e');
    }
  }

  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;
  bool get isSignedIn => _auth.currentUser != null;
  String? get userId => _auth.currentUser?.uid;
  String? get userEmail => _auth.currentUser?.email;

  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'user-not-found':
        return 'No user found for this email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many requests. Try again later.';
      case 'operation-not-allowed':
        return 'This operation is not allowed.';
      case 'invalid-credential':
        return 'The credential is invalid or expired.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with a different credential.';
      case 'requires-recent-login':
        return 'This operation requires recent authentication. Please sign in again.';
      case 'credential-already-in-use':
        return 'This credential is already associated with a different user account.';
      case 'invalid-verification-code':
        return 'The verification code is invalid.';
      case 'invalid-verification-id':
        return 'The verification ID is invalid.';
      default:
        return e.message ?? 'An authentication error occurred.';
    }
  }

  

  bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  Map<String, bool> validatePassword(String password) {
    return {
      'minLength': password.length >= 8,
      'hasUppercase': password.contains(RegExp(r'[A-Z]')),
      'hasLowercase': password.contains(RegExp(r'[a-z]')),
      'hasDigits': password.contains(RegExp(r'[0-9]')),
      'hasSpecialCharacters': password.contains(
        RegExp(r'[!@#$%^&*(),.?":{}|<>]'),
      ),
    };
  }

  bool isStrongPassword(String password) {
    final validation = validatePassword(password);
    return validation.values.every((isValid) => isValid);
  }

  UserModel? mapFirebaseUserToUserModel(User? user) {
    if (user == null) return null;

    return UserModel(
      id: user.uid,
      email: user.email ?? '',
      name: user.displayName ?? '',
      role: 'patient', // or fetch from Firestore if needed
      createdAt: DateTime.now(), // or fetch from Firestore
      updatedAt: DateTime.now(),
    );
  }

  /// Initialize default admin user if it doesn't exist
  Future<void> initializeDefaultAdmin() async {
    try {
      const adminEmail = 'admin@yopmail.com';
      const adminPassword = 'Admin123\$';
      const adminName = 'Admin User';

      // Check if admin user exists in Firestore
      final existingAdmin = await _firestoreService.getUserByEmail(adminEmail);
      
      if (existingAdmin != null && existingAdmin.role.toLowerCase() == 'admin') {
        print('Admin user already exists');
        return;
      }

      // Check if Firebase Auth user exists
      try {
        await _auth.signInWithEmailAndPassword(
          email: adminEmail,
          password: adminPassword,
        );
        // If sign in succeeds, user exists but might not have admin role in Firestore
        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          // Update existing user to admin role
          await _firestoreService.updateUser(currentUser.uid, {
            'role': 'admin',
            'name': adminName,
            'isVerified': true,
          });
          await _auth.signOut();
          print('Updated existing user to admin role');
          return;
        }
      } catch (e) {
        // User doesn't exist, create new one
        print('Admin user does not exist, creating...');
      }

      // Create new admin user
      final credential = await _auth.createUserWithEmailAndPassword(
        email: adminEmail,
        password: adminPassword,
      );

      if (credential.user != null) {
        await credential.user!.updateDisplayName(adminName);
        
        // Mark email as verified for admin
        await credential.user!.reload();
        
        final userModel = UserModel(
          id: credential.user!.uid,
          name: adminName,
          email: adminEmail,
          role: 'admin',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isVerified: true, // Admin doesn't need email verification
        );

        await _firestoreService.createUser(userModel);
        await _auth.signOut(); // Sign out after creating
        
        print('Default admin user created successfully');
        print('Email: $adminEmail');
        print('Password: $adminPassword');
      }
    } catch (e) {
      print('Error initializing default admin: $e');
      // Don't throw - this is a background initialization
    }
  }
}
