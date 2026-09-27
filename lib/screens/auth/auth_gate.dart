import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'role_selection_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<Widget> _resolveScreen(User user) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists || doc.data()?['role'] == null) {
      return RoleSelectionScreen(uid: user.uid);
    }

    final role = doc['role'];

    if (role == 'customer') {
      return const Placeholder(); // CustomerHomeScreen
    } else {
      return const Placeholder(); // CraftsmanHomeScreen
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: Text("Login screen")),
          );
        }

        final user = snapshot.data!;

        return FutureBuilder<Widget>(
          future: _resolveScreen(user),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return snap.data!;
          },
        );
      },
    );
  }
}