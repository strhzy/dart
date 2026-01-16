import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:convert';
import 'dart:async';

enum Direction { horizontal, vertical }
enum ShotOutcome { invalid, repeat, miss, hit, sunk, victory }
var recievePort = ReceivePort();

class LogService {
  Isolate? _isolate;
  SendPort? _sendPort;

  Future<void> start() async {
    final ready = ReceivePort();
    _isolate = await Isolate.spawn(_loggerIsolateEntry, ready.sendPort);
    final sp = await ready.first as SendPort;
    _sendPort = sp;
  }

  void log(String text) {
    _sendPort?.send({'cmd': 'log', 'text': text});
  }

  Future<void> stop() async {
    _sendPort?.send({'cmd': 'close'});
    _isolate?.kill(priority: Isolate.immediate);
  }
}

void _loggerIsolateEntry(SendPort replyTo) {
  final port = ReceivePort();
  replyTo.send(port.sendPort);
  final logFile = File('game.log');
  IOSink? sink;
  try {
    sink = logFile.openWrite(mode: FileMode.append, encoding: utf8);
  } catch (_) {
    sink = null;
  }

  port.listen((message) async {
    try {
      if (message is Map && message['cmd'] == 'log') {
        final line = message['text']?.toString() ?? '';
        final time = DateTime.now().toIso8601String();
        final out = '[$time] $line';
        if (sink != null) sink.writeln(out);
      } else if (message is Map && message['cmd'] == 'close') {
        await sink?.flush();
        await sink?.close();
        port.close();
        Isolate.exit();
      }
    } catch (_) {

    }
  });
}

class ShotFeedback {
  final ShotOutcome result;
  final String? note;
  final Vessel? target;

  const ShotFeedback(this.result, {this.note, this.target});
}

class PlayerHistory {
  final String alias;
  final int gamesPlayed;
  final int gamesWon;

  PlayerHistory({required this.alias, required this.gamesPlayed, required this.gamesWon});

  Map<String, dynamic> toJson() => {
        'alias': alias,
        'gamesPlayed': gamesPlayed,
        'gamesWon': gamesWon,
      };

  factory PlayerHistory.fromJson(Map<String, dynamic> json) {
    return PlayerHistory(
      alias: json['alias'],
      gamesPlayed: json['gamesPlayed'],
      gamesWon: json['gamesWon'],
    );
  }
}

class FileHelper {
  final StreamController<Map<String, dynamic>> _currentGameController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get currentGameUpdates =>
      _currentGameController.stream;

  Future<void> _ensureDir() async {
    final dir = Directory('players');
    if (!await dir.exists()) await dir.create(recursive: true);
  }

  Future<void> writeCurrentGame(Commander p1, Commander p2) async {
    await _ensureDir();
    final file = File('players/current_game.json');

    final data = {
      'players': [
        _serializeCommander(p1),
        _serializeCommander(p2),
      ],
      'timestamp': DateTime.now().toIso8601String(),
    };

    await file.writeAsString(jsonEncode(data), flush: true);

    if (!_currentGameController.isClosed) {
      _currentGameController.add(data);
    }
  }

  Future<void> clearCurrentGame() async {
    final file = File('players/current_game.json');
    if (await file.exists()) {
      await file.delete();
    }
    if (!_currentGameController.isClosed) {
      _currentGameController.add({'players': [], 'timestamp': DateTime.now().toIso8601String()});
    }
  }

  Map<String, dynamic> _serializeCommander(Commander c) {
    final isBot = c is AutoCommander;
    return {
      'alias': c.alias,
      'isBot': isBot,
      'history': c.history.map((p) => [p.y, p.x]).toList(),
      'sea': _serializeField(c.sea),
    };
  }

  Map<String, dynamic> _serializeField(Field f) {
    return {
      'dimension': f.dimension,
      'fleet': f.fleet.map((v) => _serializeVessel(v)).toList(),
      'hits': f.hits.map((p) => [p.y, p.x]).toList(),
      'misses': f.misses.map((p) => [p.y, p.x]).toList(),
    };
  }

  Map<String, dynamic> _serializeVessel(Vessel v) {
    return {
      'label': v.label,
      'length': v.length,
      'coords': v.coords.map((p) => [p.y, p.x]).toList(),
      'damaged': v.damaged.map((p) => [p.y, p.x]).toList(),
    };
  }

  Future<void> dispose() async {
    await _currentGameController.close();
  }
}

