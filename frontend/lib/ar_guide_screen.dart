import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ar_flutter_plugin_plus/ar_flutter_plugin_plus.dart';
import 'package:ar_flutter_plugin_plus/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin_plus/datatypes/hittest_result_types.dart';
import 'package:ar_flutter_plugin_plus/datatypes/node_types.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_plus/models/ar_anchor.dart';
import 'package:ar_flutter_plugin_plus/models/ar_hittest_result.dart';
import 'package:ar_flutter_plugin_plus/models/ar_node.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

import 'api_service.dart';

/// Real-world height of the guide in metres. 0.4 = a 40 cm tiny person.
/// Change this one number to resize the guide.
const double _guideHeightMeters = 0.7;

/// true  -> crisp nearest-neighbour sampling (pixel art)
/// false -> smooth sampling (for non-pixel art)
const bool _pixelArt = true;

/// Extra brightness baked into the AR sprite only (the avatar screen is not
/// affected). 1.0 = unchanged. Raise to ~1.3-1.6 if the guide still looks dim
/// in AR after the lighting fixes in the material below.
const double _arBrightness = 1.0;

/// How strongly the sprite glows regardless of scene lighting (0 to 1).
const double _arEmissive = 0.7;

class ArGuideScreen extends StatefulWidget {
  final String questName;
  final Object? dialogue;

  const ArGuideScreen({
    super.key,
    required this.questName,
    required this.dialogue,
  });

  @override
  State<ArGuideScreen> createState() => _ArGuideScreenState();
}

class _ArGuideScreenState extends State<ArGuideScreen> {
  ARSessionManager? _sessionManager;
  ARObjectManager? _objectManager;
  ARAnchorManager? _anchorManager;
  String? _modelFileName;
  List<String> _modelUriCandidates = const [];
  String? _avatarError;
  String? _placementError;
  bool _loadingAvatar = true;
  bool _placingGuide = false;
  bool _guidePlaced = false;
  int _dialogueIndex = 0;

  List<String> get _dialogueSegments => _parseDialogue(widget.dialogue);

  List<String> _parseDialogue(Object? value) {
    final decoded = _decodeIfJsonString(value);

    if (decoded is Map) {
      final arGuide = decoded['ar_guide'];
      if (arGuide is Map) {
        return _flattenArGuide(Map<String, dynamic>.from(arGuide));
      }
      // Fallback: no ar_guide key found, walk everything generically
      return decoded.values.expand(_parseDialogue).toList();
    }
    if (decoded is List) {
      return decoded.expand(_parseDialogue).toList();
    }
    if (decoded is String) {
      final trimmed = decoded.trim();
      return trimmed.isEmpty ? const [] : [trimmed];
    }
    if (decoded is num || decoded is bool) {
      return [decoded.toString()];
    }
    return const [];
  }

