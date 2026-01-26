import 'package:portico_auth_credentials/portico_auth_credentials.dart';

void main() async {
  // 1. Initialize with in-memory storage for this example
  final storage = AuthCredentialsInMemoryStorage();
  final auth = AuthCredentialsManager(storage: storage);

  const userId = 'alice@example.com';
  const password = 'superSecretPassword!';

  print('--- Registration ---');
  await auth.registerUser(userId, password);
  print('User $userId registered.');

  print('\n--- Verification ---');
  try {
    final isValid = await auth.verifyCredentials(userId, password);
    print('Login successful? $isValid');
  } catch (e) {
    print('Login failed: $e');
  }

  print('\n--- Password Update ---');
  const newPassword = 'evenBetterPassword!';
  await auth.updatePassword(userId, password, newPassword);
  print('Password updated.');

  print('\n--- Re-Verification ---');
  try {
    await auth.verifyCredentials(userId, password); // Should fail
  } on InvalidCredentialsException {
    print('Old password correctly rejected.');
  }

  try {
    await auth.verifyCredentials(userId, newPassword); // Should succeed
    print('New password accepted.');
  } catch (e) {
    print('New password failed: $e');
  }
}
