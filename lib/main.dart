import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/lyrics_data.dart';
import 'src/lyrics_viewer_page.dart';

const ink = Color(0xFF17223B);
const paper = Color(0xFFF7F4ED);
const moon = Color(0xFFF2CB72);
const mutedBlue = Color(0xFF5E7294);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: ink,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: paper,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const LyricsStudyApp());
}

class LyricsStudyApp extends StatelessWidget {
  const LyricsStudyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: ink,
          brightness: Brightness.light,
          surface: paper,
        ).copyWith(
          primary: ink,
          secondary: moon,
          onSecondary: ink,
          outline: const Color(0xFFD8D4CA),
        );

    return MaterialApp(
      title: '달빛 가사 · 공개 데모',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: paper,
        fontFamilyFallback: const [
          'Noto Sans CJK KR',
          'Noto Sans CJK JP',
          'sans-serif',
        ],
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            color: ink,
            fontSize: 32,
            height: 1.18,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.0,
          ),
          headlineSmall: TextStyle(
            color: ink,
            fontSize: 22,
            height: 1.35,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
          titleMedium: TextStyle(
            color: ink,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          bodyLarge: TextStyle(color: ink, fontSize: 16, height: 1.55),
          bodyMedium: TextStyle(
            color: Color(0xFF5B6474),
            fontSize: 14,
            height: 1.5,
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: ink,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: moon.withValues(alpha: 0.35),
          height: 70,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              color: ink,
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: ink,
          contentTextStyle: TextStyle(color: Colors.white),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: const _AppLoader(),
    );
  }
}

class _AppLoader extends StatefulWidget {
  const _AppLoader();

  @override
  State<_AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<_AppLoader> {
  late Future<List<LyricsDocument>> _documents;

  @override
  void initState() {
    super.initState();
    _documents = const LyricsRepository().loadAll();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LyricsDocument>>(
      future: _documents,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          return LyricsViewerPage(documents: snapshot.data!);
        }

        if (snapshot.hasError || (snapshot.hasData && snapshot.data!.isEmpty)) {
          return _LoadError(
            message: snapshot.error?.toString() ?? '표시할 데모 문서를 찾지 못했습니다.',
            onRetry: () {
              setState(() {
                _documents = const LyricsRepository().loadAll();
              });
            },
          );
        }

        return const _LoadingScreen();
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: ink,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MoonMark(size: 72),
            SizedBox(height: 24),
            Text(
              '달빛 가사',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 22),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: moon),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.nights_stay_rounded, size: 56, color: ink),
                const SizedBox(height: 20),
                Text(
                  '데모를 불러오지 못했어요',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MoonMark extends StatelessWidget {
  const _MoonMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: moon,
        boxShadow: [
          BoxShadow(
            color: moon.withValues(alpha: 0.35),
            blurRadius: size * 0.45,
            spreadRadius: size * 0.06,
          ),
        ],
      ),
      child: Align(
        alignment: const Alignment(0.35, -0.28),
        child: Container(
          width: size * 0.16,
          height: size * 0.16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFDDB65C).withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}
