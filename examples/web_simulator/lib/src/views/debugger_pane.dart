import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logging/logging.dart';
import '../../main.dart';
import '../simulated_environment.dart';

class DebuggerPane extends StatefulWidget {
  const DebuggerPane({super.key});

  @override
  State<DebuggerPane> createState() => _DebuggerPaneState();
}

class _DebuggerPaneState extends State<DebuggerPane>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final env = SimulationProvider.of(context);

    return DefaultTabController(
      length: 5,
      child: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverToBoxAdapter(child: _buildTopBar(context, env)),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  isScrollable: true,
                  labelColor: Theme.of(context).colorScheme.primary,
                  unselectedLabelColor: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant,
                  tabs: const [
                    Tab(text: 'Info'),
                    Tab(text: 'Network Traffic'),
                    Tab(text: 'System Logs'),
                    Tab(text: 'Server DB'),
                    Tab(text: 'Client Storage'),
                  ],
                ),
                backgroundColor: Theme.of(context).colorScheme.surface,
              ),
            ),
          ];
        },
        body: TabBarView(
          children: [
            const _InfoView(),
            _TrafficLogView(traffic: env.traffic),
            _LogsView(logs: env.logs),
            _ServerDbView(env: env),
            _ClientStorageView(env: env),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, SimulatedEnvironment env) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final title = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bug_report),
            const SizedBox(width: 8),
            const Text(
              'SYSTEM DEBUGGER',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        );

        final timeDisplay = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.access_time, size: 16),
            const SizedBox(width: 4),
            Text(env.currentTime.toString().split('.').first),
          ],
        );

        final controls = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Text('+1m', style: TextStyle(fontSize: 12)),
              tooltip: 'Advance 1 minute',
              onPressed: () => env.advanceTime(const Duration(minutes: 1)),
            ),
            IconButton(
              icon: const Text('+10m', style: TextStyle(fontSize: 12)),
              tooltip: 'Advance 10 minutes',
              onPressed: () => env.advanceTime(const Duration(minutes: 10)),
            ),
            IconButton(
              icon: const Text('+1h', style: TextStyle(fontSize: 12)),
              tooltip: 'Advance 1 hour',
              onPressed: () => env.advanceTime(const Duration(hours: 1)),
            ),
            IconButton(
              icon: const Text('+1d', style: TextStyle(fontSize: 12)),
              tooltip: 'Advance 1 day',
              onPressed: () => env.advanceTime(const Duration(days: 1)),
            ),
          ],
        );

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context).colorScheme.surfaceContainer,
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const Divider(),
                    Wrap(
                      spacing: 16,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [timeDisplay, controls],
                    ),
                  ],
                )
              : Row(
                  children: [
                    title,
                    const Spacer(),
                    timeDisplay,
                    const SizedBox(width: 16),
                    controls,
                  ],
                ),
        );
      },
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  final Color backgroundColor;

  _SliverAppBarDelegate(this._tabBar, {required this.backgroundColor});

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: backgroundColor, child: _tabBar);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

