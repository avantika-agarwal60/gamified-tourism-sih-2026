import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import 'api_service.dart';
import 'camera_capture_screen.dart';
import 'qr_scan_screen.dart';

class QuestCompletionFlow extends StatefulWidget {
  final String questId;
  final String questQrCode;
  final String questName;
  final LatLng questLocation;

  const QuestCompletionFlow({
    super.key,
    required this.questId,
    required this.questQrCode,
    required this.questName,
    required this.questLocation,
  });

  @override
  State<QuestCompletionFlow> createState() => _QuestCompletionFlowState();
}

class _QuestCompletionFlowState extends State<QuestCompletionFlow> {
  static const oceanBlue = Color(0xFF1684A7);
  static const tealGreen = Color(0xFF0EA391);
  static const cream = Color(0xFFF4F1EA);

  final ImagePicker _imagePicker = ImagePicker();
  Uint8List? _photoBytes;
  String? _photoName;
  String? _scannedQr;
  Position? _position;
  String? _error;
  bool _isCheckingLocation = false;
  bool _isSubmitting = false;

  Future<void> _scanQr() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (!mounted || scanned == null) return;

    if (scanned.trim() != widget.questQrCode.trim()) {
      setState(() {
        _scannedQr = null;
        _error = 'This QR code does not belong to this quest.';
      });
      return;
    }

    setState(() {
      _scannedQr = scanned.trim();
      _error = null;
    });
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final image = source == ImageSource.camera && kIsWeb
          ? await Navigator.of(context).push<XFile>(
              MaterialPageRoute(builder: (_) => const CameraCaptureScreen()),
            )
          : await _imagePicker.pickImage(
              source: source,
              imageQuality: 70,
              maxWidth: 1280,
              maxHeight: 1280,
            );
      if (image == null || !mounted) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photoBytes = bytes;
        _photoName = image.name;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not select photo: $error');
    }
  }

  Future<void> _detectLocation() async {
    setState(() {
      _isCheckingLocation = true;
      _error = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Enable location services to complete this quest.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is required.');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        widget.questLocation.latitude,
        widget.questLocation.longitude,
      );
      if (distance > 50) {
        throw Exception(
          'You are ${distance.round()} m away. Get within 50 m of the quest.',
        );
      }

      if (mounted) setState(() => _position = position);
    } catch (error) {
      if (mounted) {
        setState(() {
          _position = null;
          _error = error.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _isCheckingLocation = false);
    }
  }

  Future<void> _submitCompletion() async {
    if (_scannedQr == null || _photoBytes == null || _position == null) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final extension = (_photoName ?? '').toLowerCase().split('.').last;
      final mimeType = extension == 'png' ? 'image/png' : 'image/jpeg';
      final photoUrl = await ApiService.uploadQuestPhoto(
        questId: widget.questId,
        bytes: _photoBytes!,
        fileName: _photoName ?? 'quest-evidence.jpg',
        contentType: mimeType,
      );
      final completion = await ApiService.completeQuest(
        questId: widget.questId,
        latitude: _position!.latitude,
        longitude: _position!.longitude,
        qrCode: _scannedQr!,
        photoUrl: photoUrl,
      );
      if (mounted) Navigator.of(context).pop(completion);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString().replaceFirst('Exception: ', '');
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _scannedQr != null &&
        _photoBytes != null &&
        _position != null &&
        !_isSubmitting;

    return Dialog(
      backgroundColor: cream,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: oceanBlue, width: 3),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 460,
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'VERIFY ${widget.questName.toUpperCase()}',
                style: GoogleFonts.pressStart2p(
                  color: oceanBlue,
                  fontSize: 9,
                ),
              ),
              const SizedBox(height: 18),
              _stepLabel('1. QUEST QR', _scannedQr != null),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isSubmitting ? null : _scanQr,
                style: OutlinedButton.styleFrom(
                  foregroundColor: oceanBlue,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: oceanBlue, width: 1.5),
                ),
                icon: const Icon(Icons.qr_code_scanner),
                label:
                    Text(_scannedQr == null ? 'SCAN QUEST QR' : 'QR VERIFIED'),
              ),
              const SizedBox(height: 14),
              _stepLabel('2. PHOTO EVIDENCE', _photoBytes != null),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSubmitting
                          ? null
                          : () => _pickPhoto(ImageSource.camera),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: oceanBlue,
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: oceanBlue, width: 1.5),
                      ),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('CAMERA'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSubmitting
                          ? null
                          : () => _pickPhoto(ImageSource.gallery),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: oceanBlue,
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: oceanBlue, width: 1.5),
                      ),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('GALLERY'),
                    ),
                  ),
                ],
              ),
              if (_photoBytes != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.memory(
                    _photoBytes!,
                    height: 150,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _stepLabel('3. LOCATION', _position != null),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isCheckingLocation || _isSubmitting
                    ? null
                    : _detectLocation,
                style: OutlinedButton.styleFrom(
                  foregroundColor: oceanBlue,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: oceanBlue, width: 1.5),
                ),
                icon: _isCheckingLocation
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                label: Text(_position == null
                    ? 'DETECT LOCATION'
                    : 'LOCATION VERIFIED'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: GoogleFonts.pressStart2p(
                    color: Colors.red,
                    fontSize: 7,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: canSubmit ? _submitCompletion : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: tealGreen,
                  foregroundColor: Colors.white,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'COMPLETE QUEST',
                        style: GoogleFonts.pressStart2p(fontSize: 8),
                      ),
              ),
              TextButton(
                onPressed: _isSubmitting
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: Text(
                  'CANCEL',
                  style: GoogleFonts.pressStart2p(
                    color: oceanBlue,
                    fontSize: 8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepLabel(String label, bool complete) {
    return Row(
      children: [
        Icon(
          complete ? Icons.check_circle : Icons.radio_button_unchecked,
          color: complete ? tealGreen : oceanBlue,
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.pressStart2p(color: oceanBlue, fontSize: 7),
        ),
      ],
    );
  }
}
