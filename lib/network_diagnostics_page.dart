import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';

const _blue = Color(0xFF276BAA);
const _channel = MethodChannel('com.rdnnoob.devicescope/diagnostics');

class NetworkDiagnosticsPage extends StatefulWidget {
  const NetworkDiagnosticsPage({super.key});

  @override
  State<NetworkDiagnosticsPage> createState() => _NetworkDiagnosticsPageState();
}

class _NetworkDiagnosticsPageState extends State<NetworkDiagnosticsPage> {
  final _networkInfo = NetworkInfo();
  final _target = TextEditingController(text: '1.1.1.1');
  final _dnsDomain = TextEditingController(text: 'example.com');
  final _portHost = TextEditingController(text: 'example.com');
  final _portNumber = TextEditingController(text: '443');
  final _traceTarget = TextEditingController(text: '1.1.1.1');
  final _whoisTarget = TextEditingController(text: '');
  Timer? _timer;
  bool _loading = true;
  bool _runningPing = false;
  bool _runningGateway = false;
  bool _runningNetstat = false;
  bool _speedTesting = false;
  String _connection = 'Checking…';
  String _wifiName = 'UNKNOWN';
  String _wifiIp = 'UNKNOWN';
  String _gateway = 'UNKNOWN';
  String _subnet = 'UNKNOWN';
  String _publicIp = 'UNKNOWN';
  String _isp = 'UNKNOWN';
  String _asn = 'UNKNOWN';
  String _country = 'UNKNOWN';
  String _city = 'UNKNOWN';
  String _reverseDns = 'UNKNOWN';
  String _dhcpStatic = 'UNKNOWN';
  String _rxRate = 'UNKNOWN';
  String _txRate = 'UNKNOWN';
  int? _lastRx;
  int? _lastTx;
  DateTime? _lastTrafficAt;
  Map<String, dynamic> _ipDetails = {};
  final List<double> _rxHistory = [];
  final List<double> _txHistory = [];
  final List<String> _pingLog = [];
  final List<String> _traceLog = [];
  final List<String> _netstatLog = [];
  final List<String> _history = [];
  final List<String> _diagnosticLog = [];
  String _dnsResult = '';
  String _portResult = '';
  String _speedResult = '';
  String _whoisResult = '';
  String _gatewayResult = '';
  String _report = '';
  String _dnsType = 'A';
  int _pingInterval = 1000;
  int _pingCount = 5;
  bool _stopPing = false;
  bool _stopGateway = false;
  bool _stopNetstat = false;

  @override
  void initState() {
    super.initState();
    _refreshNetwork();
    _lookupPublicIp();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      _refreshNetwork();
      _refreshTraffic();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _target.dispose();
    _dnsDomain.dispose();
    _portHost.dispose();
    _portNumber.dispose();
    _traceTarget.dispose();
    _whoisTarget.dispose();
    super.dispose();
  }

  void _addHistory(String item) {
    final stamp = DateTime.now().toLocal().toString().substring(0, 19);
    _history.insert(0, '$stamp — $item');
    if (_history.length > 100) _history.removeLast();
  }

  String _clean(String? value) {
    if (value == null || value.trim().isEmpty) return 'UNKNOWN';
    return value.trim().replaceAll('"', '');
  }

