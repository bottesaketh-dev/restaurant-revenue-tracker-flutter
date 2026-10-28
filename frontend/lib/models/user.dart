class User {
  final int userId;
  final String username;
  final String email;
  final String role;
  final int? restaurantId;
  final String? restaurantName;
  final String? currencyCode;
  final String? currencySymbol;
  final double? taxRate;
  final int? branchId;
  final bool isActive;
  final String accessLevel;
  final List<String>? allowedTabs;

  User({
    required this.userId,
    required this.username,
    required this.email,
    required this.role,
    this.restaurantId,
    this.restaurantName,
    this.currencyCode,
    this.currencySymbol,
    this.taxRate,
    this.branchId,
    required this.isActive,
    this.accessLevel = 'FULL',
    this.allowedTabs,
  });

  bool get isSuperAdmin => role.toUpperCase() == 'SUPER_ADMIN';
  bool get isRestaurantAdmin =>
      role.toUpperCase() == 'RESTAURANT_ADMIN' || isSuperAdmin || role.toUpperCase() == 'ADMIN';
  bool get isBranchManager => role.toUpperCase() == 'BRANCH_MANAGER';

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id'] ?? json['id'] ?? 0,
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'STAFF',
      restaurantId: json['restaurant_id'],
      restaurantName: json['restaurant_name'],
      currencyCode: json['currency_code'],
      currencySymbol: json['currency_symbol'],
      taxRate: (json['tax_rate'] as num?)?.toDouble(),
      branchId: json['branch_id'],
      isActive: json['is_active'] ?? true,
      accessLevel: json['access_level'] ?? 'FULL',
      allowedTabs: (json['allowed_tabs'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'username': username,
      'email': email,
      'role': role,
      'restaurant_id': restaurantId,
      'restaurant_name': restaurantName,
      'currency_code': currencyCode,
      'currency_symbol': currencySymbol,
      'tax_rate': taxRate,
      'branch_id': branchId,
      'is_active': isActive,
      'access_level': accessLevel,
      'allowed_tabs': allowedTabs,
    };
  }
}
