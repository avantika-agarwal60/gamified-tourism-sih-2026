import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'api_service.dart';

class IndiaMapWelcomeScreen extends StatefulWidget {
  const IndiaMapWelcomeScreen({super.key});

  @override
  State<IndiaMapWelcomeScreen> createState() => _IndiaMapWelcomeScreenState();
}

class _IndiaMapWelcomeScreenState extends State<IndiaMapWelcomeScreen> {
  final MapController _mapController = MapController();
  final LatLng _indiaCenter = const LatLng(22.5937, 78.9629);

  List<Map<String, dynamic>> _questPins = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchQuests();
  }

  Future<void> _fetchQuests() async {
    try {
      final List<dynamic> quests = await ApiService.getQuests();

      if (mounted) {
        setState(() {
          _questPins = quests.map((item) {
            final quest = Map<String, dynamic>.from(item as Map);
            return {
              'id': quest['id'].toString(),
              'cityId': quest['city_id'].toString(),
              'name': (quest['name'] ?? 'QUEST').toString().toUpperCase(),
              'location': LatLng(
                (quest['lat'] as num).toDouble(),
                (quest['lng'] as num).toDouble(),
              ),
              'active': true,
            };
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching quests via API: $e');
      if (mounted) {
        setState(() {
          _questPins = [
            {
              'id': 'lucknow',
              'cityId': 'lucknow',
              'name': 'LUCKNOW',
              'location': const LatLng(26.8467, 80.9462),
              'active': true,
            },
            {
              'id': 'varanasi',
              'cityId': 'varanasi',
              'name': 'VARANASI',
              'location': const LatLng(25.3176, 82.9739),
              'active': true,
            },
          ];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _indiaCenter,
              initialZoom: 4.8,
              minZoom: 4.0,
              maxZoom: 7.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
                userAgentPackageName: 'com.example.my_first_app',
              ),
              MarkerLayer(
                markers: _questPins.map((pin) {
                  final bool isActive = pin['active'] as bool;
                  final String name = pin['name'] as String;

                  return Marker(
                    point: pin['location'] as LatLng,
                    width: 100,
                    height: 70,
                    child: IgnorePointer(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? const Color(0xFFFAF179)
                                  : Colors.white,
                              border: Border.all(
                                color: isActive
                                    ? const Color(0xFF1684A7)
                                    : Colors.grey,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  offset: Offset(1, 2),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                            child: Text(
                              name,
                              style: GoogleFonts.pressStart2p(
                                fontSize: 6,
                                color: isActive
                                    ? const Color(0xFF1684A7)
                                    : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                Icons.location_on,
                                color: isActive
                                    ? const Color(0xFFE63946)
                                    : Colors.grey.shade400,
                                size: 34,
                              ),
                              Positioned(
                                top: 6,
                                child: Icon(
                                  isActive ? Icons.star : Icons.lock,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          if (_isLoading)
            const Positioned(
              top: 80,
              right: 20,
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF1684A7),
                ),
              ),
            ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                border: Border.all(color: const Color(0xFF1684A7), width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    'QUEST MAP',
                    style: GoogleFonts.pressStart2p(
                      fontSize: 14,
                      color: const Color(0xFF1684A7),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'SELECT A PIN TO BEGIN YOUR QUEST',
                    style: GoogleFonts.pressStart2p(
                      fontSize: 7,
                      color: const Color(0xFF0EA391),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
