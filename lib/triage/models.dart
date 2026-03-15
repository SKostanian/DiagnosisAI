class TriageQuestion {
  final String id;
  final String text;
  final String type; // single or multi | number | text type or owthers
  final String topic; // quality | severity | duration
  final List<String> options; // for single/multi
  final String? unit; // 1-10 for number/scale questions

  TriageQuestion({
    required this.id,
    required this.text,
    required this.type,
    required this.topic,
    this.options = const [],
    this.unit,
  });

  // turns data into map
  static Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) {
      // map method - Map class - dart:core library - Dart API (2026) Dart.dev.
      // Available at: https://api.dart.dev/dart-core/Map/map.html (Accessed: March 15, 2026).
      return v.map((k, val) => MapEntry(k.toString(), val));

      // MapEntry class - dart:core library - Dart API (2026) Dart.dev.
      // Available at: https://api.dart.dev/dart-core/MapEntry-class.html (Accessed: March 15, 2026).
    }
    return <String, dynamic>{};
  }

  static List _asList(dynamic v) {
    // Operators (2026) Dart.dev.
    // Available at: https://dart.dev/language/operators (Accessed: March 15, 2026).
    if (v is List) return v;
    return const [];
  }

  static List<String> _asStringList(dynamic v) {
    final raw = _asList(v);
    return raw
        // сonvert each element toStrring
        // If element is null replace it with empty string.
        .map((e) => e?.toString() ?? "")

        // filter emptry strings
        // Where method (2026) Dart.dev.
        // Available at: https://api.dart.dev/dart-core/Iterable/where.html (Accessed: March 15, 2026).
        .where((e) => e.isNotEmpty)
        .toList();
  }

  // (2026) Stackoverflow.com.
  // Available at: https://stackoverflow.com/questions/52299304/dart-advantage-of-a-factory-constructor-identifier (Accessed: March 15, 2026).
  factory TriageQuestion.fromMap(Map<String, dynamic> m) {
    // I have data which is constant
    final mm = _asMap(m);
    return TriageQuestion(
      id: mm['id']?.toString() ?? '',
      text: mm['text']?.toString() ?? '',
      type: mm['type']?.toString() ?? 'text',
      topic: mm['topic']?.toString() ?? '',
      options: _asStringList(mm['options']),
      unit: mm['unit'] == null ? null : mm['unit'].toString(),
    );
  }

  // Constructors (2026) Dart.dev.
  // Available at: https://dart.dev/language/constructors (Accessed: March 15, 2026).
  factory TriageQuestion.fromJson(Map<String, dynamic> json) {
    return TriageQuestion.fromMap(json);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'type': type,
      'topic': topic,
      'options': options,
      'unit': unit,
    };
  }

  bool get isChoice => type == 'single';
  bool get isMulti => type == 'multi';
  bool get isScaleLike =>
      type == 'scale' ||
          // regular expression, r is raw string,
          // Built-in types (2026) Dart.dev. Available at: https://dart.dev/language/built-in-types (Accessed: March 15, 2026).

          // d+ in Regex is 1 or more number, s* is space
          // RegExp class - dart:core library - Dart API (2026)
          // Dart.dev. Available at: https://api.dart.dev/dart-core/RegExp-class.html (Accessed: March 15, 2026).
          (type == 'number' && RegExp(r'\d+\s*-\s*\d+').hasMatch(unit ?? ''));


  double get sliderMin {
    // Records (2026) Dart.dev.
    // Available at: https://dart.dev/language/records (Accessed: March 15, 2026).
    final r = _extractRange(unit);
    return (r?.$1 ?? 1).toDouble();
  }

  // like (1, 10) or (5, 20) if null then it is (1, 10)
  double get sliderMax {
    final r = _extractRange(unit);
    return (r?.$2 ?? 10).toDouble();
  }


  static (int, int)? _extractRange(String? u) {
    if (u == null) return (1, 10);
    // normalisation
    final s = u.replaceAll('—', '-').replaceAll('..', '-');

    // again regex, -? means that number can ne negative
    final m = RegExp(r'(-?\d+)\s*-\s*(-?\d+)').firstMatch(s);
    if (m != null) {
      // parse to int
      // group method - Match class - dart:core library - Dart API (2026) Flutter.dev.
      // Available at: https://api.flutter.dev/flutter/dart-core/Match/group.html (Accessed: March 15, 2026).
      final a = int.tryParse(m.group(1)!);
      final b = int.tryParse(m.group(2)!);
      if (a != null && b != null) {
        return (a, b);
      }
    }
    return (1, 10);
  }

  // extract a number from user input and return it as an int
  static int? parseNumericAnswer(dynamic v, {int min = 1, int max = 10}) {
    if (v is num) {
      // round it
      final n = v.round();

      // clamp method - num class - dart:core library - Dart API (2026) Flutter.dev.
      // Available at: https://api.flutter.dev/flutter/dart-core/num/clamp.html (Accessed: March 15, 2026).
      return n.clamp(min, max);
    }
    final s = v?.toString() ?? '';

    // Non-capturing group: (?:...) (2026) MDN Web Docs.
    // Available at: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Regular_expressions/Non-capturing_group (Accessed: March 15, 2026).
    final m = RegExp(r'-?\d+(?:[.,]\d+)?').firstMatch(s);
    if (m == null) return null;

    // replaceAll method - String class - dart:core library - Dart API (2026) Dart.dev.
    // Available at: https://api.dart.dev/dart-core/String/replaceAll.html (Accessed: March 15, 2026).
    final n = double.tryParse(m.group(0)!.replaceAll(',', '.'))?.round();
    if (n == null) return null;
    return n.clamp(min, max);
  }
}

