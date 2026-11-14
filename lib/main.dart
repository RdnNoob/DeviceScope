import 'package:flutter/material.dart';

void main() {
  runApp(const DeviceScopeApp());
}

class DeviceScopeApp extends StatelessWidget {
  const DeviceScopeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DeviceScope',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF2F4F6),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF276BAA),
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF263442),
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFFDCE3E9)),
          ),
        ),
      ),
      home: const DashboardPage(),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  static const Color primaryBlue = Color(0xFF276BAA);
  static const Color textDark = Color(0xFF263442);
  static const Color textMuted = Color(0xFF758392);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.phone_android, color: primaryBlue),
            SizedBox(width: 10),
            Text(
              'DeviceScope',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildWelcomePanel(),
            const SizedBox(height: 20),
            const Text(
              'DEVICE OVERVIEW',
              style: TextStyle(
                color: textMuted,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            _buildDeviceCard(),
            const SizedBox(height: 22),
            const Text(
              'DIAGNOSTIC TOOLS',
              style: TextStyle(
                color: textMuted,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            _buildDiagnosticGrid(),
            const SizedBox(height: 22),
            _buildReportCard(),
            const SizedBox(height: 20),
            const Center(
              child: Text(
                'DeviceScope • Version 0.1.0',
                style: TextStyle(
                  color: textMuted,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePanel() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: primaryBlue,
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF347DBB),
            Color(0xFF245D91),
          ],
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Smartphone Diagnostics',
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 7),
          Text(
            'Inspect your device hardware and software condition.',
            style: TextStyle(
              color: Color(0xFFE8F2FC),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _infoRow(
              Icons.smartphone,
              'Device model',
              'Detecting...',
            ),
            const Divider(height: 22),
            _infoRow(
              Icons.android,
              'Android version',
              'Detecting...',
            ),
            const Divider(height: 22),
            _infoRow(
              Icons.memory,
              'Processor',
              'Not available yet',
            ),
            const Divider(height: 22),
            _infoRow(
              Icons.battery_full,
              'Battery',
              'Not available yet',
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: primaryBlue, size: 21),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: textDark,
              fontSize: 13,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: textMuted,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildDiagnosticGrid() {
    final tools = [
      _DiagnosticItem(Icons.info_outline, 'Device Info'),
      _DiagnosticItem(Icons.memory, 'Software'),
      _DiagnosticItem(Icons.battery_std, 'Battery'),
      _DiagnosticItem(Icons.display_settings, 'Display'),
      _DiagnosticItem(Icons.touch_app, 'Touchscreen'),
      _DiagnosticItem(Icons.sensors, 'Sensors'),
      _DiagnosticItem(Icons.camera_alt_outlined, 'Camera'),
      _DiagnosticItem(Icons.volume_up_outlined, 'Audio'),
      _DiagnosticItem(Icons.wifi, 'Connectivity'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tools.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.05,
      ),
      itemBuilder: (context, index) {
        final item = tools[index];

        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${item.title} module is coming soon.'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    item.icon,
                    color: primaryBlue,
                    size: 27,
                  ),
                  const SizedBox(height: 9),
                  Text(
                    item.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: textDark,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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

  Widget _buildReportCard() {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE7F0F9),
          child: Icon(
            Icons.description_outlined,
            color: primaryBlue,
          ),
        ),
        title: const Text(
          'Diagnostic Report',
          style: TextStyle(
            color: textDark,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: const Text(
          'View your device inspection summary',
          style: TextStyle(
            color: textMuted,
            fontSize: 11,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: textMuted,
        ),
        onTap: () {},
      ),
    );
  }
}

class _DiagnosticItem {
  final IconData icon;
  final String title;

  const _DiagnosticItem(this.icon, this.title);
}
