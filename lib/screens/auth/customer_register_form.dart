import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:math';

import '../utils/countries.dart';

const _kPrimary = Color(0xFF2563EB);

class CustomerRegisterForm extends StatefulWidget {
  const CustomerRegisterForm({super.key});

  @override
  State<CustomerRegisterForm> createState() => _CustomerRegisterFormState();
}

class _CustomerRegisterFormState extends State<CustomerRegisterForm> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController streetController = TextEditingController();

  bool isLoading = false;
  bool _passwordVisible = false;

  late final List<String> countryNames;
  String selectedCountry = 'Slovakia';
  String selectedCountryCode = 'SK';

  @override
  void initState() {
    super.initState();
    countryNames = countryMap.keys.toList()..sort();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    cityController.dispose();
    streetController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  Future<void> submit() async {
    if (nameController.text.trim().isEmpty ||
        cityController.text.trim().isEmpty ||
        streetController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('fillAllFields'.tr())),
      );
      return;
    }

    if (!_isValidEmail(emailController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('enterValidEmail'.tr())),
      );
      return;
    }

    if (passwordController.text.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('passwordMinLength'.tr())),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final uid = userCredential.user!.uid;

      await FirebaseFirestore.instance.collection("customers").doc(uid).set({
        'name': nameController.text.trim(),
        'city': cityController.text.trim(),
        'street': streetController.text.trim(),
        'email': emailController.text.trim(),
        'country': selectedCountry,
        'countryCode': selectedCountryCode,
      });

      await FirebaseFirestore.instance.collection("users").doc(uid).set({
        "email": emailController.text.trim(),
        "role": "customer",
        "createdAt": Timestamp.now(),
      });

      await userCredential.user!.sendEmailVerification();
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.mark_email_unread_outlined, color: _kPrimary),
              const SizedBox(width: 8),
              Text('emailVerification'.tr()),
            ],
          ),
          content: Text('emailVerificationSent'.tr()),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('ok'.tr()),
            ),
          ],
        ),
      );

      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'registrationError'.tr())),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text('customerRegistration'.tr()),
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Image.asset(
              'assets/logo.png',
              height: 70,
              width: 70,
            ),
            const SizedBox(height: 24),

            _buildTextField(
                emailController, 'email'.tr(), Icons.email_outlined,
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 14),

            TextField(
              controller: passwordController,
              obscureText: !_passwordVisible,
              decoration: InputDecoration(
                labelText: 'password'.tr(),
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                suffixIcon: IconButton(
                  icon: Icon(_passwordVisible
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () {
                    setState(() => _passwordVisible = !_passwordVisible);
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),

            _buildTextField(nameController, 'name'.tr(),
                Icons.person_outline_rounded),
            const SizedBox(height: 14),
            _buildTextField(
                cityController, 'city'.tr(), Icons.location_city_outlined),
            const SizedBox(height: 14),
            _buildTextField(
                streetController, 'street'.tr(), Icons.signpost_outlined),
            const SizedBox(height: 14),

            DropdownButtonFormField<String>(
              value: selectedCountry,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'country'.tr(),
                prefixIcon: const Icon(Icons.flag_outlined),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              items: countryNames
                  .map((name) => DropdownMenuItem(
                        value: name,
                        child: Text(
                          name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  selectedCountry = val!;
                  selectedCountryCode = countryMap[val] ?? 'SK';
                });
              },
            ),

            const SizedBox(height: 28),
            isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: _kPrimary))
                : ElevatedButton(
                    onPressed: submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'register'.tr(),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}