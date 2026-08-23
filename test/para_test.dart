import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/core/auth/auth_provider.dart';
import 'package:focusly/core/localization/app_localizations.dart';
import 'package:focusly/core/theme/app_theme.dart';
import 'package:focusly/features/para/areas_page.dart';
import 'package:focusly/features/para/archive_page.dart';
import 'package:focusly/features/para/models/para_area_model.dart';
import 'package:focusly/features/para/models/para_project_model.dart';
import 'package:focusly/features/para/models/para_resource_model.dart';
import 'package:focusly/features/para/para_guide_page.dart';
import 'package:focusly/features/para/projects_page.dart';
import 'package:focusly/features/para/providers/para_provider.dart';
import 'package:focusly/features/para/resources_page.dart';
import 'package:focusly/features/para/widgets/add_edit_area_sheet.dart';
import 'package:focusly/features/para/widgets/add_edit_project_sheet.dart';
import 'package:focusly/features/para/widgets/add_edit_resource_sheet.dart';
import 'package:focusly/features/tasks/models/task_model.dart';
import 'package:focusly/features/tasks/providers/tasks_provider.dart';

Widget createParaTestWidget({
  required Widget child,
  List<dynamic> overrides = const [],
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      authStateStreamProvider.overrideWith((ref) => Stream.value(null)),
      currentUserIdProvider.overrideWithValue('test_user_para'),
      ...overrides.cast(),
    ],
    child: MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      home: child,
    ),
  );
}

