import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import 'models/knowledge_entry_model.dart';
import 'providers/knowledge_base_provider.dart';
import 'widgets/entry_form_modal.dart';
import 'widgets/knowledge_entry_card.dart';

/// Main Knowledge Base repository screen with live search and type filter.
class KnowledgeBasePage extends ConsumerStatefulWidget {
  const KnowledgeBasePage({super.key});

  @override
  ConsumerState<KnowledgeBasePage> createState() => _KnowledgeBasePageState();
}

class _KnowledgeBasePageState extends ConsumerState<KnowledgeBasePage> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final inputBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);

    final allEntriesAsync = ref.watch(knowledgeEntriesStreamProvider);
    final filteredEntries = ref.watch(filteredKnowledgeEntriesProvider);
    final selectedType = ref.watch(knowledgeTypeFilterProvider);
    final searchQuery = ref.watch(knowledgeSearchQueryProvider);

    final List<Map<String, String>> typeOptions = [
      {'value': 'all', 'labelKey': 'filter_all_types'},
      {'value': 'note', 'labelKey': 'knowledge_type_note_opt'},
      {'value': 'idea', 'labelKey': 'knowledge_type_idea_opt'},
      {'value': 'quote', 'labelKey': 'knowledge_type_quote_opt'},
      {'value': 'link', 'labelKey': 'knowledge_type_link_opt'},
      {'value': 'summary', 'labelKey': 'knowledge_type_summary_opt'},
    ];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: primaryTextColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('knowledge_base_title'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
              ),
            ),
            Text(
              context.tr('knowledge_base_subtitle'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: secondaryTextColor,
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF2E6FF2)),
            tooltip: context.tr('add_knowledge_btn'),
            onPressed: () {
              HapticFeedback.selectionClick();
              EntryFormModal.show(context);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2E6FF2),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: Text(
          context.tr('add_knowledge_btn'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        onPressed: () {
          HapticFeedback.selectionClick();
          EntryFormModal.show(context);
        },
      ),
      body: allEntriesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF2E6FF2)),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              '${context.tr('error')}: $err',
              style: const TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ),
        data: (allEntries) {
          if (allEntries.isEmpty) {
            return _buildGlobalEmptyState(context, primaryTextColor, secondaryTextColor);
          }

          return Column(
            children: [
              // Top Toolbar: Search Bar + Type Filters
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0A1238) : Colors.white,
                  border: Border(bottom: BorderSide(color: borderColor)),
                ),
                child: Column(
                  children: [
                    // Search Bar
                    TextField(
                      controller: _searchController,
                      style: TextStyle(fontSize: 14, color: primaryTextColor),
                      decoration: InputDecoration(
                        hintText: context.tr('search_knowledge_hint'),
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: Color(0xFF2E6FF2),
                        ),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  ref
                                      .read(knowledgeSearchQueryProvider.notifier)
                                      .clear();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: inputBg,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFF2E6FF2), width: 1.8),
                        ),
                      ),
                      onChanged: (val) {
                        ref.read(knowledgeSearchQueryProvider.notifier).setQuery(val);
                      },
                    ),
                    const SizedBox(height: 10),

                    // Type Filter Pills
                    SizedBox(
                      height: 34,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: typeOptions.length,
                        itemBuilder: (context, index) {
                          final opt = typeOptions[index];
                          final isSelected = selectedType == opt['value'];
                          return Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                ref
                                    .read(knowledgeTypeFilterProvider.notifier)
                                    .setType(opt['value']!);
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF2E6FF2)
                                      : inputBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF2E6FF2) : borderColor,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    context.tr(opt['labelKey']!),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected ? Colors.white : secondaryTextColor,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Entries List Area
              Expanded(
                child: filteredEntries.isEmpty
                    ? _buildNoResultsState(context, primaryTextColor, secondaryTextColor)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
                        physics: const BouncingScrollPhysics(),
                        itemCount: filteredEntries.length,
                        itemBuilder: (context, index) {
                          return KnowledgeEntryCard(entry: filteredEntries[index]);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGlobalEmptyState(
    BuildContext context,
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF2E6FF2).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.collections_bookmark_rounded,
                  size: 40,
                  color: Color(0xFF2E6FF2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.tr('empty_knowledge_title'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('empty_knowledge_subtitle'),
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: secondaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E6FF2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              label: Text(
                context.tr('add_knowledge_btn'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              onPressed: () {
                HapticFeedback.selectionClick();
                EntryFormModal.show(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState(
    BuildContext context,
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: secondaryTextColor.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 14),
            Text(
              context.tr('no_knowledge_search_results'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr('no_knowledge_search_results_sub'),
              style: TextStyle(
                fontSize: 13,
                color: secondaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
