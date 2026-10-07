import 'package:flutter/material.dart';

import '../api_service.dart';
import 'avatardata.dart';

class AvatarScreen extends StatefulWidget {
  const AvatarScreen({super.key});

  @override
  State<AvatarScreen> createState() => _AvatarScreenState();
}

class _AvatarScreenState extends State<AvatarScreen> {
  List<OutfitItem> _outfits = [];
  List<OutfitItem> _hairstyles = [];
  List<OutfitItem> _hats = [];

  String? _equippedOutfit;
  String? _equippedHair;
  String? _equippedHat;
  String? _equippedOutfitId;
  String? _equippedHairId;
  String? _equippedHatId;
  int _coins = 0;
  bool _isLoadingItems = true;
  bool _isSavingEquipment = false;
  String? _loadError;

  int _outfitPage = 0;
  int _hairPage = 0;
  int _hatPage = 0;
  static const int _pageSize = 3;
  int _selectedCategory = 0;
  final TextEditingController _nameController = TextEditingController(
    text: 'Riya',
  );
  final TextEditingController _descriptionController = TextEditingController(
    text:
        'A curious soul with a love for history, hidden gems and good chai. I\'ll be your guide as you explore India!',
  );

  @override
  void initState() {
    super.initState();
    _equippedOutfit = defaultAvatar.outfit;
    _equippedHair = defaultAvatar.hair;
    _equippedHat = defaultAvatar.hat;
    _loadItems();
  }

