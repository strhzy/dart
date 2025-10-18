import 'dart:io';
import 'dart:math';
import 'package:pract2/pract2.dart';

void main(List<String> args) {
  _start();
}

void _start() {
  _cls();
  print('Морской бой');
  print('\nРежим:\n1) Игрок vs Игрок\n2) Игрок vs Бот');
  final mode = _pick(1, 2);

  print('\nРазмер поля:\n1) 8x8\n2) 10x10\n3) 14x14');
  final sizeOpt = _pick(1, 3);
  final conf = switch (sizeOpt) {
    1 => Settings.small(),
    2 => Settings.medium(),
    _ => Settings.large(),
  };

  stdout.write('Имя Игрока 1: ');
  final p1Name = _read();
  final p1 = Commander(alias: p1Name, sea: Field(conf.size));

  final bool botMode = mode == 2;
  late final Commander p2;
  if (botMode) {
    p2 = AutoCommander(alias: 'Бот', sea: Field(conf.size), random: Random());
  } else {
    stdout.write('Имя Игрока 2: ');
    final p2Name = _read();
    p2 = Commander(alias: p2Name, sea: Field(conf.size));
  }

  _deploy(p1, conf, auto: false);
  _handover(p2.alias);
  _deploy(p2, conf, auto: botMode);

  final battle = Battle(a: p1, b: p2);

  while (true) {
    final snap = battle.snapshot;
    if (snap.finished) {
      _cls();
      print('Победитель: ${snap.victor!.alias}');
      break;
    }
    final repeat = _round(battle, bot: botMode);
    if (!repeat) {
      battle.swap();
      _handover(battle.snapshot.active.alias);
    }
  }
}

bool _round(Battle game, {required bool bot}) {
  final active = game.snapshot.active;
  final enemy = game.snapshot.rival;
  _cls();
  print('Ход: ${active.alias}\n');
  if (!(bot && active is AutoCommander)) {
    print('Ваше поле:');
    active.sea.display(reveal: true).forEach(print);
    print('\nПоле противника:');
    enemy.sea.display(reveal: false).forEach(print);
    print('');
  } else {
    print('Бот делает ход...\n');
  }

  late Point target;
  if (bot && active is AutoCommander) {
    target = active.pickTarget(enemy.sea);
    print('Бот стреляет по ${target.toString()}');
  } else {
    while (true) {
      stdout.write('Введите координату выстрела: ');
      final s = stdin.readLineSync() ?? '';
      final p = parsePoint(s, enemy.sea.dimension);
      if (p == null) {
        print('Неверный формат. Пример: A1');
        continue;
      }
      if (active.alreadyTried(p)) {
        print('Уже стреляли сюда.');
        continue;
      }
      target = p;
      break;
    }
  }

  final res = game.attack(target);
  switch (res.result) {
    case ShotOutcome.invalid:
      print(res.note ?? 'Ошибка');
      _wait();
      return true;
    case ShotOutcome.repeat:
      print(res.note ?? 'Повтор');
      _wait();
      return true;
    case ShotOutcome.miss:
      print('Мимо.');
      _wait();
      return false;
    case ShotOutcome.hit:
      print('Попадание!');
      _wait();
      return true;
    case ShotOutcome.sunk:
      print('Корабль потоплен!');
      _wait();
      return true;
    case ShotOutcome.victory:
      print('Все корабли уничтожены!');
      _wait();
      return true;
  }
}

void _deploy(Commander player, Settings conf, {required bool auto}) {
  _cls();
  if (auto && player is AutoCommander) {
    player.setupFleet(conf.ships);
    print('Корабли бота размещены.\nEnter для продолжения...');
    stdin.readLineSync();
    return;
  }
  print('Расстановка кораблей — ${player.alias}\n');
  for (int s in conf.ships) {
    while (true) {
      _cls();
      print('Игрок: ${player.alias}, корабль длиной $s\n');
      player.sea.display(reveal: true).forEach(print);
      print('');
      stdout.write('Координата начала: ');
      final inStr = stdin.readLineSync() ?? '';
      final start = parsePoint(inStr, player.sea.dimension);
      if (start == null) {
        print('Неверная точка.');
        _wait();
        continue;
      }
      print('Ориентация: 1) горизонтально 2) вертикально');
      final o = _pick(1, 2);
      final dir = o == 1 ? Direction.horizontal : Direction.vertical;
      if (!player.sea.canDeploy(s, start, dir)) {
        print('Нельзя поставить сюда.');
        _wait();
        continue;
      }
      player.sea.deploy('Ship-$s-${player.sea.fleet.length + 1}', s, start, dir);
      break;
    }
  }
}

void _handover(String name) {
  _cls();
  print('Передайте ход игроку: $name\nНажмите Enter...');
  stdin.readLineSync();
}

void _cls() {
  if (Platform.isWindows) {
    stdout.write('\n' * 50);
  } else {
    stdout.write('\x1B[2J\x1B[H');
  }
}

int _pick(int min, int max) {
  while (true) {
    stdout.write('Выбор [$min-$max]: ');
    final s = stdin.readLineSync() ?? '';
    final v = int.tryParse(s);
    if (v != null && v >= min && v <= max) return v;
    print('Неверный ввод.');
  }
}

String _read() {
  while (true) {
    final s = stdin.readLineSync()?.trim() ?? '';
    if (s.isNotEmpty) return s;
    stdout.write('Введите непустое имя: ');
  }
}

void _wait() {
  print('Enter для продолжения...');
  stdin.readLineSync();
}
