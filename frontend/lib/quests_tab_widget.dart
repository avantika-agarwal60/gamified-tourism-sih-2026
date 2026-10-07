import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'api_service.dart';

class QuestsListScreen extends StatefulWidget {
  final String? cityId;
  final int completionRefreshVersion;
  final ValueChanged<String>? onCityChanged;
  final Function(String questId, String cityId)? onQuestSelected;
  final VoidCallback? onLogout;

  const QuestsListScreen({
    super.key,
    this.cityId,
    this.completionRefreshVersion = 0,
    this.onCityChanged,
    this.onQuestSelected,
    this.onLogout,
  });

  @override
  State<QuestsListScreen> createState() => _QuestsListScreenState();
}

class _QuestsListScreenState extends State<QuestsListScreen> {
  // Original Palette Constants
  static const Color creamBg = Color(0xFFF4F1EA);
  static const Color oceanBlue = Color(0xFF1684A7);
  static const Color tealGreen = Color(0xFF0EA391);
  static const Color cardBorderColor = Color(0xFF1684A7);
  static const Map<String, String> _questImageAssets = {
    'avantika ka ghar': 'assets/avantika ka ghar.png',
    'bara imambara': 'assets/bara imambara.png',
    'british residency': 'assets/British residency.png',
    'chattar manzil': 'assets/chattar manzil.png',
    'chintu': 'assets/chintu.png',
    'chota imambara': 'assets/chota imambara.png',
    'dilkusha kothi': 'assets/dilkusha kothi.png',
    'rumi darwaza': 'assets/rumi darwaza.png',
    'it college': 'assets/it college.png'
  };

  List<dynamic> _quests = [];
  List<Map<String, dynamic>> _cities = [];
  List<dynamic> _allQuests = [];
  Set<String> _completedQuestIds = {};
  bool _loadingCompletedStatus = true;
  bool _completedStatusFailed = false;
  String? _selectedCityId;
  String? _selectedQuestId;
  String _questFilter = 'all';
  bool _isLoading = true;
  bool _isDetectingCity = false;
  int _coins = 0;
  bool _isLoadingCoins = true;

  String? _questImageAssetFor(String questName) {
    final normalizedName =
        questName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
    return _questImageAssets[normalizedName];
  }

  Color _questColorForXp(int xp) {
    switch (xp) {
      case 150:
        return const Color(0xFF7F9B78);
      case 200:
        return const Color(0xFF527FA3);
      case 250:
        return const Color(0xFFD6A441);
      default:
        return const Color(0xFFF8F5F0);
    }
  }

  Color _questTextColorForXp(int xp) =>
      xp == 200 ? Colors.white : const Color(0xFF1F2D2A);

  Future<void> _logout() async {
    await ApiService.logout();
    if (mounted) widget.onLogout?.call();
  }

  @override
  void initState() {
    super.initState();
    _selectedCityId = widget.cityId;
    _loadCityQuests(detectLocation: widget.cityId == null);
    _loadCoins();
  }

