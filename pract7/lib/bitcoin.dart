import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

final service = GetIt.instance;

class BitcoinService {
  Future<Bitcoin> fetchBitcoin() async {
    try {
      final response = await service<Dio>().get('/bitcoin');
      final data = response.data as Map<String, dynamic>;
      return Bitcoin.fromJson(data);
    } on DioException catch (e) {
      print("Ошибка: ${e.message}");
      Bitcoin bitcoin = Bitcoin(
        price: 0,
        timestamp: 0,
        priceChange24h: 0,
        priceChangePercent24h: 0,
        high24h: 0,
        low24h: 0,
        volume24h: 0,
      );
      return bitcoin;
    } catch (e) {
      print("Ошибка: $e");
      Bitcoin bitcoin = Bitcoin(
        price: 0,
        timestamp: 0,
        priceChange24h: 0,
        priceChangePercent24h: 0,
        high24h: 0,
        low24h: 0,
        volume24h: 0,
      );
      return bitcoin;
    }
  }
}

class Bitcoin {
  final double price;
  final int timestamp;
  final double priceChange24h;
  final double priceChangePercent24h;
  final double high24h;
  final double low24h;
  final double volume24h;

  Bitcoin({
    required this.price,
    required this.timestamp,
    required this.priceChange24h,
    required this.priceChangePercent24h,
    required this.high24h,
    required this.low24h,
    required this.volume24h,
  });

  factory Bitcoin.fromJson(Map<String, dynamic> json) {
    return Bitcoin(
      price: double.parse(json['price']),
      timestamp: json['timestamp'],
      priceChange24h: double.parse(json['24h_price_change']),
      priceChangePercent24h: double.parse(json['24h_price_change_percent']),
      high24h: double.parse(json['24h_high']),
      low24h: double.parse(json['24h_low']),
      volume24h: double.parse(json['24h_volume']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'price': price.toStringAsFixed(8),
      'timestamp': timestamp,
      '24h_price_change': priceChange24h.toStringAsFixed(8),
      '24h_price_change_percent': priceChangePercent24h.toStringAsFixed(3),
      '24h_high': high24h.toStringAsFixed(8),
      '24h_low': low24h.toStringAsFixed(8),
      '24h_volume': volume24h.toStringAsFixed(8),
    };
  }
}
