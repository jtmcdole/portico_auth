import 'dart:io';
import 'package:portico_auth_client/portico_auth_client.dart';

void main() async {
  final baseUrl = Uri.parse('http://localhost:8080/');
  final client = AuthClient(
    loginUrl: baseUrl.resolve('login'),
    registerUrl: baseUrl.resolve('register'),
    refreshUrl: baseUrl.resolve('refresh'),
    logoutUrl: baseUrl.resolve('logout'),
    updatePasswordUrl: baseUrl.resolve('updatePassword'),
  );

  print('╔══════════════════════════════════════════╗');
  print('║   Portico Auth Client Interactive CLI    ║');
  print('╚══════════════════════════════════════════╝');
  print('Connecting to server at: $baseUrl');
  print('Note: Ensure the Portico Auth Server is running.');

  bool running = true;
  while (running) {
    print('\nAvailable Actions:');
    print('1. Register');
    print('2. Login');
    print('3. Check Status');
    print('4. Refresh Session');
    print('5. Logout');
    print('6. change password');
    print('7. Exit');
    stdout.write('\nSelect an option (1-6): ');

    final choice = stdin.readLineSync();

    switch (choice) {
      case '1':
        await _register(client);
      case '2':
        await _login(client);
      case '3':
        _checkStatus(client);
      case '4':
        await _refresh(client);
      case '5':
        await _logout(client);
      case '6':
        await _changePassword(client);
      case '7':
        running = false;
        print('Goodbye!');
      default:
        print('Invalid choice. Please try again.');
    }
  }

  client.close();
}

Future<void> _register(AuthClient client) async {
  stdout.write('Enter userId: ');
  final userId = stdin.readLineSync();
  stdout.write('Enter password: ');
  final password = stdin.readLineSync();

  if (userId == null ||
      userId.isEmpty ||
      password == null ||
      password.isEmpty) {
    print('UserId and password are required.');
    return;
  }

  try {
    print('Registering...');
    await client.register(userId, password);
    print('✅ Registration successful!');
  } catch (e) {
    print('❌ Registration failed: $e');
  }
}

Future<void> _login(AuthClient client) async {
  stdout.write('Enter userId: ');
  final userId = stdin.readLineSync();
  stdout.write('Enter password: ');
  final password = stdin.readLineSync();

  if (userId == null ||
      userId.isEmpty ||
      password == null ||
      password.isEmpty) {
    print('UserId and password are required.');
    return;
  }

  try {
    print('Logging in...');
    await client.login(userId, password);
    print('✅ Login successful!');
    _checkStatus(client);
  } catch (e) {
    print('❌ Login failed: $e');
  }
}

Future<void> _changePassword(AuthClient client) async {
  stdout.write('Enter old password: ');
  final oldPassword = stdin.readLineSync();
  stdout.write('Enter new password: ');
  final password = stdin.readLineSync();

  if (password == null ||
      password.isEmpty ||
      oldPassword == null ||
      oldPassword.isEmpty) {
    print('old password and password are required.');
    return;
  }

  try {
    await client.updatePassword(oldPassword, password);
    print('✅ Password change successful!');
    _checkStatus(client);
  } catch (e) {
    print('❌ Password change failed: $e');
  }
}

void _checkStatus(AuthClient client) {
  final state = client.state;
  print('\nCurrent Client State:');
  switch (state) {
    case Unauthenticated():
      print('Status: Unauthenticated');
    case Authenticating():
      print('Status: Authenticating...');
    case Authenticated(:final user):
      print('Status: Authenticated');
      print('User ID: ${user.id}');
      if (user.name != null) print('Name: ${user.name}');
      print('Roles: ${user.roles}');
  }
}

Future<void> _refresh(AuthClient client) async {
  try {
    print('Refreshing session...');
    final headers = await client.httpHeaders();
    print('✅ Session refreshed. Headers:');
    headers.forEach(
      (key, value) => print('  $key: ${value.substring(0, 20)}...'),
    );
  } catch (e) {
    print('❌ Refresh failed: $e');
  }
}

Future<void> _logout(AuthClient client) async {
  try {
    print('Logging out...');
    await client.logout();
    print('✅ Logout successful!');
  } catch (e) {
    print('❌ Logout failed: $e');
  }
}
