import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/routine_provider.dart';
import '../providers/settings_provider.dart';
import '../models/routine_task.dart';
import '../models/task_completion.dart';
import '../main.dart';
import '../widgets/language_toggle.dart';

class RoutineScreen extends StatelessWidget {
  const RoutineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final routine = context.watch<RoutineProvider>();
    final settings = context.watch<SettingsProvider>();
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('daily_routine')),
        actions: const [LanguageToggle()],
      ),
      body: Column(
        children: [
          _DateNavigator(routine: routine),
          _GroupBanner(group: routine.groupForSelectedDate),
          Container(height: 1, color: c.border),
          Expanded(
            child: routine.loading
                ? Center(child: CircularProgressIndicator(color: c.primary))
                : routine.tasksForSelectedDate.isEmpty
                    ? const _EmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: routine.tasksForSelectedDate.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final task = routine.tasksForSelectedDate[index];
                          final status = routine.statusOf(task.id!);
                          return _TaskCard(
                            task: task,
                            status: status,
                            onMarkDone: () => routine.markDone(task.id!),
                            onMarkMissed: () => routine.markMissed(task.id!),
                            onDelete: () => _confirmDelete(context, routine, task),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: c.primary,
        onPressed: () => _showAddTaskSheet(context, routine),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(settings.t('add_task'), style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  void _confirmDelete(BuildContext context, RoutineProvider routine, RoutineTask task) {
    final c = context.colorsNoWatch;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surfaceAlt,
        title: Text('Delete task?', style: TextStyle(color: c.textPrimary)),
        content: Text(
          '"${task.title}" will be removed from ${groupLabel(task.group)}.',
          style: TextStyle(color: c.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              routine.deleteTask(task.id!);
              Navigator.pop(ctx);
            },
            child: Text('Delete', style: TextStyle(color: c.danger)),
          ),
        ],
      ),
    );
  }

  void _showAddTaskSheet(BuildContext context, RoutineProvider routine) {
    final c = context.colorsNoWatch;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surfaceAlt,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddTaskSheet(routine: routine),
    );
  }
}

class _DateNavigator extends StatelessWidget {
  final RoutineProvider routine;
  const _DateNavigator({required this.routine});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      color: c.surface,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, color: c.textSecondary),
            onPressed: routine.goToPreviousDay,
          ),
          GestureDetector(
            onTap: () => _pickDate(context),
            child: Column(
              children: [
                Text(
                  routine.isToday ? 'Today' : DateFormat('EEEE').format(routine.selectedDate),
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: c.textPrimary),
                ),
                Text(
                  DateFormat('d MMM yyyy').format(routine.selectedDate),
                  style: TextStyle(fontSize: 12, color: c.textMuted),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right, color: c.textSecondary),
            onPressed: routine.goToNextDay,
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final c = context.colorsNoWatch;
    final picked = await showDatePicker(
      context: context,
      initialDate: routine.selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2028),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme(
              brightness: c.isDark ? Brightness.dark : Brightness.light,
              primary: c.primary,
              onPrimary: Colors.white,
              secondary: c.accent,
              onSecondary: Colors.white,
              surface: c.surfaceAlt,
              onSurface: c.textPrimary,
              error: c.danger,
              onError: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      routine.goToDate(picked);
    }
  }
}