  Future<void> _loadItems() async {
    if (mounted) {
      setState(() {
        _isLoadingItems = true;
        _loadError = null;
      });
    }
    try {
      final results = await Future.wait([
        ApiService.getAvatarItems(),
        ApiService.getMyAvatar(),
      ]);
      final rawItems = results[0] as List<Map<String, dynamic>>;
      final avatar = results[1] as Map<String, dynamic>;
      final equipped = avatar['equipped'];
      if (equipped is! Map) {
        throw const FormatException('Avatar response has no equipped items.');
      }
      final equippedItems = Map<String, dynamic>.from(equipped);
      final rawOwnedIds = avatar['ownedItemIds'];
      final ownedIds = (rawOwnedIds is List ? rawOwnedIds : const [])
          .map((id) => id.toString())
          .toSet();
      for (final slot in ['outfit', 'hair', 'hat']) {
        final equippedId = _equippedId(equippedItems, slot);
        if (equippedId != null) ownedIds.add(equippedId);
      }

      final items = rawItems.map((raw) {
        final id = raw['id']?.toString();
        final slot = _normalizeSlot(raw['slot'] ?? raw['category']);
        if (id == null || slot == null) {
          throw const FormatException(
            'Avatar catalog item is missing its id or slot.',
          );
        }
        final imagePath = _resolveItemImagePath(raw, slot, id);
        final price = raw['coin_cost'] ??
            raw['coinCost'] ??
            raw['price'] ??
            raw['cost'] ??
            0;
        return OutfitItem(
          id: id,
          name: raw['name']?.toString() ??
              raw['item_name']?.toString() ??
              '${slot[0].toUpperCase()}${slot.substring(1)}',
          imagePath: imagePath,
          coinCost: price is num
              ? price.toInt()
              : int.tryParse(price.toString()) ?? 0,
          category: slot,
          isOwned: ownedIds.contains(id) ||
              raw['owned'] == true ||
              raw['isOwned'] == true,
        );
      }).toList();

      final outfitId = _equippedId(equippedItems, 'outfit');
      final hairId = _equippedId(equippedItems, 'hair');
      final hatId = _equippedId(equippedItems, 'hat');
      String? imageFor(String slot, String? id) {
        if (id == null) return null;
        for (final item in items) {
          if (item.id == id) return item.imagePath;
        }
        return _resolveItemImagePath(const {}, slot, id);
      }

      final coins = avatar['coins'];
      if (mounted) {
        setState(() {
          _outfits = items.where((item) => item.category == 'outfit').toList();
          _hairstyles = items.where((item) => item.category == 'hair').toList();
          _hats = items.where((item) => item.category == 'hat').toList();
          _equippedOutfitId = outfitId;
          _equippedHairId = hairId;
          _equippedHatId = hatId;
          _equippedOutfit = imageFor('outfit', outfitId);
          _equippedHair = imageFor('hair', hairId);
          _equippedHat = imageFor('hat', hatId);
          _coins = coins is num
              ? coins.toInt()
              : int.tryParse(coins?.toString() ?? '') ?? 0;
          _isLoadingItems = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loadError = error.toString().replaceFirst('Exception: ', '');
          _isLoadingItems = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String? _normalizeSlot(Object? rawSlot) {
    final slot = rawSlot?.toString().toLowerCase().trim();
    return switch (slot) {
      'outfit' => 'outfit',
      'hair' || 'hairstyle' => 'hair',
      'hat' || 'headwear' => 'hat',
      _ => null,
    };
  }

  String? _equippedId(Map<String, dynamic> equipped, String slot) {
    final id = equipped[slot]?.toString();
    return id == null || id.isEmpty || id == 'null' ? null : id;
  }

  String _resolveItemImagePath(
    Map<String, dynamic> item,
    String slot,
    String id,
  ) {
    final path = item['image_path']?.toString().trim();
    if (path != null && path.isNotEmpty) {
      if (path.startsWith('assets/') ||
          path.startsWith('http://') ||
          path.startsWith('https://')) {
        return path;
      }
      return '${ApiService.baseUrl}/${path.replaceFirst(RegExp(r'^/+'), '')}';
    }
    final match = RegExp(r'(\d+)$').firstMatch(id);
    final number = match == null ? null : int.tryParse(match.group(1)!);
    if (number != null && number > 0) {
      return 'assets/avatar pieces/$slot $number.webp';
    }
    throw FormatException('Avatar item $id has no image path.');
  }

  Future<void> _equip(OutfitItem item) async {
    if (!item.isOwned || _isSavingEquipment) return;
    final oldOutfit = _equippedOutfit;
    final oldHair = _equippedHair;
    final oldHat = _equippedHat;
    final oldOutfitId = _equippedOutfitId;
    final oldHairId = _equippedHairId;
    final oldHatId = _equippedHatId;
    setState(() {
      switch (item.category) {
        case 'outfit':
          _equippedOutfit = item.imagePath;
          _equippedOutfitId = item.id;
        case 'hair':
          _equippedHair = item.imagePath;
          _equippedHairId = item.id;
        case 'hat':
          _equippedHat = item.imagePath;
          _equippedHatId = item.id;
      }
      _isSavingEquipment = true;
    });
    try {
      await ApiService.equipAvatarItems(
        hair: _equippedHairId,
        outfit: _equippedOutfitId,
        hat: _equippedHatId,
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _equippedOutfit = oldOutfit;
          _equippedHair = oldHair;
          _equippedHat = oldHat;
          _equippedOutfitId = oldOutfitId;
          _equippedHairId = oldHairId;
          _equippedHatId = oldHatId;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not equip item: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingEquipment = false);
    }
  }

  Future<void> _onItemTap(OutfitItem item) async {
    if (item.isOwned) {
      await _equip(item);
      return;
    }
    if (_isSavingEquipment) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Buy this item?'),
        content: Text('${item.name} — ${item.coinCost} coins'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Buy'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isSavingEquipment = true);
    try {
      await ApiService.purchaseAvatarItem(item.id);
      await _loadItems();
      if (mounted && _loadError == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item purchased!')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingEquipment = false);
    }
  }

  Future<void> _removeEquippedSlot(String slot) async {
    if (_isSavingEquipment) return;
    final oldOutfit = _equippedOutfit;
    final oldHair = _equippedHair;
    final oldHat = _equippedHat;
    final oldOutfitId = _equippedOutfitId;
    final oldHairId = _equippedHairId;
    final oldHatId = _equippedHatId;
    setState(() {
      switch (slot) {
        case 'hair':
          _equippedHair = null;
          _equippedHairId = null;
        case 'hat':
          _equippedHat = null;
          _equippedHatId = null;
      }
      _isSavingEquipment = true;
    });
    try {
      await ApiService.equipAvatarItems(
        hair: _equippedHairId,
        outfit: _equippedOutfitId,
        hat: _equippedHatId,
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _equippedOutfit = oldOutfit;
          _equippedHair = oldHair;
          _equippedHat = oldHat;
          _equippedOutfitId = oldOutfitId;
          _equippedHairId = oldHairId;
          _equippedHatId = oldHatId;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update avatar: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingEquipment = false);
    }
  }

  void _cycleSelectedCategory(int amount) {
    final items = switch (_selectedCategory) {
      0 => _outfits,
      1 => _hairstyles,
      _ => _hats,
    };
    final equippedPath = switch (_selectedCategory) {
      0 => _equippedOutfit,
      1 => _equippedHair,
      _ => _equippedHat,
    };
    if (items.isEmpty) return;

    final currentIndex = items.indexWhere(
      (item) => item.imagePath == equippedPath,
    );
    final nextIndex = currentIndex == -1
        ? (amount > 0 ? 0 : items.length - 1)
        : (currentIndex + amount + items.length) % items.length;
    _equip(items[nextIndex]);
  }

  Future<void> _resetAvatar() async {
    if (_isSavingEquipment) return;
    final defaultOutfit = _findDefaultItem(_outfits, defaultAvatar.outfit);
    final defaultHair = _findDefaultItem(_hairstyles, defaultAvatar.hair);
    final defaultHat = _findDefaultItem(_hats, defaultAvatar.hat);
    if (defaultOutfit == null || defaultHair == null || defaultHat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Default avatar items are unavailable.')),
      );
      return;
    }
    final oldOutfit = _equippedOutfit;
    final oldHair = _equippedHair;
    final oldHat = _equippedHat;
    final oldOutfitId = _equippedOutfitId;
    final oldHairId = _equippedHairId;
    final oldHatId = _equippedHatId;
    setState(() {
      _equippedOutfit = defaultOutfit.imagePath;
      _equippedHair = defaultHair.imagePath;
      _equippedHat = defaultHat.imagePath;
      _equippedOutfitId = defaultOutfit.id;
      _equippedHairId = defaultHair.id;
      _equippedHatId = defaultHat.id;
      _outfitPage = 0;
      _hairPage = 0;
      _hatPage = 0;
      _isSavingEquipment = true;
    });
    try {
      await ApiService.equipAvatarItems(
        hair: _equippedHairId,
        outfit: _equippedOutfitId,
        hat: _equippedHatId,
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _equippedOutfit = oldOutfit;
          _equippedHair = oldHair;
          _equippedHat = oldHat;
          _equippedOutfitId = oldOutfitId;
          _equippedHairId = oldHairId;
          _equippedHatId = oldHatId;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not reset avatar: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingEquipment = false);
    }
  }

  OutfitItem? _findDefaultItem(List<OutfitItem> items, String defaultPath) {
    final fileName = defaultPath.split('/').last;
    for (final item in items) {
      if (item.imagePath.split('/').last == fileName && item.isOwned) {
        return item;
      }
    }
    return null;
  }

  Widget _avatarImage(String path, {required BoxFit fit}) {
    final uri = Uri.tryParse(path);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return Image.network(
        path,
        fit: fit,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.broken_image_outlined, color: Color(0xFF07566A)),
      );
    }
    return Image.asset(
      path,
      fit: fit,
      errorBuilder: (_, __, ___) =>
          const Icon(Icons.broken_image_outlined, color: Color(0xFF07566A)),
    );
  }

  Future<void> _saveCurrentEquipment() async {
    if (_isSavingEquipment) return;
    setState(() => _isSavingEquipment = true);
    try {
      await ApiService.equipAvatarItems(
        hair: _equippedHairId,
        outfit: _equippedOutfitId,
        hat: _equippedHatId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avatar changes saved.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save avatar: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingEquipment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFFFF9E9);
    const accent = Color(0xFF07566A);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        toolbarHeight: 58,
        leadingWidth: 48,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back, color: accent),
        ),
        title: const Text(
          'Guide Customization',
          style: TextStyle(
            color: accent,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
            fontSize: 19,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Row(
              children: [
                Image.asset('assets/coin.png', width: 20, height: 20),
                const SizedBox(width: 3),
                Text(
                  '$_coins',
                  style: const TextStyle(
                    color: accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Reset avatar',
            onPressed: _resetAvatar,
            icon: const Icon(Icons.refresh, color: accent),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () {},
            icon: const Icon(Icons.settings, color: accent),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 5, child: _buildPreviewPanel(accent)),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 6,
                        child: _buildCustomizationPanel(accent),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewPanel(Color accent) {
    final selectedCategoryName = switch (_selectedCategory) {
      0 => 'outfit',
      1 => 'hairstyle',
      _ => 'hat',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              alignment: Alignment.center,
              children: [
                const Positioned.fill(
                  child: Image(
                    image: AssetImage('assets/avatar background.png'),
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 8,
                  right: 8,
                  child: Text(
                    'Your travel companion',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      shadows: [
                        Shadow(
                          color: Colors.white.withValues(alpha: 0.8),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: const Alignment(0, 1.05),
                  child: Transform.scale(
                    scale: 1.12,
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: 470,
                      height: 470,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_equippedOutfit != null)
                            _avatarImage(_equippedOutfit!, fit: BoxFit.contain),
                          if (_equippedHair != null)
                            _avatarImage(_equippedHair!, fit: BoxFit.contain),
                          if (_equippedHat != null)
                            _avatarImage(_equippedHat!, fit: BoxFit.contain),
                        ],
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: const Alignment(-1, 0),
                  child: _roundArrow(
                    Icons.chevron_left,
                    accent,
                    () => _cycleSelectedCategory(-1),
                    'Previous $selectedCategoryName',
                  ),
                ),
                Align(
                  alignment: const Alignment(1, 0),
                  child: _roundArrow(
                    Icons.chevron_right,
                    accent,
                    () => _cycleSelectedCategory(1),
                    'Next $selectedCategoryName',
                  ),
                ),
                const Positioned(
                  left: 8,
                  bottom: 8,
                  child: Icon(Icons.eco, size: 24, color: Color(0xFF16856D)),
                ),
                const Positioned(
                  right: 8,
                  bottom: 8,
                  child: Icon(Icons.eco, size: 24, color: Color(0xFF16856D)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 7),
        _bioCard(accent),
      ],
    );
  }

  Widget _roundArrow(
    IconData icon,
    Color accent,
    VoidCallback onTap,
    String tooltip,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
        color: const Color(0xFFFFF4C5),
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: tooltip,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 34, height: 34),
          icon: Icon(icon, color: accent),
          onPressed: onTap,
        ),
      ),
    );
  }

  Widget _bioCard(Color accent) {
    return Container(
      padding: const EdgeInsets.all(9),
      constraints: const BoxConstraints(minHeight: 118),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDABF7B), width: 1.4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFF5D65E),
            child: Icon(Icons.person, color: accent, size: 26),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        maxLines: 1,
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                        decoration: const InputDecoration.collapsed(
                          hintText: 'Name',
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.edit, color: accent, size: 13),
                  ],
                ),
                const SizedBox(height: 3),
                TextField(
                  controller: _descriptionController,
                  minLines: 1,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(
                    fontSize: 9.5,
                    height: 1.22,
                    color: Color(0xFF23454B),
                  ),
                  decoration: const InputDecoration.collapsed(
                    hintText: 'Add a description',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomizationPanel(Color accent) {
    if (_isLoadingItems) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF07566A)),
      );
    }
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Could not load avatar items:\n$_loadError',
              textAlign: TextAlign.center,
              style: TextStyle(color: accent, fontSize: 12),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _loadItems,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        _categoryTabs(accent),
        const SizedBox(height: 6),
        // Scrollable so this panel never overflows on shorter screens,
        // regardless of how many category sections are stacked.
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _categorySection(
                  title: 'Outfits',
                  icon: Icons.checkroom,
                  items: _outfits,
                  page: _outfitPage,
                  accent: accent,
                  onPrev: () => setState(
                    () => _outfitPage = (_outfitPage - 1).clamp(
                      0,
                      _maxPage(_outfits),
                    ),
                  ),
                  onNext: () => setState(
                    () => _outfitPage = (_outfitPage + 1).clamp(
                      0,
                      _maxPage(_outfits),
                    ),
                  ),
                  equippedPath: _equippedOutfit,
                ),
                const SizedBox(height: 6),
                _categorySection(
                  title: 'Hairstyles',
                  icon: Icons.face_retouching_natural,
                  items: _hairstyles,
                  page: _hairPage,
                  accent: accent,
                  onPrev: () => setState(
                    () => _hairPage = (_hairPage - 1).clamp(
                      0,
                      _maxPage(_hairstyles),
                    ),
                  ),
                  onNext: () => setState(
                    () => _hairPage = (_hairPage + 1).clamp(
                      0,
                      _maxPage(_hairstyles),
                    ),
                  ),
                  equippedPath: _equippedHair,
                  onRemove: () => _removeEquippedSlot('hair'),
                  removeTooltip: 'Remove hair',
                ),
                const SizedBox(height: 6),
                _categorySection(
                  title: 'Hats & Headwear',
                  icon: Icons.sports_motorsports,
                  items: _hats,
                  page: _hatPage,
                  accent: accent,
                  onPrev: () => setState(
                    () => _hatPage = (_hatPage - 1).clamp(0, _maxPage(_hats)),
                  ),
                  onNext: () => setState(
                    () => _hatPage = (_hatPage + 1).clamp(0, _maxPage(_hats)),
                  ),
                  equippedPath: _equippedHat,
                  onRemove: () => _removeEquippedSlot('hat'),
                  removeTooltip: 'Remove hat',
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 46,
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF5D34D),
                      foregroundColor: accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(
                          color: Color(0xFFD0A83F),
                          width: 1.5,
                        ),
                      ),
                      elevation: 0,
                    ),
                    onPressed:
                        _isSavingEquipment ? null : _saveCurrentEquipment,
                    icon: const Icon(Icons.auto_awesome, size: 19),
                    label: const Text(
                      'Save Changes',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Fixed height now instead of Expanded, since this sits
                // inside a SingleChildScrollView and can't use Expanded.
                SizedBox(
                  height: 60,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                    child: Image.asset(
                      'assets/filler image.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _categoryTabs(Color accent) {
    const tabs = [
      (Icons.checkroom, 'Outfits'),
      (Icons.face_retouching_natural, 'Hair'),
      (Icons.sports_motorsports, 'Hats'),
    ];
    return SizedBox(
      height: 58,
      child: Row(
        children: List.generate(tabs.length, (index) {
          final selected = _selectedCategory == index;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Material(
                color: selected
                    ? const Color(0xFFF5D34D)
                    : const Color(0xFFE5F4EE),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _selectedCategory = index),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: selected
                            ? const Color(0xFFD0A83F)
                            : const Color(0xFF9ACFC3),
                        width: selected ? 1.6 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 2,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(tabs[index].$1, color: accent, size: 21),
                        const SizedBox(height: 1),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            tabs[index].$2,
                            style: TextStyle(
                              color: accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  int _maxPage(List<OutfitItem> items) =>
      items.isEmpty ? 0 : ((items.length - 1) ~/ _pageSize);

  Widget _categorySection({
    required String title,
    required IconData icon,
    required List<OutfitItem> items,
    required int page,
    required Color accent,
    required VoidCallback onPrev,
    required VoidCallback onNext,
    required String? equippedPath,
    VoidCallback? onRemove,
    String? removeTooltip,
  }) {
    final start = page * _pageSize;
    final end = (start + _pageSize).clamp(0, items.length);
    final visible = items.isEmpty ? <OutfitItem>[] : items.sublist(start, end);
    final totalPages = _maxPage(items) + 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E8),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFD8C28D), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 17),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              if (onRemove != null)
                IconButton(
                  tooltip: removeTooltip,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 24,
                    height: 26,
                  ),
                  icon: Icon(
                    Icons.remove_circle_outline,
                    color: equippedPath == null ? Colors.grey.shade400 : accent,
                    size: 17,
                  ),
                  onPressed: equippedPath == null ? null : onRemove,
                ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 23,
                  height: 26,
                ),
                icon: Icon(Icons.chevron_left, color: accent, size: 20),
                onPressed: page > 0 ? onPrev : null,
              ),
              // Fixed-width counter wrapped in FittedBox so longer
              // page-count strings (e.g. "10-12/37") shrink to fit
              // instead of overflowing the row on the right edge.
              SizedBox(
                width: 36,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${items.isEmpty ? 0 : start + 1}-$end/${items.length}',
                    style: TextStyle(
                      color: accent,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 23,
                  height: 26,
                ),
                icon: Icon(Icons.chevron_right, color: accent, size: 20),
                onPressed: page < _maxPage(items) ? onNext : null,
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Thumbnail row height reduced from 60 -> 48 to reclaim
          // vertical space and shrink the images as requested.
          SizedBox(
            height: 48,
            child: items.isEmpty
                ? const Center(child: Text('No items yet'))
                : Row(
                    children: visible.map((item) {
                      final isEquipped = item.imagePath == equippedPath;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => _onItemTap(item),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFFDF5),
                                    border: Border.all(
                                      color: isEquipped
                                          ? const Color(0xFFF0C52D)
                                          : const Color(0xFFD8D5C8),
                                      width: isEquipped ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(3),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: SizedBox.expand(
                                        child: _avatarImage(
                                          item.imagePath,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (isEquipped)
                                  const Positioned(
                                    top: 1,
                                    right: 1,
                                    child: Icon(
                                      Icons.check_circle,
                                      size: 15,
                                      color: Color(0xFF0B796E),
                                    ),
                                  ),
                                if (!item.isOwned)
                                  Positioned(
                                    bottom: 1,
                                    left: 1,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 3,
                                        vertical: 1,
                                      ),
                                      color: Colors.black54,
                                      child: Text(
                                        '${item.coinCost}c',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(totalPages, (i) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == page
                      ? const Color(0xFFF0BD19)
                      : const Color(0xFF9DD8CC),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}