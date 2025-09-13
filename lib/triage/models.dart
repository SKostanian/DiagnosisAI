class TriageQuestion {
  final String id;
  final String text;
  final String type; // single or multi | number | text type or owthers
  final String topic; // quality | severity | duration
  final List<String> options; // for single/multi
  final String? unit; // 0-10 for number/scale questions

  TriageQuestion({
    required this.id,
    required this.text,
    required this.type,
    required this.topic,
    this.options = const [],
    this.unit,
  });

  // helpers
  static Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) {
      return v.map((k, val) => MapEntry(k.toString(), val));
    }
    return <String, dynamic>{};
  }

  static List _asList(dynamic v) {
    if (v is List) return v;
    return const [];
  }

  static List<String> _asStringList(dynamic v) {
    final raw = _asList(v);
    return raw.map((e) => e?.toString() ?? "").where((e) => e.isNotEmpty).toList();
  }

  // decoding from map
  factory TriageQuestion.fromMap(Map<String, dynamic> m) {
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

  // UI convenience
  bool get isChoice => type == 'single';
  bool get isMulti  => type == 'multi';
  bool get isScaleLike => type == 'scale' || (type == 'number' && (unit?.contains('0-10') ?? false));

  // Min/max for slider
  double get sliderMin {
    final r = _extractRange(unit);
    return (r?.$1 ?? 0).toDouble();
  }

  double get sliderMax {
    final r = _extractRange(unit);
    return (r?.$2 ?? 10).toDouble();
  }

  static (int, int)? _extractRange(String? u) {
    if (u == null) return (0, 10);
    final s = u.replaceAll('—', '-').replaceAll('..', '-');
    final m = RegExp(r'(-?\d+)\s*-\s*(-?\d+)').firstMatch(s);
    if (m != null) {
      final a = int.tryParse(m.group(1)!);
      final b = int.tryParse(m.group(2)!);
      if (a != null && b != null) {
        return (a, b);
      }
    }
    return (0, 10);
  }

  // parse user type into number
  static int? parseNumericAnswer(dynamic v, {int min = 0, int max = 10}) {
    if (v is num) {
      final n = v.round();
      return n.clamp(min, max);
    }
    final s = v?.toString() ?? '';
    final m = RegExp(r'-?\d+(?:[.,]\d+)?').firstMatch(s);
    if (m == null) return null;
    final n = double.tryParse(m.group(0)!.replaceAll(',', '.'))?.round();
    if (n == null) return null;
    return n.clamp(min, max);
  }
}

class DxItem {
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

  static Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
    return <String, dynamic>{};
  }

  factory DxItem.fromMap(Map<String, dynamic> m) {
    final mm = _asMap(m);
    return DxItem(
      code:   mm['code']?.toString() ?? '',
      system: mm['system']?.toString() ?? '',
      label:  mm['label']?.toString() ?? '',
      prob:   (mm['prob'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class TriageDiagnosis {
  final List<DxItem> dx;
  final double confidence;
  final List<String> redFlags;
  final String explanationPatient;
  final String summaryClinician;

  // new fields from the server
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
    return raw.map((e) => e?.toString() ?? "").where((e) => e.isNotEmpty).toList();
  }

  factory TriageDiagnosis.fromMap(Map<String, dynamic> m) {
    final mm = _asMap(m);
    final dxList = _asList(mm['dx'])
        .map((e) => DxItem.fromMap(_asMap(e)))
        .toList()
        .cast<DxItem>();

    return TriageDiagnosis(
      dx: dxList,
      confidence: (mm['confidence'] as num?)?.toDouble() ?? 0.0,
      redFlags: _asStringList(mm['redFlags']),
      explanationPatient: mm['explanation_patient']?.toString() ?? '',
      summaryClinician:   mm['summary_clinician']?.toString() ?? '',
      actionsNow: _asStringList(mm['actions_now']),
      seekCareIf: _asStringList(mm['seek_care_if']),
      patientText: mm['patientText']?.toString() ?? '',
      clinicianText: mm['clinicianText']?.toString() ?? '',
    );
  }
}
