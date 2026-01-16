import 'dart:nativewrappers/_internal/vm/lib/developer.dart';

import 'package:flutter/material.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  void printbebebe(){
    print("bebebe");
  }

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(children: <Widget> [
            ElevatedButton(onPressed: (){debugPrint();}, child: Text("bebebebe"))
          ],)
        ),
      ),
    );
  }

}
