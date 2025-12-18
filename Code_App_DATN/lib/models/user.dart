enum Gender { male, female, unknown }

Gender _genderFromString(String? s) {
  if (s == null) return Gender.unknown;
  final low = s.toLowerCase();
  if (low == 'male' || low == 'm') return Gender.male;
  if (low == 'female' || low == 'f') return Gender.female;
  return Gender.unknown;
}

String _genderToString(Gender g) {
  switch (g) {
    case Gender.male:
      return 'MALE';
    case Gender.female:
      return 'FEMALE';
    default:
      return 'UNKNOWN';
  }
}

class User {
  // Core
  final int? id; // user_id
  final String? userName;
  final String? fullName;
  final String? email;
  final String? phone;

  // Single role (server lưu đơn)
  final String? role;

  // Profile
  final Gender gender;
  final DateTime? dob;
  final String? avatarUrl;
  final String? address;
  final String? schoolName;
  final String? status;
  final Map<String, dynamic>? params;

  // Auth
  final String? token;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Sensitive (do NOT persist in plain prefs in production)
  final String? password;

  const User({
    this.id,
    this.userName,
    this.fullName,
    this.email,
    this.phone,
    this.role,
    this.gender = Gender.unknown,
    this.dob,
    this.avatarUrl,
    this.address,
    this.schoolName,
    this.status,
    this.params,
    this.token,
    this.createdAt,
    this.updatedAt,
    this.password,
  });

  // Flexible parsing: chấp nhận AjaxResult/data/user nesting
  factory User.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> src = Map<String, dynamic>.from(json);

    // Wrap: nếu có data (AjaxResult)
    if (src.containsKey('data')) {
      final data = src['data'];
      if (data is String) {
        // data là token
        return User(token: data);
      } else if (data is Map) {
        src.addAll(Map<String, dynamic>.from(data));
      }
    }

    // Nếu có nested 'user'
    if (src['user'] is Map) {
      src.addAll(Map<String, dynamic>.from(src['user']));
    }

    int? parseInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    }

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        try {
          final s = v.toString();
          if (RegExp(r'^\d{2}-\d{2}-\d{4}$').hasMatch(s)) {
            final parts = s.split('-');
            final d = int.parse(parts[0]);
            final m = int.parse(parts[1]);
            final y = int.parse(parts[2]);
            return DateTime(y, m, d);
          }
        } catch (_) {}
      }
      return null;
    }

    // Role: accept 'role' or 'roles' (if roles is list/string take first)
    String? roleFromSrc;
    if (src['role'] is String) {
      roleFromSrc = src['role']?.toString();
    } else if (src['roles'] != null) {
      if (src['roles'] is List) {
        final list = List.from(src['roles']).map((e) => e.toString()).toList();
        if (list.isNotEmpty) roleFromSrc = list.first;
      } else if (src['roles'] is String) {
        final list = src['roles'].toString().split(',').map((s) => s.trim()).toList();
        if (list.isNotEmpty) roleFromSrc = list.first;
      }
    }

    Gender gender = Gender.unknown;
    if (src['gender'] != null) gender = _genderFromString(src['gender'].toString());
    else if (src['sex'] != null) gender = _genderFromString(src['sex'].toString());

    final token = src['token'] ?? src['accessToken'] ?? src['jwt'];

    return User(
      id: parseInt(src['userId'] ?? src['user_id'] ?? src['id']),
      userName: src['userName'] ?? src['user_name'] ?? src['username'] ?? src['student_id'] ?? src['studentId'] ?? src['user']?.toString(),
      fullName: src['fullName'] ?? src['full_name'] ?? src['fullname'] ?? src['name'],
      email: src['email'] ?? src['mail'],
      phone: src['phone'] ?? src['telephone'] ?? src['mobile'],
      role: roleFromSrc != null ? roleFromSrc.toString().replaceAll('ROLE_', '') : null,
      gender: gender,
      dob: parseDate(src['dob'] ?? src['birthDate'] ?? src['admissionDate']),
      avatarUrl: src['avatarUrl'] ?? src['avatar_url'] ?? src['avatar'],
      address: src['address'] ?? src['location'],
      schoolName: src['schoolName'] ?? src['school_name'],
      status: src['status']?.toString(),
      params: src['params'] is Map ? Map<String, dynamic>.from(src['params']) : null,
      token: token?.toString(),
      createdAt: parseDate(src['createdAt'] ?? src['created_at']),
      updatedAt: parseDate(src['updatedAt'] ?? src['updated_at'] ?? src['modified_date']),
      password: src['password']?.toString(),
    );
  }

  Map<String, dynamic> toJson({bool includeSensitive = false}) {
    final Map<String, dynamic> m = {};
    if (id != null) m['userId'] = id;
    if (userName != null) m['userName'] = userName;
    if (fullName != null) m['fullName'] = fullName;
    if (email != null) m['email'] = email;
    if (phone != null) m['phone'] = phone;
    if (role != null) m['role'] = role;
    if (gender != Gender.unknown) m['gender'] = _genderToString(gender);
    if (dob != null) m['dob'] = dob!.toIso8601String();
    if (avatarUrl != null) m['avatarUrl'] = avatarUrl;
    if (address != null) m['address'] = address;
    if (schoolName != null) m['schoolName'] = schoolName;
    if (status != null) m['status'] = status;
    if (params != null) m['params'] = params;
    if (createdAt != null) m['createdAt'] = createdAt!.toIso8601String();
    if (updatedAt != null) m['updatedAt'] = updatedAt!.toIso8601String();
    if (includeSensitive) {
      if (token != null) m['token'] = token;
      if (password != null) m['password'] = password;
    }
    return m;
  }

  User copyWith({
    int? id,
    String? userName,
    String? fullName,
    String? email,
    String? phone,
    String? role,
    Gender? gender,
    DateTime? dob,
    String? avatarUrl,
    String? address,
    String? schoolName,
    String? status,
    Map<String, dynamic>? params,
    String? token,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? password,
  }) {
    return User(
      id: id ?? this.id,
      userName: userName ?? this.userName,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      gender: gender ?? this.gender,
      dob: dob ?? this.dob,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      address: address ?? this.address,
      schoolName: schoolName ?? this.schoolName,
      status: status ?? this.status,
      params: params ?? this.params,
      token: token ?? this.token,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      password: password ?? this.password,
    );
  }

  String displayName() => (fullName != null && fullName!.isNotEmpty) ? fullName! : (userName ?? 'Người dùng');

  bool hasRole(String r) {
    final normalized = r.replaceAll('ROLE_', '').toUpperCase();
    if (role != null && role!.isNotEmpty) {
      return role!.replaceAll('ROLE_', '').toUpperCase() == normalized;
    }
    return false;
  }

  String tokenPreview([int len = 20]) {
    if (token == null) return 'Không có token';
    if (token!.length <= len) return token!;
    return '${token!.substring(0, len)}...';
  }

  @override
  String toString() {
    return 'User(id: $id, userName: $userName, fullName: $fullName, email: $email, phone: $phone, role: $role, schoolName: $schoolName, token: ${token != null ? '***' : 'null'})';
  }
}