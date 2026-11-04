import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  await DB.init();
  runApp(const App());
}

const bg = Color(0xFF101A2B);
const card = Color(0xFF18263A);
const teal = Color(0xFF21C7B7);
const gold = Color(0xFFFFB547);

class DB {
  static late Database db;

  static Future<void> init() async {
    final dir = Directory(
      '${Platform.environment['APPDATA'] ?? Directory.current.path}\\EngineTestManager'
    );
    await dir.create(recursive: true);

    db = await openDatabase(
      p.join(dir.path, 'engine_records.db'),
      version: 1,
      onCreate: (d, v) async {
        await d.execute('''
          CREATE TABLE engines(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            engine TEXT,
            result TEXT,
            errors TEXT,
            operator TEXT,
            notes TEXT,
            date TEXT
          )
        ''');
      },
    );
  }

  static Future<List<Map<String, Object?>>> all() =>
      db.query('engines', orderBy: 'id DESC');

  static Future<void> save(Map<String, Object?> data, [int? id]) async {
    if (id == null) {
      await db.insert('engines', data);
    } else {
      await db.update('engines', data, where: 'id=?', whereArgs: [id]);
    }
  }

  static Future<void> delete(int id) async {
    await db.delete('engines', where: 'id=?', whereArgs: [id]);
  }
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Engine Test Manager',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(primary: teal),
        useMaterial3: true,
      ),
      home: const Home(),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<Map<String, Object?>> records = [];
  String search = '';

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final data = await DB.all();
    if (mounted) setState(() => records = data);
  }

  int count(String value) =>
      records.where((r) => r['result'] == value).length;

  @override
  Widget build(BuildContext context) {
    final shown = records.where((r) =>
      (r['engine'] as String).contains(search)).toList();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.precision_manufacturing,
                      color: teal, size: 38),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ENGINE TEST MANAGER',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                        Text('سیستم مدیریت تست موتور',
                          style: TextStyle(color: gold)),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => openForm(),
                    icon: const Icon(Icons.add),
                    label: const Text('ثبت موتور جدید'),
                  ),
                ],
              ),
              const SizedBox(height: 25),

              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  stat('کل موتورها', records.length, teal),
                  stat('سالم', count('سالم'), Colors.green),
                  stat('مردود', count('مردود'), Colors.redAccent),
                  stat('نیازمند بررسی',
                      count('نیازمند بررسی'), gold),
                  stat('در انتظار', count('در انتظار'),
                      Colors.purpleAccent),
                ],
              ),

              const SizedBox(height: 25),
              const Text('سوابق تست موتور',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              TextField(
                onChanged: (v) => setState(() => search = v),
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: card,
                  prefixIcon: Icon(Icons.search),
                  hintText: 'جستجوی شماره موتور',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),

              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: shown.isEmpty
                    ? const Center(
                        child: Text('هنوز موتوری ثبت نشده است'))
                    : ListView.separated(
                        itemCount: shown.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final r = shown[i];
                          return ListTile(
                            title: Text(
                              'موتور: ${r['engine']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              '${r['result']}  |  ${r['errors']}'
                              '\n${r['operator']}  |  ${r['date']}'),
                            isThreeLine: true,
                            leading: CircleAvatar(
                              backgroundColor: teal.withOpacity(.15),
                              child: Text('${r['id']}',
                                style: const TextStyle(color: teal)),
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) async {
                                if (v == 'edit') {
                                  openForm(r);
                                } else {
                                  final yes =
                                    await showDialog<bool>(
                                      context: context,
                                      builder: (c) => AlertDialog(
                                        title: const Text('حذف موتور'),
                                        content: const Text(
                                          'آیا از حذف این رکورد مطمئن هستید؟'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                              Navigator.pop(c, false),
                                            child: const Text('انصراف')),
                                          FilledButton(
                                            onPressed: () =>
                                              Navigator.pop(c, true),
                                            child: const Text('حذف')),
                                        ],
                                      ),
                                    );
                                  if (yes == true) {
                                    await DB.delete(r['id'] as int);
                                    refresh();
                                  }
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('ویرایش')),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('حذف')),
                              ],
                            ),
                          );
                        },
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget stat(String title, int number, Color color) {
    return Container(
      width: 155,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$number',
            style: TextStyle(
              fontSize: 27,
              color: color,
              fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(title, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> openForm([Map<String, Object?>? old]) async {
    final engine = TextEditingController(
      text: old?['engine'] as String? ?? '');
    final operator = TextEditingController(
      text: old?['operator'] as String? ?? '');
    final notes = TextEditingController(
      text: old?['notes'] as String? ?? '');

    String result = old?['result'] as String? ?? 'در انتظار';
    final errors = <String>{
      if ((old?['errors'] as String? ?? '').isNotEmpty)
        ...(old!['errors'] as String).split('، ')
    };

    final options = [
      'سنسور', 'کویل', 'شمع', 'فشار روغن',
      'سوخت‌رسانی', 'صدای غیرعادی', 'سایر'
    ];

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          backgroundColor: card,
          title: const Text('ثبت اطلاعات موتور'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('شماره موتور'),
                  const SizedBox(height: 7),
                  TextField(
                    controller: engine,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'شماره موتور یا اسکن بارکد')),
                  const SizedBox(height: 18),
                  const Text('نتیجه تست'),
                  Wrap(
                    spacing: 7,
                    children: [
                      for (final v in [
                        'در انتظار', 'سالم', 'مردود', 'نیازمند بررسی'
                      ])
                        ChoiceChip(
                          label: Text(v),
                          selected: result == v,
                          onSelected: (_) =>
                            update(() => result = v),
                        ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  const Text('نوع خطا'),
                  Wrap(
                    spacing: 5,
                    children: [
                      for (final v in options)
                        FilterChip(
                          label: Text(v),
                          selected: errors.contains(v),
                          onSelected: (yes) => update(() {
                            yes ? errors.add(v) : errors.remove(v);
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  const Text('نام اپراتور'),
                  TextField(controller: operator),
                  const SizedBox(height: 15),
                  const Text('توضیحات'),
                  TextField(
                    controller: notes,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'توضیحات تکمیلی'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف')),
            FilledButton(
              onPressed: () async {
                if (engine.text.trim().isEmpty) return;

                if (old == null) {
                  final duplicate = await DB.db.query(
                    'engines',
                    where: 'engine=?',
                    whereArgs: [engine.text.trim()],
                  );

                  if (duplicate.isNotEmpty && ctx.mounted) {
                    final yes = await showDialog<bool>(
                      context: ctx,
                      builder: (c) => AlertDialog(
                        title: const Text('شماره تکراری'),
                        content: const Text(
                          'این موتور قبلاً ثبت شده است. تست مجدد ثبت شود؟'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('انصراف')),
                          FilledButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('ثبت مجدد')),
                        ],
                      ),
                    );
                    if (yes != true) return;
                  }
                }

                final date = old?['date'] as String? ??
                  DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

                await DB.save({
                  'engine': engine.text.trim(),
                  'result': result,
                  'errors': errors.join('، '),
                  'operator': operator.text.trim(),
                  'notes': notes.text.trim(),
                  'date': date,
                }, old?['id'] as int?);

                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: const Text('ذخیره'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) refresh();
  }
}
