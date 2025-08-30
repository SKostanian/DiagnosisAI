// lib/triage/session_api.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:diagnosis_ai/triage/models.dart';

class SessionApi {
  final FirebaseFunctions _fns;
  SessionApi({FirebaseFunctions? functions})
      : _fns = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  // Base url for local emulator (used only in debug mode)
  String get _httpBase {
    final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final host = isAndroid ? '10.0.2.2' : 'localhost';
    return 'http://$host:5001/health-app-9b2f5/us-central1';
  }

  // Timeout for http requests
  static const Duration _httpTimeout = Duration(seconds: 90);

  // Decide if we should use http fallback instead of FirebaseFunctions
  bool _shouldFallbackToHttp(FirebaseFunctionsException e) {
    return kDebugMode &&
        (e.code == 'internal' ||
            e.code == 'not-found' ||
            e.code == 'deadline-exceeded');
  }

  // Get Firebase id token for the current user
  Future<String> _getIdToken() async {
    final user = FirebaseAuth.instance.currentUser
        ?? (await FirebaseAuth.instance.signInAnonymously()).user;

    // Try to get normal token
    String? token = await user!.getIdToken();
    if (token != null && token.isNotEmpty) return token;

    // Try to force refresh if token is empty
    token = await user.getIdToken(true);
    if (token != null && token.isNotEmpty) return token;

    // Throw error if no token at all
    throw Exception('Failed to obtain Firebase ID token');
  }

  // Start session using Firebase function or http fallback
  Future<({String sessionId, TriageQuestion? question, TriageDiagnosis? diagnosis})>
  startSession({
    required String localeTag,
    required List<String> selectedAreas,
  }) async {
    try {
      final call = _fns.httpsCallable('startSession');
      final res = await call.call({
        'locale': localeTag,
        'selectedAreas': selectedAreas,
      });
      return _parseStart(res.data);
    } on FirebaseFunctionsException catch (e) {
      if (_shouldFallbackToHttp(e)) {
        final token = await _getIdToken();
        final uri = Uri.parse('$_httpBase/startSession');
        final r = await http
            .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          // Callable http functions expect data inside "data" object
          body: jsonEncode({
            'data': {
              'locale': localeTag,
              'selectedAreas': selectedAreas,
            },
          }),
        )
            .timeout(_httpTimeout);

        if (r.statusCode >= 400) {
          throw Exception('HTTP ${r.statusCode}: ${r.body}');
        }
        final decoded = jsonDecode(r.body) as Map<String, dynamic>;
        final payload = (decoded['result'] ?? decoded) as Map<String, dynamic>;
        return _parseStart(payload);
      }
      rethrow;
    }
  }

  // Post an answer to the server and get next question or diagnosis
  Future<({TriageQuestion? question, TriageDiagnosis? diagnosis})> postAnswer({
    required String sessionId,
    required String questionId,
    required dynamic value,
  }) async {
    try {
      final call = _fns.httpsCallable('postAnswer');
      final res = await call.call({
        'sessionId': sessionId,
        'questionId': questionId,
        'value': value,
      });
      return _parseStep(res.data);
    } on FirebaseFunctionsException catch (e) {
      if (_shouldFallbackToHttp(e)) {
        final token = await _getIdToken();
        final uri = Uri.parse('$_httpBase/postAnswer');

        // Payload when using http
        final payload = {
          'data': {
            'sessionId': sessionId,
            'questionId': questionId,
            'value': value,
          },
        };

        // Retry a few times if connection is unstable
        const maxAttempts = 3;
        Exception? lastErr;
        for (var attempt = 1; attempt <= maxAttempts; attempt++) {
          try {
            debugPrint('[postAnswer HTTP attempt $attempt] $payload');
            final r = await http
                .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
                'Connection': 'close', // helps avoid connection reset
              },
              body: jsonEncode(payload),
            )
                .timeout(_httpTimeout);

            if (r.statusCode >= 400) {
              throw Exception('HTTP ${r.statusCode}: ${r.body}');
            }

            final decoded = jsonDecode(r.body) as Map<String, dynamic>;
            final result = (decoded['result'] ?? decoded) as Map<String, dynamic>;
            return _parseStep(result);
          } catch (err) {
            lastErr = err is Exception ? err : Exception(err.toString());
            if (attempt < maxAttempts) {
              await Future.delayed(Duration(milliseconds: 300 * attempt));
              continue;
            }
          }
        }
        throw lastErr ?? Exception('HTTP fallback failed');
      }
      rethrow;
    }
  }

  // Parse startSession response to get session id, first question or diagnosis
  ({String sessionId, TriageQuestion? question, TriageDiagnosis? diagnosis})
  _parseStart(dynamic raw) {
    debugPrint('[startSession raw] $raw');
    final data = Map<String, dynamic>.from(raw as Map);

    final sessionId = (data['sessionId'] ??
        data['session_id'] ??
        data['id'] ??
        (data['session'] is Map ? (data['session'] as Map)['id'] : null))
    as String?;

    if (sessionId == null || sessionId.isEmpty) {
      throw const FormatException('startSession: missing sessionId in response');
    }

    final hasQuestionObj = data['question'] != null;
    final looksInlineQuestion = data['type'] == 'question';

    if (hasQuestionObj || looksInlineQuestion) {
      final qMap = hasQuestionObj ? data['question'] : data;
      return (
      sessionId: sessionId,
      question: TriageQuestion.fromMap(Map<String, dynamic>.from(qMap as Map)),
      diagnosis: null,
      );
    } else {
      final dxMap = data['diagnosis'] ?? data;
      return (
      sessionId: sessionId,
      question: null,
      diagnosis: TriageDiagnosis.fromMap(Map<String, dynamic>.from(dxMap as Map)),
      );
    }
  }

  // Parse postAnswer response to find if it is a question or a diagnosis
  ({TriageQuestion? question, TriageDiagnosis? diagnosis}) _parseStep(dynamic raw) {
    debugPrint('[postAnswer raw] $raw');
    final data = Map<String, dynamic>.from(raw as Map);

    final type =
    (data['type'] ?? (data['question'] != null ? 'question' : 'diagnosis')) as String;

    if (type == 'question') {
      final qMap = data['question'] ?? data;
      return (
      question: TriageQuestion.fromMap(Map<String, dynamic>.from(qMap as Map)),
      diagnosis: null,
      );
    } else {
      final dxMap = data['diagnosis'] ?? data;
      return (
      question: null,
      diagnosis: TriageDiagnosis.fromMap(Map<String, dynamic>.from(dxMap as Map)),
      );
    }
  }
}
