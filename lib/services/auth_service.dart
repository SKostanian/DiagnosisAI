import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService._();
  static final AuthService _instance = AuthService._();
  factory AuthService() => _instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>['email', 'profile'],
  );

  // sign in with google
  Future<User?> signInWithGoogle({bool forceChooseAccount = false}) async {
    try {
     // always show account picker, even if one is saved
      if (forceChooseAccount) {
        // disconnect
        try { await _googleSignIn.disconnect(); } catch (_) { }
      }

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // if user cancelled

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      final cred = await _auth.signInWithCredential(credential);
      return cred.user;
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      return null;
    }
  }

  Future<void> signOutAll() async {
    try { await _googleSignIn.signOut(); } catch (_) {}
    try { await _auth.signOut(); } catch (_) {}
  }

  // disconnect google account
  Future<void> switchGoogleAccount() async {
    try { await _googleSignIn.disconnect(); } catch (_) {}
  }
  Future<void> disconnectGoogle() async {
    try { await _googleSignIn.disconnect(); } catch (_) {}
  }

  User? get currentUser => _auth.currentUser;

  // stream with user changes then email verified
  Stream<User?> get userChanges => _auth.userChanges();

  // reload user data
  Future<User?> reloadAndGetUser() async {
    try {
      await _auth.currentUser?.reload();
      return _auth.currentUser;
    } catch (_) {
      return _auth.currentUser;
    }
  }

  // UI user details
  GoogleAccountInfo? get firebaseAccountInfo {
    final u = _auth.currentUser;
    if (u == null) return null;
    return GoogleAccountInfo(
      displayName: u.displayName,
      email: u.email ?? '',
      photoUrl: u.photoURL,
    );
  }

  // cashed google account
  GoogleAccountInfo? getCachedGoogleAccount() {
    final u = _googleSignIn.currentUser;
    if (u == null) return null;
    return GoogleAccountInfo(
      displayName: u.displayName,
      email: u.email,
      photoUrl: u.photoUrl,
    );
  }

  // should show account info in app bar
  bool shouldShowAccountHeader(User u) {
    final providers = u.providerData.map((p) => p.providerId).toSet();
    if (providers.isEmpty) return u.emailVerified;

    if (providers.any((id) => id != 'password')) return true;

    // show only if email is verified
    return u.emailVerified;
  }
}

class GoogleAccountInfo {
  final String? displayName;
  final String email;
  final String? photoUrl;

  const GoogleAccountInfo({
    required this.displayName,
    required this.email,
    required this.photoUrl,
  });
}
