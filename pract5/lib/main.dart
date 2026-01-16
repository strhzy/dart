import 'package:flutter/material.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Заметки',
      theme: ThemeData(useMaterial3: true),
      home: const NotesScreen(),
    );
  }
}

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<String> _notes = [];
  int? _editingIndex;

  void _saveNote() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      if (_editingIndex == null) {
        _notes.add(text);
      } else {
        _notes[_editingIndex!] = text;
        _editingIndex = null;
      }
      _controller.clear();
    });
  }

  void _startEditing(int index) {
    _controller.text = _notes[index];
    _editingIndex = index;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Мои заметки')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Введите заметку',
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: _saveNote,
                  child: Text(_editingIndex == null ? 'Сохранить' : 'Обновить'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _notes.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_notes[index]),
                  onTap: () => _startEditing(index),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      setState(() {
                        _notes.removeAt(index);
                        if (_editingIndex == index) {
                          _controller.clear();
                          _editingIndex = null;
                        } else if (_editingIndex != null &&
                            _editingIndex! > index) {
                          _editingIndex = _editingIndex! - 1;
                        }
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
