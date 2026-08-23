import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Full app localization class supporting English ('en') and Arabic ('ar')
/// with automatic RTL text direction and complete translation dictionaries.
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('en'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      // App General
      'app_name': 'Focusly',
      'cancel': 'Cancel',
      'save': 'Save',
      'save_changes': 'Save Changes',
      'close': 'Close',
      'or': 'or',
      'done': 'Done',
      'error': 'Error',
      'success': 'Success',
      'coming_soon': 'Coming soon!',

      // Splash Screen
      'splash_init_engine': '⚡ Initializing smart task engine...',
      'splash_sync_habits': '🔄 Syncing daily habit streaks...',
      'splash_opt_workspace': '🎯 Optimizing focus workspace...',
      'splash_ready': '✨ Welcome to Focusly!',

      // Onboarding Screen
      'onboarding_title_1': 'Organize Everything',
      'onboarding_sub_1': 'Capture tasks, set smart priorities, and master your daily agenda in one place.',
      'onboarding_title_2': 'Build Better Habits',
      'onboarding_sub_2': 'Form lasting routines with visual streak trackers and mindful milestone celebrations.',
      'onboarding_title_3': 'Stay Focused',
      'onboarding_sub_3': 'Eliminate distractions with smart focus timers, deep work zones, and soundscapes.',
      'onboarding_title_4': 'Grow With Your Team',
      'onboarding_sub_4': 'Collaborate on shared goals, track team productivity, and achieve more together.',
      'next': 'Next',
      'get_started': 'Get Started',
      'skip': 'Skip',

      // Auth / Login Screen
      'welcome_back': 'Welcome Back',
      'login_subtitle': 'Sign in to continue your focus journey',
      'email': 'Email',
      'email_hint': 'name@example.com',
      'password': 'Password',
      'password_hint': '••••••••••••',
      'remember_me': 'Remember me',
      'forgot_password': 'Forgot Password?',
      'log_in': 'Log In',
      'continue_with_google': 'Continue with Google',
      'dont_have_account': "Don't have an account?",
      'sign_up': 'Sign Up',
      'email_required': 'Please enter your email',
      'email_invalid': 'Please enter a valid email address',
      'password_required': 'Please enter your password',
      'password_too_short': 'Password must be at least 6 characters',
      'login_failed': 'Invalid email or password.',
      'user_disabled': 'This user account has been disabled.',
      'too_many_requests': 'Too many failed attempts. Please try again later.',

      // Signup Screen
      'create_account': 'Create Your Account',
      'signup_subtitle': 'Start organizing your tasks and habits today',
      'full_name': 'Full Name',
      'full_name_hint': 'John Doe',
      'full_name_required': 'Please enter your full name',
      'confirm_password': 'Confirm Password',
      'confirm_password_hint': 'Re-type your password',
      'confirm_password_required': 'Please confirm your password',
      'passwords_dont_match': 'Passwords do not match',
      'terms_agreement': 'I agree to the Terms of Service & Privacy Policy',
      'terms_required': 'You must agree to the Terms & Privacy Policy to proceed',
      'already_have_account': 'Already have an account?',
      'signup_failed': 'Failed to create account. Please try again.',
      'email_already_in_use': 'An account already exists with this email.',
      'weak_password': 'The password is too weak. Use at least 8 characters.',

      // Home Screen
      'hello_greeting': 'Hello',
      'there': 'there',
      'home': 'Home',
      'tasks': 'Tasks',
      'habits': 'Habits',
      'profile': 'Profile',
      'settings': 'Settings',
      'focus_workspace_ready': '✨ Workspace Ready • Deep Focus Flow',

      // Tasks Feature
      'all_tasks': 'All',
      'tasks_pending': 'pending',
      'tasks_completed': 'completed',
      'list_view': 'List',
      'matrix_view': 'Matrix',
      'add_task': 'Add Task',
      'new_task': 'New Task',
      'edit_task': 'Edit Task',
      'delete_task': 'Delete Task',
      'delete_task_confirm_title': 'Delete Task',
      'delete_task_confirm_message': 'Are you sure you want to delete this task?',
      'task_title_hint': 'What needs to be done?',
      'task_title_required': 'Please enter a task title',
      'task_notes_hint': 'Add additional notes or details (optional)...',
      'quick_quadrant_select': 'Quick Matrix Placement',
      'category': 'Category',
      'priority': 'Priority',
      'priority_high': 'High',
      'priority_medium': 'Medium',
      'priority_low': 'Low',
      'date': 'Date',
      'today': 'Today',
      'time': 'Time',
      'all_day': 'All Day',
      'deadline': 'Deadline',
      'no_deadline': 'No Deadline',
      'create_task': 'Create Task',
      'update_task': 'Update Task',
      'subtasks': 'Subtasks',
      'add_subtask_hint': 'Add a subtask...',
      'no_tasks_title': 'No tasks here yet',
      'no_tasks_subtitle': 'Tap the (+) button to create your first task and conquer your day!',
      'delete': 'Delete',
      'add': 'Add',

      // Categories
      'category_work': 'Work',
      'category_study': 'Study',
      'category_health': 'Health',
      'category_personal': 'Personal',
      'category_courses': 'Courses',
      'category_training': 'Training',
      'add_category_title': 'Add Category',
      'category_name_hint': 'Category Name',
      'select_color': 'Select Tag Color',

      // Eisenhower Matrix
      'matrix_q1_title': 'Do Now',
      'matrix_q1_sub': 'Urgent & Important',
      'matrix_q1_empty': '🎉 All urgent & important tasks done!',
      'matrix_q2_title': 'Schedule',
      'matrix_q2_sub': 'Important, Not Urgent',
      'matrix_q2_empty': '📅 Plan long-term goals and habits here',
      'matrix_q3_title': 'Delegate',
      'matrix_q3_sub': 'Urgent, Not Important',
      'matrix_q3_empty': '🤝 Minimize or delegate interruptions',
      'matrix_q4_title': 'Eliminate',
      'matrix_q4_sub': 'Neither Urgent nor Important',
      'matrix_q4_empty': '✨ Clean workspace! Eliminate time-wasters',
      'task_moved_to': 'Task moved to',

      // Notifications
      'notification_task_time_title': '⚡ Time for your task!',
      'notification_deadline_24h_title': '⚠️ Deadline tomorrow!',
      'notification_deadline_1h_title': '🚨 1 hour left for your deadline!',

      // Schedule & Calendar Feature
      'schedule': 'Schedule',
      'events_count': 'events',
      'view_month': 'Month',
      'view_week': 'Week',
      'view_day': 'Day',
      'add_event': 'Add Event',
      'new_event': 'New Event',
      'edit_event': 'Edit Event',
      'delete_event': 'Delete Event',
      'event_title_hint': 'Event title (e.g. Flutter Workshop)',
      'event_title_required': 'Please enter an event title',
      'event_type': 'Event Type',
      'event_note_hint': 'Add notes, location, or details (optional)...',
      'recurrence': 'Recurrence',
      'recurrence_none': 'None',
      'recurrence_daily': 'Daily',
      'recurrence_weekly': 'Weekly',
      'recurrence_monthly': 'Monthly',
      'recurrence_weekdays': 'Weekdays (Mon-Fri)',
      'recurrence_end': 'Recurrence End',
      'never_ends': 'Never (Indefinite)',
      'create_event': 'Create Event',
      'update_event': 'Update Event',
      'no_events_today': 'No events scheduled for this day',
      'no_events_agenda_subtitle': 'Enjoy your free time or tap (+) to schedule a new event!',
      'delete_event_confirm_title': 'Delete Event',
      'delete_event_confirm_message': 'Are you sure you want to delete this event?',
      'delete_recurring_event_confirm_message': 'This will delete all recurring occurrences of this event. Are you sure?',
      'edit_recurring_title': 'Edit Recurring Event',
      'edit_recurring_prompt': 'Do you want to edit all occurrences in this series or this occurrence only?',
      'edit_all_occurrences': 'Edit all occurrences',
      'edit_this_occurrence_only': 'This occurrence only',
      'add_event_type_title': 'Add Event Type',
      'event_type_name_hint': 'Type Name',
      'type_course_study': 'Course / Study',
      'type_training_sport': 'Training / Sport',
      'type_work_meeting': 'Work / Meeting',
      'type_personal': 'Personal',
      'type_exam': 'Exam',
      'type_important_urgent': 'Important / Urgent',
      'notification_event_title': '📅 Upcoming event!',

      // Habits Feature
      'habits_subtitle': 'Build streaks & anchor daily routines',
      'total_habits': 'Total Habits',
      'longest_streak': 'Longest Streak',
      'total_streak_days': 'Total Days',
      'days_streak': 'days streak',
      'add_habit': 'Add Habit',
      'new_habit': 'New Habit',
      'edit_habit': 'Edit Habit',
      'delete_habit': 'Delete Habit',
      'habit_title_hint': 'Habit title (e.g. Read 15 mins)',
      'habit_title_required': 'Please enter a habit title',
      'stack_trigger_title': 'Habit Stacking Cue (Optional)',
      'stack_trigger_hint': 'e.g. Right after morning coffee',
      'stack_trigger_help':
          'Habit Stacking anchors a new habit to an existing daily routine so it sticks effortlessly.',
      'reminder_time_optional': 'Daily Reminder Time (Optional)',
      'no_reminder_set': 'No reminder set',
      'set_time': 'Set Time',
      'advanced_options': 'Advanced & Reset Options',
      'auto_reset_title': 'Auto Weekly Rollover',
      'auto_reset_desc':
          'Automatically calculate and roll over completed streaks each week',
      'create_habit': 'Create Habit',
      'update_habit': 'Update Habit',
      'delete_habit_confirm_title': 'Delete Habit',
      'delete_habit_confirm_message':
          'Are you sure you want to delete this habit and its streak history?',
      'no_habits_yet': 'No habits created yet',
      'no_habits_subtitle':
          'Start small and build unstoppable momentum with daily habit streaks!',
      'habit_added_success': 'Habit created successfully!',
      'habit_updated_success': 'Habit updated successfully!',
      'habit_deleted_success': 'Habit deleted successfully!',
      'habit_error_saving': 'Error saving habit. Please try again.',
      'habit_error_deleting': 'Error deleting habit. Please try again.',
      'notification_habit_title': '🔥 Habit Reminder!',

      // Pomodoro Feature
      'pomodoro': 'Pomodoro',
      'pomodoro_subtitle': 'Focus cycles & deep work',
      'focus_time': 'Focus Time',
      'short_break': 'Short Break',
      'long_break': 'Long Break',
      'start': 'Start',
      'pause': 'Pause',
      'reset': 'Reset',
      'distraction': 'Distraction',
      'distractions': 'Distractions',
      'select_task_for_session': 'Link a Task to this Session',
      'link_task_optional': 'Link a task (Optional)',
      'generic_focus_session': 'General Focus Session',
      'no_active_tasks': 'No active tasks available to link',
      'focus_sessions_today': 'sessions today',
      'minutes_focused_today': 'minutes focused today',
      'weekly_focus_activity': 'Weekly Focus Activity',
      'best_day_callout_prefix': 'Your best day was',
      'best_day_callout_suffix': 'with',
      'pomodoro_settings': 'Pomodoro Settings',
      'focus_duration': 'Focus Duration',
      'short_break_duration': 'Short Break Duration',
      'long_break_duration': 'Long Break Duration',
      'long_break_interval': 'Sessions Until Long Break',
      'auto_start_phases': 'Auto-start Next Phase',
      'auto_start_phases_desc':
          'Automatically starts timer when a phase completes',
      'save_settings': 'Save Settings',
      'sessions': 'sessions',
      'minutes_short': 'min',
      'notification_work_done_title':
          'Focus session complete! Time for a break ☕',
      'notification_break_done_title':
          "Break's over! Ready to focus again? 🍅",

      // Progress & Achievements Feature
      'progress': 'Progress',
      'progress_and_achievements': 'Progress & Achievements',
      'progress_subtitle': 'Level up your daily momentum',
      'tab_overview': 'Overview',
      'tab_achievements': 'Achievements',
      'level': 'Level',
      'total_xp': 'total XP',
      'xp_to_next_level': 'XP to next level',
      'max_level_reached': 'Max Level Reached 🔱',
      'stat_tasks_completed': 'Tasks Completed',
      'focus_sessions': 'Pomodoro Sessions',
      'total_focus_time': 'Total Focus Time',
      'weekly_productivity_score': 'Weekly Productivity Score',
      'category_breakdown': 'Category Breakdown',
      'achievement_unlocked_title': 'Achievement Unlocked!',
      'unlocked': 'Unlocked',
      'locked': 'Locked',

      // Level Titles
      'level_1_title': 'Beginner',
      'level_2_title': 'Learner',
      'level_3_title': 'Diligent',
      'level_4_title': 'Productive',
      'level_5_title': 'Outstanding',
      'level_6_title': 'Expert',
      'level_7_title': 'Professional',
      'level_8_title': 'Legend',
      'level_9_title': 'Productivity Champion',
      'level_10_title': 'Master',
      'level_11_title': 'Sage',
      'level_12_title': 'Wise One',
      'level_13_title': 'Enlightened',
      'level_14_title': 'Heroic',
      'level_15_title': 'Prince',
      'level_16_title': 'King',
      'level_17_title': 'Emperor',
      'level_18_title': 'Immortal',
      'level_19_title': 'Deity',
      'level_20_title': 'Beyond the Cosmos',

      // Achievement Categories
      'achieve_cat_tasks': 'Tasks',
      'achieve_cat_habits': 'Habits',
      'achieve_cat_pomodoro': 'Pomodoro',
      'achieve_cat_events': 'Events',
      'achieve_cat_levels': 'XP & Levels',
      'achieve_cat_organization': 'Organization',
      'achieve_cat_special': 'Special',

      // Achievement Items
      'achieve_task_first_title': 'First Step',
      'achieve_task_first_desc': 'Completed your very first task',
      'achieve_task_5_title': 'High Five',
      'achieve_task_5_desc': 'Completed 5 tasks',
      'achieve_task_10_title': 'Getting Momentum',
      'achieve_task_10_desc': 'Completed 10 tasks',
      'achieve_task_25_title': 'Quarter Century',
      'achieve_task_25_desc': 'Completed 25 tasks',
      'achieve_task_50_title': 'Half Hundred',
      'achieve_task_50_desc': 'Completed 50 tasks',
      'achieve_task_100_title': 'Centurion',
      'achieve_task_100_desc': 'Completed 100 tasks',
      'achieve_task_create_20_title': 'Planner Master',
      'achieve_task_create_20_desc': 'Created 20 tasks total',
      'achieve_task_subtask_title': 'Break It Down',
      'achieve_task_subtask_desc': 'Added a subtask to any task',

      'achieve_habit_first_title': 'New Habit',
      'achieve_habit_first_desc': 'Created your first habit',
      'achieve_habit_day_1_title': 'Day One',
      'achieve_habit_day_1_desc': 'Completed a habit for 1 day',
      'achieve_habit_streak_3_title': 'Spark',
      'achieve_habit_streak_3_desc': 'Built a 3-day habit streak',
      'achieve_habit_streak_7_title': 'Unstoppable',
      'achieve_habit_streak_7_desc': 'Built a 7-day habit streak',
      'achieve_habit_streak_14_title': 'Diamond Habit',
      'achieve_habit_streak_14_desc': 'Built a 14-day habit streak',
      'achieve_habit_streak_30_title': 'Monthly Mastery',
      'achieve_habit_streak_30_desc': 'Built a 30-day habit streak',
      'achieve_habit_create_5_title': 'Habit Garden',
      'achieve_habit_create_5_desc': 'Created 5 habits total',

      'achieve_pomodoro_first_title': 'First Focus',
      'achieve_pomodoro_first_desc': 'Completed 1st Pomodoro work session',
      'achieve_pomodoro_5_title': 'Focus Rhythm',
      'achieve_pomodoro_5_desc': 'Completed 5 Pomodoro sessions',
      'achieve_pomodoro_10_title': 'Hyper Focus',
      'achieve_pomodoro_10_desc': 'Completed 10 Pomodoro sessions',
      'achieve_pomodoro_25_title': 'Flow State',
      'achieve_pomodoro_25_desc': 'Completed 25 Pomodoro sessions',
      'achieve_pomodoro_50_title': 'Deep Work Titan',
      'achieve_pomodoro_50_desc': 'Completed 50 Pomodoro sessions',
      'achieve_pomodoro_60m_title': 'Hour of Power',
      'achieve_pomodoro_60m_desc': 'Accumulated 60 total focused minutes',
      'achieve_pomodoro_300m_title': 'Zen Master',
      'achieve_pomodoro_300m_desc': 'Accumulated 300 total focused minutes',

      'achieve_event_first_title': 'First Appointment',
      'achieve_event_first_desc': 'Scheduled your first calendar event',
      'achieve_event_5_title': 'Busy Calendar',
      'achieve_event_5_desc': 'Scheduled 5 calendar events',
      'achieve_event_20_title': 'Time Architect',
      'achieve_event_20_desc': 'Scheduled 20 calendar events',

      'achieve_xp_100_title': 'XP Bronze',
      'achieve_xp_100_desc': 'Earned 100 total XP',
      'achieve_xp_500_title': 'XP Silver',
      'achieve_xp_500_desc': 'Earned 500 total XP',
      'achieve_xp_1000_title': 'XP Gold',
      'achieve_xp_1000_desc': 'Earned 1,000 total XP',
      'achieve_level_5_title': 'Rising Star',
      'achieve_level_5_desc': 'Reached Level 5 (Outstanding)',
      'achieve_level_10_title': 'Master Level',
      'achieve_level_10_desc': 'Reached Level 10 (Master)',
      'achieve_level_20_title': 'Cosmic Legend',
      'achieve_level_20_desc': 'Reached Level 20 (Beyond the Cosmos)',

      'achieve_org_3_cat_title': 'Diverse Goals',
      'achieve_org_3_cat_desc':
          'Organized tasks across 3 different categories',
      'achieve_org_5_cat_title': 'Life Balance',
      'achieve_org_5_cat_desc':
          'Organized tasks across 5 different categories',
      'achieve_org_custom_cat_title': 'Custom Touch',
      'achieve_org_custom_cat_desc': 'Created a custom task category',

      'achieve_night_owl_title': 'Night Owl',
      'achieve_night_owl_desc': 'Added a task after midnight',
      'achieve_early_bird_title': 'Early Bird',
      'achieve_early_bird_desc': 'Added a task before 7 AM',
      'achieve_perfect_week_title': 'Perfect Week',
      'achieve_perfect_week_desc':
          'Completed tasks on 7 consecutive days',

      // Settings Main
      'settings_title': 'Settings',
      'account_section': 'Account',
      'profile_desc': 'Manage your personal information',
      'change_password': 'Change Password',
      'change_password_desc': 'Update and secure your account password',
      'preferences_section': 'Preferences',
      'language': 'Language',
      'theme': 'Theme',
      'notifications': 'Notifications',
      'notifications_desc': 'Daily reminders and streak alerts',
      'advanced_section': 'Advanced & Preferences',
      'connected_accounts': 'Connected Accounts',
      'reminder_time': 'Default Reminder Time',
      'reminder_time_desc': 'Daily notifications for tasks and habits',
      'reminder_time_updated': 'Daily reminder time updated!',
      'font_size': 'Font Size',
      'font_size_small': 'Small',
      'font_size_standard': 'Standard',
      'font_size_large': 'Large',
      'about_section': 'About Focusly',
      'app_version': 'App Version',
      'terms_of_service': 'Terms of Service',
      'privacy_policy': 'Privacy Policy',
      'rate_app': 'Rate the App',
      'rate_app_launching': 'Opening store page...',
      'rate_app_error': 'Could not open the app store listing.',
      'account_actions': 'Account Actions',
      'log_out': 'Log Out',
      'log_out_confirm_title': 'Log Out',
      'log_out_confirm_message': 'Are you sure you want to log out of Focusly?',
      'delete_account': 'Delete Account',
      'delete_account_confirm_title': 'Delete Account',
      'delete_account_confirm_message':
          'This action is irreversible. All your tasks, habits, and streaks will be permanently deleted.',

      // Legal Texts (Terms & Privacy)
      'legal_last_updated': 'Last updated: August 2026',
      'terms_intro_text':
          'Welcome to Focusly. By using our application, you agree to these Terms of Service. Please read them carefully.',
      'terms_section_1_title': '1. User Accounts & Security',
      'terms_section_1_body':
          'You are responsible for maintaining the confidentiality of your account credentials. You agree to notify us immediately of any unauthorized access to your account.',
      'terms_section_2_title': '2. Acceptable Use',
      'terms_section_2_body':
          'Focusly is designed for personal productivity and habit tracking. You agree not to misuse our services, reverse-engineer the application, or violate any applicable laws.',
      'terms_section_3_title': '3. Service Modifications & Termination',
      'terms_section_3_body':
          'We reserve the right to modify or discontinue features to improve user experience. You may terminate your account at any time via Settings.',
      'privacy_intro_text':
          'Your privacy is our priority. This Privacy Policy outlines how Focusly collects, uses, and safeguards your personal productivity data.',
      'privacy_section_1_title': '1. Information We Collect',
      'privacy_section_1_body':
          'We collect only the essential data needed to provide our services: your name, email address, optional contact details, tasks, and habit tracking records.',
      'privacy_section_2_title': '2. How We Use Your Data',
      'privacy_section_2_body':
          'Your data is securely stored in Google Cloud Firebase and is used exclusively to sync your productivity workspace across your authorized devices. We never sell your personal data to third parties.',
      'privacy_section_3_title': '3. Data Security & Your Rights',
      'privacy_section_3_body':
          'All communication with our servers is encrypted using industry-standard SSL/TLS. You have full ownership of your data and can update or delete your profile at any time.',

      // Themes
      'theme_light': 'Light Mode',
      'theme_dark': 'Dark Mode',
      'theme_system': 'System Default',

      // Languages
      'lang_en': 'English',
      'lang_ar': 'العربية (Arabic)',

      // Profile Page
      'edit_profile': 'Edit Profile',
      'personal_info': 'Personal Information',
      'contact_info': 'Contact Details',
      'email_read_only_hint': 'Email is tied to your authentication account',
      'phone_number': 'Phone Number',
      'phone_number_hint': '+20 100 123 4567',
      'phone_number_invalid': 'Please enter a valid phone number',
      'job_title': 'Job Title / Profession',
      'job_title_hint': 'e.g. Software Engineer / Student',
      'bio': 'Bio / About Me',
      'bio_hint': 'Write a brief note about your goals or work...',
      'profile_updated_success': 'Profile updated successfully!',
      'profile_update_failed': 'Failed to update profile. Please try again.',
      'avatar_coming_soon': 'Custom avatar upload coming soon!',

      // Change Password Page
      'current_password': 'Current Password',
      'new_password': 'New Password',
      'confirm_new_password': 'Confirm New Password',
      'update_password_btn': 'Update Password',
      'password_updated_success': 'Your password was updated successfully!',
      'passwords_not_match': 'New passwords do not match.',
      'password_min_length': 'Password must be at least 8 characters.',
      'reauth_failed': 'Current password is incorrect.',
      'requires_recent_login':
          'This operation requires a recent login. Please log in again.',
    },
    'ar': {
      // App General
      'app_name': 'فوكسلي (Focusly)',
      'cancel': 'إلغاء',
      'save': 'حفظ',
      'save_changes': 'حفظ التغييرات',
      'close': 'إغلاق',
      'or': 'أو',
      'done': 'تم',
      'error': 'خطأ',
      'success': 'تم بنجاح',
      'coming_soon': 'قريباً في التحديث القادم!',

      // Splash Screen
      'splash_init_engine': '⚡ تهيئة محرك المهام الذكي...',
      'splash_sync_habits': '🔄 مزامنة العادات اليومية...',
      'splash_opt_workspace': '🎯 ضبط مساحة العمل والتركيز...',
      'splash_ready': '✨ مرحباً بك في Focusly!',

      // Onboarding Screen
      'onboarding_title_1': 'نظّم كل شيء',
      'onboarding_sub_1': 'سجّل مهامك، وحدد أولوياتك بذكاء، وتحكم في جدولك اليومي في مكان واحد.',
      'onboarding_title_2': 'ابنِ عادات أفضل',
      'onboarding_sub_2': 'طوّر روتينك اليومي مع متتبعات الستريك البصرية واحتفل بإنجازاتك المستمرة.',
      'onboarding_title_3': 'حافظ على تركيزك',
      'onboarding_sub_3': 'تخلص من المشتتات مع مؤقتات التركيز الذكية ومساحات العمل العميق.',
      'onboarding_title_4': 'تطور مع فريقك',
      'onboarding_sub_4': 'تعاون في الأهداف المشتركة وتابع إنتاجية الفريق لتحقيق المزيد معاً.',
      'next': 'التالي',
      'get_started': 'ابدأ الآن',
      'skip': 'تخطي',

      // Auth / Login Screen
      'welcome_back': 'مرحباً بعودتك',
      'login_subtitle': 'سجّل الدخول لمتابعة رحلة إنتاجيتك وتركيزك',
      'email': 'البريد الإلكتروني',
      'email_hint': 'name@example.com',
      'password': 'كلمة المرور',
      'password_hint': '••••••••••••',
      'remember_me': 'تذكرني',
      'forgot_password': 'نسيت كلمة المرور؟',
      'log_in': 'تسجيل الدخول',
      'continue_with_google': 'المتابعة باستخدام Google',
      'dont_have_account': 'ليس لديك حساب؟',
      'sign_up': 'إنشاء حساب جديد',
      'email_required': 'يرجى إدخال البريد الإلكتروني',
      'email_invalid': 'يرجى إدخال بريد إلكتروني صحيح',
      'password_required': 'يرجى إدخال كلمة المرور',
      'password_too_short': 'يجب ألا تقل كلمة المرور عن 6 خانات',
      'login_failed': 'البريد الإلكتروني أو كلمة المرور غير صحيحة.',
      'user_disabled': 'تم تعطيل هذا الحساب.',
      'too_many_requests': 'محاولات خاطئة كثيرة. يرجى المحاولة لاحقاً.',

      // Signup Screen
      'create_account': 'إنشاء حساب جديد',
      'signup_subtitle': 'ابدأ تنظيم مهامك وبناء عاداتك الإنتاجية اليوم',
      'full_name': 'الاسم بالكامل',
      'full_name_hint': 'بافلي باسم',
      'full_name_required': 'يرجى إدخال الاسم بالكامل',
      'confirm_password': 'تأكيد كلمة المرور',
      'confirm_password_hint': 'أعد كتابة كلمة المرور',
      'confirm_password_required': 'يرجى تأكيد كلمة المرور',
      'passwords_dont_match': 'كلمات المرور غير متطابقة',
      'terms_agreement': 'أوافق على شروط الخدمة وسياسة الخصوصية',
      'terms_required': 'يجب الموافقة على الشروط وسياسة الخصوصية للمتابعة',
      'already_have_account': 'لديك حساب بالفعل؟',
      'signup_failed': 'فشل إنشاء الحساب. يرجى المحاولة مرة أخرى.',
      'email_already_in_use': 'البريد الإلكتروني مسجل بالفعل بحساب آخر.',
      'weak_password': 'كلمة المرور ضعيفة جداً. استخدم 8 خانات على الأقل.',

      // Home Screen
      'hello_greeting': 'أهلاً',
      'there': 'بك',
      'home': 'الرئيسية',
      'tasks': 'المهام',
      'habits': 'العادات',
      'profile': 'الملف الشخصي',
      'settings': 'الإعدادات',
      'focus_workspace_ready': '✨ مساحة العمل جاهزة • وضع التركيز العميق',

      // Tasks Feature
      'all_tasks': 'الكل',
      'tasks_pending': 'متبقية',
      'tasks_completed': 'مكتملة',
      'list_view': 'قائمة',
      'matrix_view': 'المصفوفة',
      'add_task': 'إضافة مهمة',
      'new_task': 'مهمة جديدة',
      'edit_task': 'تعديل المهمة',
      'delete_task': 'حذف المهمة',
      'delete_task_confirm_title': 'حذف المهمة',
      'delete_task_confirm_message': 'هل أنت متأكد من رغبتك في حذف هذه المهمة؟',
      'task_title_hint': 'ما الذي تود إنجازه اليوم؟',
      'task_title_required': 'يرجى إدخال عنوان المهمة',
      'task_notes_hint': 'أضف ملاحظات أو تفاصيل إضافية (اختياري)...',
      'quick_quadrant_select': 'تحديد المربع في المصفوفة سريعاً',
      'category': 'التصنيف',
      'priority': 'الأولوية',
      'priority_high': 'عالية',
      'priority_medium': 'متوسطة',
      'priority_low': 'منخفضة',
      'date': 'التاريخ',
      'today': 'اليوم',
      'time': 'الوقت',
      'all_day': 'طوال اليوم',
      'deadline': 'الموعد النهائي',
      'no_deadline': 'بدون موعد نهائي',
      'create_task': 'إنشاء المهمة',
      'update_task': 'تحديث المهمة',
      'subtasks': 'المهام الفرعية',
      'add_subtask_hint': 'إضافة مهمة فرعية...',
      'no_tasks_title': 'لا توجد مهام هنا بعد',
      'no_tasks_subtitle': 'اضغط على زر (+) لإنشاء أول مهمة وابدأ يومك بإنتاجية وتركيز!',
      'delete': 'حذف',
      'add': 'إضافة',

      // Categories
      'category_work': 'العمل',
      'category_study': 'الدراسة',
      'category_health': 'الصحة',
      'category_personal': 'شخصي',
      'category_courses': 'الكورسات',
      'category_training': 'التدريب',
      'add_category_title': 'إضافة تصنيف جديد',
      'category_name_hint': 'اسم التصنيف',
      'select_color': 'اختر لون التصنيف',

      // Eisenhower Matrix
      'matrix_q1_title': 'افعل الآن',
      'matrix_q1_sub': 'عاجل وهام',
      'matrix_q1_empty': '🎉 تم إنجاز جميع المهام العاجلة والهامة!',
      'matrix_q2_title': 'جدوِل',
      'matrix_q2_sub': 'هام وغير عاجل',
      'matrix_q2_empty': '📅 خطط لأهدافك وعاداتك بعيدة المدى هنا',
      'matrix_q3_title': 'فوّض',
      'matrix_q3_sub': 'عاجل وغير هام',
      'matrix_q3_empty': '🤝 فوّض أو قلل من المقاطعات والمهام العاجلة',
      'matrix_q4_title': 'احذف',
      'matrix_q4_sub': 'غير عاجل وغير هام',
      'matrix_q4_empty': '✨ مساحة نظيفة! تخلص من مضيعات الوقت',
      'task_moved_to': 'تم نقل المهمة إلى',

      // Notifications
      'notification_task_time_title': '⚡ حان موعد مهمتك!',
      'notification_deadline_24h_title': '⚠️ الموعد النهائي غداً!',
      'notification_deadline_1h_title': '🚨 متبقي ساعة واحدة على الموعد النهائي!',

      // Schedule & Calendar Feature
      'schedule': 'الجدول',
      'events_count': 'أحداث',
      'view_month': 'الشهر',
      'view_week': 'الأسبوع',
      'view_day': 'اليوم',
      'add_event': 'إضافة حدث',
      'new_event': 'حدث جديد',
      'edit_event': 'تعديل الحدث',
      'delete_event': 'حذف الحدث',
      'event_title_hint': 'عنوان الحدث (مثال: محاضرة فلاتر / تمرين)',
      'event_title_required': 'يرجى إدخال عنوان الحدث',
      'event_type': 'نوع الحدث',
      'event_note_hint': 'أضف تفاصيل، مكان، أو ملاحظات (اختياري)...',
      'recurrence': 'التكرار',
      'recurrence_none': 'لا يتكرر',
      'recurrence_daily': 'يومياً',
      'recurrence_weekly': 'أسبوعياً',
      'recurrence_monthly': 'شهرياً',
      'recurrence_weekdays': 'أيام العمل (إثنين - جمعة)',
      'recurrence_end': 'تاريخ انتهاء التكرار',
      'never_ends': 'مستمر دائماً',
      'create_event': 'إنشاء الحدث',
      'update_event': 'تحديث الحدث',
      'no_events_today': 'لا توجد أحداث مجدولة لهذا اليوم',
      'no_events_agenda_subtitle': 'استمتع بوقتك الحر أو اضغط (+) لجدولة حدث جديد!',
      'delete_event_confirm_title': 'حذف الحدث',
      'delete_event_confirm_message': 'هل أنت متأكد من رغبتك في حذف هذا الحدث؟',
      'delete_recurring_event_confirm_message': 'سيتم حذف جميع التكرارات القادمة لهذا الحدث. هل أنت متأكد؟',
      'edit_recurring_title': 'تعديل حدث متكرر',
      'edit_recurring_prompt': 'هل تريد تعديل جميع تكرارات هذا الحدث أم هذا الموعد فقط؟',
      'edit_all_occurrences': 'تعديل كل التكرارات',
      'edit_this_occurrence_only': 'هذا الموعد فقط',
      'add_event_type_title': 'إضافة نوع حدث جديد',
      'event_type_name_hint': 'اسم النوع',
      'type_course_study': 'كورس / دراسة',
      'type_training_sport': 'تدريب / رياضة',
      'type_work_meeting': 'عمل / اجتماع',
      'type_personal': 'شخصي',
      'type_exam': 'امتحان',
      'type_important_urgent': 'هام / عاجل',
      'notification_event_title': '📅 تذكير بموعد حدث قادم!',

      // Habits Feature
      'habits_subtitle': 'ابنِ عاداتك وواظب على أهدافك اليومية',
      'total_habits': 'إجمالي العادات',
      'longest_streak': 'أطول ستريك',
      'total_streak_days': 'مجموع الأيام',
      'days_streak': 'أيام ستريك',
      'add_habit': 'إضافة عادة',
      'new_habit': 'عادة جديدة',
      'edit_habit': 'تعديل العادة',
      'delete_habit': 'حذف العادة',
      'habit_title_hint': 'عنوان العادة (مثال: قراءة ١٥ دقيقة / شرب ماء)',
      'habit_title_required': 'يرجى إدخال عنوان العادة',
      'stack_trigger_title': 'ربط العادة بروتين يومي (اختياري)',
      'stack_trigger_hint': 'مثال: فور الانتهاء من قهوة الصباح',
      'stack_trigger_help':
          'ربط العادات هو أسلوب لربط العادة الجديدة بروتين يومي معتاد لتثبيتها بسهولة وتلقائية.',
      'reminder_time_optional': 'وقت التذكير اليومي (اختياري)',
      'no_reminder_set': 'لم يتم ضبط تذكير',
      'set_time': 'تحديد الوقت',
      'advanced_options': 'خيارات متقدمة وإعادة الضبط',
      'auto_reset_title': 'الترحيل التلقائي الأسبوعي',
      'auto_reset_desc': 'حساب وترحيل أيام الستريك تلقائياً كل أسبوع',
      'create_habit': 'إنشاء العادة',
      'update_habit': 'تحديث العادة',
      'delete_habit_confirm_title': 'حذف العادة',
      'delete_habit_confirm_message':
          'هل أنت متأكد من رغبتك في حذف هذه العادة وسجل الستريك الخاص بها؟',
      'no_habits_yet': 'لا توجد عادات بعد',
      'no_habits_subtitle':
          'ابدأ بخطوة بسيطة وابنِ زخماً لا يتوقف مع الستريك اليومي!',
      'habit_added_success': 'تم إنشاء العادة بنجاح!',
      'habit_updated_success': 'تم تحديث العادة بنجاح!',
      'habit_deleted_success': 'تم حذف العادة بنجاح!',
      'habit_error_saving': 'حدث خطأ أثناء حفظ العادة. يرجى المحاولة مرة أخرى.',
      'habit_error_deleting': 'حدث خطأ أثناء حذف العادة. يرجى المحاولة مرة أخرى.',
      'notification_habit_title': '🔥 تذكير بموعد عادتك اليومية!',

      // Pomodoro Feature
      'pomodoro': 'المؤقت والتركيز',
      'pomodoro_subtitle': 'دورات التركيز والعمل العميق',
      'focus_time': 'وقت التركيز',
      'short_break': 'استراحة قصيرة',
      'long_break': 'استراحة طويلة',
      'start': 'بدء',
      'pause': 'إيقاف مؤقت',
      'reset': 'إعادة ضبط',
      'distraction': 'تشتت',
      'distractions': 'تشتتات',
      'select_task_for_session': 'ربط مهمة بهذه الجلسة',
      'link_task_optional': 'ربط بمهمة (اختياري)',
      'generic_focus_session': 'جلسة تركيز عامة',
      'no_active_tasks': 'لا توجد مهام نشطة حالياً للربط بها',
      'focus_sessions_today': 'جلسات اليوم',
      'minutes_focused_today': 'دقيقة تركيز اليوم',
      'weekly_focus_activity': 'نشاط التركيز الأسبوعي',
      'best_day_callout_prefix': 'أفضل يوم لك كان',
      'best_day_callout_suffix': 'بمجموع',
      'pomodoro_settings': 'إعدادات المؤقت والتركيز',
      'focus_duration': 'مدة جلسة التركيز',
      'short_break_duration': 'مدة الاستراحة القصيرة',
      'long_break_duration': 'مدة الاستراحة الطويلة',
      'long_break_interval': 'عدد الجلسات قبل الاستراحة الطويلة',
      'auto_start_phases': 'البدء التلقائي للمرحلة التالية',
      'auto_start_phases_desc':
          'بدء العد التنازلي تلقائياً فور انتهاء كل مرحلة',
      'save_settings': 'حفظ الإعدادات',
      'sessions': 'جلسات',
      'minutes_short': 'دقيقة',
      'notification_work_done_title':
          'انتهت جلسة التركيز! حان وقت الاستراحة ☕',
      'notification_break_done_title':
          'انتهت الاستراحة! جاهز للعودة إلى التركيز؟ 🍅',

      // Progress & Achievements Feature
      'progress': 'التقدم والإنجازات',
      'progress_and_achievements': 'التقدم والإنجازات',
      'progress_subtitle': 'ارتقِ بمستواك وعزز إنتاجيتك اليومية',
      'tab_overview': 'نظرة عامة',
      'tab_achievements': 'الأوسمة والإنجازات',
      'level': 'المستوى',
      'total_xp': 'مجموع نقاط XP',
      'xp_to_next_level': 'نقطة للوصول للمستوى التالي',
      'max_level_reached': 'وصلت لأعلى مستوى 🔱',
      'stat_tasks_completed': 'المهام المكتملة',
      'focus_sessions': 'جلسات التركيز',
      'total_focus_time': 'إجمالي وقت التركيز',
      'weekly_productivity_score': 'معدل الإنتاجية الأسبوعي',
      'category_breakdown': 'توزيع الإنجاز حسب التصنيفات',
      'achievement_unlocked_title': 'تم فتح وسام جديد!',
      'unlocked': 'مكتمل',
      'locked': 'مقفل',

      // Level Titles
      'level_1_title': 'مبتدئ',
      'level_2_title': 'متعلم',
      'level_3_title': 'مجتهد',
      'level_4_title': 'منتج',
      'level_5_title': 'متميز',
      'level_6_title': 'خبير',
      'level_7_title': 'محترف',
      'level_8_title': 'أسطورة',
      'level_9_title': 'بطل الإنتاجية',
      'level_10_title': 'ماستر',
      'level_11_title': 'حكيم التقنية',
      'level_12_title': 'العليم',
      'level_13_title': 'المستنير',
      'level_14_title': 'البطل المغوار',
      'level_15_title': 'أمير الإنتاجية',
      'level_16_title': 'الملك',
      'level_17_title': 'الإمبراطور',
      'level_18_title': 'الخالد',
      'level_19_title': 'المتألق في الفضاء',
      'level_20_title': 'ما وراء الكون',

      // Achievement Categories
      'achieve_cat_tasks': 'المهام',
      'achieve_cat_habits': 'العادات',
      'achieve_cat_pomodoro': 'المؤقت والتركيز',
      'achieve_cat_events': 'الجدول والمواعيد',
      'achieve_cat_levels': 'النقاط والمستويات',
      'achieve_cat_organization': 'التنظيم والتصنيفات',
      'achieve_cat_special': 'إنجازات خاصة',

      // Achievement Items
      'achieve_task_first_title': 'الخطوة الأولى',
      'achieve_task_first_desc': 'أكملت أول مهمة لك بنجاح',
      'achieve_task_5_title': 'خماسية الإنتاج',
      'achieve_task_5_desc': 'أكملت 5 مهام',
      'achieve_task_10_title': 'انطلاقة قوية',
      'achieve_task_10_desc': 'أكملت 10 مهام',
      'achieve_task_25_title': 'ربع مئوية',
      'achieve_task_25_desc': 'أكملت 25 مهمة',
      'achieve_task_50_title': 'نصف مئوية الإنجاز',
      'achieve_task_50_desc': 'أكملت 50 مهمة',
      'achieve_task_100_title': 'مئوية العظماء',
      'achieve_task_100_desc': 'أكملت 100 مهمة',
      'achieve_task_create_20_title': 'مخطط بارع',
      'achieve_task_create_20_desc': 'أنشأت 20 مهمة في التطبيق',
      'achieve_task_subtask_title': 'تبسيط المهام',
      'achieve_task_subtask_desc': 'أضفت مهمة فرعية إلى إحدى المهام',

      'achieve_habit_first_title': 'عادة جديدة',
      'achieve_habit_first_desc': 'أنشأت أول عادة يومية لك',
      'achieve_habit_day_1_title': 'اليوم الأول',
      'achieve_habit_day_1_desc': 'أكملت عادة ليوم كامل',
      'achieve_habit_streak_3_title': 'شرارة الالتزام',
      'achieve_habit_streak_3_desc': 'بنيت ستريك متصل لمدة 3 أيام',
      'achieve_habit_streak_7_title': 'لا يمكن إيقافك',
      'achieve_habit_streak_7_desc': 'بنيت ستريك متصل لمدة 7 أيام',
      'achieve_habit_streak_14_title': 'العادة الماسية',
      'achieve_habit_streak_14_desc': 'بنيت ستريك متصل لمدة 14 يوماً',
      'achieve_habit_streak_30_title': 'سيد العادات',
      'achieve_habit_streak_30_desc': 'بنيت ستريك متصل لمدة 30 يوماً',
      'achieve_habit_create_5_title': 'بستان العادات',
      'achieve_habit_create_5_desc': 'أنشأت 5 عادات مختلفة',

      'achieve_pomodoro_first_title': 'التركيز الأول',
      'achieve_pomodoro_first_desc': 'أكملت أول جلسة بومودورو كاملة',
      'achieve_pomodoro_5_title': 'إيقاع التركيز',
      'achieve_pomodoro_5_desc': 'أكملت 5 جلسات تركيز',
      'achieve_pomodoro_10_title': 'التركيز الفائق',
      'achieve_pomodoro_10_desc': 'أكملت 10 جلسات تركيز',
      'achieve_pomodoro_25_title': 'حالة التدفق',
      'achieve_pomodoro_25_desc': 'أكملت 25 جلسة تركيز',
      'achieve_pomodoro_50_title': 'عملاق العمل العميق',
      'achieve_pomodoro_50_desc': 'أكملت 50 جلسة تركيز',
      'achieve_pomodoro_60m_title': 'ساعة القوة',
      'achieve_pomodoro_60m_desc': 'جمعت 60 دقيقة من التركيز العميق',
      'achieve_pomodoro_300m_title': 'معلم الزن',
      'achieve_pomodoro_300m_desc': 'جمعت 300 دقيقة من التركيز العميق',

      'achieve_event_first_title': 'أول موعد',
      'achieve_event_first_desc': 'جدولت أول حدث أو موعد في التقويم',
      'achieve_event_5_title': 'جدول منظم',
      'achieve_event_5_desc': 'جدولت 5 أحداث في التقويم',
      'achieve_event_20_title': 'مهندس الوقت',
      'achieve_event_20_desc': 'جدولت 20 حدثاً في التقويم',

      'achieve_xp_100_title': 'البرونزي XP',
      'achieve_xp_100_desc': 'جمعت 100 نقطة XP',
      'achieve_xp_500_title': 'الفضي XP',
      'achieve_xp_500_desc': 'جمعت 500 نقطة XP',
      'achieve_xp_1000_title': 'الذهبي XP',
      'achieve_xp_1000_desc': 'جمعت 1000 نقطة XP',
      'achieve_level_5_title': 'النجم الصاعد',
      'achieve_level_5_desc': 'وصلت إلى المستوى 5 (متميز)',
      'achieve_level_10_title': 'مستوى الماستر',
      'achieve_level_10_desc': 'وصلت إلى المستوى 10 (ماستر)',
      'achieve_level_20_title': 'أسطورة الكون',
      'achieve_level_20_desc': 'وصلت إلى المستوى 20 (ما وراء الكون)',

      'achieve_org_3_cat_title': 'تنوع الأهداف',
      'achieve_org_3_cat_desc': 'نظمت مهامك في 3 تصنيفات مختلفة',
      'achieve_org_5_cat_title': 'توازن الحياة',
      'achieve_org_5_cat_desc': 'نظمت مهامك في 5 تصنيفات مختلفة',
      'achieve_org_custom_cat_title': 'لمستك الخاصة',
      'achieve_org_custom_cat_desc': 'أنشأت تصنيفاً مخصصاً لمهامك',

      'achieve_night_owl_title': 'بومة الليل',
      'achieve_night_owl_desc': 'أضفت مهمة بعد منتصف الليل',
      'achieve_early_bird_title': 'طائر الصباح',
      'achieve_early_bird_desc': 'أضفت مهمة قبل الساعة 7 صباحاً',
      'achieve_perfect_week_title': 'أسبوع مثالي',
      'achieve_perfect_week_desc': 'أكملت مهاماً لمدة 7 أيام متتالية',

      // Settings Main
      'settings_title': 'الإعدادات',
      'account_section': 'الحساب',
      'profile_desc': 'إدارة وتعديل معلوماتك الشخصية',
      'change_password': 'تغيير كلمة المرور',
      'change_password_desc': 'تحديث وتأمين كلمة مرور حسابك',
      'preferences_section': 'التفضيلات',
      'language': 'اللغة',
      'theme': 'المظهر',
      'notifications': 'الإشعارات',
      'notifications_desc': 'التنبيهات اليومية وتنبيهات الستريك',
      'advanced_section': 'متقدم والتفضيلات',
      'connected_accounts': 'الحسابات المتصلة',
      'reminder_time': 'وقت التذكير الافتراضي',
      'reminder_time_desc': 'وقت إرسال تنبيهات المهام والعادات اليومية',
      'reminder_time_updated': 'تم تحديث وقت التذكير اليومي!',
      'font_size': 'حجم الخط',
      'font_size_small': 'صغير',
      'font_size_standard': 'قياسي',
      'font_size_large': 'كبير',
      'about_section': 'عن Focusly',
      'app_version': 'إصدار التطبيق',
      'terms_of_service': 'شروط الخدمة',
      'privacy_policy': 'سياسة الخصوصية',
      'rate_app': 'تقييم التطبيق',
      'rate_app_launching': 'جاري فتح صفحة التقييم...',
      'rate_app_error': 'تعذر فتح صفحة متجر التطبيقات.',
      'account_actions': 'إجراءات الحساب',
      'log_out': 'تسجيل الخروج',
      'log_out_confirm_title': 'تسجيل الخروج',
      'log_out_confirm_message':
          'هل أنت متأكد من رغبتك في تسجيل الخروج من Focusly؟',
      'delete_account': 'حذف الحساب',
      'delete_account_confirm_title': 'حذف الحساب نهائياً',
      'delete_account_confirm_message':
          'هذا الإجراء لا يمكن التراجع عنه. سيتم حذف جميع مهامك وعاداتك وبياناتك نهائياً.',

      // Legal Texts (Terms & Privacy)
      'legal_last_updated': 'آخر تحديث: أغسطس ٢٠٢٦',
      'terms_intro_text':
          'مرحباً بك في فوكسلي (Focusly). باستخدامك لتطبيقنا، فإنك توافق على شروط الخدمة هذه. يرجى قراءتها بعناية.',
      'terms_section_1_title': '١. حسابات المستخدمين والأمان',
      'terms_section_1_body':
          'أنت مسؤول عن الحفاظ على سرية بيانات تسجيل دخولك. وتوافق على إخطارنا فوراً بأي وصول غير مصرح به لحسابك.',
      'terms_section_2_title': '٢. الاستخدام المقبول',
      'terms_section_2_body':
          'تم تصميم Focusly لزيادة الإنتاجية وإدارة المهام وتتبع العادات الشخصية. توافق على عدم إساءة استخدام خدماتنا أو انتهاك القوانين.',
      'terms_section_3_title': '٣. تعديل وإنهاء الخدمة',
      'terms_section_3_body':
          'نحتفظ بالحق في تحسين وتحديث الميزات باستمرار. يمكنك إنهاء وحذف حسابك في أي وقت عبر شاشة الإعدادات.',
      'privacy_intro_text':
          'خصوصيتك أولويتنا القصوى. توضح سياسة الخصوصية هذه كيفية جمع بياناتك الإنتاجية وحمايتها داخل Focusly.',
      'privacy_section_1_title': '١. المعلومات التي نجمعها',
      'privacy_section_1_body':
          'نجمع فقط البيانات الأساسية اللازمة لتقديم الخدمة: اسمك، بريدك الإلكتروني، بيانات الاتصال الاختيارية، وقوائم مهامك وعاداتك.',
      'privacy_section_2_title': '٢. كيف نستخدم بياناتك',
      'privacy_section_2_body':
          'يتم تخزين بياناتك بأمان مشفر عبر Google Cloud Firebase وتستخدم حصرياً لمزامنة مساحة عملك عبر أجهزتك. نحن لا نبيع بياناتك الشخصية لأي طرف ثالث أبداً.',
      'privacy_section_3_title': '٣. أمان البيانات وحقوقك',
      'privacy_section_3_body':
          'جميع الاتصالات مع خوادمنا مشفرة وفق أعلى معايير الأمان (SSL/TLS). لديك كامل الأحقية في تعديل أو تصدير أو حذف بياناتك بالكامل في أي وقت.',

      // Themes
      'theme_light': 'الوضع الفاتح (Light)',
      'theme_dark': 'الوضع الداكن (Dark)',
      'theme_system': 'تلقائي حسب النظام',

      // Languages
      'lang_en': 'English',
      'lang_ar': 'العربية (Arabic)',

      // Profile Page
      'edit_profile': 'تعديل الملف الشخصي',
      'personal_info': 'المعلومات الشخصية',
      'contact_info': 'بيانات التواصل',
      'email_read_only_hint':
          'البريد الإلكتروني مرتبط بتسجيل الدخول ولا يمكن تعديله',
      'phone_number': 'رقم الهاتف',
      'phone_number_hint': '+20 100 123 4567',
      'phone_number_invalid': 'يرجى إدخال رقم هاتف صحيح',
      'job_title': 'المسمى الوظيفي / المهنة',
      'job_title_hint': 'مثال: مهندس برمجيات / مصمم واجهات',
      'bio': 'نبذة عني / السيرة الذاتية',
      'bio_hint': 'اكتب نبذة مختصرة عن أهدافك أو مجالك...',
      'profile_updated_success': 'تم تحديث الملف الشخصي بنجاح!',
      'profile_update_failed':
          'فشل تحديث الملف الشخصي. يرجى المحاولة مرة أخرى.',
      'avatar_coming_soon': 'خاصية رفع الصورة الشخصية قادمة قريباً!',

      // Change Password Page
      'current_password': 'كلمة المرور الحالية',
      'new_password': 'كلمة المرور الجديدة',
      'confirm_new_password': 'تأكيد كلمة المرور الجديدة',
      'update_password_btn': 'تحديث كلمة المرور',
      'password_updated_success': 'تم تحديث كلمة المرور بنجاح!',
      'passwords_not_match': 'كلمات المرور الجديدة غير متطابقة.',
      'password_min_length': 'يجب ألا تقل كلمة المرور عن 8 خانات.',
      'reauth_failed': 'كلمة المرور الحالية غير صحيحة.',
      'requires_recent_login':
          'هذه العملية الحساسة تتطلب تسجيل دخول حديث. يرجى تسجيل الدخول مجدداً.',
    },
  };

  /// Translates the given key or returns fallback
  String tr(String key) {
    final languageCode = locale.languageCode;
    return _localizedValues[languageCode]?[key] ??
        _localizedValues['en']?[key] ??
        key;
  }

  /// Formats date according to active locale
  String formatLocalizedDate(DateTime date) {
    if (locale.languageCode == 'ar') {
      final days = [
        'الإثنين',
        'الثلاثاء',
        'الأربعاء',
        'الخميس',
        'الجمعة',
        'السبت',
        'الأحد'
      ];
      final months = [
        'يناير',
        'فبراير',
        'مارس',
        'أبريل',
        'مايو',
        'يونيو',
        'يوليو',
        'أغسطس',
        'سبتمبر',
        'أكتوبر',
        'نوفمبر',
        'ديسمبر'
      ];
      final dayName = days[date.weekday - 1];
      final monthName = months[date.month - 1];

      // Convert number to eastern arabic numerals
      final arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
      final dayStr = date.day.toString().split('').map((char) {
        final digit = int.tryParse(char);
        return digit != null ? arabicDigits[digit] : char;
      }).join('');

      return '$dayName، $dayStr $monthName';
    } else {
      final days = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ];
      final months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December'
      ];
      final dayName = days[date.weekday - 1];
      final monthName = months[date.month - 1];
      return '$dayName, $monthName ${date.day}';
    }
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'ar'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsExtension on BuildContext {
  String tr(String key) => AppLocalizations.of(this).tr(key);
}