extension _FieldStats on Field {
  Map<String, dynamic> _stats() {
    final hitsCount = hits.length;
    final missesCount = misses.length;
    int intact = 0;
    int damaged = 0;
    int sunk = 0;
    for (var v in fleet) {
      if (v.destroyed) sunk++;
      else if (v.damaged.isNotEmpty) damaged++;
      else intact++;
    }
    return {
      'hits': hitsCount,
      'misses': missesCount,
      'shipsIntact': intact,
      'shipsDamaged': damaged,
      'shipsSunk': sunk,
      'totalShips': fleet.length,
    };
  }
}

class Point {
  final int y;
  final int x;

  const Point(this.y, this.x);

  @override
  bool operator ==(Object other) =>
      other is Point && y == other.y && x == other.x;

  @override
  int get hashCode => y.hashCode ^ (x.hashCode << 8);

  @override
  String toString() => '(${String.fromCharCode('A'.codeUnitAt(0) + x)}${y + 1})';
}

class Vessel {
  final String label;
  final int length;
  final List<Point> coords = [];
  final Set<Point> damaged = {};

  Vessel({required this.label, required this.length});

  bool get placed => coords.length == length;
  bool get destroyed => damaged.length == length;
  bool occupies(Point p) => coords.contains(p);

  bool hit(Point p) {
    if (!occupies(p)) return false;
    damaged.add(p);
    return true;
  }
}

class Field {
  final int dimension;
  final List<Vessel> fleet = [];
  final Set<Point> misses = {};
  final Set<Point> hits = {};

  Field(this.dimension);

  bool inside(Point p) =>
      p.y >= 0 && p.y < dimension && p.x >= 0 && p.x < dimension;

  bool _overlaps(Point p) =>
      fleet.any((v) => v.occupies(p));

  bool _touches(Point p) {
    for (var v in fleet) {
      for (var pos in v.coords) {
        final dy = (pos.y - p.y).abs();
        final dx = (pos.x - p.x).abs();
        if (dy <= 1 && dx <= 1 && (dy != 0 || dx != 0)) return true;
      }
    }
    return false;
  }

  bool canDeploy(int len, Point start, Direction dir) {
    for (int i = 0; i < len; i++) {
      final ny = dir == Direction.vertical ? start.y + i : start.y;
      final nx = dir == Direction.horizontal ? start.x + i : start.x;
      final p = Point(ny, nx);
      if (!inside(p) || _overlaps(p) || _touches(p)) return false;
    }
    return true;
  }

  Vessel deploy(String name, int len, Point start, Direction dir) {
    if (!canDeploy(len, start, dir)) {
      throw ArgumentError('Ошибка размещения: $name');
    }
    final ship = Vessel(label: name, length: len);
    for (int i = 0; i < len; i++) {
      final ny = dir == Direction.vertical ? start.y + i : start.y;
      final nx = dir == Direction.horizontal ? start.x + i : start.x;
      ship.coords.add(Point(ny, nx));
    }
    fleet.add(ship);
    return ship;
  }

  ShotFeedback fire(Point p) {
    if (!inside(p)) return const ShotFeedback(ShotOutcome.invalid, note: 'Мимо поля');
    if (misses.contains(p) || hits.contains(p)) {
      return const ShotFeedback(ShotOutcome.repeat, note: 'Сюда уже стреляли');
    }
    for (var v in fleet) {
      if (v.occupies(p)) {
        v.hit(p);
        hits.add(p);
        if (v.destroyed) {
          final allGone = fleet.every((s) => s.destroyed);
          return ShotFeedback(
            allGone ? ShotOutcome.victory : ShotOutcome.sunk,
            note: allGone ? 'Все корабли уничтожены!' : 'Корабль потоплен!',
            target: v,
          );
        }
        return ShotFeedback(ShotOutcome.hit, note: 'Попадание!', target: v);
      }
    }
    misses.add(p);
    return const ShotFeedback(ShotOutcome.miss, note: 'Мимо');
  }

  bool get allDestroyed => fleet.isNotEmpty && fleet.every((s) => s.destroyed);

