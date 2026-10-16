import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'ai_coach.dart';
import 'db.dart';

const green = Color(0xFF72A83B), lime = Color(0xFFDDF0C5);

String tr(String en, String ar) => Store.lang.value == 'ar' ? ar : en;

double numVal(String s) =>
    double.tryParse(s.replaceAll(',', '.')) ?? 0;

Widget panel(Widget child, {Color color = Colors.white}) => Container(
  margin: const EdgeInsets.only(bottom: 12),
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(18),
  ),
  child: child,
);

String mealType(String s) =>
    {
      'breakfast': tr('Breakfast', 'فطار'),
      'lunch': tr('Lunch', 'غداء'),
      'dinner': tr('Dinner', 'عشاء'),
    }[s] ??
    tr('Snack', 'سناك');

class Root extends StatefulWidget {
  const Root({super.key});

  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  int index = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr('Nutrition Coach', 'مدرب التغذية'))),
    body: IndexedStack(
      index: index,
      children: const [
        HomePage(),
        ProgressPage(),
        CoachPage(),
        SettingsPage(),
      ],
    ),
    floatingActionButton: FloatingActionButton(
      backgroundColor: green,
      onPressed: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => const MealEditor(),
      ),
      child: const Icon(Icons.add, color: Colors.white),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: index,
      onDestinationSelected: (v) => setState(() => index = v),
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.restaurant),
          label: tr('Today', 'اليوم'),
        ),
        NavigationDestination(
          icon: const Icon(Icons.insights),
          label: tr('Progress', 'التقدم'),
        ),
        NavigationDestination(
          icon: const Icon(Icons.auto_awesome),
          label: tr('AI Coach', 'الكوتش'),
        ),
        NavigationDestination(
          icon: const Icon(Icons.settings),
          label: tr('Settings', 'الإعدادات'),
        ),
      ],
    ),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime day = DateTime.now();

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<int>(
        valueListenable: Store.tick,
        builder: (_, __, ___) => FutureBuilder<List<dynamic>>(
          future: Future.wait([Store.meals(day), Store.streak()]),
          builder: (context, snap) {
            final meals =
                (snap.data?[0] as List?)?.cast<MealRow>() ??
                <MealRow>[];
            final streak = (snap.data?[1] as int?) ?? 0;
            final goals = Store.plan();

            double sum(String k) => meals.fold(
              0.0,
              (a, m) => a + ((m[k] as num?)?.toDouble() ?? 0),
            );

            final kcal = sum('kcal');

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        DateFormat('EEE, d MMM yyyy').format(day),
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(
                        () => day = day.subtract(
                          const Duration(days: 1),
                        ),
                      ),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    IconButton(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: day,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) setState(() => day = d);
                      },
                      icon: const Icon(Icons.calendar_month),
                    ),
                    IconButton(
                      onPressed: () => setState(
                        () => day = day.add(const Duration(days: 1)),
                      ),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.local_fire_department,
                            color: green,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tr('Daily intake', 'المتناول اليومي'),
                            ),
                          ),
                          Chip(
                            label: Text(
                              tr(
                                '$streak-day streak',
                                'سلسلة $streak يوم',
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${kcal.round()} / ${goals['kcal']!.round()} kcal',
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: (kcal / goals['kcal']!)
                            .clamp(0, 1)
                            .toDouble(),
                        minHeight: 9,
                        color: green,
                        backgroundColor: lime,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        tr(
                          '${(goals['kcal']! - kcal).round()} kcal remaining',
                          'متبقي ${(goals['kcal']! - kcal).round()} سعرة',
                        ),
                      ),
                    ],
                  ),
                  color: lime,
                ),
                Row(
                  children: [
                    _macro(
                      tr('Protein', 'بروتين'),
                      sum('protein'),
                      goals['p']!,
                    ),
                    const SizedBox(width: 7),
                    _macro(
                      tr('Fat', 'دهون'),
                      sum('fat'),
                      goals['f']!,
                    ),
                    const SizedBox(width: 7),
                    _macro(
                      tr('Carbs', 'كارب'),
                      sum('carbs'),
                      goals['c']!,
                    ),
                  ],
                ),
                Text(
                  tr('Meals', 'الوجبات'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (meals.isEmpty)
                  panel(
                    Text(
                      tr(
                        'No meals logged for this date. Tap + to add one.',
                        'لا توجد وجبات في هذا اليوم. اضغط + للإضافة.',
                      ),
                    ),
                  ),
                for (final m in meals) _mealCard(context, m),
                panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('Coach tip', 'نصيحة الكوتش'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        Store.profile.isEmpty
                            ? tr(
                                'Fill in your profile to personalize targets.',
                                'أكمل بياناتك لتخصيص أهدافك.',
                              )
                            : kcal == 0
                                ? tr(
                                    'Log meals as you go; approximate portions are better than no record.',
                                    'سجل وجباتك أولًا بأول؛ التقدير أفضل من عدم التسجيل.',
                                  )
                                : sum('protein') < goals['p']! * .5
                                    ? tr(
                                        'Prioritize protein in your next meal: eggs, yogurt, beans, fish, chicken, or lentils.',
                                        'ركز على البروتين في الوجبة التالية: البيض أو الزبادي أو الفول أو السمك أو الفراخ أو العدس.',
                                      )
                                    : tr(
                                        'Include vegetables or fruit and high-fiber carbs with your protein source.',
                                        'أضف خضارًا أو فاكهة وكربوهيدرات غنية بالألياف بجانب البروتين.',
                                      ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

  Widget _macro(String label, double v, double target) =>
      Expanded(
        child: panel(
          Column(
            children: [
              Text(label, style: const TextStyle(fontSize: 12)),
              Text(
                '${v.round()} / ${target.round()} g',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: (v / target).clamp(0, 1).toDouble(),
                color: green,
                backgroundColor: lime,
              ),
            ],
          ),
        ),
      );

  Widget _mealCard(BuildContext context, MealRow m) => panel(
    Row(
      children: [
        if (m['photo'] is String &&
            File(m['photo'] as String).existsSync())
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              File(m['photo'] as String),
              width: 55,
              height: 55,
              fit: BoxFit.cover,
            ),
          )
        else
          const Icon(Icons.restaurant, color: green, size: 35),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${mealType(m['type'] as String)} · ${m['name']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '${(m['kcal'] as num).round()} kcal · '
                'P ${(m['protein'] as num).round()} · '
                'F ${(m['fat'] as num).round()} · '
                'C ${(m['carbs'] as num).round()}',
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                DateFormat('h:mm a').format(
                  DateTime.fromMillisecondsSinceEpoch(m['ts'] as int),
                ),
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => MealEditor(existing: m),
              );
            } else {
              Store.delMeal(m['id'] as int);
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'edit',
              child: Text(tr('Edit', 'تعديل')),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Text(tr('Delete', 'حذف')),
            ),
          ],
        ),
      ],
    ),
  );
}

