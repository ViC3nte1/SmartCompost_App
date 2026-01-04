import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../services/mqtt_service.dart';
import '../models/sensor_model.dart'; // Pastikan path import ini benar

class TrendsScreen extends StatefulWidget {
  @override
  _TrendsScreenState createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  // Default false: Tampilkan sedikit data (Zoom in)
  bool _showAllData = false;

  @override
  Widget build(BuildContext context) {
    final mqttService = Provider.of<MqttService>(context);
    final sensorData = mqttService.currentData;
    
    final tempHistory = mqttService.tempHistory;
    final humHistory = mqttService.humHistory;
    final gasHistory = mqttService.gasHistory;

    // LOGIKA TOGGLE:
    // Jika _showAllData TRUE -> Tampilkan 50 data.
    // Jika _showAllData FALSE -> Tampilkan 10 data (Agar grafik terlihat lebih detail/zoom).
    int dataLimit = _showAllData ? 50 : 10; 

    List<FlSpot> displayTempHistory = tempHistory.length > dataLimit
        ? tempHistory.skip(tempHistory.length - dataLimit).toList()
        : tempHistory;

    List<FlSpot> displayHumidityHistory = humHistory.length > dataLimit
        ? humHistory.skip(humHistory.length - dataLimit).toList()
        : humHistory;

    List<FlSpot> displayGasHistory = gasHistory.length > dataLimit
        ? gasHistory.skip(gasHistory.length - dataLimit).toList()
        : gasHistory;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Trends & History',
          style: GoogleFonts.poppins(
              color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Color(0xFF2E7D32),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Container(
        color: Color(0xFFFAFAFA),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Data Range Toggle ---
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
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
                    Text(
                      _showAllData ? 'Mode: History (50)' : 'Mode: Live Zoom (10)',
                      style: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    Switch(
                      value: _showAllData,
                      activeColor: Color(0xFF2E7D32),
                      onChanged: (bool value) {
                        setState(() {
                          _showAllData = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 16),
              
              // --- MENGGUNAKAN WIDGET CHART OTOMATIS (Supaya Rapi) ---
              _buildChartSection("Temperature", displayTempHistory, Color(0xFF2E7D32), 60),
              SizedBox(height: 24),
              _buildChartSection("Humidity", displayHumidityHistory, Colors.blue, 100),
              SizedBox(height: 24),
              _buildChartSection("Gas Level", displayGasHistory, Colors.orange, 1000),

              SizedBox(height: 24),
              
              // --- Current Values Card (Sudah Fix Overflow) ---
              Container(
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
                    Text('Current Readings',
                        style: GoogleFonts.poppins(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    SizedBox(height: 16),
                    // Menggunakan Row dengan Expanded agar tidak Overflow
                    Row(
                      children: [
                        Expanded(
                          child: _buildCurrentValueCard(
                            icon: Icons.thermostat,
                            title: 'Temp',
                            value: '${sensorData.temp.toStringAsFixed(1)}°C',
                            color: sensorData.temp > 33 ? Colors.red : Colors.green,
                          ),
                        ),
                        Expanded(
                          child: _buildCurrentValueCard(
                            icon: Icons.water_drop,
                            title: 'Humidity',
                            value: '${sensorData.hum.toStringAsFixed(1)}%',
                            color: Colors.blue,
                          ),
                        ),
                        Expanded(
                          child: _buildCurrentValueCard(
                            icon: Icons.cloud,
                            title: 'Gas',
                            value: '${sensorData.gas} PPM',
                            color: sensorData.gas > 500 ? Colors.red : Colors.orange,
                          ),
                        ),
                      ],
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

  // --- FUNGSI PEMBUAT CHART YANG SUDAH DIPERBAIKI ---
  Widget _buildChartSection(String title, List<FlSpot> data, Color color, double maxY) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$title Trend',
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w600)),
        SizedBox(height: 12),
        Container(
          height: 250,
          // Padding container agar chart tidak mepet pinggir kotak putih
          padding: EdgeInsets.only(right: 24, top: 24, bottom: 12, left: 12),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: data.isEmpty
              ? Center(child: Text("Waiting for data..."))
              : LineChart(
                  LineChartData(
                    gridData: FlGridData(show: true, drawVerticalLine: false),
                    titlesData: FlTitlesData(
                      // PENGATURAN SUMBU KIRI (Y)
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          // Perbesar reservedSize agar angka ratusan/ribuan muat
                          reservedSize: 46, 
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toInt().toString(),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 10, // Ukuran font pas
                              ),
                              textAlign: TextAlign.left,
                            );
                          },
                        ),
                      ),
                      // PENGATURAN SUMBU BAWAH (X)
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          // Perbesar ini agar angka bawah tidak terpotong
                          reservedSize: 30, 
                          interval: data.length > 20 ? 5 : 1, // Agar angka tidak menumpuk
                          getTitlesWidget: (value, meta) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                value.toInt().toString(),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 10,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    minY: 0,
                    maxY: maxY,
                    lineBarsData: [
                      LineChartBarData(
                        spots: data,
                        isCurved: true,
                        color: color,
                        barWidth: 3,
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(
                            show: true, color: color.withOpacity(0.1)),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  // --- WIDGET KARTU CURRENT VALUE (FIX OVERFLOW) ---
  Widget _buildCurrentValueCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    // HAPUS width: 100 agar fleksibel mengikuti Expanded
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 28),
        SizedBox(height: 8),
        Text(title, style: TextStyle(color: Colors.grey, fontSize: 12)),
        SizedBox(height: 4),
        // Gunakan FittedBox agar teks panjang mengecil otomatis
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}