import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'api_service.dart';

class QuestCompletionQuizModal extends StatefulWidget {
  final String questId;
  final String questName;
  final VoidCallback onQuizCompleted;

  const QuestCompletionQuizModal({
    super.key,
    required this.questId,
    required this.questName,
    required this.onQuizCompleted,
  });

  @override
  State<QuestCompletionQuizModal> createState() =>
      _QuestCompletionQuizModalState();
}

class _QuestCompletionQuizModalState extends State<QuestCompletionQuizModal> {
  static const Color creamBg = Color(0xFFF4F1EA);
  static const Color oceanBlue = Color(0xFF1684A7);
  static const Color tealGreen = Color(0xFF0EA391);
  static const Color sunnyYellow = Color(0xFFFAF179);

  bool _isLoading = true;
  String? _errorMessage;

  String? _attemptId;
  List<dynamic> _questions = [];
  int _currentIndex = 0;
  int _livesLeft = 4;
  int _secondsRemaining = 120;
  Timer? _timer;

  String? _selectedOption;
  bool _isSubmitting = false;

  bool _isQuizFinished = false;
  Map<String, dynamic>? _finalResults;

  @override
  void initState() {
    super.initState();
    _initQuiz();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initQuiz() async {
    try {
      final res = await ApiService.startQuiz(widget.questId);
      if (mounted) {
        setState(() {
          _attemptId = res['attemptId'];
          _questions = res['questions'] ?? [];
          _livesLeft = res['lives'] ?? 4;
          _secondsRemaining = res['timeLimit'] ?? 120;
          _isLoading = false;
        });
        _startTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer?.cancel();
        _handleFinishQuiz();
      }
    });
  }

  Future<void> _submitAnswer(String option) async {
    if (_isSubmitting || _attemptId == null) return;

    final currentQuestion = _questions[_currentIndex];
    final questionId = currentQuestion['id'];

    setState(() {
      _selectedOption = option;
      _isSubmitting = true;
    });

    try {
      final res = await ApiService.submitQuizAnswer(
        questId: widget.questId,
        attemptId: _attemptId!,
        questionId: questionId,
        selectedOption: option,
      );

      if (!mounted) return;

      if (res['lives_left'] != null) {
        setState(() => _livesLeft = res['lives_left']);
      }

      if (res['message'] == 'no lives left, quiz failed') {
        _timer?.cancel();
        _handleFinishQuiz();
        return;
      }

      // Progress to next question or finalize quiz
      if (_currentIndex < _questions.length - 1) {
        setState(() {
          _currentIndex++;
          _selectedOption = null;
          _isSubmitting = false;
        });
      } else {
        _timer?.cancel();
        await _handleFinishQuiz();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: oceanBlue,
            content: Text(
              e.toString().replaceAll('Exception: ', '').toUpperCase(),
              style: GoogleFonts.pressStart2p(fontSize: 8, color: Colors.white),
            ),
          ),
        );
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _handleFinishQuiz() async {
    if (_attemptId == null) return;
    setState(() => _isLoading = true);

    try {
      final res = await ApiService.finishQuiz(_attemptId!);
      if (mounted) {
        setState(() {
          _finalResults = res;
          _isQuizFinished = true;
          _isLoading = false;
        });
        widget.onQuizCompleted();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: creamBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: oceanBlue, width: 3),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.questName.toUpperCase(),
                    style: GoogleFonts.pressStart2p(
                      fontSize: 10,
                      color: oceanBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: oceanBlue),
                  onPressed: () => Navigator.of(context).pop(),
                )
              ],
            ),
            const Divider(color: oceanBlue, thickness: 2),
            const SizedBox(height: 12),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(color: tealGreen),
                ),
              )
            else if (_errorMessage != null)
              Column(
                children: [
                  Text(
                    _errorMessage!,
                    style: GoogleFonts.pressStart2p(
                        fontSize: 8, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: tealGreen),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'BACK',
                      style: GoogleFonts.pressStart2p(
                          fontSize: 8, color: Colors.white),
                    ),
                  )
                ],
              )
            else if (_isQuizFinished)
              _buildResultsView()
            else
              _buildQuizView(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizView() {
    final question = _questions[_currentIndex];
    final String qText = question['question'] ?? '';
    final rawOptions = question['options'];
    final List<MapEntry<String, String>> options = rawOptions is Map
        ? rawOptions.entries
            .map((entry) =>
                MapEntry(entry.key.toString(), entry.value.toString()))
            .toList()
        : rawOptions is List
            ? rawOptions.map((option) {
                final text = option.toString();
                return MapEntry(text, text);
              }).toList()
            : [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Lives & Countdown Timer
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: List.generate(
                4,
                (i) => Icon(
                  i < _livesLeft ? Icons.favorite : Icons.favorite_border,
                  color: Colors.red,
                  size: 16,
                ),
              ),
            ),
            Text(
              '${_secondsRemaining}S',
              style: GoogleFonts.pressStart2p(fontSize: 9, color: oceanBlue),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Question Progress Index
        Text(
          'QUESTION ${_currentIndex + 1}/${_questions.length}',
          style: GoogleFonts.pressStart2p(fontSize: 7, color: tealGreen),
        ),
        const SizedBox(height: 8),

        // Dynamic Question Body
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: oceanBlue, width: 2),
          ),
          child: Text(
            qText,
            style: GoogleFonts.pressStart2p(
                fontSize: 8, height: 1.4, color: Colors.black87),
          ),
        ),
        const SizedBox(height: 16),

        // Dynamic Options
        ...options.map((option) {
          final isSelected = _selectedOption == option.key;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSelected ? sunnyYellow : Colors.white,
                  foregroundColor: oceanBlue,
                  elevation: 0,
                  alignment: Alignment.centerLeft,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: isSelected ? tealGreen : oceanBlue,
                      width: 2,
                    ),
                  ),
                ),
                onPressed:
                    _isSubmitting ? null : () => _submitAnswer(option.key),
                child: Text(
                  option.value,
                  style: GoogleFonts.pressStart2p(
                    fontSize: 8,
                    color: oceanBlue,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildResultsView() {
    final score = _finalResults?['score'] ?? 0;
    final discount = _finalResults?['discountPercent'] ?? 0;
    final status = _finalResults?['status'];
    final quizFailed = status == 'failed' || status == 'expired';

    return Column(
      children: [
        Icon(
          quizFailed ? Icons.sentiment_dissatisfied : Icons.emoji_events,
          size: 48,
          color: tealGreen,
        ),
        const SizedBox(height: 12),
        Text(
          quizFailed ? 'QUIZ ENDED' : 'QUIZ COMPLETED!',
          style: GoogleFonts.pressStart2p(fontSize: 10, color: tealGreen),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: oceanBlue, width: 2),
          ),
          child: Column(
            children: [
              Text(
                'SCORE: $score%',
                style: GoogleFonts.pressStart2p(fontSize: 9, color: oceanBlue),
              ),
              const SizedBox(height: 8),
              Text(
                'DISCOUNT: $discount%',
                style: GoogleFonts.pressStart2p(fontSize: 9, color: tealGreen),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: tealGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: oceanBlue, width: 2),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'DONE',
              style: GoogleFonts.pressStart2p(fontSize: 8, color: Colors.white),
            ),
          ),
        )
      ],
    );
  }
}
