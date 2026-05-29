import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? avatar;
  final bool isActive;
  final int? branchId;
  final List<String> roles;
  final List<String> permissions;

  const UserEntity({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.avatar,
    required this.isActive,
    this.branchId,
    required this.roles,
    required this.permissions,
  });

  bool hasPermission(String permission) => permissions.contains(permission);

  bool hasRole(String role) => roles.contains(role);

  bool get isSuperAdmin => roles.contains('super-admin');

  @override
  List<Object?> get props => [id, email, roles, permissions];
}
