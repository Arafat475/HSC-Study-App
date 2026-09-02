class Chapter {
  final int? id;
  final int subjectId;
  final String title; // Bangla
  final String titleEn;
  final int sortOrder;
  final bool chapterComplete;
  final bool revisionComplete;

  Chapter({
    this.id,
    required this.subjectId,
    required this.title,
    required this.titleEn,
    required this.sortOrder,
    this.chapterComplete = false,
    this.revisionComplete = false,
  });

  String localizedTitle(String locale) => locale == 'en' ? titleEn : title;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subjectId': subjectId,
      'title': title,
      'titleEn': titleEn,
      'sortOrder': sortOrder,
      'chapterComplete': chapterComplete ? 1 : 0,
      'revisionComplete': revisionComplete ? 1 : 0,
    };
  }

  factory Chapter.fromMap(Map<String, dynamic> map) {
    return Chapter(
      id: map['id'] as int?,
      subjectId: map['subjectId'] as int,
      title: map['title'] as String,
      titleEn: (map['titleEn'] as String?) ?? map['title'] as String,
      sortOrder: map['sortOrder'] as int,
      chapterComplete: (map['chapterComplete'] as int) == 1,
      revisionComplete: (map['revisionComplete'] as int) == 1,
    );
  }

  Chapter copyWith({bool? chapterComplete, bool? revisionComplete}) {
    return Chapter(
      id: id,
      subjectId: subjectId,
      title: title,
      titleEn: titleEn,
      sortOrder: sortOrder,
      chapterComplete: chapterComplete ?? this.chapterComplete,
      revisionComplete: revisionComplete ?? this.revisionComplete,
    );
  }
}