class MealEditor extends StatefulWidget {
  final MealRow? existing;

  const MealEditor({super.key, this.existing});

  @override
  State<MealEditor> createState() => _MealEditorState();
}

class _MealEditorState extends State<MealEditor> {
  late String type = widget.existing?['type'] as String? ?? 'breakfast';

  late DateTime date = widget.existing?['ts'] is int
      ? DateTime.fromMillisecondsSinceEpoch(widget.existing!['ts'] as int)
      : DateTime.now();

  String? photo;
  File? image;
  bool busy = false;
  String status = '';

  late final name = TextEditingController(
    text: widget.existing?['name'] as String? ?? '',
  );

  final desc = TextEditingController();

  late final kcal = TextEditingController(
    text: '${widget.existing?['kcal'] ?? ''}',
  );

  late final protein = TextEditingController(
    text: '${widget.existing?['protein'] ?? ''}',
  );

  late final fat = TextEditingController(
    text: '${widget.existing?['fat'] ?? ''}',
  );

  late final carbs = TextEditingController(
    text: '${widget.existing?['carbs'] ?? ''}',
  );

  @override
  void initState() {
    super.initState();
    photo = widget.existing?['photo'] as String?;
    desc.text = widget.existing?['notes'] as String? ?? '';
  }

  Future<void> pick(ImageSource source) async {
    try {
      final x = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1280,
        imageQuality: 82,
      );

      if (x == null) return;

      final dir = await getApplicationDocumentsDirectory();
      final ext = p.extension(x.path).isEmpty ? '.jpg' : p.extension(x.path);
      final dest = p.join(
        dir.path,
        'meal_${DateTime.now().millisecondsSinceEpoch}$ext',
      );

      await File(x.path).copy(dest);

      if (mounted) {
        setState(() {
          photo = dest;
          image = File(dest);
        });
      }
    } catch (e) {
      if (mounted) setState(() => status = '$e');
    }
  }

  Future<void> estimate() async {
    if (AiCoach.key.isEmpty) {
      setState(
        () => status = tr(
          'Set Gemini API key in Settings first.',
          'أضف مفتاح Gemini من الإعدادات أولًا.',
        ),
      );
      return;
    }

    setState(() => busy = true);

    try {
      final r = await AiCoach.estimate(
        desc.text,
        image: image ??
            (photo != null && File(photo!).existsSync()
                ? File(photo!)
                : null),
      );

      if (mounted) {
        setState(() {
          name.text = '${r['name'] ?? ''}';
          kcal.text = '${r['kcal'] ?? 0}';
          protein.text = '${r['protein'] ?? 0}';
          fat.text = '${r['fat'] ?? 0}';
          carbs.text = '${r['carbs'] ?? 0}';
          status = '${r['note'] ?? ''}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => status = '$e'.replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      16,
      12,
      16,
      MediaQuery.of(context).viewInsets.bottom + 16,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.existing == null
                      ? tr('Add meal', 'إضافة وجبة')
                      : tr('Edit meal', 'تعديل الوجبة'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );

                  if (d != null) {
                    setState(
                      () => date = DateTime(
                        d.year,
                        d.month,
                        d.day,
                        date.hour,
                        date.minute,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.calendar_month),
              ),
            ],
          ),
          Text(DateFormat.yMMMd().format(date)),
          Wrap(
            spacing: 5,
            children: [
              for (final v in ['breakfast', 'lunch', 'dinner', 'snack'])
                ChoiceChip(
                  label: Text(mealType(v)),
                  selected: type == v,
                  onSelected: (_) => setState(() => type = v),
                ),
            ],
          ),
          TextField(
            controller: name,
            decoration: InputDecoration(
              labelText: tr('Meal name', 'اسم الوجبة'),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: desc,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: tr(
                'Food and portion details',
                'وصف الأكل والكميات',
              ),
              hintText: '2 eggs, bread, cheese',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: kcal,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'kcal'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: protein,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Protein g'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: fat,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Fat g'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: carbs,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Carbs g'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              OutlinedButton.icon(
                onPressed: () => pick(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: Text(tr('Camera', 'الكاميرا')),
              ),
              OutlinedButton.icon(
                onPressed: () => pick(ImageSource.gallery),
                icon: const Icon(Icons.photo),
                label: Text(tr('Gallery', 'المعرض')),
              ),
              FilledButton.tonalIcon(
                onPressed: busy ? null : estimate,
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(tr('AI estimate', 'تقدير ذكي')),
              ),
            ],
          ),
          if (photo != null && File(photo!).existsSync())
            Image.file(File(photo!), height: 90),
          if (status.isNotEmpty)
            Text(
              status,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) {
                  setState(
                    () => status = tr(
                      'Enter a meal name.',
                      'اكتب اسم الوجبة.',
                    ),
                  );
                  return;
                }

                final vals = [
                  numVal(kcal.text),
                  numVal(protein.text),
                  numVal(fat.text),
                  numVal(carbs.text),
                ];

                if (vals.any((v) => v < 0)) {
                  setState(
                    () => status = tr(
                      'Values cannot be negative.',
                      'القيم لا يمكن أن تكون سالبة.',
                    ),
                  );
                  return;
                }

                final row = <String, Object?>{
                  'ts': date.millisecondsSinceEpoch,
                  'type': type,
                  'name': name.text.trim(),
                  'kcal': vals[0],
                  'protein': vals[1],
                  'fat': vals[2],
                  'carbs': vals[3],
                  'photo': photo,
                  'notes': desc.text,
                };

                if (widget.existing == null) {
                  await Store.addMeal(row);
                } else {
                  await Store.updateMeal(
                    widget.existing!['id'] as int,
                    row,
                  );
                }

                if (context.mounted) Navigator.pop(context);
              },
              child: Text(tr('Save meal', 'حفظ الوجبة')),
            ),
          ),
        ],
      ),
    ),
  );

  @override
  void dispose() {
    name.dispose();
    desc.dispose();
    kcal.dispose();
    protein.dispose();
    fat.dispose();
    carbs.dispose();
    super.dispose();
  }
}

