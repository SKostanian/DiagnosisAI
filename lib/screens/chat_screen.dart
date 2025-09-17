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
  final _askedIds = <String>{};
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  bool _loading = true;
  String? _error;

  // --- UI state for current answer ---
  String? _singleSelected;
  final Set<String> _multiSelected = <String>{};
  double _sliderVal = 5;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_depsReady) {
      _depsReady = true;
      _start();
    }
  }

  void _resetAnswerUi() {
    _singleSelected = null;
    _multiSelected.clear();
    _sliderVal = 5;
    _textCtrl.clear();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
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
        final q = result.question!;
        if (!_askedIds.contains(q.id)) {
          _askedIds.add(q.id);
          _currentQ = q;
          _bubbles.add(_Bubble.bot(q.text));
          _resetAnswerUi();
          _scrollToBottom();
        }
      } else if (result.diagnosis != null) {
        _finalDx = result.diagnosis;
        // if no empty then display
        final displayText = _finalDx!.patientText.isNotEmpty
            ? _finalDx!.patientText
            : _finalDx!.explanationPatient;
        _bubbles.add(_Bubble.bot(displayText));
        _scrollToBottom();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _loading = false);
    }
  }

  String _formatNumberLabel(num v, String? unit) {
    if ((unit ?? '').trim() == '0-10') {
      final iv = v is double ? v.round() : v;
      return '$iv/10';
    }
    return v.toString();
  }

  Future<void> _submitAnswer(dynamic valueToSend, String humanReadable) async {
    if (_sessionId == null || _currentQ == null) return;

    setState(() {
      _bubbles.add(_Bubble.user(humanReadable));
      _loading = true;
      _error = null;
    });
    _scrollToBottom();

    try {
      final res = await _api.postAnswer(
        sessionId: _sessionId!,
        questionId: _currentQ!.id,
        value: valueToSend,
      );

      if (res.question != null) {
        var q = res.question!;
        // show only fresh questions
        if (!_askedIds.contains(q.id)) {
          _askedIds.add(q.id);
          _currentQ = q;
          _finalDx = null;
          _bubbles.add(_Bubble.bot(q.text));
          _resetAnswerUi();
          _scrollToBottom();
        } else {
          debugPrint('Duplicate question ignored: ${q.id}');
        }
      } else {
        _currentQ = null;
        _finalDx = res.diagnosis;
        final displayText = _finalDx!.patientText.isNotEmpty
            ? _finalDx!.patientText
            : _finalDx!.explanationPatient;
        _bubbles.add(_Bubble.bot(displayText));
        _scrollToBottom();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _textCtrl.clear();
      setState(() => _loading = false);
    }
  }

  Widget _answerInput() {
    if (_finalDx != null || _currentQ == null) {
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
                  setState(() => _singleSelected = o);
                  _submitAnswer(o, o);
                }
              },
            );
          }).toList(),
        );

      case 'multi':
        final opts = _currentQ!.options;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: opts.map((o) {
                final selected = _multiSelected.contains(o);
                return FilterChip(
                  label: Text(o),
                  selected: selected,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _multiSelected.add(o);
                      } else {
                        _multiSelected.remove(o);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: _multiSelected.isEmpty
                    ? null
                    : () {
                  final list = _multiSelected.toList();
                  _submitAnswer(list, list.join(', '));
                },
                child: Text(tr('done')),
              ),
            ),
          ],
        );

      case 'number':
      case 'scale':
        final is010 = (_currentQ!.unit ?? '').trim() == '0-10';
        if (is010) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Slider(
                value: _sliderVal,
                min: 0,
                max: 10,
                divisions: 10,
                label: _sliderVal.round().toString(),
                onChanged: (v) => setState(() => _sliderVal = v),
              ),
              Row(
                children: [
                  Text('${_sliderVal.round()} / 10'),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () {
                      final v = _sliderVal.round();
                      _submitAnswer(v, _formatNumberLabel(v, '0-10'));
                    },
                    child: const Text('OK'),
                  ),
                ],
              ),
            ],
          );
        } else {
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
                  onSubmitted: (_) {
                    final raw = _textCtrl.text.trim();
                    final num? parsed = num.tryParse(raw);
                    if (parsed != null) {
                      _submitAnswer(parsed, _formatNumberLabel(parsed, _currentQ!.unit));
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final raw = _textCtrl.text.trim();
                  final num? parsed = num.tryParse(raw);
                  if (parsed == null) return;
                  _submitAnswer(parsed, _formatNumberLabel(parsed, _currentQ!.unit));
                },
                child: const Text('OK'),
              ),
            ],
          );
        }

      case 'text':
      default:
        return Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textCtrl,
                decoration: const InputDecoration(hintText: 'Type your answer...'),
                onSubmitted: (raw) {
                  raw = raw.trim();
                  if (raw.isEmpty) return;
                  _submitAnswer(raw, raw);
                },
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
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(12),
              itemCount: _bubbles.length + (_loading ? 1 : 0),
              itemBuilder: (_, i) {
                if (_loading && i == _bubbles.length) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade800 : Colors.white70,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: const Text('typing…'),
                    ),
                  );
                }

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
