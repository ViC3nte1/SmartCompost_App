class SensorData {
  final double temp;
  final double hum;
  final int gas;
  final int fan;
  final bool motorSw;
  final int motorSpeed;

  SensorData({
    required this.temp,
    required this.hum,
    required this.gas,
    required this.fan,
    required this.motorSw,
    required this.motorSpeed,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    // Helper aman untuk konversi angka
    double toDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is int) return val.toDouble();
      if (val is double) return val;
      return double.tryParse(val.toString()) ?? 0.0;
    }

    int toInt(dynamic val) {
      if (val == null) return 0;
      if (val is int) return val;
      if (val is double) return val.toInt();
      return int.tryParse(val.toString()) ?? 0;
    }

    return SensorData(
      temp: toDouble(json['temp']),
      hum: toDouble(json['hum']),
      gas: toInt(json['gas']),
      fan: toInt(json['fan']),
      // Handle boolean atau integer 0/1
      motorSw: (json['motor_sw'] == true || json['motor_sw'] == 1),
      motorSpeed: toInt(json['motor_speed']),
    );
  }
}