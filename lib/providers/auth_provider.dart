/// Authentication provider - manages user auth state and profile
library;

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../core/services/firestore_service.dart';
import '../core/services/notification_service.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirestoreService _firestoreService = FirestoreService();
  final NotificationService _notificationService = NotificationService();

  User? _firebaseUser;
  UserModel? _userModel;
  bool _isLoading = false;
  String? _error;
  bool _isSigningUp = false; // Guard to prevent race during signup
  bool _isInitialized = false; // True after first auth state check completes

  StreamSubscription? _notificationSubscription;
  final Set<String> _seenNotificationIds = {};

  User? get firebaseUser => _firebaseUser;
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _firebaseUser != null && _userModel != null;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  String get userRole => _userModel?.role ?? '';

  AuthProvider() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  /// Listen to auth state changes
  Future<void> _onAuthStateChanged(User? user) async {
    _firebaseUser = user;
    if (user != null && !_isSigningUp) {
      // Only auto-load profile if we're not in the middle of signup
      await _loadUserProfile(user.uid);
      _setupNotificationListeners();
    } else if (user == null) {
      _userModel = null;
      _cancelNotificationListeners();
    }
    _isInitialized = true;
    notifyListeners();
  }

  void _setupNotificationListeners() {
    _cancelNotificationListeners();
    if (_userModel == null) return;

    if (_userModel!.role == 'donor') {
      _notificationSubscription = _firestoreService.streamPendingRequests().listen((requests) {
        for (var req in requests) {
          if (req.bloodGroup == _userModel!.bloodGroup && !_seenNotificationIds.contains(req.id)) {
            _seenNotificationIds.add(req.id);
            // Only notify if request is relatively new (prevent spam on initial load)
            if (DateTime.now().difference(req.createdAt).inMinutes < 10) {
              _notificationService.showNotification(
                title: req.isSOS ? '🆘 URGENT: ${req.bloodGroup} Needed!' : '🩸 Alert: ${req.bloodGroup} Requested',
                body: '${req.hospitalName} needs ${req.units} unit(s). Tap to respond and save a life!',
                channelId: req.isSOS ? 'sos_channel' : 'request_channel',
              );
            }
          }
        }
      });
    } else if (_userModel!.role == 'hospital' || _userModel!.role == 'blood_bank') {
      _notificationSubscription = _firestoreService.streamHospitalRequests(_userModel!.id).listen((requests) {
        for (var req in requests) {
          String statusKey = '${req.id}_${req.status}';
          if (req.status == 'accepted' && !_seenNotificationIds.contains(statusKey)) {
            _seenNotificationIds.add(statusKey);
            
            // Only notify for recent acceptances
            final updateTime = req.updatedAt ?? req.createdAt;
            if (DateTime.now().difference(updateTime).inMinutes < 10) {
              _notificationService.showNotification(
                title: '✅ Request Accepted!',
                body: '${req.assignedDonorName ?? "A donor"} has accepted your ${req.bloodGroup} blood request!',
                channelId: 'request_channel',
              );
            }
          }
        }
      });
    }
  }

  void _cancelNotificationListeners() {
    _notificationSubscription?.cancel();
    _notificationSubscription = null;
    _seenNotificationIds.clear();
  }

  /// Load user profile from Firestore
  Future<void> _loadUserProfile(String uid) async {
    try {
      final fetchedUser = await _firestoreService.getUser(uid);
      if (fetchedUser != null) {
        _userModel = fetchedUser;
      } else {
        // User exists in Firebase Auth but NOT in Firestore —
        // this means they never completed registration.
        // Sign them out so they can't access the dashboard.
        _userModel = null;
      }
    } catch (e) {
      debugPrint('Failed to load profile: $e');
      _userModel = null;
    }
  }

  /// Sign up with email and password
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String role,
    String bloodGroup = '',
    String phone = '',
  }) async {
    _setLoading(true);
    _isSigningUp = true; // Prevent authStateChanged from racing
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (cred.user != null) {
        // Get FCM token safely
        String? fcmToken;
        try {
          fcmToken = await _notificationService.getToken();
        } catch (e) {
          debugPrint('FCM Token error: $e');
        }

        // Create user profile in Firestore FIRST before anything else
        final user = UserModel(
          id: cred.user!.uid,
          name: name,
          email: email,
          phone: phone,
          role: role,
          bloodGroup: bloodGroup,
          fcmToken: fcmToken,
        );

        await _firestoreService.saveUser(user);

        // Set user model BEFORE releasing the signup guard
        _userModel = user;
        _firebaseUser = cred.user;
        _setupNotificationListeners();

        // Subscribe to role-based topics (non-critical)
        try {
          await _notificationService.subscribeToTopic(role);
          if (bloodGroup.isNotEmpty) {
            String safeGroup = bloodGroup.replaceAll('+', '_pos').replaceAll('-', '_neg');
            await _notificationService.subscribeToTopic('blood_$safeGroup');
          }
        } catch (e) {
          debugPrint('Topic subscription error: $e');
        }

        _isSigningUp = false;
        _setLoading(false);
        notifyListeners();
        return true;
      }
    } on FirebaseAuthException catch (e) {
      _error = _getAuthErrorMessage(e.code);
      debugPrint('>>> SIGNUP FirebaseAuthException code: ${e.code} message: ${e.message}');
    } on FirebaseException catch (e) {
      _error = _getAuthErrorMessage(e.code);
      debugPrint('>>> SIGNUP FirebaseException code: ${e.code} message: ${e.message}');
    } catch (e) {
      _error = 'Registration failed: ${e.toString()}';
      debugPrint('>>> SIGNUP generic error: $e');
    }
    _isSigningUp = false;
    _setLoading(false);
    return false;
  }

  /// Sign in with email and password
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (cred.user != null) {
        await _loadUserProfile(cred.user!.uid);

        // CHECK: If user profile doesn't exist in Firestore, reject sign-in
        if (_userModel == null) {
          _error = 'No account profile found. Please register first.';
          await _auth.signOut();
          _firebaseUser = null;
          _setLoading(false);
          return false;
        }

        // Update FCM token safely
        try {
          final fcmToken = await _notificationService.getToken();
          if (fcmToken != null) {
            await _firestoreService.updateFcmToken(cred.user!.uid, fcmToken);
          }
        } catch (e) {
          debugPrint('FCM update error: $e');
        }

        _setLoading(false);
        _setupNotificationListeners();
        return true;
      }
    } on FirebaseAuthException catch (e) {
      _error = _getAuthErrorMessage(e.code);
    } catch (e) {
      _error = 'Sign in failed: ${e.toString()}';
    }
    _setLoading(false);
    return false;
  }

  /// Sign in with Google
  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled
        _setLoading(false);
        return false;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      _isSigningUp = true;
      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        final user = userCredential.user!;

        // Check if user already exists in Firestore
        UserModel? existingUser;
        try {
          existingUser = await _firestoreService.getUser(user.uid);
        } catch (_) {}

        if (existingUser != null) {
          _userModel = existingUser;
          _firebaseUser = user;
          // Update FCM token
          try {
            final fcmToken = await _notificationService.getToken();
            if (fcmToken != null) {
              await _firestoreService.updateFcmToken(user.uid, fcmToken);
            }
          } catch (_) {}
        } else {
          // New Google user — force them to register first.
          await _auth.signOut();
          await _googleSignIn.signOut();
          _firebaseUser = null;
          _userModel = null;
          _isSigningUp = false;
          _setLoading(false);
          _error = 'firebase_google_new_user';
          notifyListeners();
          return false;
        }

        _isSigningUp = false;
        _setLoading(false);
        _setupNotificationListeners();
        notifyListeners();
        return true;
      }
    } on FirebaseAuthException catch (e) {
      _error = _getAuthErrorMessage(e.code);
    } catch (e) {
      _error = 'Google sign in failed: ${e.toString()}';
      debugPrint('Google sign in error: $e');
    }
    _isSigningUp = false;
    _setLoading(false);
    return false;
  }

  /// Phone OTP - Send verification code
  Future<void> sendPhoneOTP({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(_getAuthErrorMessage(e.code));
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      onError('Failed to send OTP');
    }
  }

  /// Verify OTP
  Future<bool> verifyOTP({
    required String verificationId,
    required String otp,
  }) async {
    _setLoading(true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );
      await _auth.signInWithCredential(credential);
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _getAuthErrorMessage(e.code);
    } catch (e) {
      _error = 'Invalid OTP';
    }
    _setLoading(false);
    return false;
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _auth.signOut();
    _userModel = null;
    _firebaseUser = null;
    _cancelNotificationListeners();
    notifyListeners();
  }

  /// Update user profile
  Future<void> updateProfile(UserModel updatedUser) async {
    _setLoading(true);
    try {
      await _firestoreService.saveUser(updatedUser);
      _userModel = updatedUser;
    } catch (e) {
      _error = 'Failed to update profile';
    }
    _setLoading(false);
  }

  /// Update user location
  Future<void> updateLocation(double lat, double lng) async {
    if (_firebaseUser != null) {
      await _firestoreService.updateUserLocation(_firebaseUser!.uid, lat, lng);
      _userModel = _userModel?.copyWith(latitude: lat, longitude: lng);
      notifyListeners();
    }
  }

  /// Map Firebase error codes to user-friendly messages
  String _getAuthErrorMessage(String code) {
    debugPrint('>>> Auth error code: $code');
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered. Please sign in instead.';
      case 'invalid-email':
        return 'Invalid email address';
      case 'weak-password':
        return 'Password is too weak (min 6 characters)';
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'invalid-verification-code':
        return 'Invalid OTP code';
      case 'invalid-credential':
        return 'Invalid email or password';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled. Contact support.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with a different sign-in method.';
      case 'credential-already-in-use':
        return 'This credential is already associated with another account.';
      case 'PERMISSION_DENIED':
      case 'permission-denied':
        return 'Permission denied. Please check Firestore rules.';
      default:
        return 'Authentication failed ($code). Please try again.';
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    if (loading) {
      _error = null;
    }
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
