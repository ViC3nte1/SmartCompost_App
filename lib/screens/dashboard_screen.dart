import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
// import 'package:fl_chart/fl_chart.dart'; // HAPUS INI (Tidak perlu chart di sini)
import 'package:provider/provider.dart';
import '../services/mqtt_service.dart';
import '../models/sensor_model.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Local State untuk Motor (Safety & Slider)
  bool? _localSafetyState;
  double? _localSliderValue;

  @override
  Widget build(BuildContext context) {
    final mqttService = Provider.of<MqttService>(context);
    final sensorData = mqttService.currentData;
    // final history = mqttService.tempHistory; // HAPUS INI

    bool currentSafetyUI = _localSafetyState ?? sensorData.motorSw;
    double currentSpeedUI =
        _localSliderValue ?? sensorData.motorSpeed.toDouble();
    bool isFanOn = sensorData.fan == 1;

    // --- LOGIKA STATUS KESEHATAN KOMPOS ---
    String statusTitle = "Normal";
    String statusDesc = "Kondisi kompos optimal.";
    Color statusColor = Colors.green;
    IconData statusIcon = Icons.check_circle;

    if (sensorData.gas > 500 && sensorData.temp > 33) {
      statusTitle = "KONDISI KRITIS";
      statusDesc = "Suhu & Gas berlebih! Segera buka penutup.";
      statusColor = Color(0xFFB71C1C); // Merah Tua (Dark Red)
      statusIcon = Icons.dangerous; // Ikon Bahaya
    }
    // 2. Cek Jika Hanya Gas Bermasalah
    else if (sensorData.gas > 500) {
      statusTitle = "Bahaya Gas";
      statusDesc = "Kadar amonia tinggi! Cek ventilasi.";
      statusColor = Colors.red;
      statusIcon = Icons.warning;
    }
    // 3. Cek Jika Hanya Suhu Bermasalah
    else if (sensorData.temp > 33) {
      statusTitle = "Suhu Tinggi";
      statusDesc = "Suhu panas. Kipas perlu dinyalakan.";
      statusColor = Colors.orange[800]!; // Oranye Tua
      statusIcon = Icons.thermostat;
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
              // --- PENGGANTI GRAFIK: STATUS CARD ---
              // Memberikan insight langsung tanpa perlu baca grafik
              _buildStatusCard(
                  statusTitle, statusDesc, statusColor, statusIcon),

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
                    percentage: (sensorData.temp / 60.0).clamp(0.0, 1.0),
                    color: sensorData.temp > 33 ? Colors.red : Colors.orange,
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
              _buildGasSensorCard(sensorData),

              SizedBox(height: 24),
              Text('Device Control',
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.w600)),
              SizedBox(height: 12),

              // --- FAN STATUS (READ ONLY) ---
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

              // --- MOTOR CONTROL (MANUAL) ---
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
                              Text('Motor Mixer', // Ganti nama biar beda dikit
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
                                0, // Fan ignored
                                val,
                                val ? currentSpeedUI.toInt() : 0);
                          },
                        )
                      ],
                    ),
                    Divider(),
                    Text('Speed: ${currentSpeedUI.toInt()} / 150',
                        style: TextStyle(color: Colors.grey)),

                    // --- SLIDER FIX: MAX 150 ---
                    Slider(
                      value: currentSpeedUI,
                      min: 0,
                      max: 150, // Pastikan ini 150
                      divisions: 150, // Agar halus
                      activeColor: currentSafetyUI ? Colors.green : Colors.grey,
                      thumbColor: currentSafetyUI ? Colors.green : Colors.grey,
                      onChanged: currentSafetyUI
                          ? (val) {
                              setState(() => _localSliderValue = val);
                            }
                          : null,
                      onChangeEnd: (val) {
                        mqttService.publishControlMessage(
                            0, // Fan ignored
                            currentSafetyUI,
                            val.toInt());
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

  // --- WIDGET BARU: STATUS CARD ---
  Widget _buildStatusCard(
      String title, String desc, Color color, IconData icon) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
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
    bool alert = data.gas > 500;
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: alert ? Colors.red[50] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: alert ? Border.all(color: Colors.red.withOpacity(0.5)) : null,
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
            Icon(Icons.cloud, color: alert ? Colors.red : Colors.blueGrey),
            SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Gas Level',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
              Text('${data.gas} PPM',
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: alert ? Colors.red : Colors.black)),
            ])
          ]),
          if (alert) Icon(Icons.warning, color: Colors.red),
        ],
      ),
    );
  }
}
