import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/sensor_model.dart';
import '../utils/notification_service.dart';

class MqttService extends ChangeNotifier {
  late MqttServerClient _client;
  late NotificationService _notificationService;

  String broker = 'broker.emqx.io'; // Correct broker as requested
  int port = 1883; // Default TCP port
  String topicSubscribe = 'project/smart_compost/data';
  String topicPublish = 'project/smart_compost/control';
  String clientId = '';

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  SensorData _currentData = SensorData(
    temp: 0.0,
    hum: 0.0,
    gas: 0,
    fan: 0,
    motorSw: false,
    motorSpeed: 0,
  );
  SensorData get currentData => _currentData;

  List<FlSpot> _tempHistory = [];
  List<FlSpot> _humHistory = [];
  List<FlSpot> _gasHistory = [];

  List<FlSpot> get tempHistory => _tempHistory;
  List<FlSpot> get humHistory => _humHistory;
  List<FlSpot> get gasHistory => _gasHistory;

  double _timeCounter = 0;

  MqttService() {
    _init();
  }

  void _init() {
    _notificationService = NotificationService();
    _notificationService.initialize();
    _setupMqttClient(username: _username, password: _password);
  }

  String? _username;
  String? _password;

  void _setupMqttClient({String? username, String? password}) {
    // 1. Acak Client ID agar tidak tabrakan sesi dengan koneksi sebelumnya (Zombie Session)
    // Tambahkan import 'dart:math'; di paling atas file
    var rng = new Random();
    clientId = 'flutter_compost_${rng.nextInt(100000)}'; 

    _client = MqttServerClient.withPort(broker, clientId, port);

    // 2. Wajib MQTT 3.1.1
    _client.setProtocolV311();
    
    // 3. Timeout & Keep Alive yang santai
    _client.logging(on: true);
    _client.keepAlivePeriod = 60; 
    _client.connectTimeoutPeriod = 10000; // 10 Detik
    
    // 4. Non-aktifkan WebSocket (Kita pakai TCP murni)
    _client.useWebSocket = false;
    
    // 5. Callback
    _client.onDisconnected = _onDisconnected;
    _client.onConnected = _onConnected;
    _client.onSubscribed = _onSubscribed;

    // --- BAGIAN KRUSIAL YANG DIPERBAIKI ---
    final connMess = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean() // Wajib clean session untuk public broker
        .keepAliveFor(60); 
        // HAPUS .withWillQos(...) -> Ini penyebab error jika tidak ada Will Topic!

    // 6. Autentikasi (Sesuai permintaan Anda pakai EMQX)
    // Jika user kosong, kita paksa pakai default EMQX
    if (username != null && username.isNotEmpty) {
      connMess.authenticateAs(username, password);
    } else {
      // Default EMQX
      connMess.authenticateAs('emqx', 'public');
    }

    _client.connectionMessage = connMess;
  }

  Future<void> connect() async {
    if (_client.connectionStatus!.state == MqttConnectionState.connected)
      return;

    try {
      print('MQTT: Connecting to $broker via TCP...');
      await _client.connect();
    } catch (e) {
      print('MQTT: Connection Exception - $e');
      _client.disconnect();
    }

    if (_client.connectionStatus!.state == MqttConnectionState.connected) {
      print('MQTT: Connected via TCP!');
      _isConnected = true;
      notifyListeners();
    } else {
      print('MQTT: Connection failed. Status: ${_client.connectionStatus}');
      _client.disconnect();
    }
  }

  void _onConnected() {
    print('MQTT: Connected callback');
    _isConnected = true;

    // Subscribe
    _client.subscribe(topicSubscribe, MqttQos.atLeastOnce);

    // Listener Pesan
    _client.updates!.listen(_onMessageReceived);

    notifyListeners();
  }

  void _onSubscribed(String topic) {
    print('MQTT: Success Subscribed to $topic');
  }

  void _onDisconnected() {
    print('MQTT: Disconnected');
    _isConnected = false;
    notifyListeners();
  }

  void _onMessageReceived(List<MqttReceivedMessage<MqttMessage>> event) {
    final MqttPublishMessage recMess = event[0].payload as MqttPublishMessage;

    try {
      String message = utf8.decode(recMess.payload.message);
      print('MQTT JSON Received: $message');

      final jsonData = json.decode(message);
      final sensorData = SensorData.fromJson(jsonData);
      _currentData = sensorData;

      // Maintain history for all sensors, keeping max 50 points as per spec
      if (_tempHistory.length >= 50) _tempHistory.removeAt(0);
      _tempHistory.add(FlSpot(_timeCounter, sensorData.temp));

      if (_humHistory.length >= 50) _humHistory.removeAt(0);
      _humHistory.add(FlSpot(_timeCounter, sensorData.hum));

      if (_gasHistory.length >= 50) _gasHistory.removeAt(0);
      _gasHistory.add(FlSpot(_timeCounter, sensorData.gas.toDouble()));

      _timeCounter++;

      _notificationService.checkAndNotifyForThresholds(
          sensorData.temp, sensorData.gas);

      notifyListeners();
    } catch (e) {
      print('MQTT Parsing Error: $e');
    }
  }

  void publishControlMessage(int fan, bool motorSw, int motorSpeed) {
    if (!_isConnected) return;

    final builder = MqttClientPayloadBuilder();
    builder.addString(json.encode({
      'fan': fan,
      'motor_sw': motorSw ? 1 : 0,
      'motor_speed': motorSpeed,
    }));

    _client.publishMessage(topicPublish, MqttQos.atLeastOnce, builder.payload!);
  }

  void disconnect() {
    _client.disconnect();
  }

  Future<void> updateSettings(String newBroker, int newPort, {String? username, String? password}) async {
    disconnect();
    broker = newBroker;
    port = newPort;
    _username = username;
    _password = password;
    _init();
    await connect();
  }
}
