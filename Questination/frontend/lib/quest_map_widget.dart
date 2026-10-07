import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'api_service.dart';
import 'ar_guide_screen.dart';
import 'quest_completion_flow.dart';
import 'quest_completion_quiz.dart';

class QuestMapWidget extends StatefulWidget {
  final String cityId;
  final String? questId;
  final VoidCallback? onQuestCompleted;

  const QuestMapWidget({
    super.key,
    this.cityId = 'lucknow',
    this.questId,
    this.onQuestCompleted,
  });

  @override
  State<QuestMapWidget> createState() => _QuestMapWidgetState();
}

class _QuestMapWidgetState extends State<QuestMapWidget> {
  final MapController _mapController = MapController();

  static const Color oceanBlue = Color(0xFF1684A7);
  static const Color tealGreen = Color(0xFF0EA391);
  static const Color sunnyYellow = Color(0xFFFAF179);
  static const Color backgroundOffWhite = Color(0xFFF4F4F4);
  static const LatLng _indiaCenter = LatLng(22.5937, 78.9629);

  LatLng _userLocation = const LatLng(26.8467, 80.9462);
  LatLng _destinationLocation = const LatLng(26.8375, 80.9631);

  String _questName = 'Loading...';
  String _clueText = 'Fetching clue...';
  int _xpReward = 350;
  String? _questId;
  String? _questQrCode;

  List<LatLng> _routePoints = [];
  List<Map<String, dynamic>> _cityPins = [];
  int _totalCityCount = 0;
  bool _isLoadingLocation = false;
  bool _isLoadingCities = false;
  bool _showIndiaOverview = false;
  bool _hasGpsLocation = false;
  bool _hasManualLocation = false;
  String _statusMessage = 'GPS Ready';

