import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'db.dart';
import 'screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.init();
  runApp(const NutritionCoachApp());
}

class NutritionCoachApp extends StatelessWidget {
  const NutritionCoachApp({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
    valueListenable: Store.lang,
    builder: (_, lang, __) => MaterialApp(
      title: 'Nutrition Coach', debugShowCheckedModeBanner: false,
      locale: Locale(lang), supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF72A83B)), scaffoldBackgroundColor: const Color(0xFFF5F7F2)),
      home: const Root(),
    ),
  );
}
