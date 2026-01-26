import 'package:portico_auth_client/portico_auth_client.dart';
import 'dart:io';

void main() async {
  final baseUrl = Uri.parse('http://localhost:8080/');
  final client = AuthClient(
    loginUrl: baseUrl.resolve('login'),
    registerUrl: baseUrl.resolve('register'),
    refreshUrl: baseUrl.resolve('refresh'),
    logoutUrl: baseUrl.resolve('logout'),
  );

  // Use a unique userId to avoid conflicts if the server isn't restarted
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final userId = 'user_$timestamp@example.com';
  final password = 'password123';

  print('1. Registering new user: $userId');
  try {
    await client.register(userId, password);
    print('   Registration successful!');
  } catch (e) {
    print('   Registration failed: $e');
    exit(1);
  }

  print('\n2. Attempting to login...');
  try {
    await client.login(userId, password);
    print('   Login successful!');

    if (client.state case Authenticated(:final user)) {
      print('   User ID: ${user.id}');
      print('   Roles: ${user.roles}');
    } else {
      print('   Unexpected state: ${client.state}');
      exit(1);
    }

    print('\n3. Getting HTTP headers (Refresh Token Check)...');
    final headers = await client.httpHeaders();
    print('   Headers obtained: ${headers.keys.toList()}');

    print('\n4. Logging out...');
    await client.logout();
    print('   State after logout: ${client.state}');

    print('\n✅ Verification Complete!');
    exit(0);
  } catch (e) {
    print('❌ Error: $e');
    exit(1);
  } finally {
    client.close();
  }
}
