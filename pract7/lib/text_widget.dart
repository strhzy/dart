import 'package:flutter/material.dart';
import 'text_service.dart';
import 'bitcoin.dart';

class TextWidget extends StatefulWidget {
  const TextWidget({super.key});
  @override
  State<TextWidget> createState() => _TextWidgetState();
}

class _TextWidgetState extends State<TextWidget> {
  final _textService = TextService();
  String _lang = "";
  late Bitcoin bitcoin;
  bool _loading = false;
  TextEditingController controller = TextEditingController();
  @override
  void initState() {
    super.initState();
  }

  Future<void> _loadTextLang() async {
    setState(() => _loading = true);
    late String lang;

    if (controller.text.isNotEmpty) {
      lang = await _textService.fetchText(text: controller.text);
    } else {
      return;
    }
    bitcoin = Bitcoin(
      price: 0,
      timestamp: 0,
      priceChange24h: 0,
      priceChangePercent24h: 0,
      high24h: 0,
      low24h: 0,
      volume24h: 0,
    );
    setState(() {
      _lang = lang;
      _loading = false;
    });
    controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: "Введите текст"),
          ),
          ElevatedButton(
            onPressed: _loadTextLang,
            child: Text("Определить язык"),
          ),
          _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Text(bitcoin.price.toString()),
                    Text(bitcoin.priceChange24h.toString()),
                  ],
                ),
        ],
      ),
    );
  }
}
