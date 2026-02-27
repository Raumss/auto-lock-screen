import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/lock_service.dart';

void main() {
  runApp(const AutoLockApp());
}

class AutoLockApp extends StatelessWidget {
  const AutoLockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '自动锁屏',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _isAdminActive = false;
  bool _isServiceRunning = false;
  int _timeoutMinutes = 5;
  bool _loading = true;

  static const _presetTimeouts = [1, 2, 3, 5, 10, 15, 30, 60];
  static const _prefKeyTimeout = 'timeout_minutes';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshStatus();
    }
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _timeoutMinutes = prefs.getInt(_prefKeyTimeout) ?? 5;
    await _refreshStatus();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _refreshStatus() async {
    final results = await Future.wait([
      LockService.isAdminActive(),
      LockService.isServiceRunning(),
    ]);
    if (mounted) {
      setState(() {
        _isAdminActive = results[0];
        _isServiceRunning = results[1];
      });
    }
  }

  Future<void> _requestAdmin() async {
    final granted = await LockService.requestAdmin();
    if (mounted) {
      setState(() => _isAdminActive = granted);
      if (granted) {
        _showSnackBar('设备管理员权限已授予');
      }
    }
  }

  Future<void> _toggleService() async {
    if (!_isAdminActive) {
      await _requestAdmin();
      if (!_isAdminActive) return;
    }
    try {
      if (_isServiceRunning) {
        await LockService.stopService();
        if (mounted) setState(() => _isServiceRunning = false);
        _showSnackBar('自动锁屏已停止');
      } else {
        await LockService.startService(_timeoutMinutes);
        if (mounted) setState(() => _isServiceRunning = true);
        _showSnackBar('自动锁屏已启动');
      }
    } catch (e) {
      _showSnackBar('操作失败: $e');
    }
  }

  Future<void> _onTimeoutChanged(int minutes) async {
    setState(() => _timeoutMinutes = minutes);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKeyTimeout, minutes);
    if (_isServiceRunning) {
      await LockService.updateTimeout(minutes);
    }
  }

  Future<void> _lockNow() async {
    try {
      await LockService.lockNow();
    } catch (e) {
      _showSnackBar('锁屏失败，请先授予管理员权限');
    }
  }

  Future<void> _removeAdmin() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认移除'),
        content: const Text('移除设备管理员权限后将无法自动锁屏，是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认移除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (_isServiceRunning) {
        await LockService.stopService();
      }
      await LockService.removeAdmin();
      if (mounted) {
        setState(() {
          _isAdminActive = false;
          _isServiceRunning = false;
        });
      }
      _showSnackBar('设备管理员权限已移除');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('自动锁屏'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatusCard(),
          const SizedBox(height: 16),
          _buildAdminCard(),
          const SizedBox(height: 16),
          _buildTimeoutCard(),
          const SizedBox(height: 16),
          _buildActionsCard(),
        ],
      ),
    );
  }

  // ── Status Card ──────────────────────────────────────────────────────
  Widget _buildStatusCard() {
    final isActive = _isServiceRunning && _isAdminActive;
    final color = isActive ? Colors.green : Colors.grey;
    final statusText = isActive ? '监控中' : '未运行';

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        child: Column(
          children: [
            Icon(
              isActive ? Icons.lock_outline : Icons.lock_open,
              size: 72,
              color: color,
            ),
            const SizedBox(height: 12),
            Text(
              statusText,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isActive) ...[
              const SizedBox(height: 4),
              Text(
                '将在 $_timeoutMinutes 分钟无操作后自动锁屏',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _toggleService,
              icon: Icon(isActive ? Icons.stop : Icons.play_arrow),
              label: Text(isActive ? '停止监控' : '启动监控'),
              style: FilledButton.styleFrom(
                backgroundColor: isActive
                    ? Colors.red
                    : Theme.of(context).colorScheme.primary,
                minimumSize: const Size(200, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Admin Permission Card ────────────────────────────────────────────
  Widget _buildAdminCard() {
    return Card(
      child: ListTile(
        leading: Icon(
          _isAdminActive ? Icons.admin_panel_settings : Icons.warning_amber,
          color: _isAdminActive ? Colors.green : Colors.orange,
        ),
        title: const Text('设备管理员权限'),
        subtitle: Text(_isAdminActive ? '已授权 — 可以锁定屏幕' : '需要授权才能锁定屏幕'),
        trailing: _isAdminActive
            ? const Icon(Icons.check_circle, color: Colors.green)
            : TextButton(onPressed: _requestAdmin, child: const Text('授权')),
      ),
    );
  }

  // ── Timeout Settings Card ────────────────────────────────────────────
  Widget _buildTimeoutCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('锁屏超时时间', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '$_timeoutMinutes 分钟',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Slider(
              value: _timeoutMinutes.toDouble(),
              min: 1,
              max: 60,
              divisions: 59,
              label: '$_timeoutMinutes 分钟',
              onChanged: (v) => _onTimeoutChanged(v.round()),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _presetTimeouts.map((m) {
                return ChoiceChip(
                  label: Text('$m 分钟'),
                  selected: m == _timeoutMinutes,
                  onSelected: (_) => _onTimeoutChanged(m),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Quick Actions Card ───────────────────────────────────────────────
  Widget _buildActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('快捷操作', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.lock),
              title: const Text('立即锁屏'),
              subtitle: const Text('马上锁定屏幕'),
              onTap: _isAdminActive ? _lockNow : null,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.remove_circle_outline,
                color: Colors.red,
              ),
              title: const Text('移除设备管理员'),
              subtitle: const Text('移除权限后将无法自动锁屏'),
              onTap: _isAdminActive ? _removeAdmin : null,
            ),
          ],
        ),
      ),
    );
  }
}
