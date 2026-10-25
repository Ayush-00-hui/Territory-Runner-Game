import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/logging/app_logger.dart';
import '../models/runner_profile.dart';
import '../models/territory.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  FirebaseAuth? get auth => _auth;
  FirebaseFirestore? get firestore => _firestore;

  FirebaseService._internal();

  /// Whether a user is currently signed in
  bool get isSignedIn => _isInitialized && _auth?.currentUser != null;

  /// Asynchronously initializes Firebase
  Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;
      _isInitialized = true;
      AppLogger.info(
        'Firebase initialized successfully.',
        tag: 'FirebaseService',
      );
    } catch (e) {
      _isInitialized = false;
      AppLogger.warning(
        'Running in local offline mode (Firebase init skipped/failed: $e)',
        tag: 'FirebaseService',
      );
    }
  }

  /// Current user ID (or fallback local ID)
  String get currentUserId {
    if (_isInitialized && _auth?.currentUser != null) {
      return _auth!.currentUser!.uid;
    }
    return 'local_runner';
  }

  /// Current user display name or phone/email
  String get currentUserName {
    if (_isInitialized && _auth?.currentUser != null) {
      return _auth!.currentUser!.displayName ??
          _auth!.currentUser!.email ??
          _auth!.currentUser!.phoneNumber ??
          'Athlete';
    }
    return 'Solo Runner';
  }

  /// Alias for currentUserName for compatibility across modules
  String get currentUsername => currentUserName;

  /// Current user avatar URL
  String? get currentUserPhotoUrl {
    if (_isInitialized && _auth?.currentUser != null) {
      return _auth!.currentUser!.photoURL;
    }
    return null;
  }

  /// User auth state stream
  Stream<User?> get authStateChanges => _isInitialized && _auth != null
      ? _auth!.authStateChanges()
      : const Stream.empty();

  User? get currentUser => _isInitialized ? _auth?.currentUser : null;

  /// Google Sign-In with Tactical Auth Credential Handling
  Future<UserCredential?> signInWithGoogle() async {
    if (!_isInitialized || _auth == null) return null;
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User canceled
        return null;
      }
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return await _auth!.signInWithCredential(credential);
    } catch (e) {
      AppLogger.warning(
        'Google Sign-In failed: $e',
        tag: 'FirebaseService',
        error: e,
      );
      rethrow;
    }
  }

  /// Sign in anonymously for instant zero-friction play
  Future<UserCredential?> signInAnonymously() async {
    if (!_isInitialized || _auth == null) return null;
    try {
      return await _auth!.signInAnonymously();
    } catch (e) {
      AppLogger.warning(
        'Anonymous sign-in failed: $e',
        tag: 'FirebaseService',
        error: e,
      );
      return null;
    }
  }

  /// Send Phone SMS OTP
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(FirebaseAuthException error) onVerificationFailed,
    required Function(PhoneAuthCredential credential) onVerificationCompleted,
  }) async {
    if (!_isInitialized || _auth == null) {
      throw Exception(
        'Firebase is not initialized. Please configure google-services.json.',
      );
    }

    await _auth!.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: onVerificationCompleted,
      verificationFailed: onVerificationFailed,
      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
      timeout: const Duration(seconds: 60),
    );
  }

  /// Verify OTP code sent via SMS
  Future<UserCredential?> signInWithOtp(
    String verificationId,
    String smsCode,
  ) async {
    if (!_isInitialized || _auth == null) return null;
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      return await _auth!.signInWithCredential(credential);
    } catch (e) {
      AppLogger.warning(
        'Phone OTP sign-in failed: $e',
        tag: 'FirebaseService',
        error: e,
      );
      rethrow;
    }
  }

  /// Email & Password Sign Up
  Future<UserCredential?> signUpWithEmail(
    String email,
    String password,
    String username,
  ) async {
    if (!_isInitialized || _auth == null) return null;
    try {
      final cred = await _auth!.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await cred.user?.updateDisplayName(username);
      return cred;
    } catch (e) {
      AppLogger.warning(
        'Email sign-up failed: $e',
        tag: 'FirebaseService',
        error: e,
      );
      rethrow;
    }
  }

  /// Email & Password Sign In
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    if (!_isInitialized || _auth == null) return null;
    try {
      return await _auth!.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      AppLogger.warning(
        'Email sign-in failed: $e',
        tag: 'FirebaseService',
        error: e,
      );
      rethrow;
    }
  }

  /// Sign Out
  Future<void> signOut() async {
    if (!_isInitialized || _auth == null) return;
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _auth!.signOut();
  }

  /// Syncs a captured territory to Firestore with Server Timestamp conflict resolution
  Future<void> syncTerritoryToCloud(Territory territory) async {
    if (!_isInitialized || _firestore == null) return;
    try {
      final docRef = _firestore!.collection('territories').doc(territory.id);
      final doc = await docRef.get();

      // Conflict rule: server timestamp wins on ownership disputes
      if (doc.exists) {
        final data = doc.data();
        final cloudTimestamp = (data?['serverTimestamp'] as Timestamp?)
            ?.toDate();
        if (cloudTimestamp != null &&
            cloudTimestamp.isAfter(territory.capturedAt)) {
          AppLogger.debug(
            'Conflict: Cloud territory timestamp is newer. Skipping overwrite.',
            tag: 'FirebaseService',
          );
          return;
        }
      }

      await docRef.set({
        ...territory.toJson(),
        'serverTimestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      AppLogger.debug(
        'Territory ${territory.id} synced to cloud.',
        tag: 'FirebaseService',
      );
    } catch (e) {
      AppLogger.error(
        'Error syncing territory: $e',
        tag: 'FirebaseService',
        error: e,
      );
    }
  }

  /// Syncs runner profile to Cloud Firestore
  Future<void> syncProfileToCloud(RunnerProfile profile) async {
    if (!_isInitialized || _firestore == null) return;
    try {
      await _firestore!.collection('users').doc(profile.id).set({
        ...profile.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      AppLogger.debug(
        'Profile ${profile.id} synced to cloud.',
        tag: 'FirebaseService',
      );
    } catch (e) {
      AppLogger.error(
        'Error syncing profile: $e',
        tag: 'FirebaseService',
        error: e,
      );
    }
  }

  /// Fetches global leaderboard from Firestore
  Future<List<Map<String, dynamic>>> getLeaderboard({int limit = 20}) async {
    if (!_isInitialized || _firestore == null) return [];
    try {
      try {
        final snapshot = await _firestore!
            .collection('users')
            .orderBy('totalTerritoriesClaimed', descending: true)
            .limit(limit)
            .get();
        return snapshot.docs.map((doc) => doc.data()).toList();
      } catch (_) {
        final fallbackSnapshot = await _firestore!
            .collection('users')
            .orderBy('totalHexesClaimed', descending: true)
            .limit(limit)
            .get();
        return fallbackSnapshot.docs.map((doc) => doc.data()).toList();
      }
    } catch (e) {
      AppLogger.error(
        'Leaderboard fetch error: $e',
        tag: 'FirebaseService',
        error: e,
      );
      return [];
    }
  }
}
