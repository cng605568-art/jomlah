import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_theme.dart';
import '../../../core/l10n/language.dart';
import '../../map/domain/report.dart';
import '../../map/presentation/overlays.dart';
import '../data/speech_input.dart';
import '../domain/voice_command.dart';

final speechInputProvider = Provider<SpeechInput>((ref) => SttSpeechInput());

/// What came out of a voice report: an alert to report, or "let me pick it myself".
typedef VoiceReportResult = ({ReportType? type, bool pick});

/// Tap the mic, say "ada polis" (or "banjir", "塞车"...): the sheet listens once and closes with
/// the alert it heard. Null when the driver closed it or said "batal".
Future<VoiceReportResult?> showVoiceReport(BuildContext context) => showModalBottomSheet<VoiceReportResult>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true, // as tall as its content needs, on any screen
      builder: (_) => const VoiceReportSheet(),
    );

class VoiceReportSheet extends ConsumerStatefulWidget {
  const VoiceReportSheet({super.key});

  @override
  ConsumerState<VoiceReportSheet> createState() => _VoiceReportSheetState();
}

enum _Stage { starting, listening, heard, notUnderstood, unavailable }

class _VoiceReportSheetState extends ConsumerState<VoiceReportSheet> {
  _Stage _stage = _Stage.starting;
  String _words = '';
  ReportType? _type;
  Timer? _close;
  late final SpeechInput _speech = ref.read(speechInputProvider);

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void dispose() {
    _close?.cancel();
    _speech.stop();
    super.dispose();
  }

  Future<void> _listen() async {
    final speech = _speech;
    setState(() {
      _stage = _Stage.starting;
      _words = '';
    });
    if (!await speech.init()) {
      if (mounted) setState(() => _stage = _Stage.unavailable);
      return;
    }
    if (!mounted) return;
    setState(() => _stage = _Stage.listening);
    await speech.start(
      language: ref.read(languageProvider),
      onWords: (heard, isFinal) {
        if (!mounted || _stage == _Stage.heard) return;
        setState(() => _words = heard.isEmpty ? '' : heard.first);
        if (isCancel(heard)) {
          Navigator.of(context).pop();
          return;
        }
        final type = reportFromSpeech(heard);
        if (type != null) _heard(type);
      },
      onDone: () {
        if (mounted && _stage == _Stage.listening) setState(() => _stage = _Stage.notUnderstood);
      },
    );
  }

  void _heard(ReportType type) {
    _speech.stop();
    setState(() {
      _stage = _Stage.heard;
      _type = type;
    });
    // A moment to see what was understood, then report it.
    _close = Timer(const Duration(milliseconds: 700), () {
      if (mounted) Navigator.of(context).pop((type: type, pick: false));
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final listening = _stage == _Stage.listening || _stage == _Stage.starting;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(s.voiceReport, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            if (_stage == _Stage.heard && _type != null)
              ReportBadge(type: _type!, size: 96)
            else
              _MicCircle(active: listening),
            const SizedBox(height: 16),
            Text(
              switch (_stage) {
                _Stage.starting || _Stage.listening => _words.isEmpty ? s.speakNow : '“$_words”',
                _Stage.heard => s.reportLabel(_type!),
                _Stage.notUnderstood => s.notUnderstood,
                _Stage.unavailable => s.speechUnavailable,
              },
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            if (listening && _words.isEmpty) ...[
              const SizedBox(height: 8),
              Text(s.voiceExamples, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
            ],
            if (_stage == _Stage.notUnderstood || _stage == _Stage.unavailable) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  if (_stage == _Stage.notUnderstood) ...[
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                        onPressed: _listen,
                        icon: const Icon(Icons.mic_rounded),
                        label: Text(s.tryAgain),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                      onPressed: () => Navigator.of(context).pop((type: null, pick: true)),
                      child: Text(s.pickInstead),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A big microphone that gently pulses while listening.
class _MicCircle extends StatefulWidget {
  const _MicCircle({required this.active});
  final bool active;

  @override
  State<_MicCircle> createState() => _MicCircleState();
}

class _MicCircleState extends State<_MicCircle> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    if (widget.active) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_MicCircle old) {
    super.didUpdateWidget(old);
    if (widget.active && !_pulse.isAnimating) _pulse.repeat(reverse: true);
    if (!widget.active) _pulse.stop();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) => Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDeep]),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25 + 0.35 * _pulse.value),
                blurRadius: 12 + 20 * _pulse.value,
                spreadRadius: 2 + 8 * _pulse.value,
              ),
            ],
          ),
          child: child,
        ),
        child: const Icon(Icons.mic_rounded, size: 48, color: Colors.white),
      );
}
