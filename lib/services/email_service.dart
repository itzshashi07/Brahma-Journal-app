import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/constants/app_constants.dart';

class EmailService {
  Future<bool> sendEmail({
    required String subject,
    required String htmlContent,
  }) async {
    final apiKey = AppConstants.resendApiKey;
    final toEmail = AppConstants.adminEmail;

    if (apiKey.isEmpty) {
      debugPrint('⚠️ Resend API Key is unconfigured. Cannot send email alert.');
      return false;
    }

    try {
      final url = Uri.parse('https://api.resend.com/emails');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'from': 'Brahma Journal <onboarding@resend.dev>',
          'to': toEmail,
          'subject': subject,
          'html': htmlContent,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ Email alert dispatched successfully!');
        return true;
      } else {
        debugPrint('⚠️ Resend email dispatch returned status ${response.statusCode}: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('⚠️ Exception during email dispatch: $e');
      return false;
    }
  }

  Future<bool> sendPaymentNotification({
    required String name,
    required String email,
    required String planSelected,
    required String paymentId,
    String? subscriptionId,
  }) async {
    final subject = '💳 New Premium Sign Up: $name';
    final html = '''
      <h2>🎉 New Brahma Journal Registration</h2>
      <p>A user has successfully registered and activated a premium membership subscription.</p>
      <hr/>
      <p><b>User Details:</b></p>
      <ul>
        <li><b>Name:</b> $name</li>
        <li><b>Email:</b> $email</li>
        <li><b>Plan Selected:</b> ${planSelected.toUpperCase()}</li>
      </ul>
      <p><b>Payment References:</b></p>
      <ul>
        <li><b>Payment ID:</b> $paymentId</li>
        <li><b>Subscription ID:</b> ${subscriptionId ?? 'One-time Test Fallback'}</li>
      </ul>
      <br/>
      <p>Namaste,<br/>Brahma Journal Bot</p>
    ''';
    return await sendEmail(subject: subject, htmlContent: html);
  }

  Future<bool> sendSupportQuery({
    required String name,
    required String email,
    required String category,
    required String message,
  }) async {
    final subject = '✉️ Support Ticket: [$category] from $name';
    final html = '''
      <h2>✉️ New Helpdesk Submission</h2>
      <p>A user has submitted a query / feedback through the Support Center in the mobile app.</p>
      <hr/>
      <p><b>Ticket Details:</b></p>
      <ul>
        <li><b>User Name:</b> $name</li>
        <li><b>User Email:</b> $email</li>
        <li><b>Category:</b> $category</li>
      </ul>
      <p><b>Message:</b></p>
      <blockquote style="background: #f3f4f6; padding: 12px; border-left: 4px solid #4f46e5; font-style: italic;">
        ${message.replaceAll('\n', '<br/>')}
      </blockquote>
      <br/>
      <p>Reply directly to the user at: <a href="mailto:$email">$email</a></p>
    ''';
    return await sendEmail(subject: subject, htmlContent: html);
  }
}
