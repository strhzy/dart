import 'dart:io';
import 'dart:math';

void main() {
  print('Добро пожаловать в игру Крестики-Нолики!');
  final random = Random();
  
  while (true) {
    print('\nВыберите тип игры:');
    print('1. Два игрока');
    print('2. Играть против компьютера');
    stdout.write('Ваш выбор (1 или 2, по умолчанию 1): ');
    
    final choice = stdin.readLineSync();
    final gameMode = (choice?.trim() == '2') ? 2 : 1;

    final boardSize = getBoardSize();
    final gameBoard = createEmptyBoard(boardSize);

    String activePlayer = random.nextBool() ? 'X' : '0';
    print('Первым ходит игрок: $activePlayer');

    bool gameFinished = false;
    
    while (!gameFinished) {
      displayBoard(gameBoard);
      
      if (gameMode == 2 && activePlayer == '0') {
        makeComputerMove(gameBoard);
      } else {
        if (!makeHumanMove(gameBoard, activePlayer)) {
          print('Спасибо за игру!');
          return;
        }
      }

      final gameResult = determineGameResult(gameBoard);
      
      if (gameResult != Result.inProgress) {
        displayBoard(gameBoard);
        showGameResult(gameResult);
        gameFinished = true;
      } else {
        activePlayer = switchPlayer(activePlayer);
      }
    }

    if (!askForReplay()) {
      print('До свидания!');
      break;
    }
  }
}

int getBoardSize() {
  while (true) {
    stdout.write('Укажите размер игрового поля (3-9, по умолчанию 3): ');
    final input = stdin.readLineSync();
    
    if (input == null || input.trim().isEmpty) return 3;
    
    final size = int.tryParse(input.trim());
    
    if (size != null && size >= 3 && size <= 9) {
      return size;
    }
    
    print('Пожалуйста, введите число от 3 до 9');
  }
}

List<List<String>> createEmptyBoard(int size) {
  return List.generate(size, (_) => List.filled(size, ' '));
}

void displayBoard(List<List<String>> board) {
  final size = board.length;
  print('');
  stdout.write('   ');
  for (var col = 0; col < size; col++) {
    stdout.write(' ${col + 1} ');
  }
  print('');

  for (var row = 0; row < size; row++) {
    stdout.write('${row + 1}'.padLeft(2) + ' ');
    for (var col = 0; col < size; col++) {
      final cell = board[row][col].trim().isEmpty ? ' ' : board[row][col];
      stdout.write('[$cell]');
    }
    print('');
  }
  print('');
}

void makeComputerMove(List<List<String>> board) {
  final availableMoves = findEmptyCells(board);
  
  if (availableMoves.isNotEmpty) {
    final selectedMove = availableMoves[Random().nextInt(availableMoves.length)];
    final row = selectedMove[0];
    final col = selectedMove[1];
    
    board[row][col] = '0';
    print('Компьютер (0) сделал ход: строка ${row + 1}, столбец ${col + 1}');
  }
}

bool makeHumanMove(List<List<String>> board, String player) {
  while (true) {
    stdout.write('Игрок $player, введите координаты (строка столбец) или "q" для выхода: ');
    final input = stdin.readLineSync();
    
    if (input == null) continue;
    
    final trimmedInput = input.trim();
    
    if (trimmedInput.toLowerCase() == 'q') {
      return false;
    }
    
    final coordinates = trimmedInput.split(RegExp(r'\s+'));
    
    if (coordinates.length < 2) {
      print('Нужно ввести два числа через пробел');
      continue;
    }
    
    final row = int.tryParse(coordinates[0]);
    final col = int.tryParse(coordinates[1]);
    
    if (row == null || col == null) {
      print('Координаты должны быть числами');
      continue;
    }
    
    final rowIndex = row - 1;
    final colIndex = col - 1;
    final boardSize = board.length;
    
    if (rowIndex < 0 || rowIndex >= boardSize || colIndex < 0 || colIndex >= boardSize) {
      print('Координаты должны быть в диапазоне 1-$boardSize');
      continue;
    }
    
    if (board[rowIndex][colIndex].trim().isNotEmpty) {
      print('Эта клетка уже занята');
      continue;
    }
    
    board[rowIndex][colIndex] = player;
    return true;
  }
}

List<List<int>> findEmptyCells(List<List<String>> board) {
  final emptyCells = <List<int>>[];
  final size = board.length;
  
  for (var row = 0; row < size; row++) {
    for (var col = 0; col < size; col++) {
      if (board[row][col].trim().isEmpty) {
        emptyCells.add([row, col]);
      }
    }
  }
  
  return emptyCells;
}

String switchPlayer(String currentPlayer) {
  return currentPlayer == 'X' ? '0' : 'X';
}

enum Result {
  zeroWin,
  crossWin,
  draw,
  inProgress
}

const List<List<int>> winningDirections = [
  [0, 1],
  [1, 0],
  [1, 1],
  [1, -1],
];

Result determineGameResult(List<List<String>> board) {
  final size = board.length;
  const int winLength = 3;

  for (var row = 0; row < size; row++) {
    for (var col = 0; col < size; col++) {
      final cell = board[row][col];
      if (cell == ' ') continue;

      for (final dir in winningDirections) {
        final dRow = dir[0];
        final dCol = dir[1];
        if (_checkWinFromPosition(board, row, col, dRow, dCol, winLength)) {
          return cell == '0' ? Result.zeroWin : Result.crossWin;
        }
      }
    }
  }

  if (isBoardFull(board)) {
    return Result.draw;
  }

  return Result.inProgress;
}

bool _checkWinFromPosition(List<List<String>> board, int startRow, int startCol,
    int rowStep, int colStep, int winLength) {
  final symbol = board[startRow][startCol];
  final size = board.length;
  
  for (var step = 0; step < winLength; step++) {
    final row = startRow + rowStep * step;
    final col = startCol + colStep * step;

    if (row < 0 || row >= size || col < 0 || col >= size || board[row][col] != symbol) {
      return false;
    }
  }

  return true;
}

bool isBoardFull(List<List<String>> board) {
  for (final row in board) {
    for (final cell in row) {
      if (cell.trim().isEmpty) {
        return false;
      }
    }
  }
  return true;
}

void showGameResult(Result result) {
  switch (result) {
    case Result.crossWin:
      print('Победили крестики (X)!');
      break;
    case Result.zeroWin:
      print('Победили нолики (0)!');
      break;
    case Result.draw:
      print('Ничья!');
      break;
    case Result.inProgress:
      break;
  }
}

bool askForReplay() {
  stdout.write('Хотите сыграть ещё раз? (y/n, по умолчанию y): ');
  final answer = stdin.readLineSync();
  return answer == null || answer.trim().toLowerCase() != 'n';
}