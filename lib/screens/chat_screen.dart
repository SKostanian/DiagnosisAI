import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:diagnosis_ai/triage/models.dart';
import 'package:diagnosis_ai/triage/session_api.dart';

class TriageChatArgs {
  final List<String> selectedAreas;
  TriageChatArgs(this.selectedAreas);
}

class TriageChatScreen extends StatefulWidget {
  static const routeName = '/triage_chat';
  final List<String> selectedAreas;
  const TriageChatScreen({super.key, required this.selectedAreas});

  @override
  State<TriageChatScreen> createState() => _TriageChatScreenState();
}

class _TriageChatScreenState extends State<TriageChatScreen> {
  final _api = SessionApi();
  bool _depsReady = false;

  String? _sessionId;
  TriageQuestion? _currentQ;
  TriageDiagnosis? _finalDx;
  final List<_Bubble> _bubbles = [];
  final _textCtrl = TextEditingController();
  bool _loading = true;
  String? _singleSelected;
  String? _error;

  @override
  void initState() {
    super.initState();
    // context not ready yet, I call it in changeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_depsReady) {
      _depsReady = true;
      _start(); // safe to use start here, it was my mistake earlier
    }
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final localeTag = context.locale.toLanguageTag();
      final result = await _api.startSession(
        localeTag: localeTag,
        selectedAreas: widget.selectedAreas,
      );
      _sessionId = result.sessionId;
      if (result.question != null) {
        _currentQ = result.question;
        _bubbles.add(_Bubble.bot(result.question!.text));
      } else if (result.diagnosis != null) {
        _finalDx = result.diagnosis;
        _bubbles.add(_Bubble.bot("${result.diagnosis!.explanationPatient}"));
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _submitAnswer(dynamic valueToSend, String humanReadable) async {
    if (_sessionId == null || _currentQ == null) return;

    setState(() {
      _bubbles.add(_Bubble.user(humanReadable));
      _loading = true;
      _error = null;
    });

    try {
      final res = await _api.postAnswer(
        sessionId: _sessionId!,
        questionId: _currentQ!.id,
        value: valueToSend,
      );
      if (res.question != null) {
        _currentQ = res.question;
        _finalDx = null;
        _bubbles.add(_Bubble.bot(_currentQ!.text));
      } else {
        _currentQ = null;
        _finalDx = res.diagnosis;
        _bubbles.add(_Bubble.bot("${_finalDx!.explanationPatient}"));
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _textCtrl.clear();
      _singleSelected = null;
      setState(() => _loading = false);
    }
  }

  Widget _answerInput() {
    if (_finalDx != null || _currentQ == null) {
      // when Diagnosis is ready - show short summary (and red flags if any)
      return const SizedBox.shrink();
    }

    switch (_currentQ!.type) {
      case 'single':
        final opts = _currentQ!.options;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: opts.map((o) {
            final selected = _singleSelected == o;
            return ChoiceChip(
              label: Text(o),
              selected: selected,
              onSelected: (val) {
                if (val) {
                  _singleSelected = o;
                  _submitAnswer(o, o);
                }
              },
            );
          }).toList(),
        );

      case 'number':
        return Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: _currentQ!.unit != null
                      ? 'Enter number (${_currentQ!.unit})'
                      : 'Enter number',
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                final raw = _textCtrl.text.trim();
                if (raw.isEmpty) return;
                final num? parsed = num.tryParse(raw);
                if (parsed == null) return;
                final label = _currentQ!.unit != null ? '$raw ${_currentQ!.unit}' : raw;
                _submitAnswer(parsed, label.toString());
              },
              child: const Text('OK'),
            ),
          ],
        );

      case 'text':
      default:
        return Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textCtrl,
                decoration: const InputDecoration(hintText: 'Type your answer...'),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                final raw = _textCtrl.text.trim();
                if (raw.isEmpty) return;
                _submitAnswer(raw, raw);
              },
              child: const Text('Send'),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Triage')),
      body: Column(
        children: [
          if (_error != null)
            Container(
              color: Colors.red.withOpacity(0.1),
              padding: const EdgeInsets.all(8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _bubbles.length,
              itemBuilder: (_, i) {
                final b = _bubbles[i];
                final align = b.isUser ? Alignment.centerRight : Alignment.centerLeft;
                final color = b.isUser
                    ? (isDark ? Colors.blueGrey.shade700 : Colors.blue.shade100)
                    : (isDark ? Colors.grey.shade800 : Colors.white);
                return Align(
                  alignment: align,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(maxWidth: 520),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Text(b.text),
                  ),
                );
              },
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: _answerInput(),
          ),
        ],
      ),
    );
  }
}

class _Bubble {
  final bool isUser;
  final String text;
  _Bubble.user(this.text) : isUser = true;
  _Bubble.bot(this.text) : isUser = false;
}
