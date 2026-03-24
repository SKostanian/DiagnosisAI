import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:diagnosis_ai/triage/models.dart';
import 'package:diagnosis_ai/triage/session_api.dart';

class TriageChatArgs {
  final List<String> selectedAreas;
  TriageChatArgs(this.selectedAreas);
}

class TriageChatScreen extends StatefulWidget {
  static const routeName = '/triage_chat';
  final List<String> selectedAreas;

  const TriageChatScreen({
    super.key,
    required this.selectedAreas,
  });

  @override
  State<TriageChatScreen> createState() => _TriageChatScreenState();
}

class _TriageChatScreenState extends State<TriageChatScreen> {
  // key used in SharedPreferences, store saved chats locally
  static const String _storageKey = 'triage_saved_chats_v1';

  final _api = SessionApi();
  bool _depsReady = false;

  // local id for chats
  String? _localChatId;
  // session server id
  String? _sessionId;
  TriageQuestion? _currentQ;
  TriageDiagnosis? _finalDx;

  // list of all messages
  final List<_Bubble> _bubbles = [];
  final _askedIds = <String>{};

  // Handle changes to a text field (2026) Flutter.dev.
  // Available at: http://docs.flutter.dev/cookbook/forms/text-field-changes (Accessed: March 15, 2026).
  final _textCtrl = TextEditingController();

  // Controller property (2026) Flutter.dev.
  // Available at: https://api.flutter.dev/flutter/material/Scrollbar/controller.html (Accessed: March 15, 2026).
  final _scrollCtrl = ScrollController();

  bool _loading = true;
  String? _error;

  int _answersGiven = 0;
  bool _diagnosisShown = false;

  String? _singleSelected;
  final Set<String> _multiSelected = <String>{};
  double _sliderVal = 5;

  List<_SavedChat> _savedChats = [];

  // initState method (2026) Flutter.dev.
  // Available at: https://api.flutter.dev/flutter/widgets/RawTooltipState/initState.html (Accessed: March 15, 2026).
  @override
  void initState() {
    super.initState();
    _loadSavedChats();
  }

