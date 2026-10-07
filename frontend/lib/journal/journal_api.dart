import 'package:image_picker/image_picker.dart';
import '../api_service.dart';

class JournalApi {
  JournalApi({String? authToken}) {
    if (authToken != null && authToken.isNotEmpty) {
      ApiService.accessToken = authToken;
    }
  }

  Future<List<Map<String, dynamic>>> fetchCityProgress(String userId) async {
    _verifyUser(userId);
    final results = await Future.wait([
      ApiService.getCompletedQuests(),
      ApiService.getQuests(),
      ApiService.getCities(),
    ]);
    final completedQuests = _rows(results[0]);
    final questsById = _questsById(results[1]);
    final completedCityIds = completedQuests
        .map((row) =>
            _questForCompletion(row, questsById)['city_id']?.toString())
        .whereType<String>()
        .toSet();
    if (completedCityIds.isEmpty) return [];

    return results[2]
        .map<Map<String, dynamic>>((row) => _asMap(row))
        .where((city) => completedCityIds.contains(city['id']?.toString()))
        .map((city) => {
              'city_id': city['id']?.toString() ?? '',
              'cities': city,
            })
        .toList();
  }

  Future<List<JournalEntry>> fetchJournalEntries(
    String cityId, {
    String? userId,
  }) async {
    if (userId != null) _verifyUser(userId);
    final results = await Future.wait([
      ApiService.getCompletedQuests(),
      ApiService.getQuests(),
      ApiService.getJournal(),
    ]);
    final completedQuests = _rows(results[0]);
    final questsById = _questsById(results[1]);
    final journal = _asMap(results[2]);
    final storedEntries = _rows(journal['entries']);

    return completedQuests.where((completed) {
      return _questForCompletion(completed, questsById)['city_id']
              ?.toString() ==
          cityId;
    }).map<JournalEntry>((completed) {
      final quest = _questForCompletion(completed, questsById);
      final questId = _questId(completed, quest);
      final matchingEntries = storedEntries
          .where((entry) => entry['quest_id']?.toString() == questId)
          .toList();
      final photoUrls = matchingEntries
          .expand((entry) => _stringList(entry['photo_urls']))
          .toList();
      final latestEntry =
          matchingEntries.isEmpty ? <String, dynamic>{} : matchingEntries.last;
      final merged = <String, dynamic>{
        ...latestEntry,
        'quest_id': questId,
        'photo_urls': photoUrls,
        'entry_date': latestEntry['created_at'] ??
            latestEntry['completed_at'] ??
            completed['completed_at'] ??
            completed['created_at'],
        'quests': <String, dynamic>{
          ..._asMap(latestEntry['quests']),
          ...quest,
        },
      };
      return JournalEntry.fromJson(merged);
    }).toList();
  }

  Map<String, Map<String, dynamic>> _questsById(dynamic rows) => {
        for (final row in _rows(rows))
          if (row['id'] != null) row['id'].toString(): row,
      };

  Map<String, dynamic> _questForCompletion(
    Map<String, dynamic> completion,
    Map<String, Map<String, dynamic>> questsById,
  ) {
    final nestedQuest = _asMap(completion['quests'] ?? completion['quest']);
    final questId = _questId(completion, nestedQuest);
    return {
      ...?questsById[questId],
      ...nestedQuest,
    };
  }

  String _questId(
    Map<String, dynamic> completion,
    Map<String, dynamic> quest,
  ) =>
      (completion['quest_id'] ??
              completion['questId'] ??
              quest['id'] ??
              completion['id'] ??
              '')
          .toString();

  Future<Map<String, dynamic>> createJournalPhoto({
    required String questId,
    required XFile file,
    String? caption,
    String? stickerId,
  }) async {
    final bytes = await file.readAsBytes();
    final extension = file.name.split('.').last.toLowerCase();
    final contentType = switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    return ApiService.createJournalEntry(
      questId: questId,
      photoBytes: bytes,
      fileName: 'journal_${DateTime.now().microsecondsSinceEpoch}.$extension',
      contentType: contentType,
      caption: caption,
      stickerId: stickerId,
    );
  }

  void _verifyUser(String userId) {
    final authenticatedUserId = ApiService.currentUserId;
    if (authenticatedUserId == null) {
      throw StateError('Log in to view your journal.');
    }
    if (authenticatedUserId != userId) {
      throw StateError('The journal user does not match the logged-in user.');
    }
  }
}

class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.questId,
    required this.questName,
    required this.caption,
    required this.photoUrls,
    this.xpReward = 0,
    this.entryDate,
    this.stickerImagePath,
    this.stickerEmoji,
    this.stickerId,
    this.badgeImagePath,
  });

  final String id;
  final String questId;
  final String questName;
  final String? caption;
  final List<String> photoUrls;
  final int xpReward;
  final DateTime? entryDate;
  final String? stickerImagePath;
  final String? stickerEmoji;
  final String? stickerId;
  final String? badgeImagePath;

  JournalEntry copyWith({
    String? id,
    List<String>? photoUrls,
    String? caption,
    String? stickerId,
    String? stickerImagePath,
  }) =>
      JournalEntry(
        id: id ?? this.id,
        questId: questId,
        questName: questName,
        caption: caption ?? this.caption,
        photoUrls: photoUrls ?? this.photoUrls,
        xpReward: xpReward,
        entryDate: entryDate,
        stickerImagePath: stickerImagePath ?? this.stickerImagePath,
        stickerEmoji: stickerEmoji,
        stickerId: stickerId ?? this.stickerId,
        badgeImagePath: badgeImagePath,
      );

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    final quest = _asMap(json['quests'] ?? json['quest']);
    final sticker = _asMap(quest['quest_stickers'] ?? quest['questSticker']);
    final badge = _asMap(quest['quests_badges'] ?? quest['quest_badge']);
    final xpValue = quest['xp'];
    final entryDateValue = json['entry_date'] ??
        json['completed_at'] ??
        json['created_at'] ??
        json['date'];
    final badgeImagePath = quest['quests_badges_url'] ??
        quest['badge_image_url'] ??
        quest['badge_url'] ??
        badge['image_url'] ??
        badge['image_path'] ??
        badge['url'];
    return JournalEntry(
      id: json['id']?.toString() ?? '',
      questId: (json['quest_id'] ?? quest['id'] ?? '').toString(),
      questName: quest['name']?.toString() ?? 'JOURNAL ENTRY',
      caption: json['caption']?.toString(),
      photoUrls: _stringList(json['photo_urls']),
      xpReward: xpValue is num
          ? xpValue.toInt()
          : int.tryParse(xpValue?.toString() ?? '') ?? 0,
      entryDate: entryDateValue == null
          ? null
          : DateTime.tryParse(entryDateValue.toString()),
      stickerImagePath: sticker['image_path']?.toString(),
      stickerId: json['sticker_id']?.toString(),
      badgeImagePath: badgeImagePath?.toString(),
    );
  }
}

List<Map<String, dynamic>> _rows(dynamic value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value.map<Map<String, dynamic>>((row) => _asMap(row)).toList();
}

List<String> _stringList(dynamic value) =>
    value is List ? value.whereType<String>().toList() : <String>[];

Map<String, dynamic> _asMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
