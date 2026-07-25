class User {
  final int userId;
  final String username;
  final String email;
  final String role;
  final int? branchId;
  final bool isActive;

  User({
    required this.userId,
    required this.username,
    required this.email,
    required this.role,
    this.branchId,
    required this.isActive,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id'],
      username: json['username'],
      email: json['email'],
      role: json['role'],
      branchId: json['branch_id'],
      isActive: json['is_active'],
    );
  }
}
