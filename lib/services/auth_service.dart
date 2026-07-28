import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/legal_document.dart';

class EmailAvailabilityException implements Exception {
  const EmailAvailabilityException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RegistrationData {
  const RegistrationData({
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.phoneNumber,
    required this.birthDate,
    required this.email,
    required this.password,
    required this.legalDocuments,
  });

  final String firstName;
  final String lastName;
  final String username;
  final String phoneNumber;
  final DateTime birthDate;
  final String email;
  final String password;
  final List<LegalDocument> legalDocuments;
}

class AuthService {
  AuthService._();

  static final instance = AuthService._();

  SupabaseClient get _client {
    if (!SupabaseConfig.isConfigured) {
      throw const EmailAvailabilityException(
        'Supabase is not configured for this build.',
      );
    }
    return Supabase.instance.client;
  }

  Session? get currentSession =>
      SupabaseConfig.isConfigured ? _client.auth.currentSession : null;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<List<LegalDocument>> fetchActiveLegalDocuments() async {
    final rows = await _client
        .from('legal_documents')
        .select(
          'document_id, document_type, version, title, content, effective_at',
        )
        .order('document_type');

    final documents = rows
        .map((row) => LegalDocument.fromJson(row))
        .toList(growable: false);
    documents.sort(
      (left, right) => left.type.index.compareTo(right.type.index),
    );
    return documents;
  }

  Future<bool> isEmailAvailable(String email) async {
    final response = await _client.functions.invoke(
      'email-availability',
      body: {'email': email.trim().toLowerCase()},
    );
    final data = response.data;
    if (response.status != 200 || data is! Map) {
      final message = data is Map && data['error'] is String
          ? data['error'] as String
          : 'Email availability check failed.';
      throw EmailAvailabilityException(message);
    }
    return data['available'] == true;
  }

  Future<AuthResponse> signUp(RegistrationData registration) {
    final versions = <String, String>{
      for (final document in registration.legalDocuments)
        document.type.databaseValue: document.version,
    };

    return _client.auth.signUp(
      email: registration.email.trim().toLowerCase(),
      password: registration.password,
      emailRedirectTo: SupabaseConfig.authRedirectUrl,
      data: {
        'first_name': registration.firstName.trim(),
        'last_name': registration.lastName.trim(),
        'username': registration.username.trim().toLowerCase(),
        'phone_number': registration.phoneNumber.trim(),
        'birth_date': _dateOnly(registration.birthDate),
        'legal_document_versions': versions,
      },
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
  }

  Future<ResendResponse> resendVerification(String email) {
    return _client.auth.resend(
      type: OtpType.signup,
      email: email.trim().toLowerCase(),
      emailRedirectTo: SupabaseConfig.authRedirectUrl,
    );
  }

  Future<void> sendPasswordReset(String email) {
    return _client.auth.resetPasswordForEmail(
      email.trim().toLowerCase(),
      redirectTo: SupabaseConfig.authRedirectUrl,
    );
  }

  Future<UserResponse> updatePassword(String password) {
    return _client.auth.updateUser(UserAttributes(password: password));
  }

  Future<void> signOut() => _client.auth.signOut();

  static String _dateOnly(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
