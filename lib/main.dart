import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:battery_plus/battery_plus.dart';

void main() {
  runApp(const DeviceScopeApp());
}

const Color primaryBlue = Color(0xFF276BAA);
const Color backgroundColor = Color(0xFFF2F4F6);

const Duration refreshInterval = Duration(seconds: 5);
const int maxHistoryPoints = 60;

const MethodChannel diagnosticsChannel =
    MethodChannel('com.rdnnoob.devicescope/diagnostics');

void addHistory(List<double> history, double? value) {
  if (value == null || !value.isFinite) return;

  history.add(value);

  while (history.length > maxHistoryPoints) {
    history.removeAt(0);
  }
}

String mapValue(Map<String, dynamic> map, String key) {
  final value = map[key];

  if (value == null) return 'UNKNOWN';

  final text = value.toString().trim();

  return text.isEmpty ? 'UNKNOWN' : text;
}

String mapBool(Map<String, dynamic> map, String key) {
  final value = map[key];

  if (value == true) return 'YES';
  if (value == false) return 'NO';

  return 'UNKNOWN';
}

Future<Map<String, dynamic>> getNativeDiagnostics(
  String method,
) async {
  if (!Platform.isAndroid) return {};

  try {
    final result =
        await diagnosticsChannel.invokeMethod<dynamic>(method);

    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }
  } on PlatformException {
    return {};
  } on MissingPluginException {
    return {};
  } catch (_) {
    return {};
  }

  return {};
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

