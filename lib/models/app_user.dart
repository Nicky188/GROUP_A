/**
 * Student Numbers: XXXXXXXXX, XXXXXXXXX, XXXXXXXXX, XXXXXXXXX, XXXXXXXXX
 * Student Names  : [Group Member Names Here]
 * Question: AppUser Model
 */

// ============================================================
// models/app_user.dart
// Represents a system user (student or admin)
// ============================================================

class AppUser {
  final String id;
  final String email;
  final String fullName;
  final String studentNumber;
  final String role; // 'student' | 'admin'

  const AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.studentNumber,
    required this.role,
  });

  /// Whether this user has admin access
  bool get isAdmin => role == 'admin';

  /// Whether this user is a student
  bool get isStudent => role == 'student';

  /// Creates an AppUser from a Supabase profiles table row
  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String,
      email: map['email'] as String? ?? '',
      fullName: map['full_name'] as String? ?? 'Unknown',
      studentNumber: map['student_number'] as String? ?? 'N/A',
      role: map['role'] as String? ?? 'student',
    );
  }

  /// Converts AppUser to a map for Supabase upsert
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'student_number': studentNumber,
      'role': role,
    };
  }
}
