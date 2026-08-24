import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../models/skill_model.dart';
import '../services/skills_service.dart';

/// Provider for SkillsService singleton.
final skillsServiceProvider = Provider<SkillsService>((ref) {
  return SkillsService();
});

/// Stream provider for all skills belonging to the authenticated user.
///
/// Strictly scoped to `users/{uid}/skills`.
final skillsStreamProvider = StreamProvider<List<SkillModel>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null || uid.isEmpty) return const Stream.empty();

  final service = ref.watch(skillsServiceProvider);
  return service.streamSkills(uid);
});
