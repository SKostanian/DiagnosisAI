import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:diagnosis_ai/triage/models.dart';

// clas to handle communication with server using Firebase and HTTP
class SessionApi {
  final FirebaseFunctions _fns; // firebase functions instance

  // constructor, connect to emulator in debug mode
  SessionApi({FirebaseFunctions? functions})
      : _fns = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1') {
    if (kDebugMode) {
      final host = (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
          ? '10.0.2.2' // android emulator localhost
          : 'localhost'; // other platforms
      _fns.useFunctionsEmulator(host, 5001);
    }
  }

  // private getter to build the base URL for fallback requests
  String get _httpBase {
    final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final host = isAndroid ? '10.0.2.2' : 'localhost';
    final projectId = Firebase.app().options.projectId;
    return 'http://$host:5001/$projectId/us-central1';
  }

  // request timeout
  static const Duration _httpTimeout = Duration(seconds: 90);

  // check if should fall back to plain http request
  bool _shouldFallbackToHttp(FirebaseFunctionsException e) {
    return kDebugMode &&
        (e.code == 'internal' ||
            e.code == 'not-found' ||
            e.code == 'deadline-exceeded' ||
            e.code == 'unavailable');
  }

  // get firebase ID token for auth
  Future<String> _getIdToken() async {
    var user = FirebaseAuth.instance.currentUser
        ?? (await FirebaseAuth.instance.signInAnonymously()).user;
    if (user == null) throw Exception('no user');
    final String? token = await user.getIdToken(true); // force get token
    if (token == null || token.isEmpty) throw Exception('failed to get token');
    return token; // safe to return, not null here
  }

  // safe map cast helper
  Map<String, dynamic> _asMapSD(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    throw const FormatException('expected a Map');
  }

  // safe list cast helper
  List _asListSD(dynamic raw) => (raw is List) ? raw : const [];

  // normalize answers before sending
  dynamic _normalizeForWire({
    required TriageQuestion? questionMeta,
    required dynamic value,
  }) {
    final q = questionMeta;
    // if number or scale, convert to int within range
    if (q != null && (q.type == 'number' || q.type == 'scale')) {
      final n = TriageQuestion.parseNumericAnswer(
        value,
        min: q.sliderMin.toInt(),
        max: q.sliderMax.toInt(),
      );
      return n ?? 0;
    }
    // if multi select, then always list of strings
    if (q != null && q.type == 'multi') {
      final list = _asListSD(value)
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      return list;
    }
    // if single choice, string
    if (q != null && q.type == 'single') {
      return value?.toString() ?? '';
    }
    // fallback, string
    return value?.toString() ?? '';
  }

  // parse start sesssion response
  ({String sessionId, TriageQuestion? question, TriageDiagnosis? diagnosis}) _parseStart(dynamic raw) {
    final data = _asMapSD(raw);
    final sessionId = (data['sessionId'] ??
        data['session_id'] ??
        data['id'] ??
        (data['session'] is Map ? _asMapSD(data['session'])['id'] : null))
        ?.toString();
    if (sessionId == null || sessionId.isEmpty) throw const FormatException('missing sessionId');
    final type = (data['type'] ?? (data['question'] != null ? 'question' : 'diagnosis')).toString();
    if (type == 'question') {
      final qMap = _asMapSD(data['question'] ?? data);
      return (sessionId: sessionId, question: TriageQuestion.fromMap(qMap), diagnosis: null);
    } else {
      final dxMap = _asMapSD(data['diagnosis'] ?? data);
      return (sessionId: sessionId, question: null, diagnosis: TriageDiagnosis.fromMap(dxMap));
    }
  }

  // parse step response (after answer)
  ({TriageQuestion? question, TriageDiagnosis? diagnosis}) _parseStep(dynamic raw) {
    final data = _asMapSD(raw);
    final type = (data['type'] ?? (data['question'] != null ? 'question' : 'diagnosis')).toString();
    if (type == 'question') {
      final qMap = _asMapSD(data['question'] ?? data);
      return (question: TriageQuestion.fromMap(qMap), diagnosis: null);
    } else {
      final dxMap = _asMapSD(data['diagnosis'] ?? data);
      return (question: null, diagnosis: TriageDiagnosis.fromMap(dxMap));
    }
  }

  // start a new session, using cloud function or fallback
  Future<({String sessionId, TriageQuestion? question, TriageDiagnosis? diagnosis})> startSession({
    required String localeTag,
    required List<String> selectedAreas,
  }) async {
    try {
      final call = _fns.httpsCallable('startSession');
      final res = await call.call({'locale': localeTag, 'selectedAreas': selectedAreas});
      return _parseStart(res.data);
    } on FirebaseFunctionsException catch (e) {
      if (_shouldFallbackToHttp(e)) {
        final token = await _getIdToken();
        final uri = Uri.parse('$_httpBase/startSession');
        final r = await http.post(uri, headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        }, body: jsonEncode({'data': {'locale': localeTag, 'selectedAreas': selectedAreas}}))
            .timeout(_httpTimeout);
        if (r.statusCode >= 400) throw Exception('HTTP ${r.statusCode}: ${r.body}');
        final decoded = jsonDecode(r.body);
        final payload = (decoded is Map && decoded['result'] != null) ? decoded['result'] : decoded;
        return _parseStart(payload);
      }
      rethrow;
    }
  }

  // send answer, with question meta for normalization
  Future<({TriageQuestion? question, TriageDiagnosis? diagnosis})> postAnswer({
    required String sessionId,
    required String questionId,
    required dynamic value,
    TriageQuestion? questionMeta,
  }) async {
    final cleanValue = _normalizeForWire(questionMeta: questionMeta, value: value);
    try {
      final call = _fns.httpsCallable('postAnswer');
      final res = await call.call({
        'sessionId': sessionId,
        'questionId': questionId,
        'value': cleanValue,
      });
      return _parseStep(res.data);
    } on FirebaseFunctionsException catch (e) {
      if (_shouldFallbackToHttp(e)) {
        final token = await _getIdToken();
        final uri = Uri.parse('$_httpBase/postAnswer');
        final payload = {
          'data': {'sessionId': sessionId, 'questionId': questionId, 'value': cleanValue}
        };
        // try several times if error
        const maxAttempts = 3;
        Exception? lastErr;
        for (var attempt = 1; attempt <= maxAttempts; attempt++) {
          try {
            final r = await http.post(uri, headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
              'Connection': 'close',
            }, body: jsonEncode(payload)).timeout(_httpTimeout);
            if (r.statusCode >= 400) throw Exception('HTTP ${r.statusCode}: ${r.body}');
            final decoded = jsonDecode(r.body);
            final result = (decoded is Map && decoded['result'] != null) ? decoded['result'] : decoded;
            return _parseStep(result);
          } catch (err) {
            lastErr = err is Exception ? err : Exception(err.toString());
            if (attempt < maxAttempts) {
              await Future.delayed(Duration(milliseconds: 300 * attempt));
            }
          }
        }
        throw lastErr ?? Exception('HTTP fallback failed');
      }
      rethrow;
    }
  }
}
