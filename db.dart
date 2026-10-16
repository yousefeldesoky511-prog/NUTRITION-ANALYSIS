import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

typedef MealRow = Map<String, Object?>;

class Store {
  static late Database db;
  static final lang = ValueNotifier<String>('en');
  static final tick = ValueNotifier<int>(0);
  static Map<String, dynamic> profile = {};
  static Map<String, dynamic> settings = {};

  static Future<void> init() async {
    db = await openDatabase(p.join(await getDatabasesPath(), 'nutrition_coach.db'), version: 2,
      onCreate: (d, v) async {
        await d.execute('CREATE TABLE meals(id INTEGER PRIMARY KEY AUTOINCREMENT, ts INTEGER NOT NULL, type TEXT NOT NULL, name TEXT NOT NULL, kcal REAL NOT NULL, protein REAL NOT NULL, fat REAL NOT NULL, carbs REAL NOT NULL, photo TEXT, notes TEXT)');
        await d.execute('CREATE TABLE weights(id INTEGER PRIMARY KEY AUTOINCREMENT, ts INTEGER NOT NULL, kg REAL NOT NULL)');
        await d.execute('CREATE TABLE kv(k TEXT PRIMARY KEY, v TEXT NOT NULL)');
      },
      onUpgrade: (d, old, v) async {
        if (old < 2) {
          final cols = (await d.rawQuery('PRAGMA table_info(meals)')).map((r) => r['name']).toSet();
          if (!cols.contains('notes')) await d.execute('ALTER TABLE meals ADD COLUMN notes TEXT');
        }
      });
    profile = _map(await _get('profile'));
    settings = _map(await _get('settings'));
    lang.value = await _get('lang') ?? 'en';
  }
  static Map<String, dynamic> _map(String? s) { try { return s == null ? {} : Map<String, dynamic>.from(jsonDecode(s) as Map); } catch (_) { return {}; } }
  static Future<String?> _get(String k) async { final r = await db.query('kv', where: 'k=?', whereArgs: [k], limit: 1); return r.isEmpty ? null : r.first['v'] as String?; }
  static Future<void> _set(String k, String v) async { await db.insert('kv', {'k': k, 'v': v}, conflictAlgorithm: ConflictAlgorithm.replace); }
  static void bump() => tick.value++;
  static Future<void> setLang(String v) async { await _set('lang', v); lang.value = v; bump(); }
  static Future<void> saveSettings(Map<String, dynamic> v) async { settings = {...settings, ...v}; await _set('settings', jsonEncode(settings)); bump(); }
  static Future<void> saveProfile(Map<String, dynamic> v) async { profile = {...profile, ...v}; await _set('profile', jsonEncode(profile)); if (v['weight'] is num) await addWeight((v['weight'] as num).toDouble()); bump(); }
  static Future<int> addMeal(MealRow v) async { final id = await db.insert('meals', v); bump(); return id; }
  static Future<void> updateMeal(int id, MealRow v) async { await db.update('meals', v, where: 'id=?', whereArgs: [id]); bump(); }
  static Future<void> delMeal(int id) async { await db.delete('meals', where: 'id=?', whereArgs: [id]); bump(); }
  static int start(DateTime d) => DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
  static Future<List<MealRow>> meals(DateTime d) => db.query('meals', where: 'ts>=? AND ts<?', whereArgs: [start(d), start(d.add(const Duration(days: 1)))], orderBy: 'ts DESC');
  static Future<List<double>> dailyKcal(int days) async { final out = <double>[]; final now = DateTime.now(); for (var i = days - 1; i >= 0; i--) { final d = now.subtract(Duration(days: i)); final r = await db.rawQuery('SELECT SUM(kcal) AS n FROM meals WHERE ts>=? AND ts<?', [start(d), start(d.add(const Duration(days: 1)))]); out.add((r.first['n'] as num?)?.toDouble() ?? 0); } return out; }
  static Future<void> addWeight(double kg) async { await db.insert('weights', {'ts': DateTime.now().millisecondsSinceEpoch, 'kg': kg}); bump(); }
  static Future<List<MealRow>> weights() => db.query('weights', orderBy: 'ts DESC', limit: 40);
  static Map<String, double> plan() {
    final age = (profile['age'] as num?)?.toDouble(), h = (profile['height'] as num?)?.toDouble(), w = (profile['weight'] as num?)?.toDouble();
    if (age == null || h == null || w == null || age <= 0 || h <= 0 || w <= 0) return {'ideal': 0, 'kcal': 2000, 'p': 125, 'f': 65, 'c': 240};
    final male = (profile['sex'] ?? 'm') == 'm';
    final activity = switch (profile['act'] ?? 'mid') { 'low' => 1.2, 'high' => 1.725, _ => 1.45 };
    final ideal = 22 * (h / 100) * (h / 100); final bmr = 10*w + 6.25*h - 5*age + (male ? 5 : -161); final tdee = bmr * activity;
    final goal = (profile['goal'] ?? 'lose').toString();
    final kcal = (goal == 'gain' ? tdee + 250 : goal == 'maintain' ? tdee : tdee - 350).clamp(male ? 1500 : 1200, 5000).toDouble();
    final protein = w * (goal == 'gain' ? 1.8 : 1.6); final fat = (kcal * .27 / 9).clamp(40, 150).toDouble(); final carbs = ((kcal - protein*4 - fat*9) / 4).clamp(0, 1000).toDouble();
    return {'ideal': ideal, 'kcal': kcal.roundToDouble(), 'p': protein.roundToDouble(), 'f': fat.roundToDouble(), 'c': carbs.roundToDouble()};
  }
  static Future<int> streak() async { final rows = await db.rawQuery('SELECT DISTINCT ts FROM meals'); final dates = rows.map((r) { final d = DateTime.fromMillisecondsSinceEpoch(r['ts'] as int); return '${d.year}-${d.month}-${d.day}'; }).toSet(); var d = DateTime.now(); var count = 0; while (dates.contains('${d.year}-${d.month}-${d.day}')) { count++; d = d.subtract(const Duration(days: 1)); } return count; }
  static Future<String> exportJson() async => jsonEncode({'profile': profile, 'settings': settings, 'lang': lang.value, 'meals': await db.query('meals'), 'weights': await db.query('weights')});
  static Future<bool> importJson(String s) async { try { final m = jsonDecode(s) as Map<String, dynamic>; await db.transaction((t) async { await t.delete('meals'); await t.delete('weights'); for (final r in (m['meals'] as List? ?? [])) { final row = Map<String, Object?>.from(r as Map)..remove('id'); await t.insert('meals', row); } for (final r in (m['weights'] as List? ?? [])) { final row = Map<String, Object?>.from(r as Map)..remove('id'); await t.insert('weights', row); } }); profile = Map<String, dynamic>.from(m['profile'] as Map? ?? {}); settings = Map<String, dynamic>.from(m['settings'] as Map? ?? {}); await _set('profile', jsonEncode(profile)); await _set('settings', jsonEncode(settings)); if (m['lang'] is String) await setLang(m['lang'] as String); bump(); return true; } catch (_) { return false; } }
}
