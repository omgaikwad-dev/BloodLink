/// App-wide constants for BloodLink AI
library;

class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'BloodLink AI';
  static const String appTagline = 'Emergency Blood Network System';
  static const String appVersion = '1.0.0';

  // Radius for nearby search (in km)
  static const double searchRadiusKm = 20.0;

  // Blood Groups
  static const List<String> bloodGroups = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-',
  ];

  // Blood Compatibility Map (who can donate to whom)
  static const Map<String, List<String>> bloodCompatibility = {
    'O-': ['O-', 'O+', 'A-', 'A+', 'B-', 'B+', 'AB-', 'AB+'],
    'O+': ['O+', 'A+', 'B+', 'AB+'],
    'A-': ['A-', 'A+', 'AB-', 'AB+'],
    'A+': ['A+', 'AB+'],
    'B-': ['B-', 'B+', 'AB-', 'AB+'],
    'B+': ['B+', 'AB+'],
    'AB-': ['AB-', 'AB+'],
    'AB+': ['AB+'],
  };

  // Urgency Levels
  static const List<String> urgencyLevels = [
    'Normal',
    'Urgent',
    'Critical',
    'SOS',
  ];

  // Request Status
  static const String statusPending = 'pending';
  static const String statusMatched = 'matched';
  static const String statusAccepted = 'accepted';
  static const String statusInTransit = 'in_transit';
  static const String statusCompleted = 'completed';
  static const String statusCancelled = 'cancelled';

  // Roles
  static const String roleHospital = 'hospital';
  static const String roleDonor = 'donor';
  static const String roleBloodBank = 'blood_bank';
  static const String roleAdmin = 'admin';

  // Minimum days between donations
  static const int minDaysBetweenDonations = 56;

  // Firestore Collections
  static const String usersCollection = 'users';
  static const String requestsCollection = 'requests';
  static const String bloodInventoryCollection = 'bloodInventory';
  static const String ambulancesCollection = 'ambulances';
  static const String notificationsCollection = 'notifications';
  static const String chatCollection = 'chats';

  // AI API
  static const String aiApiBaseUrl = 'https://bloodlink-ai-api.onrender.com';
}
