import 'package:material_ui/material_ui.dart';

import '../../../app_scope.dart';
import '../../history/view_models/history_view_model.dart';
import '../../history/views/history_screen.dart';
import '../../home/views/home_screen.dart';
import '../../info/views/info_screen.dart';
import 'app_bottom_nav.dart';

/// The three tabs and the bar that switches between them.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  AppTab _tab = AppTab.home;
  HistoryViewModel? _history;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_history != null) return;
    final dependencies = AppScope.of(context);
    _history = HistoryViewModel(
      history: dependencies.history,
      content: dependencies.content,
      clock: dependencies.clock,
    );
  }

  @override
  void dispose() {
    _history?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final history = _history!;
    return PopScope(
      // Back on another tab returns to Beranda before it leaves the app.
      canPop: _tab == AppTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _tab = AppTab.home);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _tab.index,
          children: [
            HomeScreen(history: history),
            HistoryScreen(history: history),
            const InfoScreen(),
          ],
        ),
        bottomNavigationBar: AppBottomNav(
          current: _tab,
          onSelected: (tab) => setState(() => _tab = tab),
        ),
      ),
    );
  }
}
