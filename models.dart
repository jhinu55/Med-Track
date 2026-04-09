// lib/models/models.dart
// Data classes matching the MySQL schema.

class MedUser {
  final int actorId;
  final String username;
  final String email;
  final String role;
  const MedUser({required this.actorId, required this.username, required this.email, required this.role});
  factory MedUser.fromJson(Map<String, dynamic> j) => MedUser(
    actorId: j['actor_id'] as int,
    username: j['username'] as String,
    email: j['email'] as String,
    role: j['role'] as String,
  );
}

class Medicine {
  final int medicineId;
  final String genericName;
  final String brandName;
  final double basePrice;
  const Medicine({required this.medicineId, required this.genericName, required this.brandName, required this.basePrice});
  factory Medicine.fromJson(Map<String, dynamic> j) => Medicine(
    medicineId: j['medicine_id'] as int,
    genericName: j['generic_name'] as String,
    brandName: j['brand_name'] as String,
    basePrice: (j['base_price'] as num).toDouble(),
  );
  @override
  String toString() => '$brandName ($genericName)';
}

class Batch {
  final int batchId;
  final int medicineId;
  final String genericName;
  final String brandName;
  final String qrCodeHash;
  final DateTime mfgDate;
  final DateTime expiryDate;
  final int currentOwnerId;
  const Batch({
    required this.batchId, required this.medicineId,
    required this.genericName, required this.brandName,
    required this.qrCodeHash, required this.mfgDate,
    required this.expiryDate, required this.currentOwnerId,
  });
  factory Batch.fromJson(Map<String, dynamic> j) => Batch(
    batchId: j['batch_id'] as int,
    medicineId: j['medicine_id'] as int,
    genericName: (j['generic_name'] as String?) ?? '',
    brandName: (j['brand_name'] as String?) ?? '',
    qrCodeHash: j['qr_code_hash'] as String,
    mfgDate: DateTime.parse(j['mfg_date'] as String),
    expiryDate: DateTime.parse(j['expiry_date'] as String),
    currentOwnerId: j['current_owner_id'] as int,
  );
  bool get isExpired => expiryDate.isBefore(DateTime.now());
  bool get isExpiringSoon =>
      !isExpired && expiryDate.isBefore(DateTime.now().add(const Duration(days: 90)));
}

class TransferLog {
  final int transferId;
  final int batchId;
  final String? brandName;
  final int senderId;
  final int receiverId;
  final String? receiverUsername;
  final DateTime transferDate;
  final String status;
  const TransferLog({
    required this.transferId, required this.batchId, this.brandName,
    required this.senderId, required this.receiverId, this.receiverUsername,
    required this.transferDate, required this.status,
  });
  factory TransferLog.fromJson(Map<String, dynamic> j) => TransferLog(
    transferId: j['transfer_id'] as int,
    batchId: j['batch_id'] as int,
    brandName: j['brand_name'] as String?,
    senderId: j['sender_id'] as int,
    receiverId: j['receiver_id'] as int,
    receiverUsername: j['receiver_username'] as String?,
    transferDate: DateTime.parse(j['transfer_date'] as String),
    status: j['status'] as String,
  );
}

class Pharmacy {
  final int actorId;
  final String username;
  final String email;
  const Pharmacy({required this.actorId, required this.username, required this.email});
  factory Pharmacy.fromJson(Map<String, dynamic> j) => Pharmacy(
    actorId: j['actor_id'] as int,
    username: j['username'] as String,
    email: j['email'] as String? ?? '',
  );
  @override
  String toString() => username;
}