// ============================================================
// DASHBOARD
// ============================================================

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
              subtitle: Text(
                'Complete tests to generate a report.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// DEVICE OVERVIEW
// ============================================================

class DeviceOverview extends StatefulWidget {
  const DeviceOverview({super.key});

  @override
  State<DeviceOverview> createState() => _DeviceOverviewState();
}

class _DeviceOverviewState extends State<DeviceOverview> {
  AndroidDeviceInfo? info;
  Timer? timer;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadDevice();

    timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => loadDevice(),
    );
  }

  Future<void> loadDevice() async {
    if (!Platform.isAndroid) return;

    try {
      final result = await DeviceInfoPlugin().androidInfo;

      if (!mounted) return;

      setState(() {
        info = result;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Card(
        child: ListTile(
          leading: CircularProgressIndicator(),
          title: Text('Detecting device...'),
        ),
      );
    }

    if (info == null) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.warning_amber),
          title: Text('Device information unavailable'),
        ),
      );
    }

    return Card(
      child: ListTile(
        leading: const Icon(
          Icons.smartphone,
          size: 35,
          color: primaryBlue,
        ),
        title: Text(
          '${info!.manufacturer} ${info!.model}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Android ${info!.version.release}'),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

// ============================================================
// DEVICE INFORMATION
// ============================================================

class DeviceInfoPage extends StatefulWidget {
  const DeviceInfoPage({super.key});

  @override
  State<DeviceInfoPage> createState() => _DeviceInfoPageState();
}

class _DeviceInfoPageState extends State<DeviceInfoPage> {
  final DeviceInfoPlugin devicePlugin = DeviceInfoPlugin();
  final Battery battery = Battery();

  AndroidDeviceInfo? info;

  int? batteryLevel;
  BatteryState? batteryState;

  Map<String, dynamic> systemDiagnostics = {};
  Map<String, dynamic> vendorDiagnostics = {};
  Map<String, dynamic> networkDiagnostics = {};

  Timer? refreshTimer;
  StreamSubscription<BatteryState>? batterySubscription;

  bool loading = true;
  bool monitoring = true;
  bool refreshing = false;

  String lastUpdate = 'Waiting for first reading';
  String readError = '';

  final List<double> ramHistory = [];
  final List<double> storageHistory = [];
  final List<double> batteryHistory = [];

  @override
  void initState() {
    super.initState();
    initializeMonitoring();
  }

  Future<void> initializeMonitoring() async {
    await refreshInformation();

    if (!mounted) return;

    batterySubscription = battery.onBatteryStateChanged.listen(
      (state) {
        if (!mounted) return;

        setState(() {
          batteryState = state;
        });
      },
      onError: (_) {},
    );

    refreshTimer = Timer.periodic(
      refreshInterval,
      (_) {
        if (monitoring) {
          refreshInformation();
        }
      },
    );
  }

  Future<void> refreshInformation() async {
    if (refreshing || !Platform.isAndroid) return;

    refreshing = true;

    try {
      final results = await Future.wait<dynamic>([
        devicePlugin.androidInfo,
        battery.batteryLevel,
        battery.batteryState,
        getNativeDiagnostics('getSystemDiagnostics'),
        getNativeDiagnostics('getVendorDiagnostics'),
        getNativeDiagnostics('getNetworkDiagnostics'),
      ]);

      final newInfo = results[0] as AndroidDeviceInfo;
      final newBatteryLevel = results[1] as int;
      final newBatteryState = results[2] as BatteryState;

      final newSystem =
          results[3] as Map<String, dynamic>;
      final newVendor =
          results[4] as Map<String, dynamic>;
      final newNetwork =
          results[5] as Map<String, dynamic>;

      if (!mounted) return;

      setState(() {
        info = newInfo;
        batteryLevel = newBatteryLevel;
        batteryState = newBatteryState;

        systemDiagnostics = newSystem;
        vendorDiagnostics = newVendor;
        networkDiagnostics = newNetwork;

        readError = '';
        loading = false;
        lastUpdate = DateTime.now().toLocal().toString();
      });

      addHistory(
        ramHistory,
        calculateRamUsage(newInfo),
      );

      addHistory(
        storageHistory,
        calculateStorageUsage(newInfo),
      );

      addHistory(
        batteryHistory,
        newBatteryLevel.toDouble(),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        loading = false;
        readError = error.toString();
      });
    } finally {
      refreshing = false;
    }
  }

  double? calculateRamUsage(AndroidDeviceInfo data) {
    final total = data.physicalRamSize;
    final available = data.availableRamSize;

    if (total <= 0 || available < 0 || available > total) {
      return null;
    }

    return ((total - available) / total) * 100;
  }

  double? calculateStorageUsage(AndroidDeviceInfo data) {
    final total = data.totalDiskSize;
    final free = data.freeDiskSize;

    if (total <= 0 || free < 0 || free > total) {
      return null;
    }

    return ((total - free) / total) * 100;
  }

  String formatBytes(int bytes) {
    if (bytes <= 0) return 'Unavailable';

    const units = ['B', 'KB', 'MB', 'GB', 'TB'];

    double value = bytes.toDouble();
    int index = 0;

    while (value >= 1024 && index < units.length - 1) {
      value /= 1024;
      index++;
    }

    return '${value.toStringAsFixed(2)} ${units[index]}';
  }

  String formatRam(int megabytes) {
    if (megabytes <= 0) return 'Unavailable';

    return '${(megabytes / 1024).toStringAsFixed(2)} GB';
  }

  String formatPercentage(double? value) {
    if (value == null) return 'Unavailable';

    return '${value.toStringAsFixed(1)}%';
  }

  String batteryStateName(BatteryState? state) {
    if (state == null) return 'Unknown';

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

  void toggleMonitoring() {
    setState(() {
      monitoring = !monitoring;
    });

    if (monitoring) {
      refreshInformation();
    }
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    batterySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading && info == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Device Information'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (info == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Device Information'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber, size: 45),
                const SizedBox(height: 12),
                const Text(
                  'Unable to retrieve device information.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 15),
                ElevatedButton(
                  onPressed: refreshInformation,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final data = info!;

    final ramUsage = calculateRamUsage(data);
    final storageUsage = calculateStorageUsage(data);

    final rootIndicators = systemDiagnostics['rootIndicators'];

    final rootEvidence = rootIndicators is List
        ? rootIndicators.map((item) => item.toString()).join(', ')
        : 'UNKNOWN';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Information'),
        actions: [
          IconButton(
            tooltip: 'Refresh now',
            onPressed: refreshing ? null : refreshInformation,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refreshInformation,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // DEVICE HEADER

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
                    '${data.manufacturer} ${data.model}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Android ${data.version.release}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 15),

            // MONITORING CONTROL

            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.monitor_heart_outlined,
                          color: primaryBlue,
                        ),
                        const SizedBox(width: 9),
                        const Expanded(
                          child: Text(
                            'LIVE MONITORING',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Text(
                          monitoring ? 'ACTIVE' : 'PAUSED',
                          style: TextStyle(
                            color: monitoring
                                ? Colors.green.shade700
                                : Colors.orange.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Refresh interval: ${refreshInterval.inSeconds} seconds',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Last update: $lastUpdate',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: toggleMonitoring,
                        icon: Icon(
                          monitoring ? Icons.pause : Icons.play_arrow,
                        ),
                        label: Text(
                          monitoring
                              ? 'Pause Monitoring'
                              : 'Resume Monitoring',
                        ),
                      ),
                    ),
                    if (readError.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Latest read error: $readError',
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            const SectionTitle(title: 'LIVE PERFORMANCE'),
            const SizedBox(height: 10),

            const LiveMetricCard(
              title: 'CPU USAGE',
              value: 'UNKNOWN',
              subtitle:
                  'CPU utilization is not exposed by the current implementation.',
              history: [],
              unavailable: true,
            ),

            LiveMetricCard(
              title: 'RAM USAGE',
              value: formatPercentage(ramUsage),
              subtitle: '${formatRam(data.physicalRamSize)} total RAM',
              history: List<double>.unmodifiable(ramHistory),
              unavailable: ramUsage == null,
            ),

            LiveMetricCard(
              title: 'BATTERY LEVEL',
              value: batteryLevel == null ? 'UNKNOWN' : '$batteryLevel%',
              subtitle: batteryStateName(batteryState),
              history: List<double>.unmodifiable(batteryHistory),
              unavailable: batteryLevel == null,
            ),

            LiveMetricCard(
              title: 'STORAGE USAGE',
              value: formatPercentage(storageUsage),
              subtitle: '${formatBytes(data.totalDiskSize)} total storage',
              history: List<double>.unmodifiable(storageHistory),
              unavailable: storageUsage == null,
            ),

            const SizedBox(height: 20),

            const SectionTitle(title: 'GENERAL INFORMATION'),
            InfoCard(items: {
              'Manufacturer': data.manufacturer,
              'Brand': data.brand,
              'Model': data.model,
              'Device': data.device,
              'Product': data.product,
              'Device Name': data.name,
              'Physical Device': data.isPhysicalDevice ? 'Yes' : 'No',
            }),

            const SizedBox(height: 18),

            const SectionTitle(title: 'ANDROID SYSTEM'),
            InfoCard(items: {
              'Android Version': data.version.release,
              'SDK Version': data.version.sdkInt.toString(),
              'Security Patch':
                  data.version.securityPatch ?? 'UNKNOWN',
              'Build ID': data.id,
              'Build Display': data.display,
              'Build Type': data.type,
              'Build Tags': data.tags,
              'Fingerprint': data.fingerprint,
            }),

            const SizedBox(height: 18),

            const SectionTitle(title: 'PROCESSOR INFORMATION'),
            InfoCard(items: {
              'Hardware Identifier': data.hardware,
              'Board': data.board,
              'CPU Cores': Platform.numberOfProcessors.toString(),
              'Supported ABIs': data.supportedAbis.join(', '),
              '32-bit ABIs': data.supported32BitAbis.join(', '),
              '64-bit ABIs': data.supported64BitAbis.join(', '),
              'CPU Frequency': 'UNSUPPORTED',
              'CPU Usage': 'UNKNOWN',
              'Chipset Marketing Name': 'NOT VERIFIED',
            }),

            const SizedBox(height: 18),

            const SectionTitle(title: 'MEMORY INFORMATION'),
            InfoCard(items: {
              'Physical RAM': formatRam(data.physicalRamSize),
              'Available RAM': formatRam(data.availableRamSize),
              'RAM Usage': formatPercentage(ramUsage),
              'Low RAM Device': data.isLowRamDevice ? 'Yes' : 'No',
            }),

            const SizedBox(height: 18),

            const SectionTitle(title: 'STORAGE INFORMATION'),
            InfoCard(items: {
              'Total Disk Size': formatBytes(data.totalDiskSize),
              'Free Disk Space': formatBytes(data.freeDiskSize),
              'Used Disk Space':
                  data.totalDiskSize > 0 &&
                          data.freeDiskSize <= data.totalDiskSize
                      ? formatBytes(
                          data.totalDiskSize - data.freeDiskSize,
                        )
                      : 'Unavailable',
              'Storage Usage': formatPercentage(storageUsage),
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
                  'App Window Pixel Size':
                      '$pixelWidth × $pixelHeight pixels',
                  'Logical App Window Size':
                      '${media.size.width.toStringAsFixed(1)} × '
                          '${media.size.height.toStringAsFixed(1)} dp',
                  'Pixel Density':
                      '${media.devicePixelRatio.toStringAsFixed(2)}x',
                  'Physical Panel Resolution': 'UNKNOWN',
                  'Refresh Rate': 'UNSUPPORTED',
                });
              },
            ),

            const SizedBox(height: 18),

            const SectionTitle(title: 'BATTERY INFORMATION'),
            InfoCard(items: {
              'Battery Level':
                  batteryLevel == null ? 'UNKNOWN' : '$batteryLevel%',
              'Battery State': batteryStateName(batteryState),
              'Battery Temperature': 'UNSUPPORTED',
              'Battery Health': 'NOT TESTED',
              'Full Charge Capacity': 'UNSUPPORTED',
            }),

            const SizedBox(height: 18),

            // OS INTEGRITY

            const SectionTitle(title: 'OS INTEGRITY'),
            InfoCard(items: {
              'Root Status': mapValue(systemDiagnostics, 'rootStatus'),
              'Root Evidence': rootEvidence,
              'SU Binary Detected':
                  mapBool(systemDiagnostics, 'suBinaryDetected'),
              'Root Package Detected':
                  mapBool(systemDiagnostics, 'rootPackageDetected'),
              'Build Tags':
                  mapValue(systemDiagnostics, 'buildTags'),
              'Build Type':
                  mapValue(systemDiagnostics, 'buildType'),
              'Verified Boot':
                  mapValue(systemDiagnostics, 'verifiedBoot'),
              'Bootloader Lock':
                  mapValue(systemDiagnostics, 'bootloaderLock'),
              'VBMeta Device State':
                  mapValue(systemDiagnostics, 'vbmetaDeviceState'),
              'Previously Rooted':
                  mapValue(systemDiagnostics, 'previouslyRooted'),
              'Official Firmware':
                  mapValue(systemDiagnostics, 'officialFirmware'),
            }),

            const SizedBox(height: 18),

            // FIRMWARE & RECOVERY

            const SectionTitle(title: 'FIRMWARE & RECOVERY'),
            InfoCard(items: {
              'Bootloader':
                  mapValue(systemDiagnostics, 'bootloader'),
              'Kernel Version':
                  mapValue(systemDiagnostics, 'kernelVersion'),
              'Recovery Version':
                  mapValue(systemDiagnostics, 'recoveryVersion'),
              'TWRP Version':
                  mapValue(systemDiagnostics, 'twrpVersion'),
              'Firmware Fingerprint':
                  mapValue(systemDiagnostics, 'buildFingerprint'),
              'Security Patch':
                  mapValue(systemDiagnostics, 'securityPatch'),
              'BIOS Version': 'NOT APPLICABLE',
            }),

            const SizedBox(height: 18),

            // VENDOR

            const SectionTitle(title: 'VENDOR & REGIONAL IDENTITY'),
            InfoCard(items: {
              'Manufacturer':
                  mapValue(vendorDiagnostics, 'manufacturer'),
              'Brand': mapValue(vendorDiagnostics, 'brand'),
              'Model': mapValue(vendorDiagnostics, 'model'),
              'Product': mapValue(vendorDiagnostics, 'product'),
              'Device': mapValue(vendorDiagnostics, 'device'),
              'Sales Region':
                  mapValue(vendorDiagnostics, 'salesRegion'),
              'Sales Code':
                  mapValue(vendorDiagnostics, 'salesCode'),
              'Carrier Branding':
                  mapValue(vendorDiagnostics, 'carrierBranding'),
              'Operator Branding':
                  mapValue(vendorDiagnostics, 'operatorBranding'),
              'Country Code':
                  mapValue(vendorDiagnostics, 'countryCode'),
              'Hardware Platform':
                  mapValue(vendorDiagnostics, 'hardwarePlatform'),
              'Manufacturing Country':
                  mapValue(vendorDiagnostics, 'manufacturingCountry'),
              'Original Market':
                  mapValue(vendorDiagnostics, 'originalMarket'),
            }),

            const SizedBox(height: 18),

            // NETWORK

            const SectionTitle(title: 'SIM & NETWORK COMPATIBILITY'),
            InfoCard(items: {
              'SIM State':
                  mapValue(networkDiagnostics, 'simState'),
              'SIM Operator':
                  mapValue(networkDiagnostics, 'simOperator'),
              'SIM Country':
                  mapValue(networkDiagnostics, 'simCountry'),
              'Network Operator':
                  mapValue(networkDiagnostics, 'networkOperator'),
              'Network Type':
                  mapValue(networkDiagnostics, 'networkType'),
              'Roaming':
                  mapValue(networkDiagnostics, 'roaming'),
              'Carrier Lock':
                  mapValue(networkDiagnostics, 'carrierLock'),
              'SIM Validity':
                  mapValue(networkDiagnostics, 'simValidity'),
            }),

            const SizedBox(height: 20),

            // TRANSPARENCY NOTICE

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.blueGrey.shade100,
                ),
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
                      'TRANSPARENCY NOTICE\n'
                      'Information is retrieved from available Android '
                      'and Flutter APIs. Some values are restricted or '
                      'unavailable. UNKNOWN means the application cannot '
                      'currently verify the information. NOT TESTED means '
                      'no diagnostic test has been performed. '
                      'NOT DETECTED does not prove that a condition '
                      'never existed. Root detection is heuristic and '
                      'may not detect concealed modifications.',
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

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// LIVE METRIC CARD
// ============================================================

class LiveMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final List<double> history;
  final bool unavailable;

  const LiveMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.history,
    this.unavailable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 0.5,
                      color: Color(0xFF526273),
                    ),
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: unavailable ? Colors.blueGrey : primaryBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 75,
              width: double.infinity,
              child: unavailable || history.length < 2
                  ? const Center(
                      child: Text(
                        'Waiting for sufficient real samples...',
                        style: TextStyle(
                          color: Colors.blueGrey,
                          fontSize: 11,
                        ),
                      ),
                    )
                  : CustomPaint(
                      painter: LiveGraphPainter(values: history),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// GRAPH PAINTER
// ============================================================

class LiveGraphPainter extends CustomPainter {
  final List<double> values;

  LiveGraphPainter({required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final gridPaint = Paint()
      ..color = Colors.blueGrey.withValues(alpha: 0.15)
      ..strokeWidth = 0.7;

    for (int i = 0; i <= 3; i++) {
      final y = size.height * i / 3;

      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    final linePaint = Paint()
      ..color = primaryBlue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = primaryBlue.withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    final stepX = size.width / (maxHistoryPoints - 1);
    final startX = size.width - ((values.length - 1) * stepX);

    for (int i = 0; i < values.length; i++) {
      final x = startX + (i * stepX);
      final normalized = values[i].clamp(0.0, 100.0) / 100;
      final y = size.height - (normalized * size.height);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    final lastX = startX + ((values.length - 1) * stepX);

    fillPath.lineTo(lastX, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    final lastValue = values.last.clamp(0.0, 100.0);
    final lastY = size.height - ((lastValue / 100) * size.height);

    canvas.drawCircle(
      Offset(lastX, lastY),
      3.5,
      Paint()
        ..color = primaryBlue
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant LiveGraphPainter oldDelegate) {
    if (oldDelegate.values.length != values.length) return true;

    for (int i = 0; i < values.length; i++) {
      if (oldDelegate.values[i] != values[i]) return true;
    }

    return false;
  }
}

// ============================================================
// INFORMATION CARD
// ============================================================

class InfoCard extends StatelessWidget {
  final Map<String, String> items;

  const InfoCard({
    super.key,
    required this.items,
  });

  bool isUnknown(String value) {
    final normalized = value.toUpperCase();

    return normalized == 'UNKNOWN' ||
        normalized == 'UNAVAILABLE' ||
        normalized == 'UNSUPPORTED' ||
        normalized == 'NOT TESTED' ||
        normalized == 'NOT VERIFIED' ||
        normalized == 'PERMISSION_REQUIRED' ||
        normalized == 'PERMISSION_REQUIRED_OR_UNKNOWN';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: items.entries.map((entry) {
          final unknown = isUnknown(entry.value);

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
                    entry.value.isEmpty ? 'UNKNOWN' : entry.value,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: unknown
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

// ============================================================
// SECTION TITLE
// ============================================================

class SectionTitle extends StatelessWidget {
  final String title;

  const SectionTitle({
    super.key,
    required this.title,
  });

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

// ============================================================
// DIAGNOSTIC TILE
// ============================================================

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
