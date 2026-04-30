import 'package:flutter/material.dart';

import '../../../core/brand/enis_brand.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../core/widgets/soft_card.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final _thoughtController = TextEditingController();
  final _feelingController = TextEditingController();
  final _nextStepController = TextEditingController();
  final List<String> _entries = [];

  @override
  void dispose() {
    _thoughtController.dispose();
    _feelingController.dispose();
    _nextStepController.dispose();
    super.dispose();
  }

  void _saveEntry() {
    final thought = _thoughtController.text.trim();
    final feeling = _feelingController.text.trim();
    final next = _nextStepController.text.trim();
    if (thought.isEmpty && feeling.isEmpty && next.isEmpty) return;
    setState(() {
      _entries.insert(
        0,
        [
          if (thought.isNotEmpty) 'Thought: $thought',
          if (feeling.isNotEmpty) 'Feeling: $feeling',
          if (next.isNotEmpty) 'Small step: $next',
        ].join('\n'),
      );
      _thoughtController.clear();
      _feelingController.clear();
      _nextStepController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Günlük',
      subtitle: 'A light CBT-style journal for reflection.',
      child: ListView(
        children: [
          SoftCard(
            child: Column(
              children: [
                TextField(
                  controller: _thoughtController,
                  decoration: const InputDecoration(labelText: 'What happened?'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _feelingController,
                  decoration: const InputDecoration(labelText: 'What did it bring up?'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nextStepController,
                  decoration: const InputDecoration(labelText: 'One small helpful action'),
                ),
                const SizedBox(height: 16),
                GradientButton(
                  label: 'Save / Kaydet',
                  icon: Icons.check_rounded,
                  onPressed: _saveEntry,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_entries.isEmpty)
            SoftCard(
              child: Text(
                'No entries yet.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: EnisColors.deepNavy.withOpacity(0.58),
                    ),
              ),
            )
          else
            ..._entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SoftCard(child: Text(entry, style: Theme.of(context).textTheme.bodyMedium)),
              ),
            ),
        ],
      ),
    );
  }
}
