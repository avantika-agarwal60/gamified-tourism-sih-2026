class PhotoSlotData {
  final String id;
  final String label;
  final bool span2;
  final bool tall;

  PhotoSlotData({
    required this.id,
    required this.label,
    this.span2 = false,
    this.tall = false,
  });

  factory PhotoSlotData.fromJson(Map<String, dynamic> json) {
    return PhotoSlotData(
      id: json['id'] ?? '',
      label: json['label'] ?? json['title'] ?? '',
      span2: json['span2'] ?? false,
      tall: json['tall'] ?? false,
    );
  }
}

class JournalPageData {
  final String title;
  final String date;
  final String notePlaceholder;
  final List<String> stickers;
  final List<PhotoSlotData> slots;
  final String? caption;
  final String? stickerImagePath;
  final String? badgeImagePath;
  final String? stickerId;
  final List<String> stickerOptions;

  JournalPageData({
    required this.title,
    required this.date,
    required this.notePlaceholder,
    required this.stickers,
    required this.slots,
    this.caption,
    this.stickerImagePath,
    this.badgeImagePath,
    this.stickerId,
    this.stickerOptions = const [],
  });

  factory JournalPageData.fromJson(Map<String, dynamic> json) {
    return JournalPageData(
      title: json['title'] ?? '',
      date: json['date'] ?? 'DAY 1',
      notePlaceholder: json['note_placeholder'] ?? 'Write a note...',
      stickers: List<String>.from(json['stickers'] ?? []),
      caption: json['caption']?.toString(),
      stickerImagePath: json['sticker_image_path']?.toString(),
      badgeImagePath: json['badge_image_path']?.toString(),
      stickerId: json['sticker_id']?.toString(),
      stickerOptions: List<String>.from(json['sticker_options'] ?? []),
      slots: (json['slots'] as List? ?? [])
          .map((s) => PhotoSlotData.fromJson(s))
          .toList(),
    );
  }
}

class JournalSpread {
  final JournalPageData left;
  final JournalPageData right;

  JournalSpread({
    required this.left,
    required this.right,
  });

  factory JournalSpread.fromJson(Map<String, dynamic> json) {
    return JournalSpread(
      left: JournalPageData.fromJson(json['left_page']),
      right: JournalPageData.fromJson(json['right_page']),
    );
  }
}

// Global fallback array for Lucknow
final List<JournalSpread> journalSpreads = [
  JournalSpread(
    left: JournalPageData(
      title: 'BARA IMAMBARA',
      date: 'DAY 1',
      notePlaceholder: 'Describe the grand arches...',
      stickers: ['🕌', '✨'],
      slots: [
        PhotoSlotData(id: 'slot_1', label: 'Main Entrance Arch', span2: true),
        PhotoSlotData(id: 'slot_2', label: 'Courtyard View'),
      ],
    ),
    right: JournalPageData(
      title: 'BHULBHULAIYA',
      date: 'DAY 1',
      notePlaceholder: 'Did you get lost in the maze?',
      stickers: ['🗺️', '🏛️'],
      slots: [
        PhotoSlotData(id: 'slot_3', label: 'Balcony View', tall: true),
        PhotoSlotData(id: 'slot_4', label: 'Labyrinth Step'),
      ],
    ),
  ),
];