void main() {
  group('PARA Data Models & Serialization Tests', () {
    test('ParaAreaModel serializes and deserializes correctly', () {
      final now = DateTime(2026, 8, 23);
      final area = ParaAreaModel(
        id: 'area_1',
        title: 'Health & Fitness',
        emoji: '🏃',
        createdAt: now,
      );

      final map = area.toMap();
      expect(map['id'], equals('area_1'));
      expect(map['title'], equals('Health & Fitness'));
      expect(map['emoji'], equals('🏃'));

      final reconstructed = ParaAreaModel.fromMap(map, 'area_1');
      expect(reconstructed.id, equals('area_1'));
      expect(reconstructed.title, equals('Health & Fitness'));
      expect(reconstructed.emoji, equals('🏃'));

      final copied = reconstructed.copyWith(title: 'Updated Health');
      expect(copied.title, equals('Updated Health'));
    });

    test('ParaProjectModel serializes and deserializes correctly', () {
      final now = DateTime(2026, 8, 23);
      final deadline = DateTime(2026, 9, 1);
      final project = ParaProjectModel(
        id: 'proj_1',
        title: 'Run 10K Marathon',
        areaId: 'area_1',
        deadline: deadline,
        archived: false,
        createdAt: now,
      );

      final map = project.toMap();
      expect(map['id'], equals('proj_1'));
      expect(map['title'], equals('Run 10K Marathon'));
      expect(map['areaId'], equals('area_1'));
      expect(map['archived'], isFalse);

      final reconstructed = ParaProjectModel.fromMap(map, 'proj_1');
      expect(reconstructed.id, equals('proj_1'));
      expect(reconstructed.deadline, equals(deadline));
      expect(reconstructed.archived, isFalse);

      final archivedCopy = reconstructed.copyWith(archived: true);
      expect(archivedCopy.archived, isTrue);
    });

    test('ParaResourceModel serializes and deserializes with tags correctly', () {
      final now = DateTime(2026, 8, 23);
      final resource = ParaResourceModel(
        id: 'res_1',
        title: 'Flutter Performance Tips',
        notes: 'Use const constructors and RepaintBoundary.',
        tags: ['flutter', 'performance', 'dev'],
        archived: false,
        createdAt: now,
      );

      final map = resource.toMap();
      expect(map['id'], equals('res_1'));
      expect(map['title'], equals('Flutter Performance Tips'));
      expect(map['tags'], equals(['flutter', 'performance', 'dev']));

      final reconstructed = ParaResourceModel.fromMap(map, 'res_1');
      expect(reconstructed.id, equals('res_1'));
      expect(reconstructed.tags.length, equals(3));
      expect(reconstructed.notes, contains('RepaintBoundary'));
    });

    test('TaskModel handles optional projectId field properly', () {
      final now = DateTime.now();
      final task = TaskModel(
        id: 'task_para',
        title: 'Buy running shoes',
        categoryId: 'health',
        date: now,
        createdAt: now,
        projectId: 'proj_1',
      );

      final map = task.toMap();
      expect(map['projectId'], equals('proj_1'));

      final reconstructed = TaskModel.fromMap(map, 'task_para');
      expect(reconstructed.projectId, equals('proj_1'));

      final unlinked = reconstructed.copyWith(clearProjectId: true);
      expect(unlinked.projectId, isNull);
    });
  });

  group('PARA Riverpod Providers & Count Computations', () {
    test('paraProjectsStreamProvider partitions active and archived projects correctly', () async {
      final now = DateTime.now();
      final allProjects = [
        ParaProjectModel(id: 'p1', title: 'Active 1', areaId: 'a1', archived: false, createdAt: now),
        ParaProjectModel(id: 'p2', title: 'Archived 1', areaId: 'a1', archived: true, createdAt: now),
        ParaProjectModel(id: 'p3', title: 'Active 2', areaId: 'a2', archived: false, createdAt: now),
      ];

      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue('user_test'),
          allParaProjectsStreamProvider.overrideWith((ref) => Stream.value(allProjects)),
        ],
      );
      addTearDown(container.dispose);

      container.listen(allParaProjectsStreamProvider, (prev, next) {});
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final active = container.read(paraProjectsStreamProvider).value ?? [];
      expect(active.length, equals(2));
      expect(active.map((p) => p.id), containsAll(['p1', 'p3']));

      final archived = container.read(archivedProjectsStreamProvider).value ?? [];
      expect(archived.length, equals(1));
      expect(archived.first.id, equals('p2'));
    });

    test('areaActiveProjectsCountProvider accurately tallies active projects under an area', () async {
      final now = DateTime.now();
      final allProjects = [
        ParaProjectModel(id: 'p1', title: 'Proj 1', areaId: 'area_health', archived: false, createdAt: now),
        ParaProjectModel(id: 'p2', title: 'Proj 2', areaId: 'area_health', archived: true, createdAt: now),
        ParaProjectModel(id: 'p3', title: 'Proj 3', areaId: 'area_health', archived: false, createdAt: now),
        ParaProjectModel(id: 'p4', title: 'Proj 4', areaId: 'area_finance', archived: false, createdAt: now),
      ];

      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue('user_test'),
          allParaProjectsStreamProvider.overrideWith((ref) => Stream.value(allProjects)),
        ],
      );
      addTearDown(container.dispose);

      container.listen(allParaProjectsStreamProvider, (prev, next) {});
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final healthCount = container.read(areaActiveProjectsCountProvider('area_health'));
      expect(healthCount, equals(2));

      final financeCount = container.read(areaActiveProjectsCountProvider('area_finance'));
      expect(financeCount, equals(1));
    });
  });

  group('PARA UI Screen & Widget Tests', () {
    testWidgets('AreasPage renders area cards, emoji, and project count chips', (tester) async {
      final areas = [
        ParaAreaModel(id: 'a1', title: 'Career & Growth', emoji: '💼', createdAt: DateTime.now()),
      ];
      final projects = [
        ParaProjectModel(id: 'p1', title: 'Portfolio Website', areaId: 'a1', archived: false, createdAt: DateTime.now()),
      ];

      await tester.pumpWidget(
        createParaTestWidget(
          child: const AreasPage(),
          overrides: [
            paraAreasStreamProvider.overrideWith((ref) => Stream.value(areas)),
            allParaProjectsStreamProvider.overrideWith((ref) => Stream.value(projects)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Areas'), findsOneWidget);
      expect(find.text('Career & Growth'), findsOneWidget);
      expect(find.text('💼'), findsOneWidget);
      expect(find.text('1 projects'), findsOneWidget);
    });

    testWidgets('ProjectsPage renders projects, area badge, deadline, and task accordion', (tester) async {
      final now = DateTime.now().add(const Duration(days: 4));
      final areas = [
        ParaAreaModel(id: 'a1', title: 'Health', emoji: '🏃', createdAt: DateTime.now()),
      ];
      final projects = [
        ParaProjectModel(id: 'p1', title: 'Run 5K Race', areaId: 'a1', deadline: now, archived: false, createdAt: DateTime.now()),
      ];
      final tasks = [
        TaskModel(id: 't1', title: 'Buy running socks', categoryId: 'work', date: DateTime.now(), createdAt: DateTime.now(), projectId: 'p1'),
      ];

      await tester.pumpWidget(
        createParaTestWidget(
          child: const ProjectsPage(),
          overrides: [
            paraAreasStreamProvider.overrideWith((ref) => Stream.value(areas)),
            allParaProjectsStreamProvider.overrideWith((ref) => Stream.value(projects)),
            tasksStreamProvider.overrideWith((ref) => Stream.value(tasks)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Projects'), findsOneWidget);
      expect(find.text('Run 5K Race'), findsOneWidget);
      expect(find.text('Health'), findsOneWidget);
      expect(find.text('1 tasks'), findsOneWidget);

      // Expand task accordion
      await tester.tap(find.text('1 tasks'));
      await tester.pumpAndSettle();
      expect(find.text('Buy running socks'), findsOneWidget);
    });

    testWidgets('ResourcesPage renders resources, note preview, and tag chips', (tester) async {
      final resources = [
        ParaResourceModel(
          id: 'r1',
          title: 'Clean Architecture Summary',
          notes: 'Entities, Use Cases, Repositories, Data Sources.',
          tags: ['architecture', 'design'],
          archived: false,
          createdAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        createParaTestWidget(
          child: const ResourcesPage(),
          overrides: [
            allParaResourcesStreamProvider.overrideWith((ref) => Stream.value(resources)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Resources'), findsOneWidget);
      expect(find.text('Clean Architecture Summary'), findsOneWidget);
      expect(find.textContaining('Entities, Use Cases'), findsOneWidget);
      expect(find.text('#architecture'), findsWidgets);
      expect(find.text('#design'), findsWidgets);
    });

    testWidgets('ArchivePage switches between Projects and Resources tabs', (tester) async {
      final archivedProjects = [
        ParaProjectModel(id: 'p_arch', title: 'Completed App V1', areaId: 'a1', archived: true, createdAt: DateTime.now()),
      ];
      final archivedResources = [
        ParaResourceModel(id: 'r_arch', title: 'Old Server Configs', tags: [], archived: true, createdAt: DateTime.now()),
      ];

      await tester.pumpWidget(
        createParaTestWidget(
          child: const ArchivePage(),
          overrides: [
            allParaProjectsStreamProvider.overrideWith((ref) => Stream.value(archivedProjects)),
            allParaResourcesStreamProvider.overrideWith((ref) => Stream.value(archivedResources)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Archive'), findsOneWidget);
      expect(find.text('Completed App V1'), findsOneWidget);

      // Switch to Resources tab
      await tester.tap(find.text('Resources'));
      await tester.pumpAndSettle();
      expect(find.text('Old Server Configs'), findsOneWidget);
    });

    testWidgets('ParaGuidePage renders hero overview and 4 pillar navigation cards', (tester) async {
      await tester.pumpWidget(
        createParaTestWidget(
          child: const ParaGuidePage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PARA Guide'), findsOneWidget);
      expect(find.text('The PARA Method'), findsOneWidget);
      expect(find.text('Projects'), findsOneWidget);
      expect(find.text('Areas'), findsOneWidget);
    });

    testWidgets('AddEditAreaSheet renders form and emoji presets', (tester) async {
      await tester.pumpWidget(
        createParaTestWidget(
          child: const Scaffold(
            body: AddEditAreaSheet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create Area of Responsibility'), findsOneWidget);
      expect(find.text('Create Area'), findsOneWidget);
      expect(find.text('🎯'), findsWidgets);
    });

    testWidgets('AddEditProjectSheet renders form and area selection', (tester) async {
      final areas = [
        ParaAreaModel(id: 'a1', title: 'Finance', emoji: '💰', createdAt: DateTime.now()),
      ];

      await tester.pumpWidget(
        createParaTestWidget(
          child: const Scaffold(
            body: AddEditProjectSheet(),
          ),
          overrides: [
            paraAreasStreamProvider.overrideWith((ref) => Stream.value(areas)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create Project'), findsWidgets);
      expect(find.text('Finance'), findsOneWidget);
    });

    testWidgets('AddEditResourceSheet renders form with tags input', (tester) async {
      await tester.pumpWidget(
        createParaTestWidget(
          child: const Scaffold(
            body: AddEditResourceSheet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create Resource'), findsWidgets);
    });
  });
}
