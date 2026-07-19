import 'package:flutter/material.dart';

import '../../../../core/widgets/nature_animated_icon.dart';
import '../../domain/profile_avatar.dart';

class ProfileAvatarView extends StatelessWidget {
  const ProfileAvatarView({
    required this.avatarKey,
    required this.size,
    this.borderRadius,
    this.semanticLabel,
    this.animationKey,
    this.animate = true,
    super.key,
  });

  final String? avatarKey;
  final double size;
  final BorderRadius? borderRadius;
  final String? semanticLabel;
  final Object? animationKey;
  final bool animate;

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

    final clippedAvatar = ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(size / 2),
      child: SizedBox.square(dimension: size, child: content),
    );

    return Semantics(
      image: true,
      label: semanticLabel ?? 'Avatar ${avatar.label}',
      child: animate
          ? NatureAnimatedIcon(
              motion: avatarNatureMotion(avatarKey),
              replayKey: animationKey,
              child: clippedAvatar,
            )
          : clippedAvatar,
    );
  }
}
