import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/trends_screen.dart';
import 'screens/settings_screen.dart';
import 'services/mqtt_service.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => MqttService(),
      child: SmartCompostApp(),
    ),
  );
}

class SmartCompostApp extends StatelessWidget {
  const SmartCompostApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Compost Monitoring',
      theme: ThemeData(
        primarySwatch: Colors.green,
        primaryColor: Color(0xFF2E7D32), // Forest Green
        scaffoldBackgroundColor: Color(0xFFFAFAFA), // Off-white
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    DashboardScreen(),
    TrendsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();

    // Initialize MQTT service after widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mqttService = Provider.of<MqttService>(context, listen: false);
      mqttService.connect();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Color(0xFF2E7D32), // Forest Green
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.trending_up),
            label: 'Trends',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}