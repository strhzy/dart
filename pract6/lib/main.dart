import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/movie.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(MovieAdapter());
  final moviesBox = await Hive.openBox<Movie>('movies');
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('app_theme') ?? false;

  runApp(MainApp(moviesBox: moviesBox, isDarkMode: isDark));
}

class ThemeService {
  static const String _themeKey = 'app_theme';

  static Future<void> saveTheme(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, isDark);
  }

  static Future<bool> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_themeKey) ?? false;
  }
}

class MainApp extends StatefulWidget {
  const MainApp({super.key, required this.moviesBox, required this.isDarkMode});
  final Box<Movie> moviesBox;
  final bool isDarkMode;

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
  }

  void toggleTheme(bool value) {
    setState(() {
      _isDarkMode = value;
    });
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('app_theme', value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Мои киношки",
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: MainScreen(
        moviesBox: widget.moviesBox,
        onThemeToggle: toggleTheme,
        isDarkMode: _isDarkMode,
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final Box<Movie> moviesBox;
  final void Function(bool) onThemeToggle;
  final bool isDarkMode;

  const MainScreen({
    super.key,
    required this.moviesBox,
    required this.onThemeToggle,
    required this.isDarkMode,
  });

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> _screens = [
      MovieScreen(moviesBox: widget.moviesBox),
      SettingsScreen(
        onThemeToggle: widget.onThemeToggle,
        isDarkMode: widget.isDarkMode,
      ),
    ];
    final List<String> _titles = ["Киношки", "Настройки"];
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        actions: [
          IconButton(
            onPressed: () => setState(() => _currentIndex = 0),
            icon: Icon(Icons.home),
          ),
          IconButton(
            onPressed: () => setState(() => _currentIndex = 1),
            icon: Icon(Icons.settings),
          ),
        ],
      ),
      body: _screens[_currentIndex],
    );
  }
}

class SettingsScreen extends StatelessWidget {
  final void Function(bool) onThemeToggle;
  final bool isDarkMode;

  const SettingsScreen({
    super.key,
    required this.onThemeToggle,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Настройки')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Тема приложения'),
            Switch(value: isDarkMode, onChanged: onThemeToggle),
          ],
        ),
      ),
    );
  }
}

class MovieScreen extends StatefulWidget {
  final Box<Movie> moviesBox;
  const MovieScreen({super.key, required this.moviesBox});

  @override
  State<MovieScreen> createState() => _MovieScreenState();
}

class _MovieScreenState extends State<MovieScreen> {
  final Map<String, TextEditingController> _controllers = {};
  int? _editingIndex;
  @override
  void initState() {
    super.initState();
    _controllers["name"] = TextEditingController();
    _controllers["description"] = TextEditingController();
    _controllers["year"] = TextEditingController();
    _controllers["rating"] = TextEditingController();
  }

  void _saveMovie() {
    final movie = Movie();
    movie.name = _controllers["name"]!.text.trim();
    if (movie.name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Введите название фильма")));
    }
    movie.description = _controllers["description"]!.text.trim();
    if (movie.description.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Введите описание фильма")));
    }
    try {
      movie.year = int.parse(_controllers["year"]!.text.trim());
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Введите корректный год")));
    }
    try {
      movie.rating = double.parse(_controllers["rating"]!.text.trim());
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Введите корректный рейтинг")));
    }
    if (movie.year > 2026 || movie.year < 1920) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Введите настоящий год")));
    } else if (movie.rating > 10.0 || movie.rating < 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Введите рейтинг от 0 до 10")));
    } else {
      setState(() {
        if (_editingIndex == null) {
          widget.moviesBox.add(movie);
        } else {
          widget.moviesBox.putAt(_editingIndex!, movie);
          _editingIndex = null;
        }
      });
      _controllers.forEach((name, contr) {
        contr.clear();
      });
    }
  }

  void _startEditing(int index) {
    Movie? movie = widget.moviesBox.getAt(index);
    _controllers["name"]?.text = movie!.name;
    _controllers["description"]?.text = movie!.description;
    _controllers["year"]?.text = movie!.year.toString();
    _controllers["rating"]?.text = movie!.rating.toString();
    _editingIndex = index;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _controllers["name"],
                  decoration: const InputDecoration(hintText: "Название"),
                ),
                TextField(
                  controller: _controllers["description"],
                  decoration: const InputDecoration(hintText: "Описание"),
                ),
                TextField(
                  controller: _controllers["year"],
                  decoration: const InputDecoration(hintText: "Год"),
                ),
                TextField(
                  controller: _controllers["rating"],
                  decoration: const InputDecoration(hintText: "Рейтинг"),
                ),
                ElevatedButton(onPressed: _saveMovie, child: Text("Сохранить")),
              ],
            ),
          ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: widget.moviesBox.listenable(),
              builder: (context, Box<Movie> box, _) {
                return ListView.builder(
                  itemCount: box.length,
                  itemBuilder: (context, index) {
                    Movie movie = box.getAt(index)!;
                    return ListTile(
                      title: Text(movie.name),
                      subtitle: Text(
                        'Год: ${movie.year}, Рейтинг: ${movie.rating}',
                      ),
                      onTap: () => _startEditing(index),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          setState(() {
                            box.deleteAt(index);
                            if (_editingIndex == index) {
                              _controllers.forEach((name, contr) {
                                contr.clear();
                              });
                              _editingIndex == null;
                            } else if (_editingIndex != null &&
                                _editingIndex! > index) {
                              _editingIndex = _editingIndex! - 1;
                            }
                          });
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
