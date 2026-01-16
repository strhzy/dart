import 'dart:io';
import 'dart:math';
import 'dart:isolate';
import 'package:pract2/pract2.dart';

Future<void> main(List<String> args) async {
  await _start();
}

Future<void> _start() async {
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

  final fh = FileHelper();
  final logger = LogService();
  await logger.start();

  logger.log('Начало новой игры: ${p1.alias} vs ${p2.alias}');

  _deploy(p1, conf, auto: false, logger: logger, fh: fh);
  await fh.writeCurrentGame(p1, p2);
  _handover(p2.alias);
  _deploy(p2, conf, auto: botMode, logger: logger, fh: fh);
  await fh.writeCurrentGame(p1, p2);

  final battle = Battle(a: p1, b: p2);
  
  while (true) {
    final snap = battle.snapshot;
    if (snap.finished) {
      _cls();
      print('Победитель: ${snap.victor!.alias}');
      break;
    }
    final repeat = _round(battle, bot: botMode, fh: fh, logger: logger);
    if (!repeat) {
      battle.swap();
      _handover(battle.snapshot.active.alias);
    }
  }
  await fh.clearCurrentGame();
  logger.log('Игра окончена: Победитель ${battle.snapshot.victor?.alias}');
  await logger.stop();
}

bool _round(Battle game, {required bool bot, required FileHelper fh, required LogService logger}) {
  final active = game.snapshot.active;
  final enemy = game.snapshot.rival;
  _cls();
  print('Ход: ${active.alias}\n');
  if (bot && active is AutoCommander) {
    print('Бот делает ход...\n');
  } else {
    print('Ваше поле:');
    active.sea.display(reveal: true).forEach(print);
    print('\nПоле противника:');
    enemy.sea.display(reveal: false).forEach(print);
    print('');
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
        logger.log('${active.alias} попытался стрелять в ${p.toString()}, но уже стрелял ранее.');
        fh.writeCurrentGame(game.a, game.b);
        continue;
      }
      target = p;
      break;
    }
  }

  final res = game.attack(target);
  fh.writeCurrentGame(game.a, game.b);
  switch (res.result) {
    case ShotOutcome.invalid:
      print(res.note ?? 'Ошибка');
      logger.log('${active.alias} попытался стрелять в ${target.toString()}: ${res.note ?? 'invalid'}');
      _wait();
      return true;
    case ShotOutcome.repeat:
      print(res.note ?? 'Повтор');
      logger.log('${active.alias} повторный выстрел в ${target.toString()}');
      _wait();
      return true;
    case ShotOutcome.miss:
      print('Мимо.');
      logger.log('${active.alias} сделал выстрел в ${target.toString()}: Мимо');
      _wait();
      return false;
    case ShotOutcome.hit:
      print('Попадание!');
      logger.log('${active.alias} сделал выстрел в ${target.toString()}: Попадание');
      _wait();
      return true;
    case ShotOutcome.sunk:
      print('Корабль потоплен!');
      logger.log('${active.alias} сделал выстрел в ${target.toString()}: Корабль потоплен');
      _wait();
      return true;
    case ShotOutcome.victory:
      print('Все корабли уничтожены!');
      logger.log('${active.alias} сделал выстрел в ${target.toString()}: Победа!');
      _wait();
      return true;
  }
}

void _deploy(Commander player, Settings conf, {required bool auto, LogService? logger, FileHelper? fh}) {
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
        logger?.log('${player.alias} ввёл неверную точку при расстановке: "$inStr"');
        _wait();
        continue;
      }
      print('Ориентация: 1) горизонтально 2) вертикально');
      final o = _pick(1, 2);
      final dir = o == 1 ? Direction.horizontal : Direction.vertical;
      if (!player.sea.canDeploy(s, start, dir)) {
        final msg = 'Ошибка: ${player.alias} пытался поставить корабль длиной $s на ${start.toString()} $dir — нельзя разместить';
        print('Нельзя поставить сюда.');
        logger?.log(msg);
        _wait();
        continue;
      }
      player.sea.deploy('Ship-$s-${player.sea.fleet.length + 1}', s, start, dir);
      logger?.log('${player.alias} разместил корабль длиной $s в ${start.toString()} ${dir == Direction.horizontal ? 'гор.' : 'верт.'}');
      fh?.writeCurrentGame(player, player);
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
  stdout.write('\x1B[2J\x1B[3J\x1B[H');
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
