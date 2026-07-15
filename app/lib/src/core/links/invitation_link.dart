import '../../config/env.dart';

class InvitationLink {
  const InvitationLink._();

  static Uri build(String token) {
    final configured = Env.appPublicUrl.trim();
    final base = configured.isEmpty ? Uri.base : Uri.parse(configured);
    final normalized =
        base.path.endsWith('/') ? base : base.replace(path: '${base.path}/');

    return normalized.replace(
      queryParameters: <String, String>{'invite': token},
      fragment: '',
    );
  }

  static String appLocation(String token) =>
      '/?invite=${Uri.encodeQueryComponent(token)}';

  static String authLocation(String token) =>
      '/auth?invite=${Uri.encodeQueryComponent(token)}';
}