/// Shows which of the 3 weekly groups today belongs to, so it's obvious
/// why these particular tasks are showing.
class _GroupBanner extends StatelessWidget {
  final RoutineGroup group;
  const _GroupBanner({required this.group});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      color: c.surfaceAlt,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.calendar_view_week, size: 14, color: c.accent),
          const SizedBox(width: 6),
          Text(
            'Weekly group: ${groupLabel(group)}',
            style: TextStyle(fontSize: 12, color: c.textSecondary, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.checklist_outlined, size: 56, color: c.border),
            const SizedBox(height: 16),
            Text(
              'No tasks in this weekly group yet.\nTap "Add task" to create one.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final RoutineTask task;
  final TaskStatus status;
  final VoidCallback onMarkDone;
  final VoidCallback onMarkMissed;
  final VoidCallback onDelete;

  const _TaskCard({
    required this.task,
    required this.status,
    required this.onMarkDone,
    required this.onMarkMissed,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDone = status == TaskStatus.done;
    final isMissed = status == TaskStatus.missed;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDone ? c.accent.withOpacity(0.4) : c.border,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          if (task.timeOfDay != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: c.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                task.timeOfDay!,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: c.primary),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              task.title,
              style: TextStyle(
                fontSize: 15,
                decoration: isDone ? TextDecoration.lineThrough : null,
                decorationColor: c.textMuted,
                color: isDone
                    ? c.textMuted
                    : isMissed
                        ? c.danger
                        : c.textPrimary,
              ),
            ),
          ),
          _RoundIconButton(
            icon: Icons.check,
            active: isDone,
            activeColor: c.accent,
            onTap: onMarkDone,
          ),
          const SizedBox(width: 6),
          _RoundIconButton(
            icon: Icons.close,
            active: isMissed,
            activeColor: c.danger,
            onTap: onMarkMissed,
          ),
          IconButton(
            icon: Icon(Icons.more_vert, size: 18, color: c.textMuted),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _RoundIconButton({
    required this.icon,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? activeColor : Colors.transparent,
          border: Border.all(color: active ? activeColor : c.border),
        ),
        child: Icon(icon, size: 18, color: active ? Colors.white : c.textMuted),
      ),
    );
  }
}

class _AddTaskSheet extends StatefulWidget {
  final RoutineProvider routine;
  const _AddTaskSheet({required this.routine});

  @override
  State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  final _controller = TextEditingController();
  late RoutineGroup _selectedGroup;
  TimeOfDay? _selectedTime;

  @override
  void initState() {
    super.initState();
    // Default to whichever group the currently-viewed day belongs to.
    _selectedGroup = widget.routine.groupForSelectedDate;
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'New task',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.textPrimary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            style: TextStyle(color: c.textPrimary),
            decoration: InputDecoration(
              hintText: 'e.g. Physics 2 hrs, Morning walk, Revise Chem notes',
              hintStyle: TextStyle(color: c.textMuted, fontSize: 13.5),
              filled: true,
              fillColor: c.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: c.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: c.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: c.primary),
              ),
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _selectedTime ?? TimeOfDay.now(),
                builder: (context, child) => Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme(
                      brightness: c.isDark ? Brightness.dark : Brightness.light,
                      primary: c.primary,
                      onPrimary: Colors.white,
                      secondary: c.accent,
                      onSecondary: Colors.white,
                      surface: c.surfaceAlt,
                      onSurface: c.textPrimary,
                      error: c.danger,
                      onError: Colors.white,
                    ),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) setState(() => _selectedTime = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: _selectedTime != null ? c.primary : c.textMuted),
                  const SizedBox(width: 10),
                  Text(
                    _selectedTime != null ? _formatTime(_selectedTime!) : 'Set a time (optional)',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: _selectedTime != null ? c.textPrimary : c.textMuted,
                    ),
                  ),
                  const Spacer(),
                  if (_selectedTime != null)
                    InkWell(
                      onTap: () => setState(() => _selectedTime = null),
                      child: Icon(Icons.close, size: 16, color: c.textMuted),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Which days should this repeat on every week?',
            style: TextStyle(fontSize: 12.5, color: c.textSecondary, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 10),
          ...RoutineGroup.values.map(
            (g) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _GroupChoiceCard(
                group: g,
                selected: _selectedGroup == g,
                onTap: () => setState(() => _selectedGroup = g),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: c.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () {
                final title = _controller.text.trim();
                if (title.isEmpty) return;
                widget.routine.addTask(
                  title: title,
                  group: _selectedGroup,
                  timeOfDay: _selectedTime != null ? _formatTime(_selectedTime!) : null,
                );
                Navigator.pop(context);
              },
              child: const Text('Add task'),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupChoiceCard extends StatelessWidget {
  final RoutineGroup group;
  final bool selected;
  final VoidCallback onTap;

  const _GroupChoiceCard({
    required this.group,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? c.primary.withOpacity(0.15) : c.surface,
          border: Border.all(color: selected ? c.primary : c.border, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: selected ? c.primary : c.textMuted,
            ),
            const SizedBox(width: 10),
            Text(
              groupLabel(group),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: selected ? c.primary : c.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
