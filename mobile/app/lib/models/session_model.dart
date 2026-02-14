class SessionModel {
  SessionModel({
    this.id,
    required this.courseCode,
    required this.courseTitle,
    required this.lecturerName,
    required this.room,
    required this.startsAt,
    this.endsAt,
    this.active = true,
    this.tokenVersion = '',
  });

  final int? id;
  final String courseCode;
  final String courseTitle;
  final String lecturerName;
  final String room;
  final DateTime startsAt;
  final DateTime? endsAt;
  final bool active;
  final String tokenVersion;

  Map<String, dynamic> toJson() {
    return {
      'course_code': courseCode,
      'course_title': courseTitle,
      'lecturer_name': lecturerName,
      'room': room,
      'starts_at': startsAt.toUtc().toIso8601String(),
      if (endsAt != null) 'ends_at': endsAt!.toUtc().toIso8601String(),
      'active': active,
      'token_version': tokenVersion,
    };
  }

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      id: json['id'] as int?,
      courseCode: json['course_code'] as String? ?? '',
      courseTitle: json['course_title'] as String? ?? '',
      lecturerName: json['lecturer_name'] as String? ?? '',
      room: json['room'] as String? ?? '',
      startsAt: DateTime.parse(json['starts_at'] as String),
      endsAt: json['ends_at'] == null
          ? null
          : DateTime.parse(json['ends_at'] as String),
      active: json['active'] as bool? ?? true,
      tokenVersion: json['token_version'] as String? ?? '',
    );
  }
}
