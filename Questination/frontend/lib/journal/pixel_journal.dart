import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../api_service.dart';
import 'journal_api.dart';
import 'journal_data.dart';
import 'journal_page_widget.dart';

class PixelJournalScreen extends StatefulWidget {
  final String userId;
  final String cityId;
  final String cityName;
  final String? authToken;
  final bool previewMode;
  final List<String> stickerUrls;

  const PixelJournalScreen({
    super.key,
    required this.userId,
    required this.cityId,
    required this.cityName,
    this.authToken,
    this.previewMode = false,
    this.stickerUrls = const [],
  });

  @override
  State<PixelJournalScreen> createState() => _PixelJournalScreenState();
}

class _PixelJournalScreenState extends State<PixelJournalScreen> {
  late final JournalApi _api;
  final PageController _pageController = PageController();
  List<JournalEntry> _entries = [];
  bool _loading = true;
  String? _error;
  int _currentPage = 0;
  final Set<String> _uploadingEntryIds = {};
  final Map<String, String> _photos = {};
  final Map<String, String> _pendingStickerIds = {};
  final Map<String, String> _pendingCaptions = {};
  final Map<String, String> _captionDrafts = {};
  String? _editingCaptionQuestId;

  @override
  void initState() {
    super.initState();
    _api = JournalApi(authToken: widget.authToken);
    _loadEntries();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    if (widget.previewMode) {
      setState(() {
        _entries = [
          const JournalEntry(
            id: 'preview_entry_1',
            questId: 'preview_quest_1',
            questName: 'BARA IMAMBARA',
            caption: 'The grand arches were even more beautiful in person.',
            photoUrls: [],
            xpReward: 150,
            stickerEmoji: '🕌',
            badgeImagePath: null,
          ),
          const JournalEntry(
            id: 'preview_entry_2',
            questId: 'preview_quest_2',
            questName: 'RUMI DARWAZA',
            caption: 'A golden evening walk through the old city.',
            photoUrls: [],
            xpReward: 200,
            stickerEmoji: '✨',
            badgeImagePath: null,
          ),
        ];
        _seedPhotoPaths(_entries);
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await _api.fetchJournalEntries(
        widget.cityId,
        userId: widget.userId,
      );
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _seedPhotoPaths(entries);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _uploadPhoto(
    JournalEntry entry,
    int photoIndex,
    XFile photo,
  ) async {
    final uploadKey = entry.questId;
    if (_uploadingEntryIds.contains(uploadKey)) return;
    if (widget.previewMode) {
      final photos = [...entry.photoUrls];
      if (photoIndex < photos.length) {
        photos[photoIndex] = photo.path;
      } else {
        photos.add(photo.path);
      }
      setState(() {
        final index = _entries.indexWhere((item) => item.id == entry.id);
        if (index != -1) {
          _entries[index] = entry.copyWith(photoUrls: photos);
          _photos['${entry.questId}_$photoIndex'] = photo.path;
        }
      });
      return;
    }
    setState(() => _uploadingEntryIds.add(uploadKey));
    try {
      final created = await _api.createJournalPhoto(
        questId: entry.questId,
        file: photo,
        caption: _pendingCaptions[entry.questId] ?? entry.caption,
        stickerId: _pendingStickerIds[entry.questId] ?? entry.stickerId,
      );
      final createdPhotos =
          (created['photo_urls'] as List? ?? []).whereType<String>().toList();
      final photoUrl =
          createdPhotos.isNotEmpty ? createdPhotos.first : photo.path;
      final photos = [...entry.photoUrls, ...createdPhotos];
      final updatedEntry = entry.copyWith(
        id: created['id']?.toString(),
        photoUrls: photos,
        caption: _pendingCaptions[entry.questId] ?? entry.caption,
        stickerId: _pendingStickerIds[entry.questId] ?? entry.stickerId,
        stickerImagePath:
            _pendingStickerIds[entry.questId] ?? entry.stickerImagePath,
      );
      if (!mounted) return;
      setState(() {
        final index =
            _entries.indexWhere((item) => item.questId == entry.questId);
        if (index != -1) {
          _entries[index] = updatedEntry;
          _photos['${entry.questId}_$photoIndex'] = photoUrl;
        }
        _pendingStickerIds.remove(entry.questId);
        _pendingCaptions.remove(entry.questId);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photo upload failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _uploadingEntryIds.remove(uploadKey));
      }
    }
  }

  Future<void> _selectSticker(JournalEntry entry) async {
    if (widget.stickerUrls.isEmpty) return;
    final selection = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.builder(
            shrinkWrap: true,
            itemCount: widget.stickerUrls.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (context, index) {
              final stickerUrl = widget.stickerUrls[index];
              return InkWell(
                onTap: () => Navigator.pop(context, stickerUrl),
                child: stickerUrl.startsWith('preview-emoji:')
                    ? Center(
                        child: Text(
                          stickerUrl.substring('preview-emoji:'.length),
                          style: const TextStyle(fontSize: 40),
                        ),
                      )
                    : Image.network(
                        _absoluteImageUrl(stickerUrl),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.broken_image),
                      ),
              );
            },
          ),
        ),
      ),
    );
    if (selection == null || !mounted) return;

    if (!widget.previewMode) {
      _pendingStickerIds[entry.questId] = selection;
    }
    if (!mounted) return;
    setState(() {
      final index =
          _entries.indexWhere((item) => item.questId == entry.questId);
      if (index != -1) {
        _entries[index] = entry.copyWith(
          stickerId: selection,
          stickerImagePath: selection,
        );
      }
    });
    if (!widget.previewMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sticker will be saved with the next photo upload.'),
        ),
      );
    }
  }

  void _beginCaptionEdit(JournalEntry entry) {
    setState(() {
      _editingCaptionQuestId = entry.questId;
      _captionDrafts[entry.questId] =
          _pendingCaptions[entry.questId] ?? entry.caption ?? '';
    });
  }

  void _updateCaptionDraft(String questId, String caption) {
    _captionDrafts[questId] = caption;
  }

  void _cancelCaptionEdit(String questId) {
    setState(() {
      _editingCaptionQuestId = null;
      _captionDrafts.remove(questId);
    });
  }

  void _saveCaption(JournalEntry entry) {
    final caption = (_captionDrafts[entry.questId] ?? '').trim();
    final index = _entries.indexWhere((item) => item.questId == entry.questId);
    if (index == -1) {
      _cancelCaptionEdit(entry.questId);
      return;
    }
    setState(() {
      _pendingCaptions[entry.questId] = caption;
      _entries[index] = _entries[index].copyWith(caption: caption);
      _captionDrafts.remove(entry.questId);
      _editingCaptionQuestId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(255, 255, 254, 1),
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: Text(
                  'BACK TO JOURNALS',
                  style: GoogleFonts.pressStart2p(fontSize: 7),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF3A2810),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildMessage(_error!, retry: true)
                      : _entries.isEmpty
                          ? _buildMessage(
                              'No journal entries found for this city.',
                            )
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                final pageCount = _entries.length;
                                final pageWidth = (constraints.maxWidth * 0.88)
                                    .clamp(280.0, 900.0)
                                    .toDouble();
                                final pageHeight = (constraints.maxHeight * 0.8)
                                    .clamp(320.0, 700.0)
                                    .toDouble();
                                return Column(
                                  children: [
                                    Expanded(
                                      child: Center(
                                        child: SizedBox(
                                          width: pageWidth,
                                          height: pageHeight,
                                          child: PageView.builder(
                                            controller: _pageController,
                                            physics:
                                                const NeverScrollableScrollPhysics(),
                                            itemCount: pageCount,
                                            onPageChanged: (index) => setState(
                                              () => _currentPage = index,
                                            ),
                                            itemBuilder: (context, pageIndex) =>
                                                _buildPage(pageIndex),
                                          ),
                                        ),
                                      ),
                                    ),
                                    _buildPageControls(pageCount),
                                    const SizedBox(height: 12),
                                  ],
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageControls(int spreadCount) {
    final canGoPrevious = _currentPage > 0;
    final canGoNext = _currentPage < spreadCount - 1;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton.icon(
          onPressed: canGoPrevious
              ? () => _pageController.jumpToPage(_currentPage - 1)
              : null,
          icon: const Icon(Icons.chevron_left),
          label: Text('PREVIOUS', style: GoogleFonts.pressStart2p(fontSize: 6)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'PAGE ${_currentPage + 1} OF $spreadCount',
            style: GoogleFonts.pressStart2p(
              fontSize: 6,
              color: const Color(0xFF7A5830),
            ),
          ),
        ),
        TextButton.icon(
          onPressed: canGoNext
              ? () => _pageController.jumpToPage(_currentPage + 1)
              : null,
          icon: const Icon(Icons.chevron_right),
          label: Text('NEXT', style: GoogleFonts.pressStart2p(fontSize: 6)),
        ),
      ],
    );
  }

  Widget _buildMessage(String message, {bool retry = false}) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.vt323(
                  fontSize: 20,
                  color: const Color(0xFF3A2810),
                ),
              ),
              if (retry) ...[
                const SizedBox(height: 12),
                IconButton(
                  onPressed: _loadEntries,
                  icon: const Icon(Icons.refresh, color: Color(0xFF3A2810)),
                  tooltip: 'Retry',
                ),
              ],
            ],
          ),
        ),
      );

  void _seedPhotoPaths(List<JournalEntry> entries) {
    _photos.clear();
    for (final entry in entries) {
      for (var index = 0; index < entry.photoUrls.length; index++) {
        _photos['${entry.questId}_$index'] = entry.photoUrls[index];
      }
    }
  }

  Widget _buildPage(int pageIndex) {
    final entry = _entries[pageIndex];
    return JournalPageWidget(
      page: _pageDataAt(pageIndex),
      photos: _photosForEntry(entry),
      onPhotoAdded: (photo) => _uploadPhoto(
        entry,
        int.parse(photo.key.split('_').last),
        photo.value,
      ),
      pageNum: pageIndex + 1,
      cityName: widget.cityName,
      xpReward: entry.xpReward,
      coinsReward: 3,
      isEditingCaption: _editingCaptionQuestId == entry.questId,
      captionDraft: _captionDrafts[entry.questId],
      onCaptionChanged: (caption) =>
          _updateCaptionDraft(entry.questId, caption),
      onStickerTap: () => _selectSticker(entry),
      onCaptionEdit: () => _beginCaptionEdit(entry),
      onCaptionSave: () => _saveCaption(entry),
      onCaptionCancel: () => _cancelCaptionEdit(entry.questId),
    );
  }

  JournalPageData _pageDataAt(int entryIndex) {
    final entry = _entries[entryIndex];
    return JournalPageData(
      title: entry.questName,
      date: _formatJournalDate(entry.entryDate),
      notePlaceholder: '',
      caption: _pendingCaptions[entry.questId] ?? entry.caption,
      stickerImagePath: entry.stickerImagePath ??
          (widget.stickerUrls.contains(entry.stickerId)
              ? entry.stickerId
              : null),
      badgeImagePath: entry.badgeImagePath,
      stickerId: entry.stickerId,
      stickerOptions: widget.stickerUrls,
      stickers: entry.stickerEmoji == null ? const [] : [entry.stickerEmoji!],
      slots: List.generate(
        3,
        (index) => PhotoSlotData(
          id: '${entry.questId}_$index',
          label: 'PHOTO ${index + 1}',
        ),
      ),
    );
  }

  String _formatJournalDate(DateTime? date) {
    if (date == null) return '';
    final localDate = date.toLocal();
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return '${localDate.day} ${months[localDate.month - 1]} ${localDate.year}';
  }

  Map<String, String> _photosForEntry(JournalEntry entry) => {
        for (var index = 0; index < entry.photoUrls.length; index++)
          '${entry.questId}_$index':
              _photos['${entry.questId}_$index'] ?? entry.photoUrls[index],
        for (var index = entry.photoUrls.length; index < 3; index++)
          if (_photos.containsKey('${entry.questId}_$index'))
            '${entry.questId}_$index': _photos['${entry.questId}_$index']!,
      };

  String _absoluteImageUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return '${ApiService.baseUrl}$normalizedPath';
  }
}