  // didChangeDependencies method (2026) Flutter.dev.
  // Available at: https://api.flutter.dev/flutter/widgets/RestorationMixin/didChangeDependencies.html (Accessed: March 15, 2026).
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_depsReady) {
      _depsReady = true;
      _start();
    }
  }

  // (2026) Stackoverflow.com.
  // Available at: https://stackoverflow.com/questions/59558604/why-do-we-use-the-dispose-method-in-flutter-dart-code (Accessed: March 15, 2026).
  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _resetAnswerUi() {
    _singleSelected = null;
    _multiSelected.clear();
    _sliderVal = 5;
    _textCtrl.clear();
  }

  // Icesousas (2024) Flutter: Master ScrollController and Widget Scrolling — A comprehensive guide, Medium.
  // Available at: https://medium.com/@icesousas/flutter-master-scrollcontroller-and-widget-scrolling-a-comprehensive-guide-9a7c9a029206 (Accessed: March 15, 2026).
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent + 140,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  String _makeChatTitle() {
    final now = DateTime.now();
    final areas = widget.selectedAreas.isEmpty
        ? 'General triage'
        : widget.selectedAreas.join(', ');
    final time =
        // padLeft method - String class - dart:core library - Dart API (2026) Dart.dev.
    // Available at: https://api.dart.dev/dart-core/String/padLeft.html (Accessed: March 15, 2026).
        '${now.day.toString().padLeft(2, '0')}.'
        '${now.month.toString().padLeft(2, '0')}.'
        '${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
    return '$areas * $time';
  }


  // I use Future here
  Future<void> _loadSavedChats() async {
    // as we get instance, it is async
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);

    if (raw == null || raw.isEmpty) {
      if (!mounted) return;
      setState(() => _savedChats = []);
      return;
    }

    // also this is a useful source:
    // Raposo, A. (2019) Flutter: How to save objects in SharedPreferences, Afonso Raposo.
    // Available at: https://afonsoraposo.com/posts/sharedpref/ (Accessed: March 15, 2026).

    try {
      // we can decode and use as List

      // jsonDecode function (2026) Flutter.dev.
      // Available at: https://api.flutter.dev/flutter/dart-convert/jsonDecode.html (Accessed: March 15, 2026).
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      final chats = decoded
          .map((e) => _SavedChat.fromJson(Map<String, dynamic>.from(e)))
          .toList()

      // sort method - List class - dart:core library - Dart API (2026) Flutter.dev.
      // Available at: https://api.flutter.dev/flutter/dart-core/List/sort.html (Accessed: March 15, 2026).
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      if (!mounted) return;
      setState(() => _savedChats = chats);
    } catch (_) {
      if (!mounted) return;
      setState(() => _savedChats = []);
    }
  }

  Future<void> _writeSavedChats() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_savedChats.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, raw);
  }

  Future<void> _saveCurrentChat() async {
    if (_localChatId == null) return;

    final chat = _SavedChat(
      // chatid is not null, that is why - !
      id: _localChatId!,
      title: _makeChatTitle(),

      selectedAreas: List<String>.from(widget.selectedAreas),
      sessionId: _sessionId,
      currentQJson: _currentQ?.toJson(),
      finalDxJson: _finalDx?.toJson(),
      bubbles: _bubbles
          .map((b) => {
          'isUser': b.isUser,
          'text': b.text,
        },
      )
          .toList(),
      askedIds: _askedIds.toList(),
      answersGiven: _answersGiven,
      diagnosisShown: _diagnosisShown,
      updatedAt: DateTime.now(),
    );

    final index = _savedChats.indexWhere((e) => e.id == chat.id);
    if (index >= 0) {
      // update chat if found
      _savedChats[index] = chat;
    } else {
      // if not then insert new chat

      // insert method - List class - dart:core library - Dart API (2026) Flutter.dev.
      // Available at: https://api.flutter.dev/flutter/dart-core/List/insert.html (Accessed: March 15, 2026).
      _savedChats.insert(0, chat);
    }

    _savedChats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    if (mounted) {
      setState(() {});
    }

    await _writeSavedChats();
  }

  Future<void> _deleteSavedChat(String id) async {

    // removeWhere method - List class - dart:core library - Dart API (2026) Flutter.dev.
    // Available at: https://api.flutter.dev/flutter/dart-core/List/removeWhere.html (Accessed: March 15, 2026).
    _savedChats.removeWhere((e) => e.id == id);
    await _writeSavedChats();

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openSavedChat(_SavedChat chat) async {
    setState(() {
      _localChatId = chat.id;
      _sessionId = chat.sessionId;
      _currentQ = chat.currentQJson != null
          ? TriageQuestion.fromMap(chat.currentQJson!)
          : null;
      _finalDx = chat.finalDxJson != null
          ? TriageDiagnosis.fromMap(chat.finalDxJson!)
          : null;

      // Operators (2026) Dart.dev.
      // Available at: https://dart.dev/language/operators (Accessed: March 15, 2026).
      _bubbles

          // clear method - Set class - dart:core library - Dart API (2026) Dart.dev. Available at: https://api.dart.dev/dart-core/Set/clear.html (Accessed: March 15, 2026).
        ..clear()

        // addAll method - Set class - dart:core library - Dart API (2026) Dart.dev. Available at: https://api.dart.dev/dart-core/Set/addAll.html (Accessed: March 15, 2026).
        ..addAll(
          chat.bubbles.map(
                (e) => (e['isUser'] as bool)
                // amd add named constructord that we define
                // for user
                ? _Bubble.user(e['text'] as String)
                // and for llm questions
                : _Bubble.bot(e['text'] as String),
          ),
        );

      _askedIds
        ..clear()
        ..addAll(chat.askedIds);

      _answersGiven = chat.answersGiven;
      _diagnosisShown = chat.diagnosisShown;
      _loading = false;
      _error = null;
      // and reset call
      _resetAnswerUi();
    });

    Navigator.of(context).pop();

    // to scroll
    _scrollToBottom();
  }


  Future<void> _startNewChat() async {
    setState(() {
      _localChatId = null;
      _sessionId = null;
      _currentQ = null;
      _finalDx = null;
      _bubbles.clear();
      _askedIds.clear();
      _answersGiven = 0;
      _diagnosisShown = false;
      _error = null;
      _loading = true;
      _resetAnswerUi();
    });

    Navigator.of(context).pop();
    await _start();
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // toLanguageTag method (2026) Flutter.dev.
      // Available at: https://api.flutter.dev/flutter/dart-ui/Locale/toLanguageTag.html (Accessed: March 15, 2026).
      final localeTag = context.locale.toLanguageTag();
      final result = await _api.startSession(
        localeTag: localeTag,
        selectedAreas: widget.selectedAreas,
      );

      // (2022) Darttutorial.org.
      // Available at: https://www.darttutorial.org/dart-tutorial/dart-null-aware-operators/ (Accessed: March 15, 2026).

      // DateTime.fromMillisecondsSinceEpoch constructor (2026) Flutter.dev.
      // Available at: https://api.flutter.dev/flutter/dart-core/DateTime/DateTime.fromMillisecondsSinceEpoch.html (Accessed: March 15, 2026).
      _localChatId ??= DateTime.now().millisecondsSinceEpoch.toString();
      _sessionId = result.sessionId;

      if (result.question != null) {
        final q = result.question!;
        if (!_askedIds.contains(q.id)) {
          _askedIds.add(q.id);
          _currentQ = q;
          _finalDx = null;
          _bubbles.add(_Bubble.bot(q.text));
          _resetAnswerUi();
          _scrollToBottom();
        }
      } else if (result.diagnosis != null) {
        _currentQ = null;
        _finalDx = result.diagnosis;
        final displayText = _finalDx!.patientText.isNotEmpty
            ? _finalDx!.patientText
            : _finalDx!.explanationPatient;
        _bubbles.add(_Bubble.bot(displayText));
        _diagnosisShown = true;
        _scrollToBottom();
      }

      await _saveCurrentChat();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _formatNumberLabel(num v, num max) {
    // rounding if double
    final iv = v is double ? v.round() : v;
    final imax = max is double ? max.round() : max;
    return '$iv/$imax';
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
        questionMeta: _currentQ,
      );

      final isValidationRetry =
          res.validationError != null && res.validationError!.isNotEmpty;

      if (!isValidationRetry) {
        _answersGiven = (_answersGiven + 1).clamp(0, 1000000);
      }

      if (res.question != null) {
        final q = res.question!;
        _currentQ = q;
        _finalDx = null;

        if (isValidationRetry) {
          _error = res.validationError;

          // remove last user bubble when answer wasnot accepted
          if (_bubbles.isNotEmpty && _bubbles.last.isUser) {
            _bubbles.removeLast();
          }

          _scrollToBottom();
        } else {
          _error = null;

          if (!_askedIds.contains(q.id)) {
            _askedIds.add(q.id);
            _bubbles.add(_Bubble.bot(q.text));
            _resetAnswerUi();
            _scrollToBottom();
          } else {
            debugPrint('Duplicate question ignored: ${q.id}');
          }
        }
      } else {
        _error = null;
        _currentQ = null;
        _finalDx = res.diagnosis;
        final displayText = _finalDx!.patientText.isNotEmpty
            ? _finalDx!.patientText
            : _finalDx!.explanationPatient;
        _bubbles.add(_Bubble.bot(displayText));
        _diagnosisShown = true;
        _scrollToBottom();
      }

      await _saveCurrentChat();
    } catch (e) {
      _error = e.toString();
    } finally {
      _textCtrl.clear();
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Widget _answerInput() {
    if (_finalDx != null || _currentQ == null) {

      // Bizzotto, A. (2026) Use SizedBox.shrink() to return an empty box, Code With Andrea. Available at: https://codewithandrea.com/tips/sizedbox-shrink/ (Accessed: March 15, 2026).
      return const SizedBox.shrink();
    }

    // questions can be single, multi
    // number, scale or text format

    switch (_currentQ!.type) {
      case 'single':
        final opts = _currentQ!.options;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          // o I use as iteration in map. lists
          children: opts.map((o) {
            final selected = _singleSelected == o;
            // Flutter - choice chip (2022) GeeksforGeeks.
            // Available at: https://www.geeksforgeeks.org/flutter/flutter-choice-chip/ (Accessed: March 15, 2026).
            return ChoiceChip(
              label: Text(
                o,
                style: const TextStyle(fontSize: 16),
              ),
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
              spacing: 10,
              runSpacing: 10,
              children: opts.map((o) {
                final selected = _multiSelected.contains(o);
                // Mapp, F. (2023) Flutter FilterChip widget. Youtube. Available at: https://www.youtube.com/watch?v=oO1fMO-e9mc (Accessed: March 15, 2026).
                return FilterChip(
                  label: Text(
                    o,
                    style: const TextStyle(fontSize: 16),
                  ),
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
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: _multiSelected.isEmpty
                    ? null
                    : () {
                  final list = _multiSelected.toList();
                  _submitAnswer(list, list.join(', '));
                },
                child: Text(
                  tr('done'),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        );

      case 'number':
      case 'scale':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Slider(
              value: _sliderVal.clamp(
                _currentQ!.sliderMin,
                _currentQ!.sliderMax,
              ),
              min: _currentQ!.sliderMin,
              max: _currentQ!.sliderMax,
              divisions:
              (_currentQ!.sliderMax - _currentQ!.sliderMin).round(),
              label: _sliderVal.round().toString(),
              onChanged: (v) => setState(() => _sliderVal = v),
            ),
            Row(
              children: [
                Text(
                  // round as before
                  // with string interpolation
                  '${_sliderVal.round()} / ${_currentQ!.sliderMax.round()}',
                  style: const TextStyle(fontSize: 16),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () {
                    final v = _sliderVal.round();
                    _submitAnswer(
                      v,
                      _formatNumberLabel(v, _currentQ!.sliderMax),
                    );
                  },
                  child: const Text(
                    'OK',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
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
                style: const TextStyle(fontSize: 17),
                // for text I use input decoration
                decoration: const InputDecoration(
                  // let user type his answer
                  hintText: 'Type your answer...',
                  hintStyle: TextStyle(fontSize: 16),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  // Paghdal, S. (2023) A visual guide to Input Decorations for Flutter TextField, Medium.
                  // Available at: https://medium.com/@paghadalsneh/a-visual-guide-to-input-decorations-for-flutter-textfield-6f805d1991b7 (Accessed: March 15, 2026).
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (raw) {
                  // trim, not to have spaces
                  raw = raw.trim();
                  if (raw.isEmpty) return;
                  _submitAnswer(raw, raw);
                },
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: () {
                final raw = _textCtrl.text.trim();
                if (raw.isEmpty) return;
                _submitAnswer(raw, raw);
              },
              child: const Text(
                'Send',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        );
    }
  }

  // allow user to finish
  Future<void> _onFinishNow() async {
    if (_finalDx != null && !_diagnosisShown) {
      final displayText = _finalDx!.patientText.isNotEmpty
          ? _finalDx!.patientText
          : _finalDx!.explanationPatient;

      setState(() {
        _bubbles.add(_Bubble.bot(displayText));
        _diagnosisShown = true;
        _currentQ = null;
      });

      _scrollToBottom();
      await _saveCurrentChat();
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          // if triage is not ready then messages for user
          title: Text(tr('triage.not_ready_title')),
          content: Text(tr('triage.not_ready_body')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            )
          ],
        ),
      );
    }
  }

  Drawer _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              // Flutter - edge insets class (2023) GeeksforGeeks.
              // Available at: https://www.geeksforgeeks.org/flutter/flutter-edge-insets-class/ (Accessed: March 15, 2026).
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.history),
                  SizedBox(width: 8),
                  Text(
                    'Saved chats',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              // Add_comment_outlined constant (2026) Flutter.dev. Available at: https://api.flutter.dev/flutter/material/Icons/add_comment_outlined-constant.html (Accessed: March 15, 2026).
              // ListTile class (2026) Flutter.dev. Available at: https://api.flutter.dev/flutter/material/ListTile-class.html (Accessed: March 15, 2026).
              leading: const Icon(Icons.add_comment_outlined),
              title: const Text(
                'New chat',
                style: TextStyle(fontSize: 17),
              ),
              onTap: _startNewChat,
            ),

            // Divider class (2026) Flutter.dev. Available at: https://api.flutter.dev/flutter/material/Divider-class.html (Accessed: March 15, 2026).
            const Divider(height: 1),
            Expanded(
              child: _savedChats.isEmpty
                  ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No saved chats yet',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              )
                  // Flutter (2020) ListView (flutter widget of the week). Youtube. Available at: https://www.youtube.com/watch?v=KJpkjHGiI5A&t=55s (Accessed: March 15, 2026).
                  : ListView.builder(
                itemCount: _savedChats.length,
                itemBuilder: (_, i) {
                  final chat = _savedChats[i];
                  final subtitle =
                      '${chat.selectedAreas.join(', ')}\n'
                      '${chat.updatedAt.day.toString().padLeft(2, '0')}.'
                      '${chat.updatedAt.month.toString().padLeft(2, '0')}.'
                      '${chat.updatedAt.year} '
                      '${chat.updatedAt.hour.toString().padLeft(2, '0')}:'
                      '${chat.updatedAt.minute.toString().padLeft(2, '0')}';

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    leading: const Icon(Icons.chat_bubble_outline),
                    title: Text(
                      chat.title,
                      maxLines: 1,
                      // Flutter - TextOverFlow (2022) GeeksforGeeks.
                      // Available at: https://www.geeksforgeeks.org/flutter/flutter-textoverflow/ (Accessed: March 15, 2026).
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16),
                    ),
                    subtitle: Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                    onTap: () => _openSavedChat(chat),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red,),
                      onPressed: () => _deleteSavedChat(chat.id),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      endDrawer: _buildDrawer(),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(tr('triage.title')),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_error != null)
            Container(
              color: Colors.red.withOpacity(0.1),
              padding: const EdgeInsets.all(10),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: _bubbles.length + (_loading ? 1 : 0),
              itemBuilder: (_, i) {
                if (_loading && i == _bubbles.length) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade800 : Colors.white70,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: const Text(
                        'typing…',
                        style: TextStyle(fontSize: 17),
                      ),
                    ),
                  );
                }

                final b = _bubbles[i];
                final align = b.isUser
                    ? Alignment.centerRight
                    : Alignment.centerLeft;
                final color = b.isUser
                    ? (isDark
                    ? Colors.blueGrey.shade700
                    : Colors.blue.shade100)
                    : (isDark
                    ? Colors.grey.shade800
                    : Colors.white);

                return Align(
                  alignment: align,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    constraints: const BoxConstraints(maxWidth: 700),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Text(
                      b.text,
                      style: const TextStyle(
                        fontSize: 18,
                        height: 1.4,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _answerInput(),
                if (_finalDx == null &&
                    _answersGiven >= 5 &&
                    _currentQ != null) ...[
                  const SizedBox(height: 14),
                  OutlinedButton(
                    onPressed: _onFinishNow,
                    child: Text(tr('triage.finish_now')),
                  ),
                ],
              ],
            ),
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

class _SavedChat {
  final String id;
  final String title;
  final List<String> selectedAreas;
  final String? sessionId;
  final Map<String, dynamic>? currentQJson;
  final Map<String, dynamic>? finalDxJson;
  final List<Map<String, dynamic>> bubbles;
  final List<String> askedIds;
  final int answersGiven;
  final bool diagnosisShown;
  final DateTime updatedAt;

  const _SavedChat({
    required this.id,
    required this.title,
    required this.selectedAreas,
    required this.sessionId,
    required this.currentQJson,
    required this.finalDxJson,
    required this.bubbles,
    required this.askedIds,
    required this.answersGiven,
    required this.diagnosisShown,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'selectedAreas': selectedAreas,
      'sessionId': sessionId,
      'currentQJson': currentQJson,
      'finalDxJson': finalDxJson,
      'bubbles': bubbles,
      'askedIds': askedIds,
      'answersGiven': answersGiven,
      'diagnosisShown': diagnosisShown,
      // toIso8601String method (2026) Flutter.dev. Available at: https://api.flutter.dev/flutter/dart-core/DateTime/toIso8601String.html (Accessed: March 15, 2026).
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // fromJson to savedCjat class
  factory _SavedChat.fromJson(Map<String, dynamic> json) {
    return _SavedChat(
      id: json['id'] as String,
      title: json['title'] as String,
      selectedAreas: List<String>.from(json['selectedAreas'] as List),
      sessionId: json['sessionId'] as String?,
      currentQJson: json['currentQJson'] != null
          ? Map<String, dynamic>.from(json['currentQJson'])
          : null,
      finalDxJson: json['finalDxJson'] != null
          ? Map<String, dynamic>.from(json['finalDxJson'])
          : null,
      bubbles: (json['bubbles'] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      askedIds: List<String>.from(json['askedIds'] as List),
      answersGiven: json['answersGiven'] as int? ?? 0,
      diagnosisShown: json['diagnosisShown'] as bool? ?? false,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}