  Future<void> _refreshNetwork() async {
    try {
      final results = await Connectivity().checkConnectivity();
      final names = results.map((e) => e.name.toUpperCase()).toSet();
      final type = names.isEmpty ? 'UNKNOWN' : names.join(', ');
      String ip = 'UNKNOWN', gateway = 'UNKNOWN', subnet = 'UNKNOWN';
      String wifi = 'UNKNOWN';
      try { ip = _clean(await _networkInfo.getWifiIP()); } catch (_) {}
      try { gateway = _clean(await _networkInfo.getWifiGatewayIP()); } catch (_) {}
      try { subnet = _clean(await _networkInfo.getWifiSubmask()); } catch (_) {}
      try { wifi = _clean(await _networkInfo.getWifiName()); } catch (_) {}
      final interfaces = await NetworkInterface.list(includeLoopback: false, type: InternetAddressType.any);
      final addresses = <String>[];
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (!address.isLoopback) addresses.add('${interface.name}: ${address.address}');
        }
      }
      if (!mounted) return;
      final previous = _connection;
      setState(() {
        _connection = type;
        _wifiName = wifi;
        _wifiIp = ip == 'UNKNOWN' && addresses.isNotEmpty ? addresses.first.split(': ').last : ip;
        _gateway = gateway;
        _subnet = subnet;
        _dhcpStatic = 'UNKNOWN (Android does not expose this reliably to ordinary apps)';
        _loading = false;
      });
      if (previous != type && previous != 'Checking…') _addHistory('Connection changed: $previous → $type');
    } catch (e) {
      if (mounted) setState(() { _connection = 'UNAVAILABLE'; _loading = false; });
    }
  }

  Future<void> _refreshTraffic() async {
    try {
      final data = await _channel.invokeMapMethod<String, dynamic>('getTrafficStats');
      if (data == null) return;
      final rx = (data['rxBytes'] as num?)?.toInt();
      final tx = (data['txBytes'] as num?)?.toInt();
      final now = DateTime.now();
      if (rx == null || tx == null || rx < 0 || tx < 0) return;
      if (_lastRx != null && _lastTx != null && _lastTrafficAt != null) {
        final seconds = now.difference(_lastTrafficAt!).inMilliseconds / 1000;
        if (seconds > 0) {
          final rxRate = ((rx - _lastRx!).clamp(0, 1 << 62)) / seconds;
          final txRate = ((tx - _lastTx!).clamp(0, 1 << 62)) / seconds;
          if (!mounted) return;
          setState(() {
            _rxRate = '${_formatRate(rxRate)}';
            _txRate = '${_formatRate(txRate)}';
            _rxHistory.add(rxRate);
            _txHistory.add(txRate);
            if (_rxHistory.length > 30) _rxHistory.removeAt(0);
            if (_txHistory.length > 30) _txHistory.removeAt(0);
          });
        }
      }
      _lastRx = rx;
      _lastTx = tx;
      _lastTrafficAt = now;
    } catch (_) {
      if (mounted) setState(() { _rxRate = 'UNAVAILABLE'; _txRate = 'UNAVAILABLE'; });
    }
  }

  String _formatRate(double bps) {
    if (!bps.isFinite) return 'UNKNOWN';
    if (bps >= 1024 * 1024) return '${(bps / (1024 * 1024)).toStringAsFixed(2)} MB/s';
    if (bps >= 1024) return '${(bps / 1024).toStringAsFixed(1)} KB/s';
    return '${bps.toStringAsFixed(0)} B/s';
  }

  Future<void> _lookupPublicIp() async {
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      final request = await client.getUrl(Uri.parse('https://ipwho.is/'));
      request.headers.set(HttpHeaders.userAgentHeader, 'DeviceScope/0.1');
      final response = await request.close().timeout(const Duration(seconds: 10));
      final body = await response.transform(utf8.decoder).join();
      client.close();
      final json = jsonDecode(body) as Map<String, dynamic>;
      if (json['success'] == false) throw Exception(json['message'] ?? 'Lookup failed');
      final connection = (json['connection'] as Map?)?.cast<String, dynamic>() ?? {};
      final ip = _clean(json['ip']?.toString());
      final isp = _clean(connection['isp']?.toString());
      final asn = '${connection['asn'] ?? 'UNKNOWN'} ${connection['org'] ?? ''}'.trim();
      if (!mounted) return;
      setState(() {
        _publicIp = ip;
        _isp = isp;
        _asn = asn.isEmpty ? 'UNKNOWN' : asn;
        _country = _clean(json['country']?.toString());
        _city = _clean(json['city']?.toString());
        _ipDetails = json;
      });
      try {
        final lookup = await InternetAddress.lookup(ip);
        if (mounted && lookup.isNotEmpty) setState(() => _reverseDns = 'Reverse DNS is not provided by this lookup service');
      } catch (_) {}
      _addHistory('Public IP refreshed: $ip');
    } catch (e) {
      if (mounted) setState(() {
        _publicIp = 'UNAVAILABLE';
        _isp = 'UNAVAILABLE';
        _asn = 'UNAVAILABLE';
        _country = 'UNAVAILABLE';
        _city = 'UNAVAILABLE';
      });
    }
  }

  Future<void> _ping() async {
    final host = _target.text.trim();
    if (host.isEmpty) return;
    setState(() { _runningPing = true; _stopPing = false; _pingLog.clear(); });
    for (var i = 0; i < _pingCount && !_stopPing; i++) {
      final sw = Stopwatch()..start();
      try {
        final addresses = await InternetAddress.lookup(host).timeout(const Duration(seconds: 4));
        if (addresses.isEmpty) throw SocketException('DNS returned no addresses');
        final socket = await Socket.connect(host, 443, timeout: const Duration(seconds: 3));
        socket.destroy();
        sw.stop();
        _pingLog.insert(0, 'Reply from ${addresses.first.address}: TCP/443 probe ${sw.elapsedMilliseconds} ms');
      } catch (e) {
        sw.stop();
        _pingLog.insert(0, 'Probe failed: $e');
      }
      if (mounted) setState(() {});
      if (i + 1 < _pingCount && !_stopPing) await Future.delayed(Duration(milliseconds: _pingInterval));
    }
    if (mounted) setState(() => _runningPing = false);
  }

  Future<void> _dnsLookup() async {
    final host = _dnsDomain.text.trim();
    if (host.isEmpty) return;
    setState(() => _dnsResult = 'Looking up $host…');
    try {
      final addresses = await InternetAddress.lookup(host).timeout(const Duration(seconds: 8));
      setState(() => _dnsResult = addresses.isEmpty ? 'No address records returned.' : addresses.map((a) => '${a.type.name}: ${a.address}').join('\n'));
    } catch (e) {
      setState(() => _dnsResult = 'Lookup failed: $e');
    }
    _addHistory('DNS lookup: $host');
  }

  Future<void> _portCheck() async {
    final host = _portHost.text.trim();
    final port = int.tryParse(_portNumber.text.trim());
    if (host.isEmpty || port == null || port < 1 || port > 65535) {
      setState(() => _portResult = 'Enter a valid host and port (1–65535).');
      return;
    }
    setState(() => _portResult = 'Checking $host:$port…');
    final sw = Stopwatch()..start();
    try {
      final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 5));
      socket.destroy(); sw.stop();
      setState(() => _portResult = 'OPEN / reachable — ${sw.elapsedMilliseconds} ms');
    } catch (e) {
      setState(() => _portResult = 'CLOSED, filtered, or unreachable — $e');
    }
    _addHistory('Port check: $host:$port');
  }

  Future<void> _traceroute() async {
    final host = _traceTarget.text.trim();
    if (host.isEmpty) return;
    setState(() { _traceLog.clear(); _traceLog.add('Resolving $host…'); });
    try {
      final addresses = await InternetAddress.lookup(host).timeout(const Duration(seconds: 8));
      setState(() {
        _traceLog
          ..clear()
          ..add('Resolved target: ${addresses.first.address}')
          ..add('Full hop-by-hop traceroute requires native TTL/raw-socket support and is not available in this portable build.')
          ..add('Use Ping/TCP probes to assess endpoint reachability.');
      });
    } catch (e) {
      setState(() { _traceLog..clear()..add('Trace failed: $e'); });
    }
    _addHistory('Traceroute requested: $host');
  }

  Future<void> _speedTest() async {
    if (_speedTesting) return;
    setState(() { _speedTesting = true; _speedResult = 'Testing download…'; });
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final sw = Stopwatch()..start();
      final request = await client.getUrl(Uri.parse('https://speed.cloudflare.com/__down?bytes=10000000'));
      final response = await request.close().timeout(const Duration(seconds: 15));
      var bytes = 0;
      await for (final chunk in response.timeout(const Duration(seconds: 15))) { bytes += chunk.length; }
      sw.stop();
      final seconds = sw.elapsedMilliseconds / 1000;
      final mbps = seconds > 0 ? bytes * 8 / seconds / 1000000 : 0;
      if (mounted) setState(() => _speedResult = 'Download: ${mbps.toStringAsFixed(2)} Mbps\nReceived: $bytes bytes\nElapsed: ${seconds.toStringAsFixed(2)} s\nUpload: not tested in this build\nLatency: see Ping/TCP probe\nNote: result depends on server, route, and current traffic.');
    } catch (e) {
      if (mounted) setState(() => _speedResult = 'Speed test failed: $e');
    } finally {
      client.close(force: true);
      if (mounted) setState(() => _speedTesting = false);
      _addHistory('Speed test run');
    }
  }

  Future<void> _gatewayMonitor() async {
    final gateway = _gateway;
    if (gateway == 'UNKNOWN' || gateway == 'UNAVAILABLE') {
      setState(() => _gatewayResult = 'Gateway is unavailable on this connection.');
      return;
    }
    setState(() { _runningGateway = true; _stopGateway = false; _gatewayResult = 'Monitoring $gateway on TCP/80 and TCP/443…'; });
    while (!_stopGateway && mounted) {
      final checks = <String>[];
      for (final port in [80, 443]) {
        final sw = Stopwatch()..start();
        try {
          final socket = await Socket.connect(gateway, port, timeout: const Duration(seconds: 2));
          socket.destroy(); sw.stop(); checks.add('$port reachable (${sw.elapsedMilliseconds} ms)');
        } catch (_) { checks.add('$port not reachable'); }
      }
      if (mounted) setState(() => _gatewayResult = '${DateTime.now().toLocal()}\n${checks.join('\n')}\nNote: closed ports do not prove gateway failure.');
      await Future.delayed(const Duration(seconds: 3));
    }
    if (mounted) setState(() => _runningGateway = false);
  }

  Future<void> _netstat() async {
    setState(() { _runningNetstat = true; _stopNetstat = false; _netstatLog.clear(); });
    do {
      try {
        final data = await _channel.invokeMapMethod<String, dynamic>('getNetstat');
        final rows = (data?['connections'] as List?)?.map((e) => e.toString()).toList() ?? [];
        if (mounted) setState(() => _netstatLog
          ..clear()
          ..addAll(rows.isEmpty ? ['No readable socket entries. Android may restrict system-wide connection visibility.'] : rows));
      } catch (e) {
        if (mounted) setState(() => _netstatLog..clear()..add('Unavailable: $e'));
      }
      if (!_stopNetstat) await Future.delayed(const Duration(seconds: 3));
    } while (!_stopNetstat && mounted);
    if (mounted) setState(() => _runningNetstat = false);
  }

  Future<void> _whois() async {
    final target = _whoisTarget.text.trim().isEmpty ? _publicIp : _whoisTarget.text.trim();
    setState(() => _whoisResult = 'Looking up $target…');
    try {
      final uri = Uri.https('rdap.org', '/ip/$target');
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      final req = await client.getUrl(uri);
      final res = await req.close().timeout(const Duration(seconds: 10));
      final body = await res.transform(utf8.decoder).join();
      client.close();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final name = json['name']?.toString() ?? 'UNKNOWN';
      final handle = json['handle']?.toString() ?? 'UNKNOWN';
      final country = json['country']?.toString() ?? 'UNKNOWN';
      final entities = (json['entities'] as List?)?.map((e) => (e as Map)['handle']?.toString() ?? '').where((s) => s.isNotEmpty).join(', ') ?? '';
      setState(() => _whoisResult = 'Registry name: $name\nHandle: $handle\nCountry: $country\nEntities: ${entities.isEmpty ? 'UNKNOWN' : entities}\nRaw record fields are summarized; this is not proof of the end-user identity.');
    } catch (e) {
      setState(() => _whoisResult = 'RDAP lookup failed. Enter an IP address for best results.\n$e');
    }
    _addHistory('RDAP/WHOIS lookup: $target');
  }

  Future<void> _runDiagnostics() async {
    setState(() => _diagnosticLog.clear());
    await _refreshNetwork();
    final items = <String>[];
    items.add('Connection type: $_connection');
    items.add('Local IP: $_wifiIp');
    items.add('Gateway: $_gateway');
    items.add('Public IP: $_publicIp');
    for (final host in ['1.1.1.1', '8.8.8.8']) {
      try {
        final sw = Stopwatch()..start();
        final socket = await Socket.connect(host, 443, timeout: const Duration(seconds: 3));
        socket.destroy(); sw.stop();
        items.add('$host TCP/443: reachable in ${sw.elapsedMilliseconds} ms');
      } catch (_) { items.add('$host TCP/443: failed or blocked'); }
    }
    if (mounted) setState(() => _diagnosticLog.addAll(items));
    _addHistory('Diagnostic test completed');
  }

  void _generateReport() {
    final lines = <String>[
      'DeviceScope Network Diagnostics Report',
      'Generated: ${DateTime.now().toLocal()}',
      'Connection: $_connection',
      'Wi-Fi SSID: $_wifiName',
      'Local IP: $_wifiIp',
      'Gateway: $_gateway',
      'Subnet: $_subnet',
      'DHCP/Static: $_dhcpStatic',
      'Public IP: $_publicIp',
      'ISP: $_isp',
      'ASN/Organization: $_asn',
      'IP country/city: $_country / $_city',
      'Download rate (device-wide counters where supported): $_rxRate',
      'Upload rate (device-wide counters where supported): $_txRate',
      '',
      'Recent history:',
      ..._history.take(30),
      '',
      'Transparency: external IP metadata is provided by a third-party lookup service. Traffic counters can include system-wide/device-wide bytes and are not necessarily app-only. Android may restrict system-wide socket visibility. Traceroute, upload speed, Wi-Fi scanning, and some router details are unavailable unless platform support and permissions exist.',
    ];
    setState(() => _report = lines.join('\n'));
    _addHistory('Diagnostic report generated');
  }

  Widget _section(String title, IconData icon, List<Widget> children) => Card(
    margin: const EdgeInsets.only(bottom: 14),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, color: _blue), const SizedBox(width: 8), Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)))]),
        const SizedBox(height: 12),
        ...children,
      ]),
    ),
  );

  Widget _kv(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(flex: 4, child: Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12))),
      Expanded(flex: 5, child: SelectableText(value, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
    ]),
  );

  Widget _field(TextEditingController c, String label, {TextInputType? keyboard}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(controller: c, keyboardType: keyboard, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true)),
  );

  Widget _button(String label, VoidCallback? action, {IconData icon = Icons.play_arrow}) => SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(onPressed: action, icon: Icon(icon), label: Text(label)),
  );

  Widget _log(List<String> lines) => Container(
    width: double.infinity, padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: Colors.black.withOpacity(.04), borderRadius: BorderRadius.circular(8)),
    child: SelectableText(lines.isEmpty ? 'No results yet.' : lines.join('\n'), style: const TextStyle(fontSize: 12, height: 1.5)),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Network Diagnostics'), actions: [
        IconButton(tooltip: 'Refresh network', onPressed: () { _refreshNetwork(); _lookupPublicIp(); }, icon: const Icon(Icons.refresh)),
      ]),
      body: _loading ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _section('CONNECTION INFORMATION', Icons.wifi, [
            _kv('Connection type', _connection),
            _kv('Wi-Fi SSID', _wifiName),
            _kv('Local IP', _wifiIp),
            _kv('Gateway', _gateway),
            _kv('Subnet mask', _subnet),
            _kv('DHCP / Static', _dhcpStatic),
            _kv('Wi-Fi scan / nearby AP', 'NOT AVAILABLE: platform permission and native scan implementation required'),
            const SizedBox(height: 6),
            const Text('Auto-refresh every 2 seconds. Some Wi-Fi fields require location permission and Location services enabled.', style: TextStyle(fontSize: 11, color: Colors.black54)),
          ]),
          _section('PUBLIC IP & ISP', Icons.public, [
            _kv('Public IP', _publicIp), _kv('ISP', _isp), _kv('ASN / organization', _asn), _kv('Country', _country), _kv('City', _city),
            _kv('Reverse DNS', _reverseDns),
            _button('Refresh Public IP', _lookupPublicIp, icon: Icons.refresh),
            const Text('Uses ipwho.is third-party API. Geolocation is approximate IP-based data, not precise device location.', style: TextStyle(fontSize: 11, color: Colors.black54)),
          ]),
          _section('LIVE TRAFFIC', Icons.swap_vert, [
            _kv('Download', _rxRate), _kv('Upload', _txRate),
            const SizedBox(height: 6), const Text('Device/network byte counters; Android may return unavailable values. These are not guaranteed to be per-app.', style: TextStyle(fontSize: 11, color: Colors.black54)),
            const SizedBox(height: 8),
            _TrafficGraph(download: List.of(_rxHistory), upload: List.of(_txHistory)),
          ]),
          _section('SPEED TEST', Icons.speed, [
            _button(_speedTesting ? 'Testing…' : 'Start Download Test', _speedTesting ? null : _speedTest, icon: Icons.speed),
            const SizedBox(height: 8), _log(_speedResult.isEmpty ? [] : _speedResult.split('\n')),
          ]),
          _section('PING / TCP REACHABILITY', Icons.network_ping, [
            _field(_target, 'Target host or IP'),
            Row(children: [
              Expanded(child: DropdownButtonFormField<int>(value: _pingInterval, decoration: const InputDecoration(labelText: 'Interval', border: OutlineInputBorder(), isDense: true), items: const [500, 1000, 2000, 3000].map((v) => DropdownMenuItem(value: v, child: Text('$v ms'))).toList(), onChanged: (v) { if (v != null) setState(() => _pingInterval = v); })),
              const SizedBox(width: 8),
              Expanded(child: DropdownButtonFormField<int>(value: _pingCount, decoration: const InputDecoration(labelText: 'Count', border: OutlineInputBorder(), isDense: true), items: const [3, 5, 10, 20].map((v) => DropdownMenuItem(value: v, child: Text('$v packets'))).toList(), onChanged: (v) { if (v != null) setState(() => _pingCount = v); })),
            ]),
            const SizedBox(height: 8),
            _button(_runningPing ? 'Stop Ping' : 'Start Ping', _runningPing ? () => setState(() => _stopPing = true) : _ping, icon: _runningPing ? Icons.stop : Icons.play_arrow),
            const Text('This portable probe measures DNS + TCP/443 connection time, not ICMP echo RTT.', style: TextStyle(fontSize: 11, color: Colors.black54)),
            const SizedBox(height: 8), _log(_pingLog),
          ]),
          _section('DNS LOOKUP', Icons.dns, [
            _field(_dnsDomain, 'Domain name'),
            DropdownButtonFormField<String>(value: _dnsType, decoration: const InputDecoration(labelText: 'Record type', border: OutlineInputBorder(), isDense: true), items: const ['A', 'AAAA', 'MX', 'TXT', 'NS', 'CNAME'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) { if (v != null) setState(() => _dnsType = v); }),
            const SizedBox(height: 8), _button('Lookup DNS', _dnsLookup, icon: Icons.search), const SizedBox(height: 8),
            _log(_dnsResult.isEmpty ? [] : _dnsResult.split('\n')),
            const Text('System DNS resolver returns address records; selected MX/TXT/NS/CNAME type is a UI label only and needs a dedicated DNS query implementation for authoritative record-type results.', style: TextStyle(fontSize: 11, color: Colors.black54)),
          ]),
          _section('TRACEROUTE', Icons.alt_route, [
            _field(_traceTarget, 'Target host or IP'),
            _button('Start Trace', _traceroute, icon: Icons.alt_route), const SizedBox(height: 8), _log(_traceLog),
          ]),
          _section('PORT CONNECTIVITY CHECKER', Icons.settings_ethernet, [
            _field(_portHost, 'Host or IP'),
            _field(_portNumber, 'Port number', keyboard: TextInputType.number),
            _button('Check Port', _portCheck, icon: Icons.check_circle_outline), const SizedBox(height: 8),
            _log(_portResult.isEmpty ? [] : _portResult.split('\n')),
          ]),
          _section('NETSTAT (ACCESSIBLE SOCKETS)', Icons.list_alt, [
            _button(_runningNetstat ? 'Stop Refresh' : 'Start Netstat', _runningNetstat ? () => setState(() => _stopNetstat = true) : _netstat, icon: _runningNetstat ? Icons.stop : Icons.play_arrow),
            const Text('Android restricts full system-wide socket visibility; this reports only entries exposed by the native implementation.', style: TextStyle(fontSize: 11, color: Colors.black54)),
            const SizedBox(height: 8), _log(_netstatLog),
          ]),
          _section('GATEWAY MONITOR', Icons.router, [
            _kv('Detected gateway', _gateway),
            _button(_runningGateway ? 'Stop Gateway Monitor' : 'Start Gateway Monitor', _runningGateway ? () => setState(() => _stopGateway = true) : _gatewayMonitor, icon: _runningGateway ? Icons.stop : Icons.play_arrow),
            const SizedBox(height: 8), _log(_gatewayResult.isEmpty ? [] : _gatewayResult.split('\n')),
          ]),
          _section('WHOIS / ASN (RDAP)', Icons.manage_search, [
            _field(_whoisTarget, 'IP address (blank = public IP)'),
            _button('Lookup RDAP', _whois, icon: Icons.search), const SizedBox(height: 8),
            _log(_whoisResult.isEmpty ? [] : _whoisResult.split('\n')),
          ]),
          _section('VPN / PROXY INSPECTOR', Icons.shield_outlined, [
            _kv('Connection type reports VPN', _connection.toLowerCase().contains('vpn') ? 'YES' : 'NOT DETECTED BY CONNECTIVITY API'),
            _kv('HTTP proxy', 'UNKNOWN (system proxy visibility varies by Android version)'),
            _kv('VPN provider / tunnel details', 'UNAVAILABLE to ordinary app without privileged APIs'),
          ]),
          _section('DIAGNOSTIC TEST', Icons.fact_check, [
            _button('Run Diagnostics', _runDiagnostics, icon: Icons.play_circle),
            const SizedBox(height: 8), _log(_diagnosticLog),
          ]),
          _section('CONNECTION HISTORY', Icons.history, [
            _log(_history),
          ]),
          _section('DIAGNOSTIC REPORT', Icons.description_outlined, [
            _button('Generate Report', _generateReport, icon: Icons.description),
            if (_report.isNotEmpty) ...[
              const SizedBox(height: 8), SelectableText(_report, style: const TextStyle(fontSize: 11, height: 1.4)),
            ],
          ]),
          const SizedBox(height: 20),
          const Text('TRANSPARENCY NOTICE\nSome tools are best-effort because Android restricts ICMP/raw sockets, Wi-Fi scanning, device-wide connection tables, and radio metadata. Public IP/ISP/ASN data comes from external services. Do not treat IP geolocation as precise physical location.', style: TextStyle(fontSize: 11, color: Colors.black54, height: 1.5)),
        ],
      ),
    );
  }
}

class _TrafficGraph extends StatelessWidget {
  final List<double> download;
  final List<double> upload;
  const _TrafficGraph({required this.download, required this.upload});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 90,
    width: double.infinity,
    child: CustomPaint(painter: _TrafficPainter(download, upload)),
  );
}

class _TrafficPainter extends CustomPainter {
  final List<double> download;
  final List<double> upload;
  _TrafficPainter(this.download, this.upload);

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = Colors.blueGrey.withOpacity(.15)..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final all = [...download, ...upload];
    if (all.length < 2) return;
    final maxValue = all.fold<double>(1, (a, b) => b > a ? b : a);
    void draw(List<double> values, Color color) {
      if (values.length < 2) return;
      final paint = Paint()..color = color..strokeWidth = 2..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
      final path = Path();
      for (var i = 0; i < values.length; i++) {
        final x = size.width * i / (values.length - 1);
        final y = size.height - (values[i] / maxValue * size.height);
        if (i == 0) { path.moveTo(x, y); } else { path.lineTo(x, y); }
      }
      canvas.drawPath(path, paint);
    }
    draw(download, _blue);
    draw(upload, Colors.deepOrange);
  }

  @override
  bool shouldRepaint(covariant _TrafficPainter oldDelegate) => true;
}
