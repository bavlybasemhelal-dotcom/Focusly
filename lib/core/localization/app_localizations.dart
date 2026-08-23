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
