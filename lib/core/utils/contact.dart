import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Real phone / WhatsApp launching (replaces the demo snackbars).
abstract final class Contact {
  static Future<void> call(BuildContext context, String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    final messenger = ScaffoldMessenger.of(context);
    if (!await launchUrl(uri)) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not start a call to $phone')),
      );
    }
  }

  static Future<void> whatsapp(
    BuildContext context,
    String phone, {
    String? message,
  }) async {
    final normalized = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.https('wa.me', '/$normalized', {'text': ?message});
    final messenger = ScaffoldMessenger.of(context);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't open WhatsApp")),
      );
    }
  }
}
