import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _softwareChannel = MethodChannel('com.rdnnoob.devicescope/diagnostics');
const _softwareBlue = Color(0xFF276BAA);

class SoftwareDiagnosticPage extends StatefulWidget {
  const SoftwareDiagnosticPage({super.key});

  @override
  State<SoftwareDiagnosticPage> createState() => _SoftwareDiagnosticPageState();
}

class _SoftwareDiagnosticPageState extends State<SoftwareDiagnosticPage> {
  bool _loading = true;
  String _error = '';
  String _query = '';
  List<Map<String, dynamic>> _apps = [];
  Map<String, dynamic> _system = {};
  Map<String, dynamic> _runtime = {};
  Map<String, dynamic> _security = {};
  Map<String, dynamic> _compatibility = {};
  Map<String, dynamic> _updates = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<Map<String, dynamic>> _callMap(String method) async {
    final value = await _softwareChannel.invokeMethod<dynamic>(method);
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  Future<void> _loadAll() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = '';
      });
    }

    try {
      final results = await Future.wait<dynamic>([
        _softwareChannel.invokeMethod<dynamic>('getSoftwareInventory'),
        _callMap('getSystemSoftwareDiagnostics'),
        _callMap('getRuntimeDiagnostics'),
        _callMap('getSoftwareSecurityDiagnostics'),
        _callMap('getAppCompatibilityDiagnostics'),
        _callMap('getSoftwareUpdateDiagnostics'),
      ]);

      final rawApps = results[0];
      final apps = rawApps is List
          ? rawApps
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : <Map<String, dynamic>>[];

      if (!mounted) return;
      setState(() {
        _apps = apps;
        _system = results[1] as Map<String, dynamic>;
        _runtime = results[2] as Map<String, dynamic>;
        _security = results[3] as Map<String, dynamic>;
        _compatibility = results[4] as Map<String, dynamic>;
        _updates = results[5] as Map<String, dynamic>;
        _loading = false;
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '${e.code}: ${e.message ?? 'Native diagnostic unavailable'}';
      });
    } on MissingPluginException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Native Software Diagnostic handler is not installed yet.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load software diagnostics: $e';
      });
    }
  }

  List<Map<String, dynamic>> get _filteredApps {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _apps;
    return _apps.where((app) {
      final name = (app['label'] ?? '').toString().toLowerCase();
      final package = (app['packageName'] ?? '').toString().toLowerCase();
      return name.contains(query) || package.contains(query);
    }).toList();
  }

  String _value(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null || value.toString().trim().isEmpty) return 'UNAVAILABLE';
    return value.toString();
  }

  Widget _section(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.bold, color: _softwareBlue,
            )),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _dataRow(String label, dynamic value) {
    final text = value == null || value.toString().isEmpty
        ? 'UNAVAILABLE'
        : value.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(child: SelectableText(text)),
        ],
      ),
    );
  }

  Future<void> _showAppDetails(Map<String, dynamic> app) async {
    final packageName = (app['packageName'] ?? '').toString();
    if (packageName.isEmpty) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Expanded(child: Text('Reading application details…')),
        ]),
      ),
    );

    Map<String, dynamic> details = {};
    String error = '';
    try {
      details = await _callAppDetails(packageName);
    } catch (e) {
      error = e.toString();
    }

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final permissions = details['requestedPermissions'];
        final permissionList = permissions is List
            ? permissions.map((e) => e.toString()).toList()
            : <String>[];
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.82,
          maxChildSize: 0.95,
          builder: (_, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
            children: [
              Text(
                (details['label'] ?? app['label'] ?? 'Application').toString(),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              SelectableText(packageName, style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 14),
              if (error.isNotEmpty)
                Text('Details unavailable: $error')
              else ...[
                _section('APPLICATION', [
                  _dataRow('Version', details['versionName']),
                  _dataRow('Version code', details['versionCode']),
                  _dataRow('Target SDK', details['targetSdk']),
                  _dataRow('Minimum SDK', details['minSdk']),
                  _dataRow('Installer', details['installer']),
                  _dataRow('Enabled', details['enabled']),
                  _dataRow('Launchable', details['hasLauncherActivity']),
                  _dataRow('System app', details['systemApp']),
                  _dataRow('First installed', details['firstInstallTime']),
                  _dataRow('Last updated', details['lastUpdateTime']),
                ]),
                _section('SECURITY INDICATORS', [
                  _dataRow('Debuggable', details['debuggable']),
                  _dataRow('Allow backup', details['allowBackup']),
                  _dataRow('Suspended', details['suspended']),
                  _dataRow('Signing SHA-256', details['signingCertificateSha256']),
                  _dataRow('Play Protect', 'NOT_EXPOSED_BY_PUBLIC_API'),
                ]),
                _section('REQUESTED PERMISSIONS (${permissionList.length})', [
                  if (permissionList.isEmpty)
                    const Text('No requested permissions reported.')
                  else
                    ...permissionList.map((permission) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: SelectableText('• $permission'),
                    )),
                ]),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _callAppDetails(String packageName) async {
    final value = await _softwareChannel.invokeMethod<dynamic>(
      'getSoftwareAppDetails',
      {'packageName': packageName},
    );
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredApps;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Software Diagnostics'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error.isNotEmpty)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.warning_amber, color: Colors.orange),
                        title: const Text('Some diagnostics could not be loaded'),
                        subtitle: Text(_error),
                      ),
                    ),
                  _section('APPLICATION INVENTORY', [
                    Text(
                      '${_apps.length} packages visible to DeviceScope',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search app name or package',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ]),
                  _section('SYSTEM SOFTWARE', [
                    _dataRow('Android WebView', _value(_system, 'webView')),
                    _dataRow('Google Play services', _value(_system, 'playServices')),
                    _dataRow('Google Play Store', _value(_system, 'playStore')),
                    _dataRow('System UI', _value(_system, 'systemUi')),
                    _dataRow('Package installer', _value(_system, 'packageInstaller')),
                    _dataRow('Google Services Framework', _value(_system, 'googleServicesFramework')),
                    _dataRow('One UI Home', _value(_system, 'oneUiHome')),
                    _dataRow('Galaxy Store', _value(_system, 'galaxyStore')),
                  ]),
                  _section('RUNTIME & COMPATIBILITY', [
                    _dataRow('Java runtime', _value(_runtime, 'javaRuntime')),
                    _dataRow('Java VM', _value(_runtime, 'javaVm')),
                    _dataRow('Supported ABIs', _value(_runtime, 'supportedAbis')),
                    _dataRow('OpenGL ES', _value(_compatibility, 'openGlesVersion')),
                    _dataRow('Vulkan declarations', _value(_compatibility, 'vulkanFeatures')),
                    _dataRow('Feature declarations', _value(_compatibility, 'featureCount')),
                  ]),
                  _section('SOFTWARE SECURITY & UPDATE', [
                    _dataRow('Debug build', _value(_security, 'debugBuild')),
                    _dataRow('Build tags', _value(_security, 'buildTags')),
                    _dataRow('Security patch', _value(_updates, 'securityPatch')),
                    _dataRow('Pending OS update', _value(_updates, 'pendingOsUpdate')),
                    _dataRow('Play Protect verdict', _value(_security, 'playProtect')),
                    _dataRow('Assessment scope', 'Limited indicators only; not a malware scan.'),
                  ]),
                  const Padding(
                    padding: EdgeInsets.only(top: 6, bottom: 8),
                    child: Text(
                      'INSTALLED APPLICATIONS',
                      style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ),
                  if (filtered.isEmpty)
                    const Card(child: ListTile(title: Text('No matching applications.')))
                  else
                    ...filtered.map((app) {
                      final isSystem = app['systemApp'] == true;
                      final launchable = app['hasLauncherActivity'] == true;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 7),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _softwareBlue.withOpacity(0.1),
                            child: Icon(
                              isSystem ? Icons.settings : Icons.apps,
                              color: _softwareBlue,
                            ),
                          ),
                          title: Text((app['label'] ?? 'Unknown app').toString(),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            '${app['packageName'] ?? 'UNKNOWN'}\n'
                            '${isSystem ? 'SYSTEM' : 'USER'} • '
                            '${launchable ? 'LAUNCHER' : 'NO_LAUNCHER_REPORTED'}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _showAppDetails(app),
                        ),
                      );
                    }),
                  const SizedBox(height: 18),
                  const Text(
                    'Visibility depends on Android package-visibility rules and device policy. '
                    'A missing package or launcher activity is not proof that an app is hidden or malicious. '
                    'Process observations are best-effort only.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
    );
  }
}
