import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
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

  FirebaseService._internal();

  /// Initialize Firebase safely (handles offline or missing config gracefully)
  Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;
      _isInitialized = true;
      debugPrint('[FirebaseService] Firebase initialized successfully.');
    } catch (e) {
      _isInitialized = false;
      debugPrint('[FirebaseService] Running in local offline mode (Firebase init skipped/failed: $e)');
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
  String get currentUsername {
    if (_isInitialized && _auth?.currentUser != null) {
      return _auth!.currentUser!.displayName ??
          _auth!.currentUser!.phoneNumber ??
          _auth!.currentUser!.email?.split('@').first ??
          'CyberRunner';
    }
    return 'CyberRunner';
  }

  User? get currentUser => _auth?.currentUser;
  bool get isSignedIn => _auth?.currentUser != null;

  /// User auth state changes stream
  Stream<User?>? get authStateChanges => _isInitialized ? _auth?.authStateChanges() : null;

  /// Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    if (!_isInitialized || _auth == null) {
      throw Exception('Firebase is not initialized. Please ensure google-services.json is configured.');
    }
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User canceled
        return null;
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return await _auth!.signInWithCredential(credential);
    } catch (e) {
      debugPrint('[FirebaseService] Google Sign-In failed: $e');
      rethrow;
    }
  }

  /// Sign in anonymously for instant zero-friction play
  Future<UserCredential?> signInAnonymously() async {
    if (!_isInitialized || _auth == null) return null;
    try {
      return await _auth!.signInAnonymously();
    } catch (e) {
      debugPrint('[FirebaseService] Anonymous sign-in failed: $e');
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
      throw Exception('Firebase is not initialized. Please configure google-services.json.');
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
  Future<UserCredential?> signInWithOtp(String verificationId, String smsCode) async {
    if (!_isInitialized || _auth == null) return null;
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      return await _auth!.signInWithCredential(credential);
    } catch (e) {
      debugPrint('[FirebaseService] Phone OTP sign-in failed: $e');
      rethrow;
    }
  }

  /// Email & Password Sign Up
  Future<UserCredential?> signUpWithEmail(String email, String password, String username) async {
    if (!_isInitialized || _auth == null) return null;
    try {
      final cred = await _auth!.createUserWithEmailAndPassword(email: email, password: password);
      await cred.user?.updateDisplayName(username);
      return cred;
    } catch (e) {
      debugPrint('[FirebaseService] Email sign-up failed: $e');
      rethrow;
    }
  }

  /// Email & Password Sign In
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    if (!_isInitialized || _auth == null) return null;
    try {
      return await _auth!.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      debugPrint('[FirebaseService] Email sign-in failed: $e');
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
        final cloudTimestamp = (data?['serverTimestamp'] as Timestamp?)?.toDate();
        if (cloudTimestamp != null && cloudTimestamp.isAfter(territory.capturedAt)) {
          debugPrint('[FirebaseService] Conflict: Cloud territory timestamp is newer. Skipping overwrite.');
          return;
        }
      }

      await docRef.set({
        ...territory.toJson(),
        'serverTimestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('[FirebaseService] Territory ${territory.id} synced to cloud.');
    } catch (e) {
      debugPrint('[FirebaseService] Error syncing territory: $e');
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
      debugPrint('[FirebaseService] Profile ${profile.id} synced to cloud.');
    } catch (e) {
      debugPrint('[FirebaseService] Error syncing profile: $e');
    }
  }

  /// Fetches global leaderboard from Firestore
  Future<List<Map<String, dynamic>>> getLeaderboard({int limit = 20}) async {
    if (!_isInitialized || _firestore == null) return [];
    try {
      final snapshot = await _firestore!
          .collection('users')
          .orderBy('totalHexesClaimed', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('[FirebaseService] Leaderboard fetch error: $e');
      return [];
    }
  }
}
