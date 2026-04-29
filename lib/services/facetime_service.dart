import 'package:url_launcher/url_launcher.dart';

class FaceTimeService {
  /// FaceTime 영상통화 (전화번호 또는 이메일)
  static Future<bool> videoCall(String contact) async {
    final uri = _faceTimeUri('facetime', contact);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return true;
    }
    return false;
  }

  /// FaceTime 음성통화
  static Future<bool> audioCall(String contact) async {
    final uri = _faceTimeUri('facetime-audio', contact);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return true;
    }
    return false;
  }

  /// 연락처 문자열 반환 (전화번호 우선, 없으면 이메일)
  static String? getContact(String? phone, String? email) {
    final normalizedPhone = phone?.trim();
    final normalizedEmail = email?.trim();
    if (normalizedPhone != null && normalizedPhone.isNotEmpty) {
      return normalizedPhone;
    }
    if (normalizedEmail != null && normalizedEmail.isNotEmpty) {
      return normalizedEmail;
    }
    return null;
  }

  static Uri _faceTimeUri(String scheme, String contact) {
    final normalized = contact.trim();
    return Uri.parse('$scheme://${Uri.encodeComponent(normalized)}');
  }
}
