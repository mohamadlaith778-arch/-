import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/task.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  Database? _db;
  List<Task> _tasks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initDb();
  }

  Future<void> _initDb() async {
    final path = join(await getDatabasesPath(), 'tasks.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tasks(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            description TEXT,
            priority INTEGER DEFAULT 2,
            isDone INTEGER DEFAULT 0
          )
        ''');
      },
    );
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final maps = await _db!.query('tasks', orderBy: 'isDone ASC, priority DESC');
    setState(() {
      _tasks = maps.map((m) => Task.fromMap(m)).toList();
      _loading = false;
    });
  }

  Future<void> _addTask(String title, int priority) async {
    await _db!.insert('tasks', {
      'title': title,
      'priority': priority,
      'isDone': 0,
    });
    _loadTasks();
  }

  Future<void> _toggleDone(Task task) async {
    task.isDone = !task.isDone;
    await _db!.update('tasks', task.toMap(),
        where: 'id = ?', whereArgs: [task.id]);
    _loadTasks();
  }

  Future<void> _deleteTask(Task task) async {
    await _db!.delete('tasks', where: 'id = ?', whereArgs: [task.id]);
    _loadTasks();
  }

  void _showAddDialog() {
    final titleCtrl = TextEditingController();
    int priority = 2;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مهمة جديدة'),
        content: StatefulBuilder(
          builder: (ctx, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'العنوان',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: priority,
                decoration: const InputDecoration(
                  labelText: 'الأولوية',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('منخفضة 🟢')),
                  DropdownMenuItem(value: 2, child: Text('متوسطة 🟠')),
                  DropdownMenuItem(value: 3, child: Text('عالية 🔴')),
                ],
                onChanged: (v) => setDialogState(() => priority = v!),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleCtrl.text.trim().isEmpty) return;
              _addTask(titleCtrl.text.trim(), priority);
              Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Color _priorityColor(int p) => switch (p) {
        3 => Colors.red,
        2 => Colors.orange,
        _ => Colors.green,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مهامي 📋'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
              ? const Center(
                  child: Text(
                    'لا توجد مهام بعد\nاضغط + لإضافة مهمة',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _tasks.length,
                  itemBuilder: (context, i) {
                    final task = _tasks[i];
                    return Dismissible(
                      key: Key(task.id.toString()),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => _deleteTask(task),
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      child: Card(
                        child: ListTile(
                          leading: Checkbox(
                            value: task.isDone,
                            onChanged: (_) => _toggleDone(task),
                          ),
                          title: Text(
                            task.title,
                            style: TextStyle(
                              decoration: task.isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          trailing: Container(
                            width: 8,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _priorityColor(task.priority),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