  @override
  void initState() {
    super.initState();
    _userLocation = _cityCenterFor(widget.cityId);
    _fetchQuestDetails();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLocation();
    });
  }

  @override
  void didUpdateWidget(covariant QuestMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cityId != widget.cityId ||
        oldWidget.questId != widget.questId) {
      if (oldWidget.cityId != widget.cityId) {
        _userLocation = _cityCenterFor(widget.cityId);
      }
      _fetchQuestDetails();
      _initLocation();
    }
  }

  Future<void> _fetchQuestDetails() async {
    try {
      final Map<String, dynamic> quest;
      if (widget.questId != null) {
        quest = await ApiService.getQuestById(widget.questId!);
      } else {
        final quests = await ApiService.getQuests(cityId: widget.cityId);
        if (quests.isEmpty) throw StateError('No quests found for this city');
        quest = Map<String, dynamic>.from(quests.first as Map);
      }

      if (!mounted) return;
      setState(() {
        _questId = quest['id']?.toString();
        _questQrCode = quest['qr_code']?.toString();
        _questName = quest['name']?.toString() ?? 'Quest';
        _clueText =
            quest['description']?.toString() ?? 'Explore this landmark.';
        _xpReward = (quest['xp'] as num?)?.toInt() ?? 0;
        _destinationLocation = LatLng(
          (quest['lat'] as num).toDouble(),
          (quest['lng'] as num).toDouble(),
        );
      });
      _fetchOSRMRoute();
    } catch (e) {
      debugPrint('Error fetching quest details: $e');
      if (mounted) {
        setState(() {
          _questId = null;
          _questQrCode = null;
          _questName = 'Quest unavailable';
          _clueText = 'Quest details could not be loaded.';
          _xpReward = 0;
        });
      }
    }
  }

  Future<void> _fetchCityPins() async {
    if (_isLoadingCities) return;
    setState(() => _isLoadingCities = true);
    try {
      final cities = await ApiService.getCities();
      final quests = await ApiService.getQuests();
      final questsByCity = <String, List<Map<String, dynamic>>>{};
      for (final rawQuest in quests) {
        final quest = Map<String, dynamic>.from(rawQuest as Map);
        final cityId = quest['city_id']?.toString();
        if (cityId == null || quest['lat'] is! num || quest['lng'] is! num) {
          continue;
        }
        questsByCity.putIfAbsent(cityId, () => []).add(quest);
      }

      final pins = <Map<String, dynamic>>[];
      for (final rawCity in cities) {
        final city = Map<String, dynamic>.from(rawCity as Map);
        final locations = questsByCity[city['id'].toString()] ?? [];
        if (locations.isEmpty) continue;

        final latitude = locations
                .map((quest) => (quest['lat'] as num).toDouble())
                .reduce((sum, value) => sum + value) /
            locations.length;
        final longitude = locations
                .map((quest) => (quest['lng'] as num).toDouble())
                .reduce((sum, value) => sum + value) /
            locations.length;
        pins.add({
          'id': city['id'].toString(),
          'name': city['name']?.toString() ?? 'City',
          'location': LatLng(latitude, longitude),
        });
      }

      if (mounted) {
        setState(() {
          _cityPins = pins;
          _totalCityCount = cities.length;
        });
      }
    } catch (e) {
      debugPrint('Error loading city pins: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not load cities from the server.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingCities = false);
    }
  }

  Future<void> _setMapMode(bool showQuestMap) async {
    setState(() => _showIndiaOverview = !showQuestMap);
    if (showQuestMap) {
      _mapController.move(_userLocation, 14.2);
      await _fetchOSRMRoute();
    } else {
      _mapController.move(_indiaCenter, 4.8);
      if (_cityPins.isEmpty) await _fetchCityPins();
    }
  }

  void _pickMapLocation(LatLng location) {
    if (!_showIndiaOverview) return;
    setState(() {
      _userLocation = location;
      _hasManualLocation = true;
      _hasGpsLocation = false;
      _statusMessage = 'Location Selected';
    });
  }

  List<Marker> _buildMapMarkers() {
    if (_showIndiaOverview) {
      final markers = _cityPins.map((city) {
        final location = city['location'] as LatLng;
        return Marker(
          point: location,
          width: 124,
          height: 50,
          child: IgnorePointer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: sunnyYellow,
                    border: Border.all(color: oceanBlue, width: 1.5),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    city['name'].toString().toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.pressStart2p(
                      fontSize: 6,
                      color: oceanBlue,
                    ),
                  ),
                ),
                const Icon(Icons.location_on,
                    color: Color(0xFFE63946), size: 26),
              ],
            ),
          ),
        );
      }).toList();

      if (_hasGpsLocation || _hasManualLocation) {
        markers.add(
          Marker(
            point: _userLocation,
            width: 40,
            height: 40,
            child: const Icon(Icons.my_location, color: tealGreen, size: 30),
          ),
        );
      }
      return markers;
    }

    return [
      Marker(
        point: _userLocation,
        width: 44,
        height: 44,
        child: Container(
          decoration: const BoxDecoration(
            color: tealGreen,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: tealGreen, blurRadius: 8)],
          ),
          child: const Icon(Icons.my_location, color: Colors.white, size: 22),
        ),
      ),
      Marker(
        point: _destinationLocation,
        width: 48,
        height: 48,
        child: Container(
          decoration: const BoxDecoration(
            color: sunnyYellow,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: sunnyYellow, blurRadius: 10)],
          ),
          child: const Icon(Icons.location_on, color: oceanBlue, size: 28),
        ),
      ),
    ];
  }

  Future<void> _confirmQuestStart() async {
    final shouldStart = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: backgroundOffWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: oceanBlue, width: 3),
        ),
        title: Text(
          _questName.toUpperCase(),
          style: GoogleFonts.pressStart2p(
            color: oceanBlue,
            fontSize: 10,
          ),
        ),
        content: Text(
          'REWARD: $_xpReward XP\n\nSCAN THE QUEST QR, ADD PHOTO EVIDENCE, AND VERIFY YOUR LOCATION TO COMPLETE IT.',
          style: GoogleFonts.pressStart2p(
            color: tealGreen,
            fontSize: 9,
            height: 1.6,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'NOT NOW',
              style: GoogleFonts.pressStart2p(color: oceanBlue, fontSize: 8),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: tealGreen),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'START QUEST',
              style: GoogleFonts.pressStart2p(color: Colors.white, fontSize: 8),
            ),
          ),
        ],
      ),
    );

    if (shouldStart != true || !mounted || _questId == null) return;

    final completion = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => QuestCompletionFlow(
        questId: _questId!,
        questQrCode: _questQrCode ?? '',
        questName: _questName,
        questLocation: _destinationLocation,
      ),
    );
    if (completion == null || !mounted) return;
    widget.onQuestCompleted?.call();

    String normalizedKey(Object? key) =>
        key.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    dynamic rawGuide;
    for (final entry in completion.entries) {
      if (normalizedKey(entry.key) == 'arguide' ||
          normalizedKey(entry.key) == 'guide') {
        rawGuide = entry.value;
        break;
      }
    }
    if (rawGuide is String) {
      try {
        rawGuide = jsonDecode(rawGuide);
      } on FormatException {
        rawGuide = null;
      }
    }
    dynamic guideSection = rawGuide;
    if (guideSection is Map) {
      for (final entry in guideSection.entries) {
        if (normalizedKey(entry.key) == 'arguide') {
          guideSection = entry.value;
          break;
        }
      }
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => ArGuideScreen(
          questName: _questName,
          dialogue: guideSection,
        ),
      ),
    );
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => QuestCompletionQuizModal(
        questId: _questId!,
        questName: _questName,
        onQuizCompleted: () {},
      ),
    );
    if (mounted) widget.onQuestCompleted?.call();
  }

  Future<void> _fetchOSRMRoute() async {
    final String url = 'https://router.project-osrm.org/route/v1/driving/'
        '${_userLocation.longitude},${_userLocation.latitude};'
        '${_destinationLocation.longitude},${_destinationLocation.latitude}'
        '?overview=full&geometries=geojson';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final List<dynamic> coordinates =
              data['routes'][0]['geometry']['coordinates'];
          if (mounted) {
            setState(() {
              _routePoints = coordinates
                  .map((coord) =>
                      LatLng(coord[1].toDouble(), coord[0].toDouble()))
                  .toList();
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _routePoints = [_userLocation, _destinationLocation]);
      }
    }
  }

  Future<void> _initLocation() async {
    if (!mounted) return;
    setState(() {
      _isLoadingLocation = true;
      _statusMessage = 'Checking GPS...';
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _updateStatus('GPS Disabled - City Center');
        await _fetchOSRMRoute();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _updateStatus('GPS Denied - City Center');
          await _fetchOSRMRoute();
          return;
        }
      }

      Position? position = await Geolocator.getLastKnownPosition();
      // ✅ NEW (Compatible across all Geolocator versions):
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );

      if (mounted) {
        setState(() {
          _userLocation = LatLng(position!.latitude, position.longitude);
          _isLoadingLocation = false;
          _hasGpsLocation = true;
          _hasManualLocation = false;
          _statusMessage = 'GPS Active';
        });
        _mapController.move(_userLocation, _showIndiaOverview ? 7.0 : 14.5);
      }
    } catch (e) {
      _updateStatus('GPS Unavailable - City Center');
    }

    await _fetchOSRMRoute();
  }

  void _updateStatus(String message) {
    if (mounted) {
      final cityCenter = _cityCenterFor(widget.cityId);
      setState(() {
        _userLocation = cityCenter;
        _hasGpsLocation = false;
        _statusMessage = message;
        _isLoadingLocation = false;
      });
      _mapController.move(cityCenter, 14.2);
    }
  }

  LatLng _cityCenterFor(String cityId) {
    if (cityId.toLowerCase().contains('varanasi')) {
      return const LatLng(25.3176, 82.9739);
    }
    return const LatLng(26.8467, 80.9462);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundOffWhite,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _showIndiaOverview ? _indiaCenter : _userLocation,
              initialZoom: _showIndiaOverview ? 4.8 : 14.2,
              onTap: (_, location) => _pickMapLocation(location),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.my_first_app',
                tileBuilder: (context, tileWidget, tile) {
                  return ColorFiltered(
                    colorFilter: const ColorFilter.mode(
                      Color(0x33FFFFFF),
                      BlendMode.screen,
                    ),
                    child: tileWidget,
                  );
                },
              ),
              if (!_showIndiaOverview)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints.isNotEmpty
                          ? _routePoints
                          : [_userLocation, _destinationLocation],
                      strokeWidth: 16,
                      color: tealGreen.withValues(alpha: 0.4),
                    ),
                    Polyline(
                      points: _routePoints.isNotEmpty
                          ? _routePoints
                          : [_userLocation, _destinationLocation],
                      strokeWidth: 7,
                      color: const Color(0xFF40DFAE),
                    ),
                    Polyline(
                      points: _routePoints.isNotEmpty
                          ? _routePoints
                          : [_userLocation, _destinationLocation],
                      strokeWidth: 2,
                      color: const Color(0xFFB8FFE8),
                    ),
                  ],
                ),
              MarkerLayer(markers: _buildMapMarkers()),
            ],
          ),

          // Top Header Overlay
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: oceanBlue.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: sunnyYellow, width: 2),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _showIndiaOverview
                              ? 'INDIA CITY MAP${_isLoadingCities ? ' - LOADING' : ''}'
                              : _isLoadingLocation
                                  ? 'FETCHING GPS...'
                                  : _statusMessage.toUpperCase(),
                          style: GoogleFonts.pressStart2p(
                            color: sunnyYellow,
                            fontSize: 8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _showIndiaOverview
                              ? _hasManualLocation
                                  ? 'TAP TO CHANGE LOCATION'
                                  : 'TAP MAP TO PICK LOCATION'
                              : 'NAVIGATE: $_questName',
                          style: GoogleFonts.pressStart2p(
                            color: Colors.white,
                            fontSize: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'QUEST',
                        style: GoogleFonts.pressStart2p(
                          color: Colors.white,
                          fontSize: 6,
                        ),
                      ),
                      Switch(
                        value: !_showIndiaOverview,
                        onChanged: _setMapMode,
                        activeThumbColor: sunnyYellow,
                      ),
                      Text(
                        'INDIA',
                        style: GoogleFonts.pressStart2p(
                          color: Colors.white,
                          fontSize: 6,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    tooltip: 'Detect my location',
                    icon: const Icon(Icons.gps_fixed,
                        color: sunnyYellow, size: 20),
                    onPressed: _initLocation,
                  ),
                ],
              ),
            ),
          ),

          // Bottom Details Overlay
          if (!_showIndiaOverview)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: oceanBlue,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tealGreen, width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _questName.toUpperCase(),
                          style: GoogleFonts.pressStart2p(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: sunnyYellow,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '+$_xpReward XP',
                            style: GoogleFonts.pressStart2p(
                              color: Colors.black,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'CLUE: $_clueText',
                      style: GoogleFonts.pressStart2p(
                        color: Colors.white70,
                        fontSize: 7,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tealGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: oceanBlue, width: 2),
                          ),
                        ),
                        onPressed: _questId == null ? null : _confirmQuestStart,
                        child: Text(
                          'COMPLETE QUEST',
                          style: GoogleFonts.pressStart2p(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_showIndiaOverview)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: oceanBlue,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tealGreen, width: 2),
                ),
                child: Text(
                  'CITIES: ${_cityPins.length}/$_totalCityCount  |  ${_hasGpsLocation ? 'GPS LOCATION ACTIVE' : _hasManualLocation ? 'CUSTOM LOCATION SELECTED' : 'LOCATION NOT SET'}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.pressStart2p(
                    color: Colors.white,
                    fontSize: 7,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
