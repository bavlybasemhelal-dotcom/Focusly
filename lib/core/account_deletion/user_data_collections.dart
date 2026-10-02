/// Centralized registry of all user-scoped Firestore subcollections across Focusly.
///
/// ==============================================================================
/// IMPORTANT NOTICE FOR MAINTAINERS & FEATURE DEVELOPERS:
/// ==============================================================================
/// Whenever a new feature or module is added to Focusly that creates a per-user
/// subcollection under `users/{uid}/{subcollectionName}`, YOU MUST ADD THAT
/// SUBCOLLECTION NAME TO [kUserDataSubcollections] BELOW.
///
/// Failure to register a new subcollection here will cause it to be bypassed
/// during the Account Deletion process, leaving orphaned user data in Firestore
/// and violating privacy compliance (e.g. GDPR / Right to Erasure).
///
/// KEEP THIS LIST COMPREHENSIVE, ALPHABETIZED, AND UP TO DATE.
/// ==============================================================================
library;

/// Immutable list of all 43 user-scoped Firestore subcollections currently in Focusly.
/// Each subcollection exists path-wise as:
/// `users/{uid}/[collectionName]`
const List<String> kUserDataSubcollections = [
  // 1. Annual Reviews feature
  'annualReviews',

  // 2. Body Metrics tracker
  'bodyMetrics',

  // 3. Reading Tracker: Books library
  'books',

  // 4. Reading Tracker: Session logs
  'readingLogs',

  // 5. Bucket List feature
  'bucketList',

  // 6. Budget Tracker: Configurations & categories
  'budgetConfig',

  // 7. Budget Tracker: Expense & income transactions
  'budgetTransactions',

  // 8. Tasks: User-defined task categories
  'categories',

  // 9. Energy & Mood / Rituals: Daily emotional and energy check-ins
  'checkins',

  // 10. Contacts & Relationship Health: VIP contact records
  'contacts',

  // 11. Course Tracker: Courses and syllabus tracking
  'courses',

  // 12. Decision Journal: Mental models & decision logs
  'decisions',

  // 13. Schedule / Calendar: Custom event types and colors
  'event_types',

  // 14. Schedule / Calendar: User scheduled events
  'events',

  // 15. Spaced Repetition: Flashcards with SM-2 algorithm
  'flashcards',

  // 16. Goals feature: Long-term and quarterly milestones
  'goals',

  // 17. Rituals / Gratitude: Daily gratitude journal entries
  'gratitude',

  // 18. Habit Tracker: Habits and daily completion logs
  'habits',

  // 19. GTD / Weekly Review: Quick inbox collection
  'inbox',

  // 20. Knowledge Base: Articles, notes, and takeaways
  'knowledge',

  // 21. Learning Paths: Structured skill progression milestones
  'learningPaths',

  // 22. Legacy Journal: Milestone reflections and life philosophy
  'legacyJournal',

  // 23. Life Areas: 8-pillar wheel assessment records
  'lifeAreas',

  // 24. Life Score: Overall productivity and health score snapshots
  'lifeScoreLog',

  // 25. Mental Health: Daily mood, anxiety, and wellness reflections
  'mentalLog',

  // 26. Weekly Review: Review metadata and historical status
  'meta',

  // 27. Notification Center: In-app logged notifications & reminders
  'notificationLog',

  // 28. Nutrition Log: Meal, water, and macro tracking logs
  'nutritionLog',

  // 29. PARA Method: Areas of responsibility
  'paraAreas',

  // 30. PARA Method: Active and archived projects
  'paraProjects',

  // 31. PARA Method: Resources and references
  'paraResources',

  // 32. Pomodoro: Completed focus intervals and sessions
  'pomodoroLogs',

  // 33. Relationship Health: Logged interactions and check-in history
  'relationshipLogs',

  // 34. Project Retrospective: Sprint and project post-mortems
  'retrospectives',

  // 35. Rituals: Morning and shutdown ritual configurations & logs
  'rituals',

  // 36. Skills Board: XP and skill mastery progression
  'skills',

  // 37. Social Battery: Social energy level logs and drains
  'socialBattery',

  // 38. Progress & Analytics: Aggregated user statistics
  'stats',

  // 39. Tasks: Core to-do items and subtasks
  'tasks',

  // 40. Time Audit: Time tracking and activity categorizations
  'timeAuditLogs',

  // 41. Weekly Review: Completed weekly reflections and plans
  'weeklyReviews',

  // 42. Workout Tracker: Exercise and fitness logs
  'workouts',

  // 43. Gamification / XP: Historical XP gain events
  'xpLog',
];
