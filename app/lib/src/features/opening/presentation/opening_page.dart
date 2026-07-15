import 'dart:async';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../data/opening_preferences.dart';
import '../domain/opening_experience.dart';

class OpeningPage extends StatefulWidget {
  const OpeningPage({
    required this.experience,
    required this.onFinished,
    super.key,
  });

  final OpeningExperience experience;
  final VoidCallback onFinished;

  @override
  State<OpeningPage> createState() => _OpeningPageState();
}

class _OpeningPageState extends State<OpeningPage> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _phraseTimer;
  bool _started = false;
  bool _soundEnabled = true;
  bool _finishing = false;
  int _phraseIndex = 0;

  bool get _isLastPhrase =>
      _phraseIndex == widget.experience.phrases.length - 1;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSoundPreference());
  }

  @override
  void dispose() {
    _phraseTimer?.cancel();
    unawaited(_audioPlayer.dispose());
    super.dispose();
  }

  Future<void> _loadSoundPreference() async {
    final enabled = await OpeningPreferences.isSoundEnabled();
    if (mounted) setState(() => _soundEnabled = enabled);
  }

  Future<void> _start() async {
    if (_started) return;
    setState(() => _started = true);
    if (_soundEnabled) await _playMusic();
    _scheduleNextPhrase();
  }

  Future<void> _playMusic() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.setVolume(0.34);
      await _audioPlayer.play(AssetSource('audio/opening_theme.wav'));
    } catch (_) {
      // The story remains fully usable if a browser or device blocks audio.
    }
  }

  void _scheduleNextPhrase() {
    _phraseTimer?.cancel();
    if (_isLastPhrase) return;
    _phraseTimer = Timer(const Duration(milliseconds: 3600), _nextPhrase);
  }

  void _nextPhrase() {
    if (!mounted || _isLastPhrase) return;
    setState(() => _phraseIndex += 1);
    _scheduleNextPhrase();
  }

  Future<void> _toggleSound() async {
    final enabled = !_soundEnabled;
    setState(() => _soundEnabled = enabled);
    await OpeningPreferences.setSoundEnabled(enabled);
    if (!enabled) {
      await _audioPlayer.pause();
    } else if (_started) {
      await _playMusic();
    }
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    _phraseTimer?.cancel();
    await _audioPlayer.stop();
    if (mounted) widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 640;

    return Scaffold(
      backgroundColor: const Color(0xFF070817),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/opening_gateway.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x70050719),
                  Color(0xA20A0B21),
                  Color(0xEF050612),
                ],
                stops: [0, 0.54, 1],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.12),
                radius: 0.9,
                colors: [Color(0x006C56B8), Color(0xB000010A)],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 20 : 48,
                vertical: 16,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _GlassIconButton(
                        tooltip: _soundEnabled
                            ? 'Couper la musique'
                            : 'Activer la musique',
                        icon: _soundEnabled
                            ? Icons.music_note_rounded
                            : Icons.music_off_rounded,
                        onPressed: _toggleSound,
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _finish,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white70,
                        ),
                        child: const Text('Passer'),
                      ),
                    ],
                  ),
                  const Spacer(flex: 3),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      children: [
                        Text(
                          widget.experience.eyebrow,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: const Color(0xFFE5C77A),
                            fontSize: compact ? 11 : 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 4.2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.experience.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: compact ? 32 : 48,
                            height: 1.04,
                            fontWeight: FontWeight.w700,
                            shadows: const [
                              Shadow(
                                color: Color(0xFF110B2D),
                                blurRadius: 24,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 38),
                        if (!_started)
                          _StartPanel(
                            label: widget.experience.startLabel,
                            onPressed: _start,
                          )
                        else
                          _StorySequence(
                            key: ValueKey(_phraseIndex),
                            phrase: widget.experience.phrases[_phraseIndex],
                            nextPhrase: _isLastPhrase
                                ? null
                                : widget.experience.phrases[_phraseIndex + 1],
                            compact: compact,
                            onAdvance: _nextPhrase,
                          ),
                      ],
                    ),
                  ),
                  const Spacer(flex: 2),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 700),
                    child: _started && _isLastPhrase
                        ? FilledButton.icon(
                            key: const ValueKey('finish'),
                            onPressed: _finish,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFD5B969),
                              foregroundColor: const Color(0xFF171120),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 18,
                              ),
                            ),
                            icon: const Icon(Icons.auto_awesome_rounded),
                            label: Text(widget.experience.finishLabel),
                          )
                        : const SizedBox(
                            key: ValueKey('progress'),
                            height: 56,
                          ),
                  ),
                  const SizedBox(height: 12),
                  if (_started)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        widget.experience.phrases.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          width: index == _phraseIndex ? 22 : 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: index <= _phraseIndex
                                ? const Color(0xFFE5C77A)
                                : Colors.white24,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StartPanel extends StatelessWidget {
  const _StartPanel({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Le son révèle ce que les yeux ne peuvent encore voir.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xC74B3B82),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          ),
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(label),
        ),
      ],
    );
  }
}

class _StorySequence extends StatelessWidget {
  const _StorySequence({
    required this.phrase,
    required this.nextPhrase,
    required this.compact,
    required this.onAdvance,
    super.key,
  });

  final String phrase;
  final String? nextPhrase;
  final bool compact;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: nextPhrase != null,
      label: phrase,
      child: InkWell(
        onTap: nextPhrase == null ? null : onAdvance,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 1700),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) => ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: 10 * (1 - value),
                    sigmaY: 10 * (1 - value),
                  ),
                  child: Opacity(opacity: 0.2 + value * 0.8, child: child),
                ),
                child: Text(
                  phrase,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 21 : 28,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                    shadows: const [
                      Shadow(color: Colors.black87, blurRadius: 18),
                    ],
                  ),
                ),
              ),
              if (nextPhrase != null) ...[
                const SizedBox(height: 22),
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Opacity(
                    opacity: 0.23,
                    child: Text(
                      nextPhrase!,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFE8DCFF),
                        fontSize: 15,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x66090A1C),
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(99),
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        color: Colors.white,
        icon: Icon(icon),
      ),
    );
  }
}
