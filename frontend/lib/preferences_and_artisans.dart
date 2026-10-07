import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api_service.dart';

const _green = Color(0xFF2A4A20);
const _yellow = Color(0xFFFAF179);

class PreferencesAndArtisansScreen extends StatefulWidget {
  final String? cityId;

  const PreferencesAndArtisansScreen({super.key, this.cityId});

  @override
  State<PreferencesAndArtisansScreen> createState() =>
      _PreferencesAndArtisansScreenState();
}

class _PreferencesAndArtisansScreenState
    extends State<PreferencesAndArtisansScreen> {
  bool _loading = true;
  bool _loadingRecommendations = false;
  bool _savingPreferences = false;
  String? _categoriesError;
  String? _preferenceSaveError;
  String? _recommendationsError;
  List<dynamic> _categories = [];
  List<dynamic> _recommendations = [];
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PreferencesAndArtisansScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.cityId != oldWidget.cityId) {
      _load();
    }
  }

  Future<void> _load() async {
    final cityId = widget.cityId;
    if (cityId == null || cityId.isEmpty) {
      setState(() {
        _loading = false;
        _categories = [];
        _recommendations = [];
        _loadingRecommendations = false;
        _categoriesError = null;
        _preferenceSaveError = null;
        _recommendationsError = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _categoriesError = null;
    });
    final result = await ApiService.getCraftCategories(cityId)
        .then<Object>((value) => value)
        .catchError((Object error) => error);
    if (!mounted) return;
    setState(() {
      if (result is List) {
        _categories = result;
      } else {
        _categories = [];
        _categoriesError = result.toString();
      }
      _loading = false;
    });
    await _loadArtisans();
  }

  Future<void> _toggleCategory(String id) async {
    if (_savingPreferences) return;
    final next = Set<String>.from(_selectedIds);
    if (!next.add(id)) next.remove(id);
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(next);
      _preferenceSaveError = null;
    });
    await _savePreferences();
  }

  Future<void> _savePreferences() async {
    if (_savingPreferences) return;
    setState(() {
      _savingPreferences = true;
      _preferenceSaveError = null;
    });
    try {
      await ApiService.saveCraftPreferences(_selectedIds.toList());
      if (!mounted) return;
      await _loadArtisans();
      if (mounted) setState(() => _savingPreferences = false);
    } catch (error) {
      if (mounted) {
        setState(() {
          _savingPreferences = false;
          _preferenceSaveError =
              error.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _loadArtisans() async {
    final cityId = widget.cityId;
    if (cityId == null || cityId.isEmpty) return;
    if (mounted) {
      setState(() => _loadingRecommendations = true);
    }
    try {
      final artisans = await ApiService.getArtisansByCity(cityId);
      if (mounted) {
        setState(() {
          _recommendations = artisans;
          _recommendationsError = null;
          _loadingRecommendations = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _recommendations = [];
          _recommendationsError = error.toString();
          _loadingRecommendations = false;
        });
      }
    }
  }

  List<dynamic> get _visibleRecommendations {
    if (_selectedIds.isEmpty) return _recommendations;

    final selectedNames = _categories
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .where((category) => _selectedIds.contains(category['id']?.toString()))
        .map((category) => category['name']?.toString().toLowerCase())
        .whereType<String>()
        .toSet();

    return _recommendations.where((row) {
      if (row is! Map) return false;
      final artisan = Map<String, dynamic>.from(row);
      final category = artisan['craft_categories']; 
      final categoryMap = category is Map
          ? Map<String, dynamic>.from(category)
          : <String, dynamic>{};
      final categoryId = (artisan['craft_category_id'] ??
              artisan['craftCategoryId'] ??
              categoryMap['id'])
          ?.toString();
      if (categoryId != null) return _selectedIds.contains(categoryId);

      final categoryName = (artisan['category_name'] ??
              artisan['categoryName'] ??
              categoryMap['name'])
          ?.toString()
          .toLowerCase();
      return categoryName != null && selectedNames.contains(categoryName);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final city = widget.cityId;
    final visibleRecommendations = _visibleRecommendations;
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9ED),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                'assets/local shops header.png',
                width: double.infinity,
                height: 180,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 10),
            _buildCraftPreferences(),
            const SizedBox(height: 10),
            if (city == null || city.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'SELECT A CITY TO SEE LOCAL SHOPS',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.pressStart2p(
                      fontSize: 7,
                      color: _green,
                    ),
                  ),
                ),
              )
            else ...[
              if (_loading)
                const LinearProgressIndicator(
                  minHeight: 2,
                  color: _green,
                  backgroundColor: Color(0xFFE3E7D8),
                ),
              if (_categoriesError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Could not load shop categories: $_categoriesError',
                    style: GoogleFonts.vt323(
                      fontSize: 17,
                      color: _green,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'LOCAL PICKS',
                    style: GoogleFonts.pressStart2p(
                      fontSize: 7,
                      color: _green,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${visibleRecommendations.length} SHOPS',
                    style: GoogleFonts.pressStart2p(
                      fontSize: 5,
                      color: const Color(0xFF52756A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_loadingRecommendations)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(color: _green),
                  ),
                )
              else if (_recommendationsError != null)
                _buildStatusMessage(
                  'Could not load local shops.',
                  retry: _loadArtisans,
                )
              else if (visibleRecommendations.isEmpty)
                _buildStatusMessage(
                  _selectedIds.isEmpty
                      ? 'No local shops found yet.'
                      : 'No shops found for the selected crafts.',
                )
              else
                ...visibleRecommendations.map((row) => _artisanTile(row)),
              const SizedBox(height: 10),
              _buildSupportBanner(),
            ],
          ],
        ),
      ),
    );
  }

  String? _categoryImagePath(String name) {
    final normalized = name.toLowerCase();
    if (normalized.contains('chikan')) return 'assets/lucknow chikan craft.png';
    if (normalized.contains('zardozi')) {
      return normalized.contains('banaras') || normalized.contains('varanasi')
          ? 'assets/banaras zardozi.png'
          : 'assets/lucknow zardozi.png';
    }
    if (normalized.contains('batik')) return 'assets/hand batik.png';
    if (normalized.contains('jewell')) return 'assets/others jewellery.png';
    if (normalized.contains('block') || normalized.contains('print')) {
      return 'assets/banarasi hand block print.png';
    }
    if (normalized.contains('glass') || normalized.contains('bead')) {
      return 'assets/varanasi glass beads.png';
    }
    return null;
  }

  Widget? _categoryAvatar(String name) {
    final imagePath = _categoryImagePath(name);
    if (imagePath == null) return null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.asset(
        imagePath,
        width: 24,
        height: 24,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildStatusMessage(String message, {VoidCallback? retry}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.vt323(fontSize: 19, color: _green),
          ),
          if (retry != null) ...[
            const SizedBox(height: 8),
            IconButton(
              onPressed: retry,
              tooltip: 'Retry loading shops',
              icon: const Icon(Icons.refresh),
              color: _green,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCraftPreferences() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CRAFT PREFERENCES',
          style: GoogleFonts.pressStart2p(fontSize: 6, color: _green),
        ),
        const SizedBox(height: 8),
        if (_categories.isEmpty)
          Text(
            _loading
                ? 'Loading craft categories...'
                : 'Shop categories are not available right now.',
            style: GoogleFonts.vt323(fontSize: 17, color: _green),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 2,
            children: _categories.map((row) {
              final category = Map<String, dynamic>.from(row as Map);
              final id = category['id']?.toString();
              if (id == null) return const SizedBox.shrink();
              final name = (category['name'] ?? 'Craft').toString();
              return FilterChip(
                selected: _selectedIds.contains(id),
                avatar: _categoryAvatar(name),
                label: Text(
                  name,
                  style: GoogleFonts.vt323(fontSize: 16, color: _green),
                ),
                selectedColor: _yellow,
                onSelected:
                    _savingPreferences ? null : (_) => _toggleCategory(id),
              );
            }).toList(),
          ),
        if (_savingPreferences) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(color: _green),
        ],
        if (_preferenceSaveError != null)
          Row(
            children: [
              Expanded(
                child: Text(
                  'Could not save preferences: $_preferenceSaveError',
                  style: GoogleFonts.vt323(fontSize: 16, color: _green),
                ),
              ),
              TextButton(
                onPressed: _savingPreferences ? null : _savePreferences,
                child: Text(
                  'RETRY',
                  style: GoogleFonts.pressStart2p(fontSize: 5),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildSupportBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F1E5),
        border: Border.all(color: const Color(0xFF9BB5A0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.storefront, color: _green, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'SUPPORT LOCAL, COLLECT MORE!',
              style: GoogleFonts.pressStart2p(fontSize: 5, color: _green),
            ),
          ),
          const Icon(Icons.spa, color: Color(0xFF62815D), size: 18),
        ],
      ),
    );
  }

  Widget _artisanTile(Object raw) {
    final artisan = Map<String, dynamic>.from(raw as Map);
    final category = artisan['craft_categories']; 
    final categoryMap = category is Map
        ? Map<String, dynamic>.from(category)
        : <String, dynamic>{};
    final categoryName =
        (artisan['category_name'] ?? categoryMap['name'])?.toString();
    final name = (artisan['shop_name'] ??
            artisan['store_name'] ??
            artisan['name'] ??
            'Local shop')
        .toString();
    final cityName = (artisan['city_name'] ??
            (artisan['city'] is Map ? artisan['city']['name'] : null))
        ?.toString();
    final address = artisan['address']?.toString();
    final offer = (artisan['offer'] ??
            artisan['offer_text'] ??
            artisan['discount'] ??
            artisan['promotion'])
        ?.toString();
    final rating = (artisan['rating'] ?? artisan['average_rating'])?.toString();
    final reviewCount =
        (artisan['review_count'] ?? artisan['reviews_count'])?.toString();
    final distance = _artisanDistance(artisan);
    final imageUrl = (artisan['image_url'] ??
            artisan['imageUrl'] ??
            artisan['photo_url'] ??
            artisan['cover_image'] ??
            artisan['logo_url'])
        ?.toString();
    final categoryImagePath =
        categoryName == null ? null : _categoryImagePath(categoryName);

    Widget fallbackImage() => const Center(
          child: Icon(Icons.storefront, size: 28, color: Color(0xFF52756A)),
        );

    final profileImage = categoryImagePath != null
        ? Image.asset(
            categoryImagePath,
            width: 64,
            height: 64,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallbackImage(),
          )
        : imageUrl == null || imageUrl.isEmpty
            ? fallbackImage()
            : imageUrl.startsWith('assets/')
                ? Image.asset(
                    imageUrl,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => fallbackImage(),
                  )
                : Image.network(
                    imageUrl,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => fallbackImage(),
                  );

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEF7),
        border: Border.all(color: const Color(0xFFD3DCCB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFE3EEE0),
            ),
            clipBehavior: Clip.antiAlias,
            child: profileImage,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.vt323(
                          fontSize: 20,
                          color: _green,
                          height: 1,
                        ),
                      ),
                    ),
                    if (offer != null && offer.trim().isNotEmpty) ...[
                      const SizedBox(width: 5),
                      Container(
                        constraints: const BoxConstraints(maxWidth: 76),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4DF83),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          offer,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.vt323(
                            fontSize: 15,
                            color: _green,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [categoryName, cityName].whereType<String>().join(' | '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.vt323(
                    fontSize: 15,
                    color: const Color(0xFF52756A),
                  ),
                ),
                if (address != null && address.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.vt323(
                      fontSize: 15,
                      color: const Color(0xFF54605A),
                    ),
                  ),
                ],
                if (rating != null ||
                    reviewCount != null ||
                    distance != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (rating != null) ...[
                        const Icon(Icons.star,
                            size: 13, color: Color(0xFFE2A826)),
                        const SizedBox(width: 3),
                        Text(
                          rating,
                          style: GoogleFonts.vt323(
                            fontSize: 15,
                            color: const Color(0xFF303B34),
                          ),
                        ),
                      ],
                      if (reviewCount != null)
                        Text(
                          ' ($reviewCount)',
                          style: GoogleFonts.vt323(
                            fontSize: 15,
                            color: const Color(0xFF56645B),
                          ),
                        ),
                      if (distance != null) ...[
                        const Spacer(),
                        const Icon(
                          Icons.location_on,
                          size: 14,
                          color: Color(0xFF1B796D),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          distance,
                          style: GoogleFonts.vt323(
                            fontSize: 15,
                            color: const Color(0xFF303B34),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _artisanDistance(Map<String, dynamic> artisan) {
    final distance = artisan['distance_m'] ??
        artisan['distance_meters'] ??
        artisan['distance'] ??
        artisan['distance_km'];
    if (distance is num) {
      if (artisan.containsKey('distance_km')) {
        return '${distance.toStringAsFixed(1)} km';
      }
      if (distance >= 1000) return '${(distance / 1000).toStringAsFixed(1)} km';
      return '${distance.round()} m';
    }
    return distance?.toString();
  }
}
