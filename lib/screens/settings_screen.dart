import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/mqtt_service.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controller
  final TextEditingController _brokerCtrl = TextEditingController();
  final TextEditingController _portCtrl = TextEditingController();
  final TextEditingController _clientCtrl = TextEditingController();
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Load dengan Default Value Otomatis
  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? broker = prefs.getString('mqtt_broker');
    int? port = prefs.getInt('mqtt_port');
    String? client = prefs.getString('mqtt_client_id');
    String? username = prefs.getString('mqtt_username');
    String? password = prefs.getString('mqtt_password');

    setState(() {
      // If empty, fill with correct default broker
      _brokerCtrl.text = (broker != null && broker.isNotEmpty) ? broker : 'broker.emqx.io';
      _portCtrl.text = (port != null) ? port.toString() : '1883';
      _clientCtrl.text = client ?? 'flutter_client_${DateTime.now().millisecondsSinceEpoch}';
      _usernameCtrl.text = username ?? '';
      _passwordCtrl.text = password ?? '';
    });
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      // Tutup keyboard
      FocusScope.of(context).unfocus();

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('mqtt_broker', _brokerCtrl.text);
      await prefs.setInt('mqtt_port', int.parse(_portCtrl.text));
      await prefs.setString('mqtt_client_id', _clientCtrl.text);
      await prefs.setString('mqtt_username', _usernameCtrl.text);
      await prefs.setString('mqtt_password', _passwordCtrl.text);

      final mqttService = Provider.of<MqttService>(context, listen: false);

      // Tampilkan Loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connecting to ${_brokerCtrl.text}...')),
      );

      // Update & Reconnect
      await mqttService.updateSettings(
        _brokerCtrl.text,
        int.parse(_portCtrl.text),
        username: _usernameCtrl.text,
        password: _passwordCtrl.text,
      );

      if (mounted) {
        // Cek hasil koneksi
        bool success = mqttService.isConnected;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Connected Successfully!' : 'Connection Failed!'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Gunakan Consumer agar tampilan otomatis berubah saat status koneksi berubah
    return Consumer<MqttService>(
      builder: (context, mqttService, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text('Settings', style: GoogleFonts.poppins(color: Colors.white)),
            backgroundColor: Color(0xFF2E7D32),
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- CONNECTION STATUS CARD ---
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: mqttService.isConnected ? Colors.green[50] : Colors.red[50],
                      border: Border.all(color: mqttService.isConnected ? Colors.green : Colors.red),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          mqttService.isConnected ? Icons.check_circle : Icons.error,
                          color: mqttService.isConnected ? Colors.green : Colors.red,
                          size: 30,
                        ),
                        SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mqttService.isConnected ? 'CONNECTED' : 'DISCONNECTED',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: mqttService.isConnected ? Colors.green[800] : Colors.red[800],
                                fontSize: 16
                              ),
                            ),
                            Text(
                              mqttService.isConnected 
                                ? 'Connected to ${mqttService.broker}' 
                                : 'Check your internet or broker settings',
                              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                  SizedBox(height: 24),

                  Text('Broker Configuration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green[800])),
                  SizedBox(height: 8),
                  Text(
                    'Note: Uses broker.mqtt.io (port 1883). Username and password can be customized below.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 16),

                  TextFormField(
                    controller: _brokerCtrl,
                    decoration: InputDecoration(
                      labelText: 'Broker Address',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.cloud),
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  SizedBox(height: 16),

                  TextFormField(
                    controller: _portCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Port (TCP)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.settings_input_component),
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  SizedBox(height: 16),

                  TextFormField(
                    controller: _clientCtrl,
                    decoration: InputDecoration(
                      labelText: 'Client ID',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.refresh),
                        onPressed: () {
                          setState(() {
                            _clientCtrl.text = 'flutter_${DateTime.now().millisecondsSinceEpoch}';
                          });
                        },
                      )
                    ),
                  ),

                  SizedBox(height: 16),

                  TextFormField(
                    controller: _usernameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),

                  SizedBox(height: 16),

                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),

                  SizedBox(height: 30),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _saveSettings,
                      icon: Icon(Icons.save),
                      label: Text('SAVE & RECONNECT'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}