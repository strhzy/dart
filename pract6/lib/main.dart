import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/movie.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(MovieAdapter());
  final moviesBox = await Hive.openBox<Movie>('movies');
  runApp(MainApp(moviesBox: await moviesBox));
}

class MainApp extends StatelessWidget {
  const MainApp({super.key, required this.moviesBox});
  final Box<Movie> moviesBox;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Мои киношки",
      home: MovieScreen(moviesBox: moviesBox),
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
      appBar: AppBar(title: const Text("Киношки")),
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
