import 'package:material_ui/material_ui.dart';

import '../services/ask_munora_service.dart';
import '../models/weather_snapshot.dart';

class AskMunoraChat extends StatefulWidget {
  final String city;
  final AskMunoraService? service;
  const AskMunoraChat({super.key, required this.city, this.service});
  @override
  State<AskMunoraChat> createState() => _AskMunoraChatState();
}

class _AskMunoraChatState extends State<AskMunoraChat> {
  late final AskMunoraService service = widget.service ?? AskMunoraService();
  final input = TextEditingController();
  final scroll = ScrollController();
  final turns = <AskTurn>[];
  final answers = <AskAnswer>[];
  static const retainedExchanges = 12;
  bool historyEvicted = false;
  bool loading = false;
  int generation = 0;
  String? error, lastQuestion;
  @override
  void dispose() {
    generation++;
    service.cancel();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AskMunoraChat old) {
    super.didUpdateWidget(old);
    if (old.city != widget.city) clear();
  }

  void clear() {
    generation++;
    service.cancel();
    setState(() {
      turns.clear();
      answers.clear();
      historyEvicted = false;
      loading = false;
      error = null;
      lastQuestion = null;
      input.clear();
    });
  }

  void revealNewest() {
    final id = generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != id || !scroll.hasClients) return;
      scroll.animateTo(
        scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> send(String value, {bool clearInput = false}) async {
    final question = value.trim();
    if (loading || question.isEmpty || question.length > 600) return;
    final id = ++generation;
    final history = turns
        .map(
          (t) => AskTurn(
            t.role,
            t.content.length > 600 ? t.content.substring(0, 600) : t.content,
          ),
        )
        .toList();
    while (history.length > 6 ||
        history.fold<int>(0, (n, t) => n + t.content.length) > 2400) {
      history.removeRange(0, 2);
    }
    setState(() {
      loading = true;
      error = null;
      lastQuestion = question;
      if (clearInput) input.clear();
    });
    revealNewest();
    try {
      final answer = await service.ask(
        city: widget.city,
        question: question,
        history: history,
      );
      if (!mounted || id != generation) return;
      setState(() {
        turns.add(AskTurn('user', question));
        turns.add(AskTurn('assistant', answer.answer));
        answers.add(answer);
        if (answers.length > retainedExchanges) {
          final removed = answers.length - retainedExchanges;
          answers.removeRange(0, removed);
          turns.removeRange(0, removed * 2);
          historyEvicted = true;
        }
      });
    } on AskMunoraException catch (e) {
      if (mounted && id == generation) setState(() => error = e.message);
    } finally {
      if (mounted && id == generation) {
        setState(() => loading = false);
        revealNewest();
      }
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .85,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ask MUNORA · ${widget.city}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Clear chat',
                    onPressed: clear,
                    icon: const Icon(Icons.delete_outline),
                  ),
                  IconButton(
                    tooltip: 'Close Ask MUNORA',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scroll,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Your question and selected city are sent to the MUNORA AI service. Chat clears when closed.',
                    ),
                    if (historyEvicted)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('Showing the latest 12 exchanges. Earlier messages are cleared.'),
                      ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final q in [
                          'Do I need an umbrella?',
                          'When is a good time outdoors?',
                          'How should I prepare for the heat?',
                        ])
                          Semantics(
                            button: true,
                            label: q,
                            enabled: !loading,
                            onTap: loading ? null : () => send(q),
                            excludeSemantics: true,
                            child: ActionChip(
                              label: Text(q),
                              onPressed: loading ? null : () => send(q),
                            ),
                          ),
                      ],
                    ),
                    for (var i = 0; i < answers.length; i++) ...[
                      const SizedBox(height: 16),
                      Text(
                        turns[i * 2].content,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(answers[i].answer),
                      const SizedBox(height: 8),
                      for (final f in answers[i].facts)
                        Text('${f.label}: ${f.value}'),
                      Text(
                        '${answers[i].source} · Weather ${weatherTime(answers[i].observedAt)}\nGenerated ${weatherTime(answers[i].generatedAt)}\nForecast through ${weatherTime(answers[i].forecastUntil)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const Text(
                        'AI-generated explanation. Check current forecasts before making plans.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                    if ((loading || error != null) && lastQuestion != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        lastQuestion!,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                    if (loading) ...[
                      const SizedBox(height: 16),
                      const LinearProgressIndicator(),
                      const Text(
                        'Checking fresh weather and preparing an answer…',
                      ),
                    ],
                    if (error != null) ...[
                      Text(error!),
                      TextButton(
                        onPressed: loading ? null : () => send(lastQuestion!),
                        child: const Text('Retry'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: input,
                    maxLength: 600,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Your question',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.newline,
                  ),
                  FilledButton(
                    onPressed: loading
                        ? null
                        : () => send(input.text, clearInput: true),
                    child: const Text('Send question'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
