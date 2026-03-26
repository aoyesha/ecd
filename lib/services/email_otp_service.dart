import 'dart:math';

import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

enum EmailOtpPurpose {
  accountVerification,
  monthlyLoginVerification,
  passwordReset,
}

class EmailOtpChallenge {
  final String code;
  final DateTime expiresAt;

  const EmailOtpChallenge({required this.code, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class EmailOtpService {
  static const _defaultSmtpHost = 'smtp.gmail.com';
  static const _defaultSmtpPort = 587;
  static const _defaultSmtpUsername = 'vincentyuri.jose.cics@ust.edu.ph';
  static const _defaultSmtpPassword = 'copo ncgg xxrq kmvt';
  static const _defaultFromName = 'Mail';

  static const _smtpHost = String.fromEnvironment(
    'SMTP_HOST',
    defaultValue: _defaultSmtpHost,
  );
  static const _smtpPort = int.fromEnvironment(
    'SMTP_PORT',
    defaultValue: _defaultSmtpPort,
  );
  static const _smtpUsername = String.fromEnvironment(
    'SMTP_USERNAME',
    defaultValue: _defaultSmtpUsername,
  );
  static const _smtpPassword = String.fromEnvironment(
    'SMTP_PASSWORD',
    defaultValue: _defaultSmtpPassword,
  );
  static const _smtpUseSsl = bool.fromEnvironment(
    'SMTP_SSL',
    defaultValue: false,
  );
  static const _smtpAllowInsecure = bool.fromEnvironment(
    'SMTP_ALLOW_INSECURE',
    defaultValue: false,
  );
  static const _fromName = String.fromEnvironment(
    'SMTP_FROM_NAME',
    defaultValue: _defaultFromName,
  );
  static const _subject = 'ECCD Checklist verification code';

  const EmailOtpService();

  EmailOtpChallenge createChallenge() {
    return EmailOtpChallenge(
      code: _generateCode(),
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
    );
  }

  Future<void> sendOtp({
    required String email,
    required EmailOtpChallenge challenge,
    EmailOtpPurpose purpose = EmailOtpPurpose.accountVerification,
  }) async {
    _ensureConfigured();

    final message = Message()
      ..from = Address(_smtpUsername, _fromName)
      ..recipients.add(email.trim().toLowerCase())
      ..subject = _subjectFor(purpose)
      ..text = _bodyFor(purpose, challenge);

    final smtpServer = SmtpServer(
      _smtpHost,
      port: _smtpPort,
      username: _smtpUsername,
      password: _smtpPassword,
      ssl: _smtpUseSsl,
      allowInsecure: _smtpAllowInsecure,
    );

    await send(message, smtpServer);
  }

  Future<EmailOtpChallenge> createAndSendOtp({
    required String email,
    EmailOtpPurpose purpose = EmailOtpPurpose.accountVerification,
  }) async {
    final challenge = createChallenge();
    await sendOtp(email: email, challenge: challenge, purpose: purpose);
    return challenge;
  }

  String _generateCode() {
    final value = Random.secure().nextInt(900000) + 100000;
    return value.toString();
  }

  void _ensureConfigured() {
    if (_smtpHost.isEmpty || _smtpUsername.isEmpty || _smtpPassword.isEmpty) {
      throw StateError(
        'Email OTP is not configured. Set SMTP_HOST, SMTP_USERNAME, and SMTP_PASSWORD.',
      );
    }
  }

  String _subjectFor(EmailOtpPurpose purpose) {
    switch (purpose) {
      case EmailOtpPurpose.accountVerification:
        return _subject;
      case EmailOtpPurpose.monthlyLoginVerification:
        return 'ECCD Checklist monthly teacher verification code';
      case EmailOtpPurpose.passwordReset:
        return 'ECCD Checklist password reset code';
    }
  }

  String _bodyFor(EmailOtpPurpose purpose, EmailOtpChallenge challenge) {
    final actionLine = switch (purpose) {
      EmailOtpPurpose.accountVerification =>
        'Use this code to verify your ECCD Checklist account.',
      EmailOtpPurpose.monthlyLoginVerification =>
        'Use this code to verify that your teacher account is still active for this month.',
      EmailOtpPurpose.passwordReset =>
        'Use this code to reset your ECCD Checklist password.',
    };

    return [
      'Your ECCD Checklist verification code is ${challenge.code}.',
      actionLine,
      'This code expires in 10 minutes.',
      'If you did not request this code, you can ignore this email.',
    ].join('\n\n');
  }
}
