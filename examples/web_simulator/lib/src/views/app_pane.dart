import 'package:flutter/material.dart';
import '../../main.dart';
import '../simulated_environment.dart';

class AppPane extends StatefulWidget {
  const AppPane({super.key});

  @override
  State<AppPane> createState() => _AppPaneState();
}

class _AppPaneState extends State<AppPane> {
  final _userIdController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  String? _message;

  @override
  void dispose() {
    _userIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final env = SimulationProvider.of(context);

    return Container(
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 64,
                maxWidth: 400,
              ),
              child: Center(
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        // 1. Define the dynamic width:
                        // Taking 80% of the screen width effectively leaves
                        // a 10% margin on the left and 10% on the right.
                        width: MediaQuery.of(context).size.width * 0.8,

                        // 2. Set the hard limit:
                        // This ensures that if 80% of the screen is larger than 512px,
                        // the width stops growing at 512px.
                        constraints: const BoxConstraints(maxWidth: 256),

                        // 3. The Logo:
                        child: Image.asset(
                          'assets/logo.png',
                          fit: BoxFit.contain, // Prevents distortion
                        ),
                      ),
                    ),

                    ListenableBuilder(
                      listenable: env,
                      builder: (context, child) {
                        if (env.isAuthenticated) {
                          return _buildDashboard(env);
                        }
                        return _buildAuthForm(env);
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAuthForm(SimulatedEnvironment env) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Auth Client App',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              autofillHints: const [AutofillHints.username],
              keyboardType: TextInputType.name,
              controller: _userIdController,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            TextField(
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              keyboardType: TextInputType.visiblePassword,
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 24),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _message!,
                  style: const TextStyle(color: Colors.green),
                ),
              ),
            ElevatedButton(
              onPressed: _isLoading ? null : () => _login(env),
              child: const Text('Login'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _isLoading ? null : () => _register(env),
              child: const Text('Register'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(SimulatedEnvironment env) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Welcome!',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Center(child: Text('Logged in as: ${env.userId}')),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _callProtectedApi(env),
              child: const Text('Call Protected API'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _callScopedApi(env),
              child: const Text('Call Admin Only API (Scoped)'),
            ),
            const SizedBox(height: 24),
            if (_message != null)
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.green.withValues(alpha: 0.1),
                child: Text(
                  _message!,
                  style: const TextStyle(color: Colors.green),
                ),
              ),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.red.withValues(alpha: 0.1),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => _handleLogout(env),
              child: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _login(SimulatedEnvironment env) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _message = null;
    });
    try {
      await env.authClient.login(
        _userIdController.text,
        _passwordController.text,
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _register(SimulatedEnvironment env) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _message = null;
    });
    try {
      await env.authClient.register(
        _userIdController.text,
        _passwordController.text,
      );
      setState(() {
        _message = 'Registered! Now you can login.';
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLogout(SimulatedEnvironment env) async {
    await env.authClient.logout();
    setState(() {
      _message = null;
      _error = null;
    });
  }

  Future<void> _callProtectedApi(SimulatedEnvironment env) async {
    setState(() {
      _message = null;
      _error = null;
    });
    try {
      final response = await env.get(
        Uri.parse('https://api.example.com/api/protected'),
      );
      setState(() {
        _message = 'Response: ${response.body}';
      });
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
      });
    }
  }

  Future<void> _callScopedApi(SimulatedEnvironment env) async {
    setState(() {
      _message = null;
      _error = null;
    });
    try {
      final response = await env.get(
        Uri.parse('https://api.example.com/api/scoped'),
      );
      if (response.statusCode == 200) {
        setState(() {
          _message = 'Response: ${response.body}';
        });
      } else {
        setState(() {
          _error = 'Status: ${response.statusCode}\nBody: ${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
      });
    }
  }
}