// class of diagnosis
class DxItem {

  // diagnosis code, system of classsification, label of diagnosis and probability
  final String code;
  final String system;
  final String label;
  final double prob;

  DxItem({
    required this.code,
    required this.system,
    required this.label,
    required this.prob,
  });

  // I do the same mapping as before
  static Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
    return <String, dynamic>{};
  }

  factory DxItem.fromMap(Map<String, dynamic> m) {
    final mm = _asMap(m);
    return DxItem(
      code: mm['code']?.toString() ?? '',
      system: mm['system']?.toString() ?? '',
      label: mm['label']?.toString() ?? '',
      prob: (mm['prob'] as num?)?.toDouble() ?? 0.0,
    );
  }

  factory DxItem.fromJson(Map<String, dynamic> json) {
    return DxItem.fromMap(json);
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'system': system,
      'label': label,
      'prob': prob,
    };
  }
}

class TriageDiagnosis {
  final List<DxItem> dx;
  final double confidence;
  final List<String> redFlags;
  final String explanationPatient;
  final String summaryClinician;

  final List<String> actionsNow;
  final List<String> seekCareIf;
  final String patientText;
  final String clinicianText;

  TriageDiagnosis({
    required this.dx,
    required this.confidence,
    required this.redFlags,
    required this.explanationPatient,
    required this.summaryClinician,
    this.actionsNow = const [],
    this.seekCareIf = const [],
    this.patientText = '',
    this.clinicianText = '',
  });

  static Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
    return <String, dynamic>{};
  }

  static List _asList(dynamic v) {
    if (v is List) return v;
    return const [];
  }

  static List<String> _asStringList(dynamic v) {
    final raw = _asList(v);
    return raw
        .map((e) => e?.toString() ?? "")
        .where((e) => e.isNotEmpty)
        .toList();
  }

  factory TriageDiagnosis.fromMap(Map<String, dynamic> m) {
    final mm = _asMap(m);
    final dxList = _asList(mm['dx'])
        .map((e) => DxItem.fromMap(_asMap(e)))
        .toList()
        // cast method - List class - dart:core library - Dart API (2026) Dart.dev.
        // Available at: https://api.dart.dev/dart-core/List/cast.html (Accessed: March 15, 2026).
        .cast<DxItem>();

    return TriageDiagnosis(
      dx: dxList,
      // confidence is double
      confidence: (mm['confidence'] as num?)?.toDouble() ?? 0.0,
      redFlags: _asStringList(mm['redFlags']),
      explanationPatient: mm['explanation_patient']?.toString() ?? '',
      summaryClinician: mm['summary_clinician']?.toString() ?? '',
      actionsNow: _asStringList(mm['actions_now']),
      seekCareIf: _asStringList(mm['seek_care_if']),
      patientText: mm['patientText']?.toString() ?? '',
      clinicianText: mm['clinicianText']?.toString() ?? '',
    );
  }

  factory TriageDiagnosis.fromJson(Map<String, dynamic> json) {
    return TriageDiagnosis.fromMap(json);
  }

  Map<String, dynamic> toJson() {
    return {
      'dx': dx.map((e) => e.toJson()).toList(),
      'confidence': confidence,
      'redFlags': redFlags,
      'explanation_patient': explanationPatient,
      'summary_clinician': summaryClinician,
      'actions_now': actionsNow,
      'seek_care_if': seekCareIf,
      'patientText': patientText,
      'clinicianText': clinicianText,
    };
  }
}