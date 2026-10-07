import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  // Base URL pointing directly to Railway host.
  // Copy the exact hostname from Railway -> Networking.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://questination-production-08b6.up.railway.app',
  );

  static const _storage = FlutterSecureStorage();

  static String? accessToken;
  static String? refreshToken;

  // ---------------------------------------------------------------------------
  // Token handling
  // ---------------------------------------------------------------------------

  /// Call once at app start, before runApp.
  static Future<void> loadTokens() async {
    accessToken = await _storage.read(key: 'access_token');
    refreshToken = await _storage.read(key: 'refresh_token');
  }

  static Future<void> _saveTokens(String access, String refresh) async {
    accessToken = access;
    refreshToken = refresh;
    await _storage.write(key: 'access_token', value: access);
    await _storage.write(key: 'refresh_token', value: refresh);
  }

  static Future<void> logout() async {
    accessToken = null;
    refreshToken = null;
    await _storage.deleteAll();
  }

  static bool get isLoggedIn => accessToken != null;

  // Only one refresh runs at a time; other requests wait for it.
  static Future<bool>? _refreshing;
  static Future<bool> _refresh() =>
      _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);

  static Future<bool> _doRefresh() async {
    final rt = refreshToken;
    if (rt == null) return false;
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/refreshtoken'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshtoken': rt}),
      );
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is! Map) return false;
        final access = decoded['token'];
        if (access is! String || access.isEmpty) return false;
        final refreshed = decoded['Refresh_token'];
        final nextRefresh =
            refreshed is String && refreshed.isNotEmpty ? refreshed : rt;
        await _saveTokens(access, nextRefresh);
        return true;
      }
      // Refresh token invalid/expired/revoked: user must log in again.
      if (res.statusCode == 401 || res.statusCode == 403) await logout();
      return false;
    } catch (_) {
      return false; // network error: keep tokens, don't log out
    }
  }

  /// Wrap every authenticated call: on 401, refresh once and retry.
  /// The request is built inside [send], so the retry uses the new token.
  static Future<http.Response> _authed(
      Future<http.Response> Function() send) async {
    var res = await send();
    if (res.statusCode == 401 && await _refresh()) {
      res = await send();
    }
    return res;
  }

  static Map<String, String> get authHeaders => {
        'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      };

  static String? get currentUserId {
    final token = accessToken;
    if (token == null) return null;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      return payload is Map ? payload['id']?.toString() : null;
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------------

  // POST /auth/log-in
  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/log-in'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    final data = _decodeResponseBody(response, 'POST /auth/log-in');

    if (response.statusCode == 200 && data is Map) {
      await _saveTokens(data['token'], data['Refresh_token']);
      return Map<String, dynamic>.from(data);
    }
    throw Exception(
        _responseMessage(data, 'Failed to log in', response.statusCode));
  }

  // POST /auth/register
  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String phone,
    String role = 'tourist',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
        'phone': phone,
        'role': role,
      }),
    );

    final data = _decodeResponseBody(response, 'POST /auth/register');

    if (response.statusCode == 201) {
      // Auto-login after successful registration to retrieve JWT tokens
      return await login(email, password);
    }
    throw Exception(
        _responseMessage(data, 'Failed to register', response.statusCode));
  }

  // ---------------------------------------------------------------------------
  // Quests
  // ---------------------------------------------------------------------------

  // GET /quests
  static Future<List<dynamic>> getQuests({String? cityId}) async {
    final Uri uri = Uri.parse('$baseUrl/quests').replace(
      queryParameters: cityId != null ? {'city_id': cityId} : null,
    );

    final response = await _authed(() => http.get(uri, headers: authHeaders));
    final data = _decodeResponseBody(response, 'GET /quests');
    if (response.statusCode == 200) {
      if (data is List) return data;
      if (data is Map && data['quests'] is List) {
        return data['quests'] as List<dynamic>;
      }
      throw const FormatException(
          'Unexpected response format from GET /quests');
    }
    throw Exception(
        _responseMessage(data, 'Failed to load quests', response.statusCode));
  }

  // GET /quests/completed_quests
  static Future<List<dynamic>> getCompletedQuests() async {
    final response = await _authed(() => http.get(
          Uri.parse('$baseUrl/quests/completed_quests'),
          headers: authHeaders,
        ));
    final data = _decodeResponseBody(response, 'GET completed quests');
    if (response.statusCode == 200) {
      if (data is List) return data;
      if (data is Map) {
        for (final key in const [
          'completed_quests',
          'completedQuests',
          'data',
        ]) {
          if (data[key] is List) return data[key] as List<dynamic>;
        }
      }
      throw const FormatException(
        'Unexpected response format from GET /quests/completed_quests',
      );
    }
    throw Exception(_responseMessage(
      data,
      'Failed to load completed quests',
      response.statusCode,
    ));
  }

  // GET /quests/cities
  static Future<List<dynamic>> getCities() async {
    final response = await _authed(() => http.get(
          Uri.parse('$baseUrl/quests/cities'),
          headers: authHeaders,
        ));
    final data = _decodeResponseBody(response, 'GET /quests/cities');
    if (response.statusCode == 200 && data is Map && data['cities'] is List) {
      return data['cities'] as List<dynamic>;
    }
    throw Exception(
        _responseMessage(data, 'Failed to load cities', response.statusCode));
  }

  // GET /quests/:id
  static Future<Map<String, dynamic>> getQuestById(String questId) async {
    final response = await _authed(() => http.get(
          Uri.parse('$baseUrl/quests/$questId'),
          headers: authHeaders,
        ));
    final data = _decodeResponseBody(response, 'GET /quests/:id');
    if (response.statusCode == 200 && data is Map && data['quest'] is Map) {
      return Map<String, dynamic>.from(data['quest'] as Map);
    }
    throw Exception(
        _responseMessage(data, 'Failed to load quest', response.statusCode));
  }

  // POST /quests/:id/accept
  static Future<void> acceptQuest(String questId) async {
    final response = await _authed(() => http.post(
          Uri.parse('$baseUrl/quests/$questId/accept'),
          headers: authHeaders,
        ));
    final data = _decodeResponseBody(response, 'POST quest acceptance');
    if (response.statusCode == 200 ||
        response.statusCode == 201 ||
        response.statusCode == 204) {
      return;
    }
    throw Exception(
        _responseMessage(data, 'Failed to accept quest', response.statusCode));
  }

  // POST /quests/photo-upload-url, then PUT to the signed URL
  static Future<String> uploadQuestPhoto({
    required String questId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    if (bytes.isEmpty) throw ArgumentError('The selected photo is empty.');

    final signedUrlResponse = await _authed(() => http.post(
          Uri.parse('$baseUrl/quests/photo-upload-url'),
          headers: authHeaders,
          body: jsonEncode({
            'questId': questId,
            'fileName': fileName,
            'contentType': contentType,
          }),
        ));
    final dynamic signedData;
    try {
      signedData = jsonDecode(signedUrlResponse.body);
    } on FormatException {
      if (signedUrlResponse.body.trimLeft().startsWith('<')) {
        throw Exception(
          'The server returned an HTML error for photo upload '
          '(HTTP ${signedUrlResponse.statusCode}). Deploy the latest backend '
          'with POST /quests/photo-upload-url enabled.',
        );
      }
      throw const FormatException(
          'Photo upload service returned invalid JSON.');
    }
    if (signedUrlResponse.statusCode != 200 ||
        signedData is! Map ||
        signedData['uploadUrl'] is! String ||
        signedData['publicUrl'] is! String) {
      final message = signedData is Map ? signedData['message'] : null;
      throw Exception(message ?? 'Could not prepare photo upload');
    }

    // Signed URL goes to Supabase, not your backend: no auth refresh here.
    final uploadResponse = await http.put(
      Uri.parse(signedData['uploadUrl'] as String),
      headers: {
        'Content-Type': contentType,
        'x-upsert': 'false',
      },
      body: bytes,
    );
    if (uploadResponse.statusCode != 200 && uploadResponse.statusCode != 201) {
      throw Exception('Photo upload failed (${uploadResponse.statusCode})');
    }

    return signedData['publicUrl'] as String;
  }

  // POST /quests/:id/completion
  static Future<Map<String, dynamic>> completeQuest({
    required String questId,
    required double latitude,
    required double longitude,
    required String qrCode,
    required String photoUrl,
  }) async {
    final response = await _authed(() => http.post(
          Uri.parse('$baseUrl/quests/$questId/completion'),
          headers: authHeaders,
          body: jsonEncode({
            'lat': latitude,
            'lng': longitude,
            'qr_code': qrCode,
            'photoUrl': photoUrl,
          }),
        ));
    final data = _decodeResponseBody(response, 'POST quest completion');
    if (response.statusCode == 200 && data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw Exception(_responseMessage(
        data, 'Failed to complete quest', response.statusCode));
  }

  static Future<List<Map<String, dynamic>>> getAvatarItems() async {
    final response = await _authed(() => http.get(
          Uri.parse('$baseUrl/api/avatars/items'),
          headers: authHeaders,
        ));
    final data = _decodeResponseBody(response, 'GET avatar items');
    if (response.statusCode == 200 && data is List) {
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    throw Exception(_responseMessage(
      data,
      'Failed to load avatar items',
      response.statusCode,
    ));
  }

  static Future<Map<String, dynamic>> getMyAvatar() async {
    final response = await _authed(() => http.get(
          Uri.parse('$baseUrl/api/avatars/me'),
          headers: authHeaders,
        ));
    final data = _decodeResponseBody(response, 'GET my avatar');
    if (response.statusCode == 200 && data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw Exception(_responseMessage(
      data,
      'Failed to load your avatar',
      response.statusCode,
    ));
  }

  static Future<Map<String, dynamic>> equipAvatarItems({
    String? hair,
    String? outfit,
    String? hat,
  }) async {
    final response = await _authed(() => http.put(
          Uri.parse('$baseUrl/api/avatars/me'),
          headers: authHeaders,
          body: jsonEncode({
            'avatar': {
              'hair': hair,
              'outfit': outfit,
              'hat': hat,
            },
          }),
        ));
    final data = _decodeResponseBody(response, 'PUT equipped avatar');
    if (response.statusCode == 200 ||
        response.statusCode == 201 ||
        response.statusCode == 204) {
      return data is Map ? Map<String, dynamic>.from(data) : {};
    }
    throw Exception(_responseMessage(
      data,
      'Failed to save equipped avatar',
      response.statusCode,
    ));
  }

  static Future<Map<String, dynamic>> purchaseAvatarItem(
    String itemId,
  ) async {
    final response = await _authed(() => http.post(
          Uri.parse('$baseUrl/api/avatars/purchase'),
          headers: authHeaders,
          body: jsonEncode({'itemId': itemId}),
        ));
    final data = _decodeResponseBody(response, 'POST avatar item purchase');
    if (response.statusCode == 200 ||
        response.statusCode == 201 ||
        response.statusCode == 204) {
      return data is Map ? Map<String, dynamic>.from(data) : {};
    }
    throw Exception(_responseMessage(
      data,
      'Failed to purchase avatar item',
      response.statusCode,
    ));
  }

  // ---------------------------------------------------------------------------
  // Journal
  // ---------------------------------------------------------------------------

  // POST /api/journal (multipart)
  static Future<Map<String, dynamic>> createJournalEntry({
    required String questId,
    required Uint8List photoBytes,
    required String fileName,
    required String contentType,
    String? caption,
    String? stickerId,
  }) async {
    // Built inside the closure: a MultipartRequest can only be sent once.
    final response = await _authed(() async {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/journal'),
      );
      if (accessToken != null) {
        request.headers['Authorization'] = 'Bearer $accessToken';
      }
      request.fields['quest_id'] = questId;
      if (caption?.trim().isNotEmpty == true) {
        request.fields['caption'] = caption!.trim();
      }
      if (stickerId?.isNotEmpty == true) {
        request.fields['sticker_id'] = stickerId!;
      }
      request.files.add(
        http.MultipartFile.fromBytes(
          'photos',
          photoBytes,
          filename: fileName,
          contentType: MediaType.parse(contentType),
        ),
      );
      return http.Response.fromStream(await request.send());
    });

    final data = _decodeResponseBody(response, 'POST /api/journal');
    if ((response.statusCode == 200 || response.statusCode == 201) &&
        data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw Exception(_responseMessage(
      data,
      'Failed to upload journal photo',
      response.statusCode,
    ));
  }

  // GET /api/journal/:userId
  static Future<Map<String, dynamic>> getJournal({String? cityId}) async {
    final userId = currentUserId;
    if (userId == null) throw StateError('Log in to view your journal.');
    final uri = Uri.parse('$baseUrl/api/journal/$userId').replace(
      queryParameters: cityId == null ? null : {'city_id': cityId},
    );
    final response = await _authed(() => http.get(uri, headers: authHeaders));
    final data = _decodeResponseBody(response, 'GET /api/journal');
    if (response.statusCode == 200 && data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw Exception(
        _responseMessage(data, 'Failed to load journal', response.statusCode));
  }

  // ---------------------------------------------------------------------------
  // Preferences & recommendations
  // ---------------------------------------------------------------------------

  static Future<List<dynamic>> getCraftCategories(String cityId) async {
    final response = await _authed(() => http.get(
          Uri.parse(
              '$baseUrl/api/preferences/cities/${Uri.encodeComponent(cityId)}/craft-categories'),
          headers: authHeaders,
        ));
    final data = _decodeResponseBody(response, 'GET craft categories');
    if (response.statusCode == 200 && data is List) return data;
    throw Exception(_responseMessage(
      data,
      'Failed to load craft categories',
      response.statusCode,
    ));
  }

  static Future<List<dynamic>> getArtisansByCity(String cityId) async {
    final response = await _authed(() => http.get(
          Uri.parse(
              '$baseUrl/api/artisans/city/${Uri.encodeComponent(cityId)}'),
          headers: authHeaders,
        ));
    final data = _decodeResponseBody(response, 'GET artisans by city');
    if (response.statusCode == 200 && data is List) return data;
    throw Exception(_responseMessage(
      data,
      'Failed to load artisans',
      response.statusCode,
    ));
  }

  static Future<void> saveCraftPreferences(
      List<String> craftCategoryIds) async {
    final userId = currentUserId;
    if (accessToken?.isNotEmpty != true || userId == null) {
      throw StateError('Log in again before saving craft preferences.');
    }
    final response = await _authed(() => http.post(
          Uri.parse('$baseUrl/api/preferences'),
          headers: authHeaders,
          body: jsonEncode({'craftCategoryIds': craftCategoryIds}),
        ));
    final data = _decodeResponseBody(response, 'POST /api/preferences');
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    final serverMessage = data is Map ? data['error'] ?? data['message'] : null;
    final message = serverMessage is String && serverMessage.isNotEmpty
        ? serverMessage
        : 'Failed to save preferences';
    throw Exception('$message (HTTP ${response.statusCode})');
  }

  static Future<List<dynamic>> getRecommendations() async {
    final userId = currentUserId;
    if (userId == null) throw StateError('Log in to view recommendations.');
    final response = await _authed(() => http.get(
          Uri.parse('$baseUrl/api/recommendations/$userId'),
          headers: authHeaders,
        ));
    final data = _decodeResponseBody(response, 'GET recommendations');
    if (response.statusCode == 200 && data is List) return data;
    throw Exception(_responseMessage(
      data,
      'Failed to load recommendations',
      response.statusCode,
    ));
  }

  // ---------------------------------------------------------------------------
  // Ratings
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> submitRating({
    required int rating,
    String? questId,
    String? sellerId,
    String? reviewText,
  }) async {
    final response = await _authed(() => http.post(
          Uri.parse('$baseUrl/ratings'),
          headers: authHeaders,
          body: jsonEncode({
            'rating': rating,
            if (questId != null) 'questId': questId,
            if (sellerId != null) 'sellerId': sellerId,
            if (reviewText != null) 'reviewText': reviewText,
          }),
        ));
    final data = _decodeResponseBody(response, 'POST /ratings');
    if (response.statusCode == 201 && data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw Exception(
        _responseMessage(data, 'Failed to submit rating', response.statusCode));
  }

  // ---------------------------------------------------------------------------
  // Quiz
  // ---------------------------------------------------------------------------

  // POST /quiz/:questId/start
  static Future<Map<String, dynamic>> startQuiz(String questId) async {
    final response = await _authed(() => http.post(
          Uri.parse('$baseUrl/quiz/$questId/start'),
          headers: authHeaders,
        ));
    final data = _decodeResponseBody(response, 'POST quiz start');
    if (response.statusCode == 200 && data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw Exception(
        _responseMessage(data, 'Failed to start quiz', response.statusCode));
  }

  // POST /quiz/:questId/answer
  static Future<Map<String, dynamic>> submitQuizAnswer({
    required String questId,
    required String attemptId,
    required String questionId,
    required String selectedOption,
  }) async {
    final response = await _authed(() => http.post(
          Uri.parse('$baseUrl/quiz/$questId/answer'),
          headers: authHeaders,
          body: jsonEncode({
            'attemptId': attemptId,
            'questionId': questionId,
            'selectedOption': selectedOption,
          }),
        ));
    final data = _decodeResponseBody(response, 'POST quiz answer');
    if (response.statusCode == 200 && data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw Exception(
        _responseMessage(data, 'Failed to submit answer', response.statusCode));
  }

  // GET /quiz/:attemptId/finish
  static Future<Map<String, dynamic>> finishQuiz(String attemptId) async {
    final response = await _authed(() => http.get(
          Uri.parse('$baseUrl/quiz/$attemptId/finish'),
          headers: authHeaders,
        ));
    final data = _decodeResponseBody(response, 'GET quiz finish');
    if (response.statusCode == 200 && data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw Exception(
        _responseMessage(data, 'Failed to finish quiz', response.statusCode));
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static dynamic _decodeResponseBody(http.Response response, String endpoint) {
    if (response.body.trim().isEmpty) return null;
    try {
      return jsonDecode(response.body);
    } on FormatException {
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('$endpoint failed (HTTP ${response.statusCode}).');
      }
      throw FormatException('$endpoint returned an invalid response.');
    }
  }

  static String _responseMessage(
    dynamic data,
    String fallback,
    int statusCode,
  ) {
    if (data is Map) {
      final message = data['error'] ?? data['message'];
      if (message is String && message.isNotEmpty) return message;
    }
    return '$fallback (HTTP $statusCode)';
  }
}
