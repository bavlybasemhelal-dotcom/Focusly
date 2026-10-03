import 'package:flutter/material.dart';
import '../../core/platform/desktop_bridge.dart';

class DesktopSettingsCard extends StatefulWidget {
  const DesktopSettingsCard({super.key});
  @override
  State<DesktopSettingsCard> createState() => _DesktopSettingsCardState();
}

class _DesktopSettingsCardState extends State<DesktopSettingsCard> {
  Map<String, dynamic> settings = {};
  final hash = TextEditingController();
  String? result;
  bool saving = false;
  String t(String ar, String en) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (!DesktopBridge.available) return;
    final value = await DesktopBridge.request('settings');
    if (mounted) setState(() => settings = value);
  }

  @override
  void dispose() {
    hash.dispose();
    super.dispose();
  }

  Future<void> run(String operation, Map<String, dynamic> args) async {
    if (saving) return;
    setState(() => saving = true);
    try {
      final value = await DesktopBridge.request(operation, args);
      if (operation == 'releaseInfo' && mounted) {
        hash.text = value['sha256'] as String;
        setState(
          () => result = t(
            'أحدث إصدار منشور: ${value['version']}. استخدم ملف التثبيت وقارن البصمة.',
            'Latest published version: ${value['version']}. Select the installer and compare its hash.',
          ),
        );
      }
      if (operation == 'verifyInstaller' && mounted) {
        setState(
          () => result = value['cancelled'] == true
              ? null
              : value['matches'] == true
              ? t(
                  'البصمة مطابقة. شغّل ملف التثبيت لترقية البرنامج.',
                  'Hash matches. Run the installer to upgrade.',
                )
              : t(
                  'البصمة مختلفة. تأكد من ملف التثبيت والتقرير.',
                  'Hash does not match. Check the installer and report.',
                ),
        );
      }
      await load();
    } catch (_) {
      if (mounted) {
        setState(
          () => result = t(
            'تعذر تنفيذ الطلب. حاول مرة أخرى.',
            'Could not complete this request. Retry.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!DesktopBridge.available) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Focusly Windows ${settings['version'] ?? ''}'),
            SwitchListTile(
              title: Text(
                t('ابدأ مع Windows — اختياري', 'Start with Windows — optional'),
              ),
              value: settings['startup'] == true,
              onChanged: saving
                  ? null
                  : (value) => run('setStartup', {'enabled': value}),
            ),
            SwitchListTile(
              title: Text(
                t(
                  'خلي البرنامج في شريط النظام عند إغلاق النافذة',
                  'Keep running in tray when closing the window',
                ),
              ),
              value: settings['tray'] != false,
              onChanged: saving
                  ? null
                  : (value) => run('setTray', {'enabled': value}),
            ),
            Text(
              t(
                'للخروج الكامل استخدم «إغلاق البرنامج» في شريط النظام. التذكيرات المجدولة على Windows تستمر بعد الخروج؛ تجديد تكرارها يتم عند فتح البرنامج.',
                'Use Quit in the tray to exit. Windows scheduled reminders survive exit; their horizon renews when the app opens.',
              ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.system_update),
              label: Text(
                t('تحقق من معلومات الإصدار', 'Check release information'),
              ),
              onPressed: saving ? null : () => run('releaseInfo', {}),
            ),
            TextField(
              controller: hash,
              maxLength: 64,
              decoration: InputDecoration(
                labelText: t(
                  'SHA-256 من تقرير الإصدار للتحقق من التحديث',
                  'Release SHA-256 to verify an update',
                ),
              ),
            ),
            OutlinedButton(
              onPressed: saving
                  ? null
                  : () => run('verifyInstaller', {'sha256': hash.text.trim()}),
              child: Text(
                t(
                  'اختار ملف التثبيت وقارن البصمة',
                  'Select installer & compare hash',
                ),
              ),
            ),
            if (result != null) Text(result!),
          ],
        ),
      ),
    );
  }
}