  Object? _decodeIfJsonString(Object? value) {
    if (value is! String) return value;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return value;
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        return jsonDecode(trimmed);
      } on FormatException {
        return value;
      }
    }
    return value;
  }

  List<String> _flattenArGuide(Map<String, dynamic> arGuide) {
    final segments = <String>[];

    void addIfPresent(String key) {
      final value = arGuide[key];
      if (value is String && value.trim().isNotEmpty) {
        segments.add(value.trim());
      }
    }

    addIfPresent('welcome');
    addIfPresent('introduction');

    final observations = arGuide['things_to_observe'];
    if (observations is List) {
      for (final item in observations) {
        if (item is String && item.trim().isNotEmpty) {
          segments.add(item.trim());
        }
      }
    }

    addIfPresent('discovery_challenge');
    addIfPresent('closing');

    return segments;
  }

  bool get _canAdvanceDialogue =>
      (_guidePlaced || _avatarError != null) && _dialogueSegments.isNotEmpty;

  bool get _hasNextDialogueSegment =>
      _canAdvanceDialogue && _dialogueIndex < _dialogueSegments.length - 1;

  void _advanceDialogue() {
    if (_hasNextDialogueSegment) {
      setState(() => _dialogueIndex++);
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  void initState() {
    super.initState();
    _loadAvatarAndBuildSprite();
  }

  Future<void> _loadAvatarAndBuildSprite() async {
    try {
      final results = await Future.wait([
        ApiService.getMyAvatar(),
        ApiService.getAvatarItems(),
      ]);
      final avatar = results[0] as Map<String, dynamic>;
      final catalog = results[1] as List<Map<String, dynamic>>;
      final equipped = avatar['equipped'];
      if (equipped is! Map) {
        throw const FormatException('Avatar response has no equipped look.');
      }

      final equippedMap = Map<String, dynamic>.from(equipped);
      final imagePaths = <String>[];
      for (final slot in ['outfit', 'hair', 'hat']) {
        final itemId = equippedMap[slot]?.toString();
        if (itemId == null || itemId.isEmpty || itemId == 'null') continue;
        final item = catalog.where((row) {
          return row['id']?.toString() == itemId &&
              row['slot']?.toString().toLowerCase() == slot;
        }).firstOrNull;
        imagePaths.add(_resolveImagePath(slot, itemId, item?['image_path']));
      }
      if (imagePaths.isEmpty) {
        throw const FormatException('Your avatar has no equipped items.');
      }

      final sprite = await _composeAvatarSprite(imagePaths);
      final candidates = await _writeSpriteGlb(sprite);
      if (!mounted) return;
      setState(() {
        _modelUriCandidates = candidates;
        _modelFileName = candidates.first;
        _loadingAvatar = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _avatarError = error.toString().replaceFirst('Exception: ', '');
        _loadingAvatar = false;
      });
    }
  }

  String _resolveImagePath(String slot, String itemId, Object? rawPath) {
    final localAsset = _localAssetFor(slot, itemId);
    if (localAsset != null) return localAsset;
    final path = rawPath?.toString().trim();
    if (path == null || path.isEmpty) {
      throw FormatException('Avatar item $itemId has no image path.');
    }
    if (path.startsWith('assets/')) return path;
    final uri = Uri.tryParse(path);
    if (uri != null && uri.hasScheme) return path;
    return '${ApiService.baseUrl}/${path.replaceFirst(RegExp(r'^/+'), '')}';
  }

  String? _localAssetFor(String slot, String itemId) {
    final match = RegExp(
      '^${RegExp.escape(slot)}[_-]?(\\d+)\$',
      caseSensitive: false,
    ).firstMatch(itemId);
    final itemNumber = match == null ? null : int.tryParse(match.group(1)!);
    if (itemNumber == null || itemNumber < 1 || itemNumber > 10) return null;
    return 'assets/avatar pieces/${slot.toLowerCase()} $itemNumber.webp';
  }

  Future<ui.Image> _decodeImage(String path) async {
    final ImageStream stream;
    if (path.startsWith('assets/')) {
      stream = AssetImage(path).resolve(ImageConfiguration.empty);
    } else {
      stream = NetworkImage(path).resolve(ImageConfiguration.empty);
    }
    final completer = Completer<ui.Image>();
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (frame, _) {
        stream.removeListener(listener);
        completer.complete(frame.image);
      },
      onError: (Object error, StackTrace? stackTrace) {
        stream.removeListener(listener);
        completer.completeError(error, stackTrace);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }

  /// Stacks the layers at the NATIVE size of the first layer, so the aspect
  /// ratio is preserved and pixel art is never resampled here. The GPU does
  /// the scaling (with nearest-neighbour if [_pixelArt] is true).
  /// All layers should share the same canvas size.
  Future<({Uint8List png, int width, int height})> _composeAvatarSprite(
    List<String> imagePaths,
  ) async {
    final decoded = <ui.Image>[];
    try {
      for (final path in imagePaths) {
        decoded.add(await _decodeImage(path));
      }
      final width = decoded.first.width;
      final height = decoded.first.height;
      final destination =
          Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder, destination);
      final paint = Paint()
        ..filterQuality = _pixelArt ? FilterQuality.none : FilterQuality.high;
      if (_arBrightness != 1.0) {
        const b = _arBrightness;
        paint.colorFilter = const ColorFilter.matrix(<double>[
          b, 0, 0, 0, 0, //
          0, b, 0, 0, 0, //
          0, 0, b, 0, 0, //
          0, 0, 0, 1, 0,
        ]);
      }

      for (final image in decoded) {
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(
            0,
            0,
            image.width.toDouble(),
            image.height.toDouble(),
          ),
          destination,
          paint,
        );
      }
      final composite = await recorder.endRecording().toImage(width, height);
      final data = await composite.toByteData(format: ui.ImageByteFormat.png);
      composite.dispose();
      if (data == null) throw StateError('Could not encode the guide avatar.');
      return (
        png: data.buffer.asUint8List(),
        width: width,
        height: height,
      );
    } finally {
      for (final image in decoded) {
        image.dispose();
      }
    }
  }

  /// Builds a GLB containing one flat quad textured with the sprite.
  /// The quad is [_guideHeightMeters] tall, its width follows the sprite's
  /// aspect ratio, and its ORIGIN IS AT THE FEET (bottom centre), so placing
  /// the node at the anchor puts the guide's feet on the surface.
  Future<List<String>> _writeSpriteGlb(
    ({Uint8List png, int width, int height}) sprite,
  ) async {
    final quadHeight = _guideHeightMeters;
    final quadHalfWidth = quadHeight * (sprite.width / sprite.height) / 2;

    final binary = BytesBuilder(copy: false);
    final bufferViews = <Map<String, Object>>[];

    void addView(Uint8List bytes, int target) {
      while (binary.length % 4 != 0) {
        binary.addByte(0);
      }
      final offset = binary.length;
      binary.add(bytes);
      bufferViews.add({
        'buffer': 0,
        'byteOffset': offset,
        'byteLength': bytes.length,
        if (target != 0) 'target': target,
      });
    }

    Uint8List floats(List<double> values) {
      final data = ByteData(values.length * 4);
      for (var i = 0; i < values.length; i++) {
        data.setFloat32(i * 4, values[i], Endian.little);
      }
      return data.buffer.asUint8List();
    }

    // Positions: bottom-left, bottom-right, top-right, top-left.
    // y runs from 0 (feet) to quadHeight (head).
    addView(
      floats([
        -quadHalfWidth, 0, 0, //
        quadHalfWidth, 0, 0, //
        quadHalfWidth, quadHeight, 0, //
        -quadHalfWidth, quadHeight, 0,
      ]),
      34962,
    );
    addView(
      floats([
        0, 0, 1, //
        0, 0, 1, //
        0, 0, 1, //
        0, 0, 1,
      ]),
      34962,
    );
    addView(floats([0, 1, 1, 1, 1, 0, 0, 0]), 34962);
    final indices = ByteData(12)
      ..setUint16(0, 0, Endian.little)
      ..setUint16(2, 1, Endian.little)
      ..setUint16(4, 2, Endian.little)
      ..setUint16(6, 0, Endian.little)
      ..setUint16(8, 2, Endian.little)
      ..setUint16(10, 3, Endian.little);
    addView(indices.buffer.asUint8List(), 34963);
    addView(sprite.png, 0);
    final binaryBytes = binary.toBytes();

    // 9728 = NEAREST, 9729 = LINEAR
    final filter = _pixelArt ? 9728 : 9729;

    final document = <String, Object>{
      'asset': {'version': '2.0', 'generator': 'Questination AR Guide'},
      'extensionsUsed': ['KHR_materials_unlit'],
      'scene': 0,
      'scenes': [
        {
          'nodes': [0]
        },
      ],
      'nodes': [
        {'mesh': 0},
      ],
      'meshes': [
        {
          'primitives': [
            {
              'attributes': {'POSITION': 0, 'NORMAL': 1, 'TEXCOORD_0': 2},
              'indices': 3,
              'material': 0,
            }
          ]
        }
      ],
      'materials': [
        {
          'pbrMetallicRoughness': {
            'baseColorTexture': {'index': 0},
            'metallicFactor': 0,
            'roughnessFactor': 1,
          },
          // Ignore scene lighting where supported (unlit), and add emissive
          // as a fallback for renderers that ignore the unlit extension.
          'emissiveTexture': {'index': 0},
          'emissiveFactor': [_arEmissive, _arEmissive, _arEmissive],
          'extensions': {'KHR_materials_unlit': {}},
          'alphaMode': 'BLEND',
          'doubleSided': true,
        }
      ],
      'textures': [
        {'sampler': 0, 'source': 0},
      ],
      'samplers': [
        {
          'magFilter': filter,
          'minFilter': filter,
          'wrapS': 33071,
          'wrapT': 33071,
        },
      ],
      'images': [
        {'bufferView': 4, 'mimeType': 'image/png'},
      ],
      'accessors': [
        {
          'bufferView': 0,
          'componentType': 5126,
          'count': 4,
          'type': 'VEC3',
          'min': [-quadHalfWidth, 0, 0],
          'max': [quadHalfWidth, quadHeight, 0],
        },
        {
          'bufferView': 1,
          'componentType': 5126,
          'count': 4,
          'type': 'VEC3',
        },
        {
          'bufferView': 2,
          'componentType': 5126,
          'count': 4,
          'type': 'VEC2',
        },
        {
          'bufferView': 3,
          'componentType': 5123,
          'count': 6,
          'type': 'SCALAR',
        },
      ],
      'bufferViews': bufferViews,
      'buffers': [
        {'byteLength': binaryBytes.length},
      ],
    };

    final jsonBytes = Uint8List.fromList(utf8.encode(jsonEncode(document)));
    final paddedJsonLength = (jsonBytes.length + 3) & ~3;
    final paddedBinaryLength = (binaryBytes.length + 3) & ~3;
    final totalLength = 12 + 8 + paddedJsonLength + 8 + paddedBinaryLength;
    final glb = BytesBuilder(copy: false)
      ..add(_uint32Bytes(0x46546C67))
      ..add(_uint32Bytes(2))
      ..add(_uint32Bytes(totalLength))
      ..add(_uint32Bytes(paddedJsonLength))
      ..add(_uint32Bytes(0x4E4F534A))
      ..add(jsonBytes)
      ..add(List<int>.filled(paddedJsonLength - jsonBytes.length, 0x20))
      ..add(_uint32Bytes(paddedBinaryLength))
      ..add(_uint32Bytes(0x004E4942))
      ..add(binaryBytes)
      ..add(List<int>.filled(paddedBinaryLength - binaryBytes.length, 0));

    // The AR plugin resolves "app folder" files differently across platforms
    // and plugin versions, so write the file to every likely location.
    final bytes = glb.toBytes();
    const fileName = 'questination-guide-avatar.glb';
    final documents = await getApplicationDocumentsDirectory();
    final support = await getApplicationSupportDirectory();
    final dirs = <Directory>[
      documents,
      support,
      Directory('${support.path}${Platform.pathSeparator}app_flutter'),
    ];
    for (final dir in dirs) {
      try {
        await dir.create(recursive: true);
        final file = File('${dir.path}${Platform.pathSeparator}$fileName');
        await file.writeAsBytes(bytes, flush: true);
        debugPrint('Guide GLB written: ${file.path} (${bytes.length} bytes)');
      } catch (e) {
        debugPrint('Could not write guide GLB to ${dir.path}: $e');
      }
    }
    // On Android this plugin opens the uri as an exact path (the log showed
    // it trying the bare file name), so pass the full path. On iOS the
    // plugin adds the documents folder itself, so pass only the file name.
    final absoluteDocuments =
        '${documents.path}${Platform.pathSeparator}$fileName';
    return Platform.isAndroid ? [absoluteDocuments] : [fileName];
  }

  Uint8List _uint32Bytes(int value) {
    final data = ByteData(4)..setUint32(0, value, Endian.little);
    return data.buffer.asUint8List();
  }

  Future<void> _onARViewCreated(
    ARSessionManager sessionManager,
    ARObjectManager objectManager,
    ARAnchorManager anchorManager,
    ARLocationManager locationManager,
  ) async {
    _sessionManager = sessionManager;
    _objectManager = objectManager;
    _anchorManager = anchorManager;
    sessionManager.onPlaneOrPointTap = _placeGuide;
    try {
      await sessionManager.onInitialize(
        showFeaturePoints: false,
        showPlanes: true,
        showWorldOrigin: false,
        handleTaps: true,
      );
      objectManager.onInitialize();
    } catch (error) {
      if (mounted) {
        setState(() {
          _placementError = 'Could not start AR tracking: ${error.toString()}';
        });
      }
    }
  }

  /// Yaw (radians, around the anchor's up axis) that turns the quad's front
  /// (+Z) toward the camera. Returns 0 if the camera pose is unavailable.
  double _yawTowardCamera(Matrix4 anchorTransform, Matrix4? cameraPose) {
    if (cameraPose == null) return 0;
    try {
      final cameraInAnchor =
          Matrix4.inverted(anchorTransform).transform3(cameraPose.getTranslation());
      if (cameraInAnchor.x.abs() < 1e-4 && cameraInAnchor.z.abs() < 1e-4) {
        return 0;
      }
      return math.atan2(cameraInAnchor.x, cameraInAnchor.z);
    } catch (_) {
      return 0;
    }
  }

  Future<void> _placeGuide(List<ARHitTestResult> hits) async {
    debugPrint('AR tap hits: ${hits.map((h) => h.type).toList()}');
    ARHitTestResult? hit;
    for (final h in hits) {
      if (h.type == ARHitTestResultType.plane) {
        hit = h;
        break;
      }
    }
    // Fall back to any hit (e.g. a feature point) if no plane was hit.
    hit ??= hits.isNotEmpty ? hits.first : null;
    if (hit == null) {
      setState(() {
        _placementError =
            'No surface found there. Try the PLACE IN FRONT OF ME button.';
      });
      return;
    }
    await _placeAt(hit.worldTransform);
  }

  /// Fallback that needs no detected surface: puts the guide in front of the
  /// camera, a bit below it. The height is approximate, so it may float or
  /// sit slightly low. Tune the two constants to taste.
  Future<void> _placeInFront() async {
    const forwardMeters = 0.7;
    const dropMeters = 0.5;
    Matrix4? pose;
    try {
      pose = await _sessionManager?.getCameraPose();
    } catch (_) {
      pose = null;
    }
    if (pose == null) {
      setState(() {
        _placementError =
            'Camera is not tracking yet. Move your device slowly and retry.';
      });
      return;
    }
    final position = pose.getTranslation();
    final forward = pose.transformed3(Vector3(0, 0, -1)) - position;
    forward.y = 0;
    if (forward.length < 1e-3) {
      forward.setValues(0, 0, -1);
    }
    forward.normalize();
    final target = position + forward * forwardMeters;
    target.y = position.y - dropMeters;
    await _placeAt(Matrix4.identity()..setTranslation(target));
  }

  Future<void> _placeAt(Matrix4 transform) async {
    if (_placingGuide || _guidePlaced) return;
    final modelFileName = _modelFileName;
    final anchorManager = _anchorManager;
    final objectManager = _objectManager;
    if (modelFileName == null ||
        anchorManager == null ||
        objectManager == null) {
      setState(() => _placementError = 'The guide avatar is not ready yet.');
      return;
    }

    setState(() {
      _placingGuide = true;
      _placementError = null;
    });
    ARPlaneAnchor? anchor;
    try {
      anchor = ARPlaneAnchor(transformation: transform);
      if (await anchorManager.addAnchor(anchor) != true) {
        throw StateError('Could not anchor the guide to this surface.');
      }

      Matrix4? cameraPose;
      try {
        cameraPose = await _sessionManager?.getCameraPose();
      } catch (_) {
        cameraPose = null;
      }
      final yaw = _yawTowardCamera(transform, cameraPose);

      // Size is baked into the GLB geometry, so scale stays 1.
      // The GLB origin is at the feet, so position stays at the anchor.
      var added = false;
      Object? lastError;
      for (final uri in _modelUriCandidates) {
        try {
          debugPrint('Trying guide GLB uri: $uri');
          final node = ARNode(
            type: NodeType.fileSystemAppFolderGLB,
            uri: uri,
            scale: Vector3(1, 1, 1),
            position: Vector3(0, 0, 0),
            eulerAngles: Vector3(0, yaw, 0),
          );
          if (await objectManager.addNode(node, planeAnchor: anchor) == true) {
            debugPrint('addNode accepted: $uri (the model loads asynchronously; '
                'watch for an "Error loading model" line)');
            added = true;
            break;
          }
          debugPrint('addNode returned false for: $uri');
        } catch (e) {
          lastError = e;
          debugPrint('addNode failed for $uri: $e');
        }
      }
      if (!added) {
        throw StateError(
          'Could not load the guide model. ${lastError ?? ''}',
        );
      }
      if (mounted) setState(() => _guidePlaced = true);
    } catch (error) {
      debugPrint('Guide placement failed: $error');
      // Don't leave an orphan anchor behind after a failed attempt.
      if (anchor != null) {
        try {
          await anchorManager.removeAnchor(anchor);
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _placementError = error.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _placingGuide = false);
    }
  }

  @override
  void dispose() {
    _sessionManager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF07545A);
    const cream = Color(0xFFFFF8E1);

    return Scaffold(
      backgroundColor: const Color(0xFF1B2827),
      body: SafeArea(
        child: Stack(
          children: [
            if (!kIsWeb && (Platform.isAndroid || Platform.isIOS))
              ARView(
                onARViewCreated: _onARViewCreated,
                // Horizontal only: the guide stands on floors and tables.
                planeDetectionConfig: PlaneDetectionConfig.horizontal,
                permissionPromptDescription:
                    'Camera access is needed to place your guide in AR.',
              )
            else
              const Center(
                child: Text(
                  'AR guide is available on Android and iOS devices.',
                  style: TextStyle(color: cream),
                ),
              ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black.withValues(alpha: 0.52),
                padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: cream),
                      tooltip: 'Close guide',
                    ),
                    Expanded(
                      child: Text(
                        '${widget.questName.toUpperCase()} GUIDE',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.pressStart2p(
                          fontSize: 8,
                          color: cream,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_loadingAvatar || _placingGuide)
              Positioned(
                top: 70,
                left: 18,
                right: 18,
                child: Center(
                  child: Card(
                    color: cream,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: teal,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _loadingAvatar
                                ? 'LOADING YOUR GUIDE...'
                                : 'PLACING GUIDE...',
                            style: GoogleFonts.pressStart2p(
                              fontSize: 7,
                              color: teal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else if (_avatarError != null)
              _statusBanner(
                'Could not load your equipped avatar: $_avatarError',
                top: 66,
              )
            else if (!_guidePlaced && _placementError != null)
              _statusBanner(_placementError!, top: 66),
            if (!_guidePlaced && !_loadingAvatar && _avatarError == null)
              Positioned(
                top: 74,
                left: 18,
                right: 18,
                child: IgnorePointer(
                  child: Text(
                    'MOVE YOUR DEVICE TO SCAN, THEN TAP A SURFACE TO PLACE YOUR GUIDE.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.pressStart2p(
                      fontSize: 7,
                      color: Colors.white,
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 5),
                      ],
                    ),
                  ),
                ),
              ),
            if (!_guidePlaced && !_loadingAvatar && _avatarError == null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 160,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF70401F),
                    foregroundColor: cream,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  onPressed: _placingGuide ? null : _placeInFront,
                  child: Text(
                    'PLACE IN FRONT OF ME',
                    style: GoogleFonts.pressStart2p(fontSize: 8),
                  ),
                ),
              ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: cream,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: teal, width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _canAdvanceDialogue
                          ? '“${_dialogueSegments[_dialogueIndex]}”'
                          : _guidePlaced
                              ? 'Your guide has no dialogue for this quest yet.'
                              : _avatarError == null
                                  ? 'Point to the target and tap to welcome your guide'
                                  : 'No dialogue is available for this quest yet.',
                      style: GoogleFonts.vt323(
                        fontSize: 20,
                        color: teal,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: teal,
                        foregroundColor: cream,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: _advanceDialogue,
                      child: Text(
                        _hasNextDialogueSegment ? 'NEXT' : 'CONTINUE TO QUIZ',
                        style: GoogleFonts.pressStart2p(fontSize: 8),
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

  Widget _statusBanner(String message, {required double top}) {
    return Positioned(
      top: top,
      left: 18,
      right: 18,
      child: Card(
        color: const Color(0xFF70401F),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.vt323(
              fontSize: 16,
              color: const Color(0xFFFFF8E1),
            ),
          ),
        ),
      ),
    );
  }
}