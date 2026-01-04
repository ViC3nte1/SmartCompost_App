import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:provider/provider.dart';
import '../services/mqtt_service.dart';
import '../models/sensor_model.dart';
import '../services/notification_service.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool? _localSafetyState;
  double? _localSliderValue;

  DateTime? _lastNotificationTime;
  final NotificationService _notifService = NotificationService();

  void _checkAndTriggerNotification(double gas, double temp) {
    // Cek apakah kondisi Kritis atau Bahaya
    bool isCritical = (gas > 60 && temp > 65);
    bool isGasDanger = (gas > 60);
    bool isTempDanger = (temp > 65);

    if (isCritical || isGasDanger || isTempDanger) {
      DateTime now = DateTime.now();

      // Logika: Hanya bunyikan notif jika belum pernah bunyi, 
      // atau sudah lewat 1 menit sejak notif terakhir.
      if (_lastNotificationTime == null ||
          now.difference(_lastNotificationTime!).inMinutes >= 1) {
        
        String title = "PERINGATAN KOMPOS!";
        String body = "";

        if (isCritical) {
          body = "BAHAYA: Suhu & Gas Tinggi Sekaligus! Cek Segera!";
        } else if (isGasDanger) {
          body = "Gas Amonia Tinggi: ${gas.toStringAsFixed(0)}% (Batas 60%)";
        } else if (isTempDanger) {
          body = "Suhu Terlalu Panas: ${temp.toStringAsFixed(1)}°C";
        }

        // Panggil Notifikasi Pop-up
        _notifService.showNotification(1, title, body, "alert_payload");
        
        // Update waktu terakhir notif
        _lastNotificationTime = now;
        print("Notifikasi dikirim: $body");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mqttService = Provider.of<MqttService>(context);
    final sensorData = mqttService.currentData;

    bool currentSafetyUI = _localSafetyState ?? sensorData.motorSw;
    double currentSpeedUI =
        _localSliderValue ?? sensorData.motorSpeed.toDouble();
    bool isFanOn = sensorData.fan == 1;
    _checkAndTriggerNotification(sensorData.gas.toDouble(), sensorData.temp);

    // --- LOGIKA STATUS (MULTI-ALERT) ---
    // Kita tampung semua peringatan dalam sebuah List
    List<Widget> alertWidgets = [];

    // 1. CEK SUHU (Cek Sendiri)
    if (sensorData.temp > 65) {
      alertWidgets.add(_buildStatusCard(
          "Suhu Bahaya",
          "Suhu panas (${sensorData.temp.toStringAsFixed(1)}°C). Kipas perlu nyala.",
          Colors.red,
          Icons.thermostat));
      alertWidgets.add(SizedBox(height: 12)); // Spasi antar kartu
    } else if (sensorData.temp > 45) {
      alertWidgets.add(_buildStatusCard(
          "Suhu Waspada",
          "Suhu mulai naik (${sensorData.temp.toStringAsFixed(1)}°C).",
          Colors.orange[800]!,
          Icons.thermostat));
      alertWidgets.add(SizedBox(height: 12));
    }

    // 2. CEK GAS (Cek Sendiri)
    if (sensorData.gas > 60) {
      alertWidgets.add(_buildStatusCard(
          "Bahaya Gas",
          "Kadar gas tinggi (${sensorData.gas}%). Cek ventilasi!",
          Colors.red,
          Icons.warning));
      alertWidgets.add(SizedBox(height: 12));
    } else if (sensorData.gas > 30) {
      alertWidgets.add(_buildStatusCard(
          "Waspada Gas",
          "Gas mulai meningkat (${sensorData.gas}%).",
          Colors.orange[800]!,
          Icons.info));
      alertWidgets.add(SizedBox(height: 12));
    }

    // 3. JIKA TIDAK ADA PERINGATAN SAMA SEKALI -> TAMPILKAN NORMAL
    if (alertWidgets.isEmpty) {
      alertWidgets.add(_buildStatusCard(
          "System Normal",
          "Kondisi kompos optimal. Tidak ada peringatan.",
          Colors.green,
          Icons.check_circle));
    }

    // --- LOGIKA WARNA BAR SUHU ---
    Color tempBarColor = Colors.green;
    if (sensorData.temp > 65) {
      tempBarColor = Colors.red;
    } else if (sensorData.temp > 45) {
      tempBarColor = Colors.orange;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Smart Compost Monitor',
          style: GoogleFonts.poppins(
              color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Color(0xFF2E7D32),
        elevation: 0,
        actions: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: EdgeInsets.only(right: 16, top: 10, bottom: 10),
            decoration: BoxDecoration(
              color:
                  mqttService.isConnected ? Colors.green[800] : Colors.red[800],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(Icons.circle,
                    size: 10,
                    color: mqttService.isConnected
                        ? Colors.greenAccent
                        : Colors.redAccent),
                SizedBox(width: 6),
                Text(
                  mqttService.isConnected ? 'LIVE' : 'OFFLINE',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Container(
        color: Color(0xFFFAFAFA),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              
              // --- MENAMPILKAN LIST STATUS CARD (BISA LEBIH DARI SATU) ---
              Column(
                children: alertWidgets,
              ),

              SizedBox(height: 24),
              Text('Sensor Overview',
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800])),
              SizedBox(height: 12),

              // Sensor Cards
              Row(
                children: [
                  Expanded(
                      child: _buildSensorCard(
                    icon: Icons.thermostat,
                    title: 'Temperature',
                    value: '${sensorData.temp.toStringAsFixed(1)}°C',
                    percentage: (sensorData.temp / 80.0).clamp(0.0, 1.0),
                    color: tempBarColor,
                  )),
                  SizedBox(width: 12),
                  Expanded(
                      child: _buildSensorCard(
                    icon: Icons.water_drop,
                    title: 'Humidity',
                    value: '${sensorData.hum.toStringAsFixed(1)}%',
                    percentage: (sensorData.hum / 100.0).clamp(0.0, 1.0),
                    color: Colors.blue,
                  )),
                ],
              ),
              SizedBox(height: 12),
              
              // --- KARTU GAS ---
              _buildGasSensorCard(sensorData),

              SizedBox(height: 24),
              Text('Device Control',
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.w600)),
              SizedBox(height: 12),

              // --- FAN STATUS ---
              _buildControlCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Icon(Icons.cyclone,
                          color: isFanOn ? Colors.green : Colors.grey),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Cooling Fan',
                              style: GoogleFonts.poppins(
                                  fontSize: 16, fontWeight: FontWeight.w500)),
                          Text('Automatic Control',
                              style:
                                  TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ]),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isFanOn
                            ? Colors.green.withOpacity(0.2)
                            : Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: isFanOn ? Colors.green : Colors.grey),
                      ),
                      child: Text(
                        isFanOn ? "ACTIVE" : "IDLE",
                        style: TextStyle(
                          color: isFanOn ? Colors.green[800] : Colors.grey[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    )
                  ],
                ),
              ),
              SizedBox(height: 12),

              // --- MOTOR CONTROL ---
              _buildControlCard(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          Icon(Icons.settings,
                              color:
                                  currentSafetyUI ? Colors.green : Colors.grey),
                          SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Motor Mixer',
                                  style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500)),
                              Text('Manual Control',
                                  style: TextStyle(
                                      fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        ]),
                        Switch(
                          value: currentSafetyUI,
                          activeColor: Colors.green,
                          onChanged: (val) {
                            setState(() => _localSafetyState = val);
                            mqttService.publishControlMessage(
                                0, val, val ? currentSpeedUI.toInt() : 0);
                          },
                        )
                      ],
                    ),
                    Divider(),
                    Text('Speed: ${currentSpeedUI.toInt()} / 255',
                        style: TextStyle(color: Colors.grey)),

                    // Slider Max 255
                    Slider(
                      value: currentSpeedUI,
                      min: 0,
                      max: 255,
                      divisions: 255,
                      activeColor: currentSafetyUI ? Colors.green : Colors.grey,
                      thumbColor: currentSafetyUI ? Colors.green : Colors.grey,
                      onChanged: currentSafetyUI
                          ? (val) {
                              setState(() => _localSliderValue = val);
                            }
                          : null,
                      onChangeEnd: (val) {
                        mqttService.publishControlMessage(
                            0, currentSafetyUI, val.toInt());
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildStatusCard(
      String title, String desc, Color color, IconData icon) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      // Hapus margin bottom di sini karena kita pakai SizedBox di List
      decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 10,
                offset: Offset(0, 4))
          ]),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("System Status",
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text(title,
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                Text(desc, style: TextStyle(color: Colors.white, fontSize: 14)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildControlCard({required Widget child}) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 4))
        ],
      ),
      child: child,
    );
  }

  Widget _buildSensorCard(
      {required IconData icon,
      required String title,
      required String value,
      required double percentage,
      required Color color}) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          SizedBox(height: 8),
          Text(title, style: TextStyle(color: Colors.grey, fontSize: 12)),
          SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          LinearPercentIndicator(
            lineHeight: 6,
            percent: percentage,
            progressColor: color,
            backgroundColor: color.withOpacity(0.1),
            barRadius: Radius.circular(3),
            padding: EdgeInsets.zero,
          )
        ],
      ),
    );
  }

  Widget _buildGasSensorCard(SensorData data) {
    Color cardColor;
    Color iconColor;
    Color textColor;
    IconData? statusIcon;
    bool showBorder = false;

    if (data.gas > 60) {
      cardColor = Colors.red[50]!;
      iconColor = Colors.red;
      textColor = Colors.red;
      statusIcon = Icons.warning;
      showBorder = true;
    } else if (data.gas > 30) {
      cardColor = Colors.orange[50]!;
      iconColor = Colors.orange;
      textColor = Colors.orange[800]!;
      statusIcon = Icons.info;
      showBorder = true;
    } else {
      cardColor = Colors.white;
      iconColor = Colors.blueGrey;
      textColor = Colors.black;
      statusIcon = null;
      showBorder = false;
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: showBorder ? Border.all(color: iconColor.withOpacity(0.5)) : null,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 4))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Icon(Icons.cloud, color: iconColor),
            SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Gas Level',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
              Text('${data.gas} %',
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor)),
            ])
          ]),
          if (statusIcon != null) Icon(statusIcon, color: iconColor),
        ],
      ),
    );
  }
}