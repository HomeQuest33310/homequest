import 'package:flutter/material.dart';

import '../../domain/profile_avatar.dart';

class ProfileAvatarView extends StatelessWidget {
  const ProfileAvatarView({
    required this.avatarKey,
    required this.size,
    this.borderRadius,
    this.semanticLabel,
    super.key,
  });

  final String? avatarKey;
  final double size;
  final BorderRadius? borderRadius;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final avatar = profileAvatarFor(avatarKey);
    final fallback = Center(
      child: Text(
        avatar.fallbackEmoji,
        style: TextStyle(fontSize: size * 0.52),
      ),
    );
    final content = avatar.assetPath == null
        ? fallback
        : Image.asset(
            avatar.assetPath!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback,
          );

    return Semantics(
      image: true,
      label: semanticLabel ?? 'Avatar ${avatar.label}',
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(size / 2),
        child: SizedBox.square(dimension: size, child: content),
      ),
    );
  }
}
