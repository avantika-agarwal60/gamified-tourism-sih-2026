import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'pixel_journal.dart';
import 'journal_api.dart';

const _kGreen = Color(0xFF1E5228);
const _kCream = Color(0xFFFFF8E1);
const _kTeal = Color(0xFF287F78);
const _kGold = Color(0xFFB99858);

class CityBook {
  final String id;
  final String name;
  final List<String> stickerUrls;
  final bool unlocked;

  const CityBook({
    required this.id,
    required this.name,
    this.stickerUrls = const [],
    this.unlocked = false,
  });

  factory CityBook.fromProgressJson(Map<String, dynamic> json) {
    final city =
        (json['cities'] ?? json['city']) as Map<String, dynamic>? ?? {};
    return CityBook(
      id: (json['city_id'] ?? city['id'] ?? '').toString(),
      name: (city['name'] ?? '').toString(),
      stickerUrls: (city['cities_stickers_url'] as List? ?? [])
          .whereType<String>()
          .toList(),
      unlocked: true,
    );
  }
}

class BookshelfScreen extends StatefulWidget {
  final String userId;
  final String? authToken;
  final bool previewMode;
  final int completionRefreshVersion;

  const BookshelfScreen({
    super.key,
    this.userId = const String.fromEnvironment('USER_ID'),
    this.authToken,
    this.previewMode = false,
    this.completionRefreshVersion = 0,
  });

  @override
  State<BookshelfScreen> createState() => _BookshelfScreenState();
}

class _BookshelfScreenState extends State<BookshelfScreen> {
  late final JournalApi _api;
  List<CityBook> _books = [];
  bool _loadingBooks = true;
  String? _booksError;

  @override
  void initState() {
    super.initState();
    _api = JournalApi(authToken: widget.authToken);
    _loadBooks();
  }

  @override
  void didUpdateWidget(covariant BookshelfScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.completionRefreshVersion != widget.completionRefreshVersion) {
      setState(() {
        _loadingBooks = true;
        _booksError = null;
      });
      _loadBooks();
    }
  }

  Future<void> _loadBooks() async {
    if (widget.previewMode) {
      setState(() {
        _books = const [
          CityBook(
            id: 'preview_lucknow',
            name: 'Lucknow',
            unlocked: true,
            stickerUrls: [
              'preview-emoji:🌸',
              'preview-emoji:🪔',
              'preview-emoji:✨',
              'preview-emoji:🏛️',
            ],
          ),
          CityBook(
            id: 'preview_varanasi',
            name: 'Varanasi',
            unlocked: true,
            stickerUrls: [
              'preview-emoji:🌸',
              'preview-emoji:🪔',
              'preview-emoji:✨',
              'preview-emoji:🏛️',
            ],
          ),
          CityBook(id: 'preview_delhi', name: 'Delhi'),
        ];
        _loadingBooks = false;
        _booksError = null;
      });
      return;
    }
    if (widget.userId.isEmpty) {
      setState(() {
        _loadingBooks = false;
        _booksError = 'Provide a user ID to load city journals.';
      });
      return;
    }
    try {
      final rows = await _api.fetchCityProgress(widget.userId);
      if (!mounted) return;
      setState(() {
        _books = rows.map(CityBook.fromProgressJson).toList();
        _loadingBooks = false;
        _booksError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingBooks = false;
        _booksError = error.toString();
      });
    }
  }

  void _handleBookTap(CityBook book) {
    if (!book.unlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _kCream,
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Travel to ${book.name} to unlock this journal!',
            style: GoogleFonts.vt323(fontSize: 18, color: _kGreen),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (context, animation, secondaryAnimation) =>
            PixelJournalScreen(
          userId: widget.userId,
          cityId: book.id,
          cityName: book.name,
          authToken: widget.authToken,
          previewMode: widget.previewMode,
          stickerUrls: book.stickerUrls,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kCream,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/journal home bg.png',
              fit: BoxFit.fill,
            ),
            if (_loadingBooks)
              const Center(
                child: CircularProgressIndicator(color: _kTeal),
              )
            else if (_booksError != null)
              _buildError()
            else
              _buildPostcardCollection(),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _booksError!,
              textAlign: TextAlign.center,
              style: GoogleFonts.vt323(fontSize: 20, color: _kGreen),
            ),
            const SizedBox(height: 12),
            IconButton(
              onPressed: () {
                setState(() {
                  _loadingBooks = true;
                  _booksError = null;
                });
                _loadBooks();
              },
              icon: const Icon(Icons.refresh, color: _kTeal),
              tooltip: 'Retry',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostcardCollection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            constraints.maxWidth * 0.035,
            constraints.maxHeight * 0.17,
            constraints.maxWidth * 0.035,
            constraints.maxHeight * 0.075,
          ),
          child: _books.isEmpty
              ? Center(
                  child: Text(
                    'Your city postcards will appear here.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.vt323(fontSize: 20, color: _kGreen),
                  ),
                )
              : GridView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: _books.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.76,
                  ),
                  itemBuilder: (context, index) => _PostcardCard(
                    book: _books[index],
                    onTap: () => _handleBookTap(_books[index]),
                  ),
                ),
        );
      },
    );
  }
}

class _PostcardCard extends StatelessWidget {
  final CityBook book;
  final VoidCallback onTap;

  const _PostcardCard({
    required this.book,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final stampCity = switch (book.name.trim().toLowerCase()) {
      'lucknow' => 'Lucknow',
      'varanasi' => 'Varanasi',
      _ => null,
    };

    return Semantics(
      button: true,
      label: book.unlocked
          ? 'Open ${book.name} postcard'
          : '${book.name} postcard locked',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFDF3),
            border: Border.all(color: const Color(0xFF76B8AD), width: 1.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: book.unlocked
                            ? const Color(0xFFE5EBDD)
                            : const Color(0xFF9BB4A0),
                        border: Border.all(color: _kGold, width: 2),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: book.unlocked && stampCity != null
                          ? _buildCityStamp(stampCity)
                          : _buildPhotoSpace(book.unlocked),
                    ),
                    if (!book.unlocked)
                      const Positioned(
                        top: 5,
                        right: 5,
                        child: Icon(
                          Icons.lock_outline,
                          size: 22,
                          color: _kGreen,
                        ),
                      ),
                    if (!book.unlocked)
                      const Center(
                        child: Icon(
                          Icons.lock,
                          size: 28,
                          color: Color(0xFFFFF8E1),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              Container(
                height: 30,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: _kTeal, width: 1.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  book.unlocked ? book.name : '???',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.vt323(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                    color: book.unlocked ? _kGreen : _kTeal,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              const Icon(Icons.diamond_outlined, color: _kTeal, size: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoSpace(bool unlocked) {
    return Center(
      child: Icon(
        Icons.photo_outlined,
        size: 34,
        color: unlocked ? _kTeal.withValues(alpha: 0.45) : _kGreen,
      ),
    );
  }

  Widget _buildCityStamp(String cityName) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Image.asset(
        cityName.trim().toLowerCase() == 'lucknow'
            ? 'assets/lucknow stamp.png'
            : 'assets/varanasi stamp.png',
        fit: BoxFit.contain,
      ),
    );
  }
}
