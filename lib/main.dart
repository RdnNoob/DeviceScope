import 'dart:io';

import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:battery_plus/battery_plus.dart';

void main() {
  runApp(const DeviceScopeApp());
}

const Color primaryBlue = Color(0xFF276BAA);
const Color backgroundColor = Color(0xFFF2F4F6);

class DeviceScopeApp extends StatelessWidget {
  const DeviceScopeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DeviceScope',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: backgroundColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryBlue,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: backgroundColor,
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
                colors: [Color(0xFF347DBB), Color(0xFF235B91)],
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: ListTile(
              leading: CircularProgressIndicator(),
              title: Text('Detecting device...'),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
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
              color: primaryBlue,
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
  late Future<int> batteryLevelFuture;
  late Future<BatteryState> batteryStateFuture;

  @override
  void initState() {
    super.initState();
    loadInformation();
  }

  void loadInformation() {
    deviceFuture = DeviceInfoPlugin().androidInfo;

    final battery = Battery();
    batteryLevelFuture = battery.batteryLevel;
    batteryStateFuture = battery.batteryState;
  }

  String formatBytes(int bytes) {
    if (bytes <= 0) return 'Unavailable';

    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double value = bytes.toDouble();
    int unitIndex = 0;

    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }

    return '${value.toStringAsFixed(2)} ${units[unitIndex]}';
  }

  String formatRam(int megabytes) {
    if (megabytes <= 0) return 'Unavailable';
    return '${(megabytes / 1024).toStringAsFixed(2)} GB';
  }

  String batteryStateName(BatteryState state) {
    switch (state) {
      case BatteryState.charging:
        return 'Charging';
      case BatteryState.discharging:
        return 'Discharging';
      case BatteryState.full:
        return 'Full';
      case BatteryState.connectedNotCharging:
        return 'Connected, not charging';
      case BatteryState.unknown:
        return 'Unknown';
    }
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
            return const Center(child: CircularProgressIndicator());
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
                  color: primaryBlue,
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
                'Device Name': info.name,
                'Physical Device': info.isPhysicalDevice ? 'Yes' : 'No',
              }),

              const SizedBox(height: 18),
              const SectionTitle(title: 'ANDROID SYSTEM'),
              InfoCard(items: {
                'Android Version': info.version.release,
                'SDK Version': info.version.sdkInt.toString(),
                'Security Patch':
                    info.version.securityPatch ?? 'Unavailable',
                'Build ID': info.id,
                'Build Display': info.display,
                'Build Type': info.type,
                'Build Tags': info.tags,
                'Fingerprint': info.fingerprint,
              }),

              const SizedBox(height: 18),
              const SectionTitle(title: 'PROCESSOR INFORMATION'),
              InfoCard(items: {
                'Hardware Identifier': info.hardware,
                'Board': info.board,
                'CPU Cores': Platform.numberOfProcessors.toString(),
                'Supported ABIs': info.supportedAbis.join(', '),
                '32-bit ABIs': info.supported32BitAbis.join(', '),
                '64-bit ABIs': info.supported64BitAbis.join(', '),
                'CPU Frequency': 'Unavailable through current API',
                'Chipset Marketing Name':
                    'Not independently verified',
              }),

              const SizedBox(height: 18),
              const SectionTitle(title: 'MEMORY INFORMATION'),
              InfoCard(items: {
                'Physical RAM': formatRam(info.physicalRamSize),
                'Available RAM': formatRam(info.availableRamSize),
                'Low RAM Device': info.isLowRamDevice ? 'Yes' : 'No',
              }),

              const SizedBox(height: 18),
              const SectionTitle(title: 'STORAGE INFORMATION'),
              InfoCard(items: {
                'Total Disk Size': formatBytes(info.totalDiskSize),
                'Free Disk Space': formatBytes(info.freeDiskSize),
                'Used Disk Space': info.totalDiskSize > 0 &&
                        info.freeDiskSize <= info.totalDiskSize
                    ? formatBytes(
                        info.totalDiskSize - info.freeDiskSize,
                      )
                    : 'Unavailable',
              }),

              const SizedBox(height: 18),
              const SectionTitle(title: 'DISPLAY INFORMATION'),
              Builder(
                builder: (context) {
                  final media = MediaQuery.of(context);
                  final pixelWidth =
                      (media.size.width * media.devicePixelRatio).round();
                  final pixelHeight =
                      (media.size.height * media.devicePixelRatio).round();

                  return InfoCard(items: {
                    'Physical Resolution':
                        '$pixelWidth × $pixelHeight pixels',
                    'Logical Resolution':
                        '${media.size.width.toStringAsFixed(1)} × '
                            '${media.size.height.toStringAsFixed(1)} dp',
                    'Pixel Density':
                        '${media.devicePixelRatio.toStringAsFixed(2)}x',
                    'Refresh Rate':
                        'Unavailable through current API',
                  });
                },
              ),

              const SizedBox(height: 18),
              const SectionTitle(title: 'BATTERY INFORMATION'),
              FutureBuilder<int>(
                future: batteryLevelFuture,
                builder: (context, batterySnapshot) {
                  return FutureBuilder<BatteryState>(
                    future: batteryStateFuture,
                    builder: (context, stateSnapshot) {
                      return InfoCard(items: {
                        'Battery Level': batterySnapshot.hasData
                            ? '${batterySnapshot.data}%'
                            : batterySnapshot.hasError
                                ? 'Unavailable'
                                : 'Reading...',
                        'Battery State': stateSnapshot.hasData
                            ? batteryStateName(stateSnapshot.data!)
                            : stateSnapshot.hasError
                                ? 'Unavailable'
                                : 'Reading...',
                        'Battery Temperature':
                            'Unavailable through current API',
                        'Battery Health':
                            'Not tested',
                        'Full Charge Capacity':
                            'Unavailable through current API',
                      });
                    },
                  );
                },
              ),

              const SizedBox(height: 20),
              const SectionTitle(title: 'HARDWARE IDENTIFIERS'),
              InfoCard(items: {
                'Hardware': info.hardware,
                'Board': info.board,
                'Bootloader': info.bootloader,
                'Host': info.host,
              }),

              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blueGrey.shade100),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: primaryBlue,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Transparency Notice\n'
                        'Information is retrieved from available '
                        'Android and Flutter APIs. Some values may be '
                        'restricted, unavailable, or not independently '
                        'verified. Display resolution is calculated from '
                        'the active application window metrics.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
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
          final unavailable = entry.value == 'Unavailable' ||
              entry.value == 'Not independently verified';

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
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: unavailable
                          ? Colors.blueGrey
                          : const Color(0xFF263746),
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
                color: active ? primaryBlue : Colors.blueGrey,
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
