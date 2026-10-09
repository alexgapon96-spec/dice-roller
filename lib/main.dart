import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'feedback/roll_feedback.dart';
import 'home_screen.dart';
import 'settings.dart';
import 'widgets/die_picker_sheet.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
  ));
  final settings = await AppSettings.load();
  final feedback = RollFeedback(settings);
  // Sounds load in the background so startup isn't delayed.
  feedback.init();
  runApp(DiceRollerApp(settings: settings, feedback: feedback));
}

class DiceRollerApp extends StatelessWidget {
  const DiceRollerApp({super.key, required this.settings, required this.feedback});

  final AppSettings settings;
  final RollFeedback feedback;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dice Roller',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF6A4A96),
        brightness: Brightness.dark,
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: sheetColor,
          dragHandleColor: Color(0xFF6A4A96),
        ),
      ),
      home: HomeScreen(settings: settings, feedback: feedback),
    );
  }
}
