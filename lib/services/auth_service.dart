import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<UserCredential> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

    if (googleUser == null) {
      throw Exception("Login zrušený používateľom");
    }

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential =
        await _auth.signInWithCredential(credential);

    final uid = userCredential.user!.uid;

    await _createUserIfNotExists(userCredential);

    return userCredential;
  }

  Future<void> _createUserIfNotExists(UserCredential userCredential) async {
    final user = userCredential.user!;
    final uid = user.uid;

    final doc = await _db.collection('users').doc(uid).get();

    if (!doc.exists) {
      await _db.collection('users').doc(uid).set({
        'uid': uid,
        'email': user.email,
        'name': user.displayName ?? '',
        'photoUrl': user.photoURL ?? '',
        'role': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}