  @override
  void didUpdateWidget(covariant QuestsListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.completionRefreshVersion != widget.completionRefreshVersion) {
      _loadCityQuests();
      _loadCoins();
      return;
    }
    if (oldWidget.cityId != widget.cityId && widget.cityId != _selectedCityId) {
      setState(() {
        _selectedCityId = widget.cityId;
        _quests = _questsForCity(widget.cityId);
      });
    }
  }

  Future<void> _loadCoins() async {
    try {
      final avatar = await ApiService.getMyAvatar();
      final coins = avatar['coins'];
      if (mounted) {
        setState(() {
          _coins = coins is num
              ? coins.toInt()
              : int.tryParse(coins?.toString() ?? '') ?? 0;
          _isLoadingCoins = false;
        });
      }
    } catch (error) {
      debugPrint('Error loading coins: $error');
      if (mounted) {
        setState(() => _isLoadingCoins = false);
      }
    }
  }

  Future<void> _loadCityQuests({bool detectLocation = false}) async {
    _loadCompletedQuestStatus();
    setState(() {
      _isLoading = true;
      _isDetectingCity = detectLocation;
    });
    try {
      final results = await Future.wait([
        ApiService.getCities(),
        ApiService.getQuests(),
      ]);
      final cities = results[0]
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      final quests = results[1];
      var cityId = _selectedCityId ?? widget.cityId;
      if (detectLocation || cityId == null) {
        cityId = await _nearestSupportedCity(cities, quests);
      }
      if (mounted) {
        setState(() {
          _cities = cities;
          _allQuests = quests;
          _selectedCityId = cityId;
          _quests = _questsForCity(cityId);
          _isLoading = false;
          _isDetectingCity = false;
        });
        if (cityId != null) widget.onCityChanged?.call(cityId);
      }
    } catch (e) {
      debugPrint('Error loading quests: $e');
      if (mounted) {
        setState(() {
          _quests = [];
          _isLoading = false;
          _isDetectingCity = false;
        });
      }
    }
  }

  Future<void> _loadCompletedQuestStatus() async {
    if (mounted) {
      setState(() {
        _loadingCompletedStatus = true;
        _completedStatusFailed = false;
      });
    }
    try {
      Set<String> completedQuestIds;
      try {
        final completedRows = await ApiService.getCompletedQuests()
            .timeout(const Duration(seconds: 8));
        completedQuestIds = _completedIdsFrom(completedRows);
        if (completedRows.isNotEmpty && completedQuestIds.isEmpty) {
          throw const FormatException(
            'Completed quest response did not contain quest IDs.',
          );
        }
      } catch (endpointError) {
        debugPrint(
          'Completed-quests route failed; falling back to journal data: '
          '$endpointError',
        );
        final journal =
            await ApiService.getJournal().timeout(const Duration(seconds: 8));
        final completedRows = journal['completedQuests'];
        if (completedRows is! List) {
          throw const FormatException(
            'Journal response did not contain completedQuests.',
          );
        }
        completedQuestIds = _completedIdsFrom(completedRows);
      }
      if (!mounted) return;
      setState(() {
        _completedQuestIds = completedQuestIds;
        _loadingCompletedStatus = false;
        _completedStatusFailed = false;
      });
    } catch (error) {
      debugPrint('Could not load completed quest status: $error');
      if (!mounted) return;
      setState(() {
        _loadingCompletedStatus = false;
        _completedStatusFailed = true;
      });
    }
  }

  Set<String> _completedIdsFrom(List<dynamic> rows) => rows
      .map((row) {
        if (row is String) return row;
        if (row is! Map) return null;
        final quest = row['quests'] is Map ? row['quests'] as Map : null;
        return (row['quest_id'] ?? row['questId'] ?? quest?['id'] ?? row['id'])
            ?.toString();
      })
      .whereType<String>()
      .toSet();

  Future<String?> _nearestSupportedCity(
    List<Map<String, dynamic>> cities,
    List<dynamic> quests,
  ) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      String? nearestCityId;
      var nearestDistance = double.infinity;

      for (final city in cities) {
        final cityId = city['id']?.toString();
        if (cityId == null) continue;
        final locations = quests
            .map((row) => Map<String, dynamic>.from(row as Map))
            .where((quest) =>
                quest['city_id']?.toString() == cityId &&
                quest['lat'] is num &&
                quest['lng'] is num)
            .toList();
        if (locations.isEmpty) continue;

        final latitude = locations
                .map((quest) => (quest['lat'] as num).toDouble())
                .reduce((sum, value) => sum + value) /
            locations.length;
        final longitude = locations
                .map((quest) => (quest['lng'] as num).toDouble())
                .reduce((sum, value) => sum + value) /
            locations.length;
        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          latitude,
          longitude,
        );
        if (distance < nearestDistance) {
          nearestDistance = distance;
          nearestCityId = cityId;
        }
      }
      return nearestCityId;
    } catch (error) {
      debugPrint('Could not detect city from location: $error');
      return null;
    }
  }

  List<dynamic> _questsForCity(String? cityId) {
    if (cityId == null) return [];
    return _allQuests.where((row) {
      final quest = row as Map;
      return quest['city_id']?.toString() == cityId;
    }).toList();
  }

  void _selectCity(String? cityId) {
    setState(() {
      _selectedCityId = cityId;
      _selectedQuestId = null;
      _quests = _questsForCity(cityId);
    });
    if (cityId != null) widget.onCityChanged?.call(cityId);
  }

  List<dynamic> _filteredQuests() {
    final current = _quests.where((quest) {
      final questId = quest['id']?.toString();
      final isCompleted =
          questId != null && _completedQuestIds.contains(questId);

      switch (_questFilter) {
        case 'completed':
          return isCompleted;
        case 'available':
          return !isCompleted;
        case 'all':
        default:
          return true;
      }
    }).toList();

    if (_selectedQuestId == null) return current;

    current.sort((a, b) {
      final aId = a['id']?.toString();
      final bId = b['id']?.toString();
      if (aId == _selectedQuestId) return -1;
      if (bId == _selectedQuestId) return 1;
      return 0;
    });

    return current;
  }

  Map<String, int> _cityLevelProgress() {
    if (_selectedCityId == null) {
      return {'level': 1, 'currentXp': 0, 'threshold': 500};
    }

    var totalXp = 0;
    for (final quest in _allQuests) {
      final questMap = quest as Map;
      final cityId = questMap['city_id']?.toString();
      final questId = questMap['id']?.toString();
      if (cityId != _selectedCityId || questId == null) continue;
      if (!_completedQuestIds.contains(questId)) continue;

      final xpValue = questMap['xp'];
      final questXp = xpValue is num
          ? xpValue.toInt()
          : int.tryParse(xpValue?.toString() ?? '') ?? 0;
      totalXp += questXp;
    }

    final level = (totalXp ~/ 500) + 1;
    final currentXp = totalXp % 500;
    return {
      'level': level,
      'currentXp': currentXp,
      'threshold': 500,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cityProgress = _cityLevelProgress();
    final level = cityProgress['level'] ?? 1;
    final currentXp = cityProgress['currentXp'] ?? 0;
    final threshold = cityProgress['threshold'] ?? 500;
    final xpRatio =
        threshold <= 0 ? 0.0 : (currentXp / threshold).clamp(0.0, 1.0);
    final selectedCityName = _selectedCityId == null
        ? 'Select city'
        : (_cities.firstWhere(
              (city) => city['id']?.toString() == _selectedCityId,
              orElse: () => <String, dynamic>{},
            )['name'] ??
            _cities.firstWhere(
              (city) => city['id']?.toString() == _selectedCityId,
              orElse: () => <String, dynamic>{},
            )['city_name'] ??
            'City');

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9ED),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: _logout,
                        tooltip: 'Log out',
                        icon:
                            const Icon(Icons.logout, color: Color(0xFF184D55)),
                        splashRadius: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF2F7E8D),
                          border: Border.all(
                              color: const Color(0xFF164B5F), width: 2.5),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/profile picture.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 34,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'LV. $level',
                            style: GoogleFonts.pressStart2p(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1F2D2A),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/xp.png',
                                width: 14,
                                height: 14,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '$currentXp/$threshold XP',
                                maxLines: 1,
                                style: GoogleFonts.pressStart2p(
                                  fontSize: 6,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1F2D2A),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            Container(
                              height: 14,
                              decoration: BoxDecoration(
                                color: const Color(0xFFD8E7D2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF1F2D2A),
                                  width: 1,
                                ),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: xpRatio,
                              child: Container(
                                height: 14,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7EC7BA),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Image.asset(
                        'assets/coin.png',
                        width: 23,
                        height: 23,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                          Icons.toll,
                          color: Color(0xFFE7A200),
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isLoadingCoins ? '...' : '$_coins',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2D2A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset(
                        'assets/header_image_quests.png',
                        width: double.infinity,
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBFBEF),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: const Color(0xFF1F2D2A), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            color: Color(0xFF1B796D),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _cities.isEmpty
                                ? Text(
                                    'Detecting city...',
                                    style: GoogleFonts.pressStart2p(
                                      fontSize: 8,
                                      color: const Color(0xFF1F2D2A),
                                    ),
                                  )
                                : DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedCityId,
                                      isExpanded: true,
                                      icon: const Icon(Icons.arrow_drop_down,
                                          color: Color(0xFF1F2D2A)),
                                      hint: Text(
                                        selectedCityName,
                                        style: GoogleFonts.pressStart2p(
                                          fontSize: 8,
                                          color: const Color(0xFF1F2D2A),
                                        ),
                                      ),
                                      dropdownColor: const Color(0xFFF9F9ED),
                                      style: GoogleFonts.pressStart2p(
                                        fontSize: 8,
                                        color: const Color(0xFF1F2D2A),
                                      ),
                                      onChanged: (String? cityId) {
                                        if (cityId != null) {
                                          _selectCity(cityId);
                                        }
                                      },
                                      items: _cities
                                          .map((city) {
                                            final cityId =
                                                city['id']?.toString();
                                            final cityName = city['name'] ??
                                                city['city_name'] ??
                                                'City';
                                            if (cityId == null) return null;
                                            return DropdownMenuItem<String>(
                                              value: cityId,
                                              child: Text(cityName),
                                            );
                                          })
                                          .whereType<DropdownMenuItem<String>>()
                                          .toList(),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAE2D7),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: const Color(0xFF1F2D2A), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _questFilter = 'all'),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _questFilter == 'all'
                                      ? const Color(0xFF7EC7BA)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'All',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.pressStart2p(
                                    fontSize: 8,
                                    color: const Color(0xFF1F2D2A),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _questFilter = 'available'),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _questFilter == 'available'
                                      ? const Color(0xFF7EC7BA)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Available',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.pressStart2p(
                                    fontSize: 8,
                                    color: const Color(0xFF1F2D2A),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _questFilter = 'completed'),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _questFilter == 'completed'
                                      ? const Color(0xFF7EC7BA)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Completed',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.pressStart2p(
                                    fontSize: 8,
                                    color: const Color(0xFF1F2D2A),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: _isLoading
                          ? const Center(
                              child:
                                  CircularProgressIndicator(color: tealGreen),
                            )
                          : _selectedCityId == null
                              ? Center(
                                  child: Text(
                                    'ALLOW LOCATION OR SELECT A CITY',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.pressStart2p(
                                      fontSize: 8,
                                      color: oceanBlue,
                                    ),
                                  ),
                                )
                              : _quests.isEmpty
                                  ? Center(
                                      child: Text(
                                        'NO QUESTS FOUND FOR THIS CITY',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.pressStart2p(
                                          fontSize: 8,
                                          color: oceanBlue,
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: EdgeInsets.zero,
                                      itemCount: _filteredQuests().length,
                                      itemBuilder: (context, index) {
                                        final quest = _filteredQuests()[index];
                                        final name =
                                            (quest['name'] ?? 'Unknown Quest')
                                                .toString();
                                        final questImageAsset =
                                            _questImageAssetFor(name);
                                        final xpValue = quest['xp'];
                                        final xp = xpValue is num
                                            ? xpValue.toInt()
                                            : int.tryParse(
                                                    xpValue?.toString() ??
                                                        '') ??
                                                0;
                                        final questColor = _questColorForXp(xp);
                                        final questTextColor =
                                            _questTextColorForXp(xp);
                                        final description =
                                            quest['description']?.toString() ??
                                                'No description available';
                                        final questId = quest['id']?.toString();
                                        final cityId =
                                            quest['city_id']?.toString() ??
                                                'lucknow';
                                        final isCompleted = questId != null &&
                                            _completedQuestIds
                                                .contains(questId);
                                        final isActionDisabled = isCompleted ||
                                            _loadingCompletedStatus ||
                                            _completedStatusFailed;

                                        return Container(
                                          margin:
                                              const EdgeInsets.only(bottom: 10),
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: questColor,
                                            borderRadius: BorderRadius.zero,
                                            border: Border.all(
                                              color: const Color(0xFF2A6E7A),
                                              width: 2,
                                            ),
                                            boxShadow: const [
                                              BoxShadow(
                                                color: Color(0x662A6E7A),
                                                offset: Offset(3, 3),
                                                blurRadius: 0,
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 68,
                                                height: 68,
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFDBEDE5),
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  border: Border.all(
                                                    color:
                                                        const Color(0xFF2A6E7A),
                                                    width: 1.5,
                                                  ),
                                                ),
                                                child: questImageAsset == null
                                                    ? const Center(
                                                        child: Icon(
                                                          Icons.account_balance,
                                                          size: 26,
                                                          color:
                                                              Color(0xFF2A6E7A),
                                                        ),
                                                      )
                                                    : ClipRRect(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                        child: Image.asset(
                                                          questImageAsset,
                                                          fit: BoxFit.cover,
                                                          errorBuilder: (
                                                            context,
                                                            error,
                                                            stackTrace,
                                                          ) =>
                                                              const Center(
                                                            child: Icon(
                                                              Icons
                                                                  .account_balance,
                                                              size: 26,
                                                              color: Color(
                                                                  0xFF2A6E7A),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      name,
                                                      style: GoogleFonts
                                                          .pressStart2p(
                                                        fontSize: 9,
                                                        color: questTextColor,
                                                      ),
                                                      maxLines: 2,
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      description,
                                                      style: GoogleFonts
                                                          .pressStart2p(
                                                        fontSize: 7,
                                                        color: questTextColor
                                                            .withValues(
                                                                alpha: 0.9),
                                                      ),
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Row(
                                                      children: [
                                                        Image.asset(
                                                          'assets/xp.png',
                                                          width: 14,
                                                          height: 14,
                                                          fit: BoxFit.contain,
                                                          errorBuilder: (
                                                            context,
                                                            error,
                                                            stackTrace,
                                                          ) =>
                                                              const Icon(
                                                            Icons.star,
                                                            size: 12,
                                                            color: Color(
                                                                0xFFE7A200),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 4),
                                                        Text(
                                                          '+$xp XP',
                                                          style: GoogleFonts
                                                              .pressStart2p(
                                                            fontSize: 7,
                                                            color:
                                                                questTextColor,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              InkWell(
                                                onTap: isActionDisabled ||
                                                        questId == null
                                                    ? null
                                                    : () {
                                                        setState(() {
                                                          _selectedQuestId =
                                                              questId;
                                                        });
                                                        widget.onQuestSelected
                                                            ?.call(
                                                          questId,
                                                          cityId,
                                                        );
                                                      },
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 12,
                                                      vertical: 10),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFF9ED0C5),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                    border: Border.all(
                                                        color: const Color(
                                                            0xFF2A6E7A),
                                                        width: 1.5),
                                                  ),
                                                  child: Text(
                                                    isCompleted
                                                        ? 'Done'
                                                        : 'Quest',
                                                    style: GoogleFonts
                                                        .pressStart2p(
                                                      fontSize: 7,
                                                      color: const Color(
                                                          0xFF1F2D2A),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestActionButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final String label;
  final IconData icon;

  const _QuestActionButton({
    required this.onPressed,
    required this.label,
    required this.icon,
  });

  @override
  State<_QuestActionButton> createState() => _QuestActionButtonState();
}

class _QuestActionButtonState extends State<_QuestActionButton> {
  bool _pressed = false;

  void _setPressed(bool pressed) {
    if (_pressed == pressed) return;
    setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    const backgroundColor = Colors.teal;
    final foregroundColor = enabled ? Colors.white : Colors.black54;

    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTapDown: enabled
            ? (_) {
                _setPressed(true);
                HapticFeedback.selectionClick();
              }
            : null,
        onTapUp: enabled ? (_) => _setPressed(false) : null,
        onTapCancel: enabled ? () => _setPressed(false) : null,
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(0, _pressed ? 2 : 0, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: enabled ? const Color(0xFF087967) : Colors.grey.shade400,
                width: 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.transparent,
                  offset: Offset(0, 4),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 16, color: foregroundColor),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: GoogleFonts.pressStart2p(
                    fontSize: 7,
                    color: foregroundColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
