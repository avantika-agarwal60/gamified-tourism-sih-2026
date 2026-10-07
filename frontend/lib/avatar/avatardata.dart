class OutfitItem {
  final String id;
  final String name;
  final String imagePath;
  final int coinCost;
  final String category;
  final bool isOwned;

  OutfitItem({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.coinCost,
    required this.category,
    this.isOwned = false,
  });
}

class AvatarAppearance {
  final String outfit;
  final String hair;
  final String hat;

  const AvatarAppearance({
    required this.outfit,
    required this.hair,
    required this.hat,
  });
}

const defaultAvatar = AvatarAppearance(
  outfit: 'assets/avatar pieces/outfit 6.webp',
  hair: 'assets/avatar pieces/hair 4.webp',
  hat: 'assets/avatar pieces/hat 2.webp',
);