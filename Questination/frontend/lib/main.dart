import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'api_service.dart';
import 'avatar/avatar_screen.dart';
import 'login_screen.dart';
import 'preferences_and_artisans.dart';
import 'quest_map_widget.dart';
import 'quests_tab_widget.dart';
import 'journal/home_screen.dart';
import 'splash_screen.dart';

const journalPreviewMode = bool.fromEnvironment('JOURNAL_PREVIEW');

void main() {
  runApp(const QuestinationApp());
}

class QuestinationApp extends StatefulWidget {
  const QuestinationApp({super.key});

  @override
  State<QuestinationApp> createState() => _QuestinationAppState();
}

class _QuestinationAppState extends State<QuestinationApp> {
  bool _isLoggedIn = false;
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Questination',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4F1EA),
      ),
      home: _showSplash
          ? SplashScreen(
              onComplete: () => setState(() => _showSplash = false),
            )
          : _isLoggedIn
              ? MainNavigationContainer(
                  onLogout: () => setState(() => _isLoggedIn = false),
                )
              : LoginScreen(
                  onLoginSuccess: () => setState(() => _isLoggedIn = true),
                ),
    );
  }
}

class MainNavigationContainer extends StatefulWidget {
  final VoidCallback onLogout;

  const MainNavigationContainer({
    super.key,
    required this.onLogout,
  });

  @override
  State<MainNavigationContainer> createState() =>
      _MainNavigationContainerState();
}

class _MainNavigationContainerState extends State<MainNavigationContainer> {
  int _currentIndex = 0;
  int _completionRefreshVersion = 0;
  String? _selectedCityId;
  String? _selectedQuestId;
  bool _isAcceptingQuest = false;

  void _onCityChanged(String cityId) {
    if (_selectedCityId == cityId) return;
    setState(() {
      _selectedCityId = cityId;
      _selectedQuestId = null;
    });
  }

  Future<void> _onQuestSelected(String questId, String cityId) async {
    if (_isAcceptingQuest) return;
    setState(() => _isAcceptingQuest = true);
    try {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F5F0),
              border: Border.all(color: const Color(0xFF2A6E7A), width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x662A6E7A),
                  offset: Offset(4, 4),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDBEDE5),
                        border: Border.all(
                          color: const Color(0xFF2A6E7A),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.explore_outlined,
                        color: Color(0xFF2A6E7A),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'ACCEPT QUEST?',
                        style: GoogleFonts.pressStart2p(
                          fontSize: 10,
                          color: const Color(0xFF1F2D2A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Ready to explore this landmark? Accept the quest to open its map.',
                  style: GoogleFonts.pressStart2p(
                    fontSize: 8,
                    height: 1.8,
                    color: const Color(0xFF1F2D2A),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF2A6E7A),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                      ),
                      child: Text(
                        'NOT NOW',
                        style: GoogleFonts.pressStart2p(fontSize: 7),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF9ED0C5),
                        foregroundColor: const Color(0xFF1F2D2A),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                          side:
                              BorderSide(color: Color(0xFF2A6E7A), width: 1.5),
                        ),
                      ),
                      child: Text(
                        'ACCEPT',
                        style: GoogleFonts.pressStart2p(fontSize: 7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      if (accepted != true || !mounted) return;

      await ApiService.acceptQuest(questId);
      if (!mounted) return;
      setState(() {
        _selectedCityId = cityId;
        _selectedQuestId = questId;
        _currentIndex = 1;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not accept quest: $error')),
      );
    } finally {
      if (mounted) setState(() => _isAcceptingQuest = false);
    }
  }

  void _onQuestCompleted() {
    setState(() => _completionRefreshVersion++);
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      QuestsListScreen(
        cityId: _selectedCityId,
        completionRefreshVersion: _completionRefreshVersion,
        onCityChanged: _onCityChanged,
        onQuestSelected: _onQuestSelected,
        onLogout: widget.onLogout,
      ),
      QuestMapWidget(
        cityId: _selectedCityId ?? 'city-lucknow',
        questId: _selectedQuestId,
        onQuestCompleted: _onQuestCompleted,
      ),
      BookshelfScreen(
        userId: ApiService.currentUserId ?? '',
        authToken: ApiService.accessToken,
        previewMode: journalPreviewMode,
        completionRefreshVersion: _completionRefreshVersion,
      ),
      PreferencesAndArtisansScreen(
        cityId: _selectedCityId ?? 'city-lucknow',
      ),
      const AvatarScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFEFF8F2),
          border: Border(
            top: BorderSide(color: Color(0xFFBBDCC9), width: 1.2),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xFFEFF8F2),
          elevation: 0,
          selectedItemColor: const Color(0xFF1B796D),
          unselectedItemColor: const Color(0xFF335D5C),
          selectedIconTheme: const IconThemeData(color: Color(0xFF1B796D)),
          unselectedIconTheme: const IconThemeData(color: Color(0xFF335D5C)),
          selectedLabelStyle: GoogleFonts.pressStart2p(fontSize: 6),
          unselectedLabelStyle: GoogleFonts.pressStart2p(fontSize: 6),
          items: [
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _currentIndex == 0
                      ? const Color(0xFFFCE789)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.explore_outlined),
              ),
              label: 'QUESTS',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _currentIndex == 1
                      ? const Color(0xFFFCE789)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.map_outlined),
              ),
              label: 'MAP',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _currentIndex == 2
                      ? const Color(0xFFFCE789)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.menu_book_outlined),
              ),
              label: 'JOURNAL',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _currentIndex == 3
                      ? const Color(0xFFFCE789)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.storefront_outlined),
              ),
              label: 'ARTISANS',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _currentIndex == 4
                      ? const Color(0xFFFCE789)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person_outline_rounded),
              ),
              label: 'GUIDE',
            ),
          ],
        ),
      ),
    );
  }
}
