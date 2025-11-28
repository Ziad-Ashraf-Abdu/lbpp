class UserProfile {
  final String userId;
  final String activationKey; // The password for the ESP32 Handshake
  final DateTime lastSync;
  final UserPreferences preferences;

  UserProfile({
    required this.userId,
    required this.activationKey,
    required this.lastSync,
    this.preferences = const UserPreferences(),
  });

  // Create a profile when the user first enters their key
  factory UserProfile.create(String key) {
    return UserProfile(
      userId: DateTime.now().millisecondsSinceEpoch.toString(), // Simple ID generation
      activationKey: key,
      lastSync: DateTime.now(),
    );
  }
}

class UserPreferences {
  final double safeLimit; // Default 10.0
  final double riskLimit; // Default 15.0
  final bool hapticEnabled;

  const UserPreferences({
    this.safeLimit = 10.0,
    this.riskLimit = 15.0,
    this.hapticEnabled = true,
  });
}