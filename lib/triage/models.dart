class TriageQuestion {
  final String id;
  final String text;
  final String type; // single | multi | number | text | scale
  final List<String> options; // single/multi
  final String? unit; // number/scale

  TriageQuestion({
    required this.id,
    required this.text,
    required this.type,
    this.options = const [],
    this.unit,
  });

  factory TriageQuestion.fromMap(Map<String, dynamic> m) {
    return TriageQuestion(
      id: m['id'] as String,
      text: m['text'] as String,
      type: m['type'] as String,
      options: (m['options'] as List?)?.cast<String>() ?? const [],
      unit: m['unit'] as String?,
    );
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

  factory DxItem.fromMap(Map<String, dynamic> m) => DxItem(
    code: m['code'] as String,
    system: m['system'] as String,
    label: m['label'] as String,
    prob: (m['prob'] as num).toDouble(),
  );
}

class TriageDiagnosis {
  final List<DxItem> dx;
  final double confidence;
  final List<String> redFlags;
  final String explanationPatient;
  final String summaryClinician;

  TriageDiagnosis({
    required this.dx,
    required this.confidence,
    required this.redFlags,
    required this.explanationPatient,
    required this.summaryClinician,
  });

  factory TriageDiagnosis.fromMap(Map<String, dynamic> m) => TriageDiagnosis(
    dx: (m['dx'] as List).map((e) => DxItem.fromMap(e)).toList(),
    confidence: (m['confidence'] as num).toDouble(),
    redFlags: (m['redFlags'] as List?)?.cast<String>() ?? const [],
    explanationPatient: m['explanation_patient'] as String,
    summaryClinician: m['summary_clinician'] as String,
  );
}
