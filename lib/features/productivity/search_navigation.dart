import 'package:flutter/material.dart';
import '../tasks/models/task_model.dart';
import '../tasks/widgets/add_edit_task_sheet.dart';
import '../reading_tracker/models/book_model.dart';
import '../reading_tracker/widgets/book_form_modal.dart';
import '../course_tracker/models/course_model.dart';
import '../course_tracker/widgets/course_form_modal.dart';
import '../contacts/models/contact_model.dart';
import '../contacts/widgets/add_edit_contact_sheet.dart';
import '../goals/models/goal_model.dart';
import '../goals/goal_detail_page.dart';
import '../schedule/models/event_model.dart';
import '../schedule/widgets/add_edit_event_sheet.dart';
import '../para/models/para_project_model.dart';
import '../para/models/para_resource_model.dart';
import '../para/widgets/add_edit_project_sheet.dart';
import '../para/widgets/add_edit_resource_sheet.dart';
import '../learning_paths/models/learning_path_model.dart';
import '../learning_paths/widgets/path_form_modal.dart';
import 'habit_calendar_page.dart';
import '../knowledge_base/models/knowledge_entry_model.dart';
import '../knowledge_base/widgets/entry_form_modal.dart';
import '../gtd/inbox_screen.dart';

String moduleLabel(String name, bool ar) =>
    (ar
        ? {
            'all': 'كل الأقسام',
            'tasks': 'المهام',
            'habits': 'العادات',
            'events': 'التقويم',
            'inbox': 'الأفكار',
            'goals': 'الأهداف',
            'books': 'الكتب',
            'courses': 'الكورسات',
            'contacts': 'العلاقات',
            'paraProjects': 'المشاريع',
            'paraResources': 'المصادر',
            'learningPaths': 'مسارات التعلم',
            'knowledge': 'الملاحظات',
            'bodyMetrics': 'قياسات الجسم',
            'checkins': 'متابعة اليوم',
            'habitLogs': 'سجل العادات',
            'pomodoroLogs': 'جلسات التركيز',
          }
        : {
            'all': 'All modules',
            'paraProjects': 'Projects',
            'paraResources': 'Resources',
            'learningPaths': 'Learning paths',
            'knowledge': 'Notes',
            'bodyMetrics': 'Body measurements',
            'checkins': 'Daily check-ins',
            'habitLogs': 'Habit history',
            'pomodoroLogs': 'Focus sessions',
          })[name] ??
    name;

Future<void> openSearchResult(
  BuildContext context,
  Map<String, dynamic> data,
) async {
  final id = data['id'] as String;
  switch (data['collection']) {
    case 'inbox':
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const InboxScreen()),
      );
    case 'knowledge':
      await EntryFormModal.show(
        context,
        entryToEdit: KnowledgeEntryModel.fromMap(data, id),
      );
    case 'tasks':
      await AddEditTaskSheet.show(
        context,
        taskToEdit: TaskModel.fromMap(data, id),
      );
    case 'books':
      await BookFormModal.show(
        context,
        bookToEdit: BookModel.fromMap(data, id),
      );
    case 'courses':
      await CourseFormModal.show(
        context,
        courseToEdit: CourseModel.fromMap(data, id),
      );
    case 'contacts':
      await AddEditContactSheet.show(
        context,
        contact: ContactModel.fromMap(data, id),
      );
    case 'paraProjects':
      await AddEditProjectSheet.show(
        context,
        project: ParaProjectModel.fromMap(data, id),
      );
    case 'paraResources':
      await AddEditResourceSheet.show(
        context,
        resource: ParaResourceModel.fromMap(data, id),
      );
    case 'learningPaths':
      await PathFormModal.show(
        context,
        pathToEdit: LearningPathModel.fromMap(data, id),
      );
    case 'goals':
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GoalDetailPage(
            goalId: id,
            initialGoal: GoalModel.fromMap(data, id),
          ),
        ),
      );
    case 'habits':
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HabitCalendarPage(initialHabitId: id),
        ),
      );
    case 'events':
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) =>
            AddEditEventSheet(eventToEdit: EventModel.fromMap(data, id)),
      );
    default:
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(
            (data['title'] ?? data['name'] ?? data['text'] ?? id).toString(),
          ),
          content: SingleChildScrollView(
            child: SelectableText(
              (data['notes'] ?? data['note'] ?? data['text'] ?? '').toString(),
            ),
          ),
        ),
      );
  }
}
