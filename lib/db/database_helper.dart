import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../data/seed_data.dart';
import '../models/subject.dart';
import '../models/chapter.dart';
import '../models/study_session.dart';
import '../models/routine_task.dart';
import '../models/task_completion.dart';

class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'hsc_study_app.db');
    return openDatabase(
      path,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createRoutineTables(db);
    }
    if (oldVersion < 3) {
      await db.execute('DROP TABLE IF EXISTS task_completions');
      await db.execute('DROP TABLE IF EXISTS routine_tasks');
      await _createRoutineTables(db);
      await db.execute('ALTER TABLE study_sessions ADD COLUMN chapterId INTEGER');
      await db.execute('ALTER TABLE study_sessions ADD COLUMN chapterTitle TEXT');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE chapters ADD COLUMN titleEn TEXT');
      await db.execute('ALTER TABLE study_sessions ADD COLUMN chapterTitleEn TEXT');
      await db.execute('ALTER TABLE study_sessions ADD COLUMN sessionType INTEGER DEFAULT 0');
      await _populateEnglishChapterTitles(db);
    }
    if (oldVersion < 5) {
      // The subject catalog expanded from HSC-Science-only (13 subjects) to
      // SSC + all three HSC groups (42 subjects), and every subject now
      // carries a level/group tag used to filter which subjects show for
      // the user's chosen class+group. Matching old subjects one-by-one
      // into the new catalog isn't reliable, so this is a clean re-seed --
      // chapter tick progress and study session history reset with this
      // update (the app is still early / actively changing shape).
      await db.execute('DROP TABLE IF EXISTS study_sessions');
      await db.execute('DROP TABLE IF EXISTS chapters');
      await db.execute('DROP TABLE IF EXISTS subjects');
      await _createCoreTables(db);
      await _seedSubjects(db);
      // Existing routine_tasks table (created before this version) needs
      // the new optional time-of-day column added in place.
      final cols = await db.rawQuery('PRAGMA table_info(routine_tasks)');
      final hasTimeOfDay = cols.any((c) => c['name'] == 'timeOfDay');
      if (!hasTimeOfDay) {
        await db.execute('ALTER TABLE routine_tasks ADD COLUMN timeOfDay TEXT');
      }
    }
  }

  Future<void> _populateEnglishChapterTitles(Database db) async {
    final subjectRows = await db.query('subjects');
    for (final row in subjectRows) {
      final nameBn = row['nameBn'] as String;
      final subjectId = row['id'] as int;
      final seed = kSeedSubjects.where((s) => s.nameBn == nameBn);
      if (seed.isEmpty) continue;
      final chapters = seed.first.chapters;
      final chapterRows = await db.query(
        'chapters',
        where: 'subjectId = ?',
        whereArgs: [subjectId],
        orderBy: 'sortOrder ASC',
      );
      for (final cRow in chapterRows) {
        final order = cRow['sortOrder'] as int;
        if (order >= 0 && order < chapters.length) {
          await db.update(
            'chapters',
            {'titleEn': chapters[order].en},
            where: 'id = ?',
            whereArgs: [cRow['id']],
          );
        }
      }
    }
  }

  Future<void> _createRoutineTables(Database db) async {
    await db.execute('''
      CREATE TABLE routine_tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        sortOrder INTEGER NOT NULL,
        weekdayGroup INTEGER NOT NULL,
        timeOfDay TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE task_completions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        taskId INTEGER NOT NULL,
        date TEXT NOT NULL,
        status INTEGER NOT NULL,
        UNIQUE(taskId, date),
        FOREIGN KEY (taskId) REFERENCES routine_tasks (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createCoreTables(Database db) async {
    await db.execute('''
      CREATE TABLE subjects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nameBn TEXT NOT NULL,
        nameEn TEXT NOT NULL,
        colorValue INTEGER NOT NULL,
        sortOrder INTEGER NOT NULL,
        level INTEGER NOT NULL,
        subjectGroup INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE chapters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subjectId INTEGER NOT NULL,
        title TEXT NOT NULL,
        titleEn TEXT,
        sortOrder INTEGER NOT NULL,
        chapterComplete INTEGER NOT NULL DEFAULT 0,
        revisionComplete INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (subjectId) REFERENCES subjects (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE study_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subjectId INTEGER NOT NULL,
        chapterId INTEGER,
        chapterTitle TEXT,
        chapterTitleEn TEXT,
        sessionType INTEGER DEFAULT 0,
        durationSeconds INTEGER NOT NULL,
        startedAt TEXT NOT NULL,
        FOREIGN KEY (subjectId) REFERENCES subjects (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _seedSubjects(Database db) async {
    for (int i = 0; i < kSeedSubjects.length; i++) {
      final s = kSeedSubjects[i];
      final subjectId = await db.insert('subjects', {
        'nameBn': s.nameBn,
        'nameEn': s.nameEn,
        'colorValue': s.colorValue,
        'sortOrder': i,
        'level': s.level.index,
        'subjectGroup': s.group.index,
      });
      for (int j = 0; j < s.chapters.length; j++) {
        await db.insert('chapters', {
          'subjectId': subjectId,
          'title': s.chapters[j].bn,
          'titleEn': s.chapters[j].en,
          'sortOrder': j,
          'chapterComplete': 0,
          'revisionComplete': 0,
        });
      }
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createCoreTables(db);
    await _createRoutineTables(db);
    await _seedSubjects(db);
  }

  // ---------- Subjects ----------

  Future<List<Subject>> getSubjects() async {
    final db = await database;
    final rows = await db.query('subjects', orderBy: 'sortOrder ASC');
    return rows.map((r) => Subject.fromMap(r)).toList();
  }

  // ---------- Chapters ----------

  Future<List<Chapter>> getChaptersForSubject(int subjectId) async {
    final db = await database;
    final rows = await db.query(
      'chapters',
      where: 'subjectId = ?',
      whereArgs: [subjectId],
      orderBy: 'sortOrder ASC',
    );
    return rows.map((r) => Chapter.fromMap(r)).toList();
  }

  Future<void> updateChapterProgress(
    int chapterId, {
    bool? chapterComplete,
    bool? revisionComplete,
  }) async {
    final db = await database;
    final Map<String, dynamic> values = {};
    if (chapterComplete != null) {
      values['chapterComplete'] = chapterComplete ? 1 : 0;
    }
    if (revisionComplete != null) {
      values['revisionComplete'] = revisionComplete ? 1 : 0;
    }
    if (values.isEmpty) return;
    await db.update('chapters', values, where: 'id = ?', whereArgs: [chapterId]);
  }

  // ---------- Study sessions ----------

  Future<int> insertSession(StudySession session) async {
    final db = await database;
    return db.insert('study_sessions', session.toMap());
  }

  Future<List<StudySession>> getAllSessions() async {
    final db = await database;
    final rows = await db.query('study_sessions', orderBy: 'startedAt DESC');
    return rows.map((r) => StudySession.fromMap(r)).toList();
  }

  Future<List<StudySession>> getSessionsSince(DateTime since) async {
    final db = await database;
    final rows = await db.query(
      'study_sessions',
      where: 'startedAt >= ?',
      whereArgs: [since.toIso8601String()],
      orderBy: 'startedAt ASC',
    );
    return rows.map((r) => StudySession.fromMap(r)).toList();
  }

  // ---------- Routine tasks ----------

  Future<int> insertRoutineTask(RoutineTask task) async {
    final db = await database;
    return db.insert('routine_tasks', task.toMap()..remove('id'));
  }

  Future<void> deleteRoutineTask(int taskId) async {
    final db = await database;
    await db.delete('task_completions', where: 'taskId = ?', whereArgs: [taskId]);
    await db.delete('routine_tasks', where: 'id = ?', whereArgs: [taskId]);
  }

  Future<List<RoutineTask>> getTasksForGroup(int groupIndex) async {
    final db = await database;
    final rows = await db.query(
      'routine_tasks',
      where: 'weekdayGroup = ?',
      whereArgs: [groupIndex],
      orderBy: 'sortOrder ASC',
    );
    return rows.map((r) => RoutineTask.fromMap(r)).toList();
  }

  Future<List<RoutineTask>> getAllRoutineTasks() async {
    final db = await database;
    final rows = await db.query('routine_tasks', orderBy: 'sortOrder ASC');
    return rows.map((r) => RoutineTask.fromMap(r)).toList();
  }

  // ---------- Task completions ----------

  Future<Map<int, TaskStatus>> getCompletionsForDate(String date) async {
    final db = await database;
    final rows = await db.query('task_completions', where: 'date = ?', whereArgs: [date]);
    final map = <int, TaskStatus>{};
    for (final r in rows) {
      final c = TaskCompletion.fromMap(r);
      map[c.taskId] = c.status;
    }
    return map;
  }

  Future<List<TaskCompletion>> getCompletionsSince(String sinceDate) async {
    final db = await database;
    final rows = await db.query(
      'task_completions',
      where: 'date >= ?',
      whereArgs: [sinceDate],
    );
    return rows.map((r) => TaskCompletion.fromMap(r)).toList();
  }

  Future<void> setTaskStatus(int taskId, String date, TaskStatus status) async {
    final db = await database;
    if (status == TaskStatus.pending) {
      await db.delete(
        'task_completions',
        where: 'taskId = ? AND date = ?',
        whereArgs: [taskId, date],
      );
      return;
    }
    final completion = TaskCompletion(taskId: taskId, date: date, status: status);
    await db.insert(
      'task_completions',
      completion.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
