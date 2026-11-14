import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';

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
          backgroundColor: Color(0xFFF2F4F6),
          foregroundColor: Color(0xFF263746),
          elevation: 0,
        ),
      ),
      home: const DashboardPage(),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'DeviceScope',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF347DBB),
                  Color(0xFF235B91),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SMARTPHONE DIAGNOSTICS',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Device Inspection',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Inspect device information and hardware condition.',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          const SectionTitle(title: 'DEVICE OVERVIEW'),
          const SizedBox(height: 10),
          const DeviceOverview(),
          const SizedBox(height: 25),
          const SectionTitle(title: 'DIAGNOSTIC TOOLS'),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.55,
            children: [
              DiagnosticTile(
                icon: Icons.phone_android,
                title: 'Device Info',
                subtitle: 'Device specifications',
                active: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DeviceInfoPage(),
                    ),
                  );
                },
              ),
              const DiagnosticTile(
                icon: Icons.system_update,
                title: 'Software',
                subtitle: 'System inspection',
              ),
              const DiagnosticTile(
                icon: Icons.battery_full,
                title: 'Battery',
                subtitle: 'Battery condition',
              ),
              const DiagnosticTile(
                icon: Icons.display_settings,
                title: 'Display',
                subtitle: 'Screen inspection',
              ),
              const DiagnosticTile(
                icon: Icons.touch_app,
                title: 'Touchscreen',
                subtitle: 'Touch response',
              ),
              const DiagnosticTile(
                icon: Icons.sensors,
                title: 'Sensors',
                subtitle: 'Sensor inspection',
              ),
              const DiagnosticTile(
                icon: Icons.camera_alt,
                title: 'Camera',
                subtitle: 'Camera inspection',
              ),
              const DiagnosticTile(
                icon: Icons.volume_up,
                title: 'Audio',
                subtitle: 'Speaker and microphone',
              ),
              const DiagnosticTile(
                icon: Icons.wifi,
                title: 'Connectivity',
                subtitle: 'Network inspection',
              ),
            ],
          ),
          const SizedBox(height: 25),
          const SectionTitle(title: 'DIAGNOSTIC REPORT'),
          const Card(
            child: ListTile(
              leading: Icon(Icons.description_outlined),
              title: Text('No diagnostic report'),
              subtitle: Text('Complete tests to generate a report.'),
            ),
          ),
        ],
      ),
    );
  }
}

class DeviceOverview extends StatelessWidget {
  const DeviceOverview({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AndroidDeviceInfo>(
      future: DeviceInfoPlugin().androidInfo,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Card(
            child: ListTile(
              leading: CircularProgressIndicator(),
              title: Text('Detecting device...'),
            ),
          );
        }

        if (snapshot.hasError) {
          return const Card(
            child: ListTile(
              leading: Icon(Icons.warning_amber),
              title: Text('Device information unavailable'),
            ),
          );
        }

        final info = snapshot.data!;

        return Card(
          child: ListTile(
            leading: const Icon(
              Icons.smartphone,
              size: 35,
              color: Color(0xFF276BAA),
            ),
            title: Text(
              '${info.manufacturer} ${info.model}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('Android ${info.version.release}'),
            trailing: const Icon(Icons.chevron_right),
          ),
        );
      },
    );
  }
}

class DeviceInfoPage extends StatefulWidget {
  const DeviceInfoPage({super.key});

  @override
  State<DeviceInfoPage> createState() => _DeviceInfoPageState();
}

class _DeviceInfoPageState extends State<DeviceInfoPage> {
  late Future<AndroidDeviceInfo> deviceFuture;

  @override
  void initState() {
    super.initState();
    deviceFuture = DeviceInfoPlugin().androidInfo;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Information'),
      ),
      body: FutureBuilder<AndroidDeviceInfo>(
        future: deviceFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(
              child: Text('Unable to retrieve device information.'),
            );
          }

          final info = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF276BAA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.phone_android,
                      color: Colors.white,
                      size: 45,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${info.manufacturer} ${info.model}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Android ${info.version.release}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const SectionTitle(title: 'GENERAL INFORMATION'),
              InfoCard(items: {
                'Manufacturer': info.manufacturer,
                'Brand': info.brand,
                'Model': info.model,
                'Device': info.device,
                'Product': info.product,
                'Physical Device': info.isPhysicalDevice ? 'Yes' : 'No',
              }),
              const SizedBox(height: 18),
              const SectionTitle(title: 'ANDROID SYSTEM'),
              InfoCard(items: {
                'Android Version': info.version.release,
                'SDK Version': info.version.sdkInt.toString(),
                'Security Patch': info.version.securityPatch,
                'Build ID': info.id,
                'Build Display': info.display,
                'Build Type': info.type,
                'Build Tags': info.tags,
              }),
              const SizedBox(height: 18),
              const SectionTitle(title: 'HARDWARE INFORMATION'),
              InfoCard(items: {
                'Hardware': info.hardware,
                'Board': info.board,
                'Bootloader': info.bootloader,
                'Supported ABIs': info.supportedAbis.join(', '),
                'Host': info.host,
              }),
              const SizedBox(height: 18),
              const Text(
                'Information is provided by Android system APIs. '
                'Some fields may be restricted or unavailable.',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  final Map<String, String> items;

  const InfoCard({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: items.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 13,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    entry.key,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Text(
                    entry.value.isEmpty ? 'Unavailable' : entry.value,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;

  const SectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: Color(0xFF526273),
        letterSpacing: 0.8,
      ),
    );
  }
}

class DiagnosticTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool active;
  final VoidCallback? onTap;

  const DiagnosticTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap ??
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$title module is coming soon.'),
                ),
              );
            },
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: active
                    ? const Color(0xFF276BAA)
                    : Colors.blueGrey,
                size: 25,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