class _InfoView extends StatelessWidget {
  const _InfoView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Auth Service Simulator',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'This simulator demonstrates the full stack of the portico_auth_service ecosystem running entirely in your browser.',
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 24),
        _buildFeatureSection(
          icon: Icons.router,
          title: 'Virtual Network',
          description:
              'No real HTTP requests are made. A custom adapter routes traffic directly to the server logic in memory. '
              'Check the "Network Traffic" tab to inspect raw JSON request/response bodies.',
        ),
        _buildFeatureSection(
          icon: Icons.update,
          title: 'Time Travel',
          description:
              'Use the controls in the top bar (+10m, +1h) to fast-forward time. '
              'This allows you to test token expiration and automatic refresh flows instantly.',
        ),
        _buildFeatureSection(
          icon: Icons.storage,
          title: 'State Inspection',
          description:
              'Inspect the internal state of the Server (Registered Users, Roles, Active Sessions) '
              'and the Client (Access/Refresh Tokens) in their respective tabs.',
        ),
        _buildFeatureSection(
          icon: Icons.save,
          title: 'Persistence',
          description:
              'Use the Save/Load buttons to persist the simulator state to your browser\'s LocalStorage. '
              'This allows you to close the tab and resume your session later.',
        ),
        const Divider(height: 48),
        const Text(
          'Getting Started',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildStep(1, 'Register an account and password on the left.'),
        _buildStep(2, 'Log in with your new credentials.'),
        _buildStep(3, 'Try clicking "Call Protected API" to see it succeed.'),
        _buildStep(
          4,
          'Go to "Server DB", create an "admin" role, and assign it to your user.',
        ),
        _buildStep(
          5,
          'Advance time by 1 hour in the top bar to expire your access token.',
        ),
        _buildStep(
          6,
          'Click "Call Admin Only API" - notice how it triggers a refresh flow before failing (or succeeding if you assigned the role!).',
        ),
        _buildStep(
          7,
          'Change your password in the app. Notice how all server sessions for your user are revoked, forcing you to log in again.',
        ),
      ],
    );
  }

  Widget _buildStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: Colors.indigo,
            child: Text(
              number.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildFeatureSection({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: Colors.indigo),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LogsView extends StatelessWidget {
  final List<LogRecord> logs;

  const _LogsView({required this.logs});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const Center(child: Text('No system logs yet.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[logs.length - 1 - index]; // Newest first
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _LogLevelBadge(level: log.level),
                    const SizedBox(width: 8),
                    Text(
                      log.loggerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      log.time.toString().split('.').first,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SelectableText(
                  log.message,
                  style: GoogleFonts.firaCode(fontSize: 12),
                ),
                if (log.error != null) ...[
                  const SizedBox(height: 4),
                  SelectableText(
                    'Error: ${log.error}',
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LogLevelBadge extends StatelessWidget {
  final Level level;

  const _LogLevelBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    Color color = Colors.grey;
    color = switch (level) {
      Level.INFO => Colors.blue,
      Level.WARNING => Colors.orange,
      Level.SEVERE => Colors.red,
      Level.SHOUT => Colors.purple,
      _ => Colors.white,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Text(
        level.name,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _TrafficLogView extends StatelessWidget {
  final List<TrafficEntry> traffic;

  const _TrafficLogView({required this.traffic});

  @override
  Widget build(BuildContext context) {
    if (traffic.isEmpty) {
      return const Center(
        child: Text('No traffic yet. Interact with the app on the left.'),
      );
    }

    return ListView.separated(
      itemCount: traffic.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = traffic[traffic.length - 1 - index]; // Show latest first
        return ExpansionTile(
          title: Row(
            children: [
              _StatusBadge(statusCode: entry.statusCode),
              const SizedBox(width: 8),
              Text(
                entry.method,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(entry.url.path, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          subtitle: Text(entry.timestamp.toString().split('.').first),
          children: [_buildTrafficDetail(context, entry)],
        );
      },
    );
  }

  Widget _buildTrafficDetail(BuildContext context, TrafficEntry entry) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Request Body:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          _JsonView(jsonString: entry.requestBody),
          const SizedBox(height: 16),
          const Text(
            'Response Body:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          _JsonView(jsonString: entry.responseBody),
        ],
      ),
    );
  }
}

class _ServerDbView extends StatelessWidget {
  final SimulatedEnvironment env;

  const _ServerDbView({required this.env});

  @override
  Widget build(BuildContext context) {
    final users = env.users;
    final tokens = env.tokens;
    final roles = env.roles;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.save, size: 16),
              label: const Text('Save DB'),
              onPressed: () => env.saveState(),
            ),
            TextButton.icon(
              icon: const Icon(Icons.file_open, size: 16),
              label: const Text('Load DB'),
              onPressed: () => env.loadState(),
            ),
            TextButton.icon(
              icon: const Icon(Icons.delete_forever, size: 16),
              label: const Text('Reset DB'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => env.reset(),
            ),
          ],
        ),
        const Divider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Roles',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showAddRoleDialog(context, env),
              tooltip: 'Add Role',
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (roles.isEmpty)
          const Text('No roles defined.')
        else
          ...roles.values.map(
            (role) => ListTile(
              title: Text(role.name),
              subtitle: Text(role.description),
              trailing: Switch(
                value: role.isActive,
                onChanged: (val) => env.toggleRoleStatus(role.name, val),
              ),
            ),
          ),
        const Divider(height: 32),
        const Text(
          'Registered Users',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (users.isEmpty)
          const Text('No users registered.')
        else
          ...users.entries.map(
            (e) => _UserTile(env: env, userId: e.key, userData: e.value),
          ),
        const Divider(height: 32),
        const Text(
          'Refresh Tokens (Chains)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (tokens.isEmpty)
          const Text('No active sessions.')
        else
          ...tokens.values.map(
            (v) => ListTile(
              title: Text('Name: ${v.name} (${v.userId})'),
              subtitle: Text(
                'Serial: ${v.serial}\nCounter: ${v.counter}\nUpdated: ${v.lastTime}',
              ),
              isThreeLine: true,
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => env.revokeSession(v.serial, v.userId),
                tooltip: 'Revoke Session',
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _showAddRoleDialog(
    BuildContext context,
    SimulatedEnvironment env,
  ) async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Role'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Role Name (e.g. admin)',
              ),
            ),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                env.createRole(
                  nameController.text,
                  nameController.text,
                  descriptionController.text,
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final SimulatedEnvironment env;
  final String userId;
  final dynamic userData; // UserData

  const _UserTile({
    required this.env,
    required this.userId,
    required this.userData,
  });

  @override
  Widget build(BuildContext context) {
    final assignments = env.rolesStorage.assignments
        .where((a) => a.userId == userId)
        .toList();

    return ExpansionTile(
      title: Text(userId),
      subtitle: Text('Salt: ${userData.salt}\nHash: ${userData.hash}'),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Assigned Roles:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Assign'),
                    onPressed: () =>
                        _showAssignRoleDialog(context, env, userId),
                  ),
                ],
              ),
              if (assignments.isEmpty)
                const Text(
                  'No roles assigned.',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                )
              else
                ...assignments.map(
                  (a) => ListTile(
                    dense: true,
                    title: Text(a.roleName),
                    subtitle: a.scope != null
                        ? Text('Scope: ${a.scope}')
                        : null,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, size: 16),
                      onPressed: () =>
                          env.unassignRole(userId, a.roleName, scope: a.scope),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showAssignRoleDialog(
    BuildContext context,
    SimulatedEnvironment env,
    String userId,
  ) async {
    final roles = env.rolesStorage.roles.values
        .where((r) => r.isActive)
        .toList();
    if (roles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active roles available.')),
      );
      return;
    }

    String selectedRole = roles.first.name;
    final scopeController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Assign Role to $userId'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedRole,
                decoration: const InputDecoration(labelText: 'Role'),
                items: roles
                    .map(
                      (r) =>
                          DropdownMenuItem(value: r.name, child: Text(r.name)),
                    )
                    .toList(),
                onChanged: (val) => setState(() => selectedRole = val!),
              ),
              TextField(
                controller: scopeController,
                decoration: const InputDecoration(
                  labelText: 'Scope (Optional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                env.assignRole(
                  userId,
                  selectedRole,
                  scope: scopeController.text.isEmpty
                      ? null
                      : scopeController.text,
                );
                Navigator.pop(context);
              },
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientStorageView extends StatelessWidget {
  final SimulatedEnvironment env;

  const _ClientStorageView({required this.env});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: env.clientStorage.loadTokens(),
      builder: (context, snapshot) {
        final tokens = snapshot.data;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.save, size: 16),
                  label: const Text('Save'),
                  onPressed: tokens == null
                      ? null
                      : () => env.saveClientTokens(),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Load'),
                  onPressed: () => env.loadClientTokens(),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.delete, size: 16),
                  label: const Text('Clear'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () => env.clearClientTokens(),
                ),
              ],
            ),
            const Divider(),
            if (tokens == null)
              const Padding(
                padding: EdgeInsets.only(top: 32),
                child: Center(child: Text('No tokens stored on client.')),
              )
            else ...[
              const Text(
                'Access Token (JWT)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _JwtInspectView(token: tokens.accessToken),
              const Divider(height: 48),
              const Text(
                'Refresh Token (JWE)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                tokens.refreshToken,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
              ),
              const SizedBox(height: 8),
              const Text(
                'Note: Refresh tokens are encrypted (JWE) and cannot be decoded by the client.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _JwtInspectView extends StatelessWidget {
  final String token;

  const _JwtInspectView({required this.token});

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> claims = {};
    try {
      final parts = token.split('.');
      if (parts.length == 3) {
        final payload = parts[1];
        final normalized = base64.normalize(payload);
        final decoded = utf8.decode(base64.decode(normalized));
        claims = jsonDecode(decoded);
      }
    } catch (e) {
      return Text('Error decoding JWT: $e');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Decoded Claims:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 4),
        _JsonView(jsonString: jsonEncode(claims)),
        const SizedBox(height: 16),
        const Text(
          'Raw Token:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          token,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            color: Colors.blue,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final int statusCode;

  const _StatusBadge({required this.statusCode});

  @override
  Widget build(BuildContext context) {
    final color = statusCode < 300
        ? Colors.green
        : (statusCode < 400 ? Colors.orange : Colors.red);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        statusCode.toString(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _JsonView extends StatelessWidget {
  final String? jsonString;

  const _JsonView({this.jsonString});

  @override
  Widget build(BuildContext context) {
    if (jsonString == null || jsonString!.isEmpty) {
      return const Text(
        '(empty)',
        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
      );
    }

    String formatted = jsonString!;
    try {
      final decoded = jsonDecode(jsonString!);
      formatted = const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.all(8),
      child: SelectableText(
        formatted,
        style: GoogleFonts.firaCode(fontSize: 12),
      ),
    );
  }
}