class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key});

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  int days = 7;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<int>(
        valueListenable: Store.tick,
        builder: (_, __, ___) => FutureBuilder<List<dynamic>>(
          future: Future.wait([
            Store.dailyKcal(days),
            Store.weights(),
          ]),
          builder: (context, s) {
            final values =
                (s.data?[0] as List?)?.cast<double>() ??
                List<double>.filled(days, 0);
            final weights =
                (s.data?[1] as List?)?.cast<MealRow>() ??
                <MealRow>[];
            final target = Store.plan()['kcal']!;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  tr('Progress', 'التقدم'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SegmentedButton<int>(
                  segments: [
                    ButtonSegment(
                      value: 7,
                      label: Text(tr('7 days', '٧ أيام')),
                    ),
                    ButtonSegment(
                      value: 30,
                      label: Text(tr('30 days', '٣٠ يومًا')),
                    ),
                  ],
                  selected: {days},
                  onSelectionChanged: (v) =>
                      setState(() => days = v.first),
                ),
                panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('Calories by day', 'السعرات حسب اليوم'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        tr(
                          'Target ${target.round()} kcal',
                          'الهدف ${target.round()} سعرة',
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 150,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (var i = 0; i < values.length; i++)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 1,
                                  ),
                                  child: Tooltip(
                                    message: '${values[i].round()} kcal',
                                    child: Container(
                                      height: 140 *
                                          (values[i] / target)
                                              .clamp(.02, 1)
                                              .toDouble(),
                                      decoration: BoxDecoration(
                                        color: i == values.length - 1
                                            ? green
                                            : lime,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr('Weight history', 'سجل الوزن'),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: addWeight,
                      icon: const Icon(Icons.add),
                      label: Text(tr('Add', 'إضافة')),
                    ),
                  ],
                ),
                if (weights.isEmpty)
                  panel(
                    Text(
                      tr(
                        'Add weigh-ins to see trends.',
                        'أضف وزنك لمتابعة التغير.',
                      ),
                    ),
                  ),
                for (final w in weights.take(20))
                  panel(
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            DateFormat.yMMMd().format(
                              DateTime.fromMillisecondsSinceEpoch(
                                w['ts'] as int,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          '${(w['kg'] as num).toStringAsFixed(1)} kg',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      );

  Future<void> addWeight() async {
    final c = TextEditingController();

    final v = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Add weight', 'إضافة الوزن')),
        content: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('Cancel', 'إلغاء')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, numVal(c.text)),
            child: Text(tr('Save', 'حفظ')),
          ),
        ],
      ),
    );

    c.dispose();

    if (v != null && v > 0) await Store.addWeight(v);
  }
}

class CoachPage extends StatefulWidget {
  const CoachPage({super.key});

  @override
  State<CoachPage> createState() => _CoachPageState();
}

class _CoachPageState extends State<CoachPage> {
  bool busy = false;
  String plan = '', answer = '';
  final q = TextEditingController();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text(
        tr('Your AI nutrition coach', 'كوتش التغذية الذكي'),
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr(
                'Calculated daily targets',
                'الأهداف اليومية المحسوبة',
              ),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              '${Store.plan()['kcal']!.round()} kcal · '
              'P ${Store.plan()['p']!.round()}g · '
              'F ${Store.plan()['f']!.round()}g · '
              'C ${Store.plan()['c']!.round()}g',
            ),
            Text(
              tr(
                'AI plan and chat require a Gemini API key in Settings. Local targets and tips work offline.',
                'الخطة والشات يحتاجان مفتاح Gemini في الإعدادات. الأهداف والنصائح المحلية تعمل دون إنترنت.',
              ),
            ),
          ],
        ),
        color: lime,
      ),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: busy ? null : makePlan,
          icon: const Icon(Icons.calendar_month),
          label: Text(
            tr('Create 7-day meal plan', 'إنشاء نظام غذائي لأسبوع'),
          ),
        ),
      ),
      if (plan.isNotEmpty)
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('Meal plan', 'الخطة الغذائية'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              SelectableText(pretty(plan)),
              TextButton.icon(
                onPressed: () => Clipboard.setData(
                  ClipboardData(text: plan),
                ),
                icon: const Icon(Icons.copy),
                label: Text(tr('Copy', 'نسخ')),
              ),
            ],
          ),
        ),
      const SizedBox(height: 12),
      Text(
        tr('Ask your coach', 'اسأل الكوتش'),
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      TextField(
        controller: q,
        minLines: 2,
        maxLines: 4,
        decoration: InputDecoration(
          hintText: tr(
            'What can I eat to reach my protein goal?',
            'آكل إيه عشان أكمل البروتين؟',
          ),
        ),
      ),
      FilledButton.icon(
        onPressed: busy ? null : ask,
        icon: const Icon(Icons.send),
        label: Text(tr('Ask', 'اسأل')),
      ),
      if (answer.isNotEmpty) panel(SelectableText(answer)),
      Text(
        tr(
          'Nutrition estimates are approximate and do not replace medical advice.',
          'التقديرات تقريبية ولا تغني عن نصيحة المختص.',
        ),
        style: const TextStyle(
          fontSize: 12,
          color: Colors.grey,
        ),
      ),
    ],
  );

  String pretty(String raw) {
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final b = StringBuffer(
        '${j['title'] ?? '7-day plan'}\n${j['guidance'] ?? ''}\n',
      );

      for (final d in (j['days'] as List? ?? [])) {
        b.writeln('\n${d['day']}');

        for (final m in (d['meals'] as List? ?? [])) {
          b.writeln(
            '• ${m['type']}: ${m['name']} '
            '(${m['portion'] ?? ''}) - ${m['kcal'] ?? '?'} kcal',
          );
        }
      }

      if (j['shopping_list'] is List) {
        b.writeln(
          '\nShopping list: ${(j['shopping_list'] as List).join(', ')}',
        );
      }

      return b.toString();
    } catch (_) {
      return raw;
    }
  }

  Future<void> makePlan() async {
    setState(() => busy = true);

    try {
      final v = await AiCoach.weeklyPlan();
      if (mounted) setState(() => plan = v);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$e'.replaceFirst('Exception: ', ''),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> ask() async {
    if (q.text.trim().isEmpty) return;

    setState(() => busy = true);

    try {
      final v = await AiCoach.chat(q.text.trim());
      if (mounted) setState(() => answer = v);
    } catch (e) {
      if (mounted) {
        setState(
          () => answer = '$e'.replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    q.dispose();
    super.dispose();
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late String sex = Store.profile['sex'] ?? 'm';
  late String act = Store.profile['act'] ?? 'mid';
  late String goal = Store.profile['goal'] ?? 'lose';

  late final age = TextEditingController(
    text: '${Store.profile['age'] ?? ''}',
  );
  late final height = TextEditingController(
    text: '${Store.profile['height'] ?? ''}',
  );
  late final weight = TextEditingController(
    text: '${Store.profile['weight'] ?? ''}',
  );
  late final target = TextEditingController(
    text: '${Store.profile['target'] ?? ''}',
  );
  late final key = TextEditingController(
    text: '${Store.settings['geminiApiKey'] ?? ''}',
  );

  bool reveal = false;
  String status = '';

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text(
        tr('Profile & goals', 'البيانات والأهداف'),
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('Language', 'اللغة')),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'en',
                  label: Text('English'),
                ),
                ButtonSegment(
                  value: 'ar',
                  label: Text('العربية'),
                ),
              ],
              selected: {Store.lang.value},
              onSelectionChanged: (v) => Store.setLang(v.first),
            ),
            const SizedBox(height: 10),
            Text(tr('Sex', 'النوع')),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'm',
                  label: Text(tr('Male', 'ذكر')),
                ),
                ButtonSegment(
                  value: 'f',
                  label: Text(tr('Female', 'أنثى')),
                ),
              ],
              selected: {sex},
              onSelectionChanged: (v) => setState(() => sex = v.first),
            ),
            const SizedBox(height: 8),
            field(age, tr('Age (18+)', 'العمر (١٨+)')),
            const SizedBox(height: 8),
            field(height, tr('Height cm', 'الطول سم')),
            const SizedBox(height: 8),
            field(weight, tr('Weight kg', 'الوزن كجم')),
            const SizedBox(height: 8),
            field(
              target,
              tr('Target weight kg (optional)', 'الوزن المستهدف اختياري'),
            ),
            const SizedBox(height: 8),
            Text(tr('Activity', 'النشاط')),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'low',
                  label: Text(tr('Low', 'قليل')),
                ),
                ButtonSegment(
                  value: 'mid',
                  label: Text(tr('Moderate', 'متوسط')),
                ),
                ButtonSegment(
                  value: 'high',
                  label: Text(tr('High', 'مرتفع')),
                ),
              ],
              selected: {act},
              onSelectionChanged: (v) => setState(() => act = v.first),
            ),
            const SizedBox(height: 8),
            Text(tr('Goal', 'الهدف')),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'lose',
                  label: Text(tr('Lose fat', 'خسارة دهون')),
                ),
                ButtonSegment(
                  value: 'maintain',
                  label: Text(tr('Maintain', 'ثبات')),
                ),
                ButtonSegment(
                  value: 'gain',
                  label: Text(tr('Gain muscle', 'زيادة عضلات')),
                ),
              ],
              selected: {goal},
              onSelectionChanged: (v) => setState(() => goal = v.first),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: saveProfile,
              child: Text(tr('Save profile', 'حفظ البيانات')),
            ),
            Text(
              '${Store.plan()['kcal']!.round()} kcal · '
              'P ${Store.plan()['p']!.round()}g · '
              'F ${Store.plan()['f']!.round()}g · '
              'C ${Store.plan()['c']!.round()}g',
            ),
          ],
        ),
      ),
      Text(
        tr('Gemini AI setup', 'إعداد Gemini AI'),
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: key,
              obscureText: !reveal,
              decoration: InputDecoration(
                labelText: 'Gemini API key',
                suffixIcon: IconButton(
                  onPressed: () => setState(() => reveal = !reveal),
                  icon: Icon(
                    reveal ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
            ),
            Text(
              tr(
                'Create a key in Google AI Studio. Saved locally on this device. Do not commit keys to GitHub. Provider quotas or charges may apply.',
                'أنشئ المفتاح من Google AI Studio. يُحفظ على الجهاز فقط. لا ترفع المفاتيح إلى GitHub. قد توجد حدود استخدام أو رسوم.',
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: saveKey,
                  child: Text(tr('Save key', 'حفظ المفتاح')),
                ),
                OutlinedButton(
                  onPressed: () => setState(() => key.clear()),
                  child: Text(tr('Clear field', 'مسح الحقل')),
                ),
              ],
            ),
            if (status.isNotEmpty) Text(status),
          ],
        ),
      ),
      Text(
        tr('Backup', 'نسخة احتياطية'),
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      panel(
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: exportData,
              child: Text(tr('Copy backup', 'نسخ احتياطي')),
            ),
            OutlinedButton(
              onPressed: importData,
              child: Text(tr('Restore backup', 'استعادة')),
            ),
          ],
        ),
      ),
      Text(
        tr(
          'For adults only. Targets are estimates, not medical advice. Consult a qualified professional for medical conditions.',
          'للبالغين فقط. الأهداف تقديرية وليست نصيحة طبية. استشر مختصًا للحالات الطبية.',
        ),
        style: const TextStyle(
          fontSize: 12,
          color: Colors.grey,
        ),
      ),
    ],
  );

  Widget field(TextEditingController c, String label) => TextField(
    controller: c,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label),
  );

  Future<void> saveProfile() async {
    final a = numVal(age.text);
    final h = numVal(height.text);
    final w = numVal(weight.text);
    final tw = numVal(target.text);

    if (a < 18 ||
        a > 100 ||
        h < 100 ||
        h > 250 ||
        w < 25 ||
        w > 350 ||
        (target.text.trim().isNotEmpty && (tw < 25 || tw > 350))) {
      setState(
        () => status = tr(
          'Check your entries; planner is for adults.',
          'راجع البيانات؛ المخطط مخصص للبالغين.',
        ),
      );
      return;
    }

    await Store.saveProfile({
      'sex': sex,
      'act': act,
      'goal': goal,
      'age': a,
      'height': h,
      'weight': w,
      if (tw > 0) 'target': tw,
    });

    if (mounted) {
      setState(
        () => status = tr('Profile saved', 'تم حفظ البيانات'),
      );
    }
  }

  Future<void> saveKey() async {
    await Store.saveSettings({'geminiApiKey': key.text.trim()});

    if (mounted) {
      setState(
        () => status = tr(
          'Settings saved locally',
          'تم الحفظ على الجهاز',
        ),
      );
    }
  }

  Future<void> exportData() async {
    await Clipboard.setData(
      ClipboardData(text: await Store.exportJson()),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('Backup copied', 'تم نسخ النسخة الاحتياطية')),
        ),
      );
    }
  }

  Future<void> importData() async {
    final d = await Clipboard.getData('text/plain');
    final ok = await Store.importJson(d?.text ?? '');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok ? tr('Restored', 'تم الاسترجاع') : tr('Invalid backup', 'نسخة غير صالحة'),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    age.dispose();
    height.dispose();
    weight.dispose();
    target.dispose();
    key.dispose();
    super.dispose();
  }
}
