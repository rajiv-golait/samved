class Profile {
  const Profile({
    required this.id,
    required this.fullName,
    this.phone,
    this.email,
    required this.role,
    this.zoneId,
    required this.departmentId,
    this.isActive = true,
    this.employeeId,
  });

  final String id;
  final String fullName;
  final String? phone;
  final String? email;
  final String role;
  final int? zoneId;
  final int departmentId;
  final bool isActive;
  final String? employeeId;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      role: json['role'] as String? ?? '',
      zoneId: json['zone_id'] as int?,
      departmentId: json['department_id'] as int? ?? 1,
      isActive: json['is_active'] as bool? ?? true,
      employeeId: json['employee_id']?.toString(),
    );
  }
}