  List<String> display({required bool reveal}) {
    final grid = List.generate(
      dimension,
      (_) => List.filled(dimension, '.'),
    );

    final sunk = <Point>{};

    if (reveal) {
      for (var v in fleet) {
        final dead = v.destroyed;
        for (var p in v.coords) {
          grid[p.y][p.x] = dead ? '#' : 'O';
          if (dead) sunk.add(p);
        }
      }
    } else {
      for (var v in fleet.where((s) => s.destroyed)) {
        sunk.addAll(v.coords);
      }
    }

    for (var m in misses) grid[m.y][m.x] = '*';
    for (var h in hits) grid[h.y][h.x] = sunk.contains(h) ? '#' : 'X';

    final colHead = List.generate(dimension, (i) => String.fromCharCode(65 + i)).join(' ');
    final lines = ['   $colHead'];
    for (int r = 0; r < dimension; r++) {
      lines.add('${(r + 1).toString().padLeft(2)} ${grid[r].join(' ')}');
    }
    return lines;
  }
}

class Commander {
  final String alias;
  final Field sea;
  final Set<Point> history = {};

  Commander({required this.alias, required this.sea});

  bool alreadyTried(Point p) => history.contains(p);
}

class AutoCommander extends Commander {
  final Random _rnd;

  AutoCommander({required super.alias, required super.sea, Random? random})
      : _rnd = random ?? Random();

  void setupFleet(List<int> sizes) {
  final sortedSizes = List<int>.from(sizes)..sort((a, b) => b - a);
  
  for (int s in sortedSizes) {
    bool ok = false;
    int attempts = 0;
    while (!ok && attempts < 10000) {
      attempts++;
      final dir = _rnd.nextBool() ? Direction.horizontal : Direction.vertical;
      final maxY = dir == Direction.vertical ? sea.dimension - s : sea.dimension - 1;
      final maxX = dir == Direction.horizontal ? sea.dimension - s : sea.dimension - 1;
      final start = Point(_rnd.nextInt(maxY + 1), _rnd.nextInt(maxX + 1));
      if (sea.canDeploy(s, start, dir)) {
        sea.deploy('Bot-$s', s, start, dir);
        ok = true;
      }
    }
    if (!ok) throw StateError('Ошибка авторазмещения');
  }
}

  Point pickTarget(Field enemy) {
    while (true) {
      final p = Point(_rnd.nextInt(enemy.dimension), _rnd.nextInt(enemy.dimension));
      if (!history.contains(p)) return p;
    }
  }
}

class Settings {
  final int size;
  final List<int> ships;

  const Settings({required this.size, required this.ships});

  static Settings small() => const Settings(size: 8, ships: [3, 2, 2, 1]);
  static Settings medium() => const Settings(size: 10, ships: [4, 3, 2, 2, 1]);
  static Settings large() => const Settings(size: 14, ships: [5, 4, 3, 3, 2, 2, 1, 1]);
}

class BattleState {
  final Commander active;
  final Commander rival;
  final bool finished;
  final Commander? victor;

  const BattleState({required this.active, required this.rival, required this.finished, this.victor});
}

class Battle {
  final Commander a;
  final Commander b;
  Commander _turn;
  Commander _enemy;

  Battle({required this.a, required this.b})
      : _turn = a,
        _enemy = b;

  BattleState get snapshot => BattleState(
        active: _turn,
        rival: _enemy,
        finished: _enemy.sea.allDestroyed,
        victor: _enemy.sea.allDestroyed ? _turn : null,
      );

  ShotFeedback attack(Point p) {
    _turn.history.add(p);
    return _enemy.sea.fire(p);
  }

  void swap() {
    final tmp = _turn;
    _turn = _enemy;
    _enemy = tmp;
  }
}

Point? parsePoint(String input, int size) {
  final s = input.trim().toUpperCase();
  if (s.isEmpty) return null;
  int i = 0;
  while (i < s.length && RegExp(r'[A-Z]').hasMatch(s[i])) i++;
  if (i == 0 || i >= s.length) return null;
  final colPart = s.substring(0, i);
  final rowPart = s.substring(i);
  final row = int.tryParse(rowPart);
  if (row == null) return null;
  final col = _lettersToIndex(colPart);
  if (col < 0) return null;
  final p = Point(row - 1, col);
  if (p.y < 0 || p.y >= size || p.x < 0 || p.x >= size) return null;
  return p;
}

int _lettersToIndex(String letters) {
  const lettersSet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  int res = 0;
  for (int i = 0; i < letters.length; i++) {
    final idx = lettersSet.indexOf(letters[i]);
    if (idx < 0) return -1;
    res = res * 26 + (idx + 1);
  }
  return res - 1;
}
