import '../data/seed_data.dart';

class Subject {
  final int? id;
  final String nameBn;
  final String nameEn;
  final int colorValue;
  final int sortOrder;
  final EduLevel level;
  final EduGroup group;

  Subject({
    this.id,
    required this.nameBn,
    required this.nameEn,
    required this.colorValue,
    required this.sortOrder,
    required this.level,
    required this.group,
  });

  String localizedName(String locale) => locale == 'en' ? nameEn : nameBn;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nameBn': nameBn,
      'nameEn': nameEn,
      'colorValue': colorValue,
      'sortOrder': sortOrder,
      'level': level.index,
      'subjectGroup': group.index,
    };
  }

  factory Subject.fromMap(Map<String, dynamic> map) {
    return Subject(
      id: map['id'] as int?,
      nameBn: map['nameBn'] as String,
      nameEn: map['nameEn'] as String,
      colorValue: map['colorValue'] as int,
      sortOrder: map['sortOrder'] as int,
      level: EduLevel.values[(map['level'] as int?) ?? EduLevel.hsc.index],
      group: EduGroup.values[(map['subjectGroup'] as int?) ?? EduGroup.science.index],
    );
  }
}
