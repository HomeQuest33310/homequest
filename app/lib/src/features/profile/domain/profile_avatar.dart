class ProfileAvatarOption {
  const ProfileAvatarOption({
    required this.key,
    required this.label,
    required this.fallbackEmoji,
    this.assetPath,
    this.goldPrice = 0,
  });

  final String key;
  final String label;
  final String fallbackEmoji;
  final String? assetPath;
  final int goldPrice;

  bool get isPremium => goldPrice > 0;
}

const profileAvatarCatalog = <ProfileAvatarOption>[
  ProfileAvatarOption(
    key: 'guardian',
    label: 'Gardien',
    fallbackEmoji: '🛡️',
  ),
  ProfileAvatarOption(
    key: 'knight',
    label: 'Chevalier',
    fallbackEmoji: '⚔️',
  ),
  ProfileAvatarOption(
    key: 'mage',
    label: 'Mage',
    fallbackEmoji: '🧙',
  ),
  ProfileAvatarOption(
    key: 'ranger',
    label: 'Rôdeur',
    fallbackEmoji: '🏹',
  ),
  ProfileAvatarOption(
    key: 'healer',
    label: 'Guérisseur',
    fallbackEmoji: '💚',
  ),
  ProfileAvatarOption(
    key: 'scholar',
    label: 'Érudit',
    fallbackEmoji: '📚',
  ),
  ProfileAvatarOption(
    key: 'explorer',
    label: 'Explorateur',
    fallbackEmoji: '🧭',
  ),
  ProfileAvatarOption(
    key: 'druid',
    label: 'Druide',
    fallbackEmoji: '🌿',
  ),
  ProfileAvatarOption(
    key: 'cook',
    label: 'Cuisinier',
    fallbackEmoji: '🍳',
  ),
  ProfileAvatarOption(
    key: 'builder',
    label: 'Bâtisseur',
    fallbackEmoji: '🔨',
  ),
  ProfileAvatarOption(
    key: 'star',
    label: 'Étoile',
    fallbackEmoji: '⭐',
  ),
  ProfileAvatarOption(
    key: 'dragon',
    label: 'Dragon',
    fallbackEmoji: '🐉',
  ),
  ProfileAvatarOption(
    key: 'akatsuki_ninja',
    label: 'Ninja de l’Akatsuki',
    fallbackEmoji: '🥷',
    assetPath: 'assets/images/profile_avatars/akatsuki_ninja.png',
    goldPrice: 100,
  ),
  ProfileAvatarOption(
    key: 'warrior_queen',
    label: 'Reine guerrière',
    fallbackEmoji: '👑',
    assetPath: 'assets/images/profile_avatars/warrior_queen.png',
    goldPrice: 100,
  ),
  ProfileAvatarOption(
    key: 'totoro',
    label: 'Totoro',
    fallbackEmoji: '🌳',
    assetPath: 'assets/images/profile_avatars/totoro.png',
    goldPrice: 100,
  ),
  ProfileAvatarOption(
    key: 'meerkat',
    label: 'Suricate',
    fallbackEmoji: '🐾',
    assetPath: 'assets/images/profile_avatars/meerkat.png',
    goldPrice: 100,
  ),
];

ProfileAvatarOption profileAvatarFor(String? key) {
  for (final avatar in profileAvatarCatalog) {
    if (avatar.key == key) return avatar;
  }
  return profileAvatarCatalog[6];
}

Set<String> get profileAvatarKeys =>
    profileAvatarCatalog.map((avatar) => avatar.key).toSet();

String avatarEmoji(String? key) => profileAvatarFor(key).fallbackEmoji;
