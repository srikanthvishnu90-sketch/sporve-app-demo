import 'package:flutter/material.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../widgets/common_widgets.dart';
import '../controllers/search_provider.dart';

class FilterScreen extends StatefulWidget {
  const FilterScreen({super.key});

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  double _radius = 25;
  String _selectedSport = 'VOLLEYBALL';
  String? _sessionType; // null (any) | 'one_on_one' | 'group'
  num? _maxPrice; // null (any) | max dollars
  int? _age; // null (any) | representative athlete age
  String _selectedSkill = 'INTERMEDIATE';

  // A skill level maps to a soft (ranking-hint) attribute, never a hard filter.
  static const Map<String, String> _skillToSoft = {
    'BEGINNER': 'beginner-friendly',
    'INTERMEDIATE': 'intermediate',
    'ADVANCED': 'advanced',
    'ELITE': 'competitive',
  };

  @override
  void initState() {
    super.initState();
    // Round-trip with the AI constraint chips: seed the controls from whatever
    // the current search already resolved.
    final c = context.read<SearchProvider>().constraints;
    final sport = c['sport']?.toString();
    if (sport != null && sport.isNotEmpty) _selectedSport = sport.toUpperCase();
    final radius = c['radius_miles'];
    if (radius is num) _radius = radius.toDouble().clamp(0, 100);
    if (c['session_type'] is String) _sessionType = c['session_type'] as String;
    if (c['max_price'] is num) _maxPrice = c['max_price'] as num;
    if (c['athlete_age'] is num) _age = (c['athlete_age'] as num).toInt();
  }

  void _applyFilters() {
    final search = context.read<SearchProvider>();
    final existing =
        (search.constraints['soft_attributes'] as List?)?.map((e) => '$e') ??
        const <String>[];
    final soft = <String>{...existing};
    final skill = _skillToSoft[_selectedSkill];
    if (skill != null) soft.add(skill);

    search.applyConstraints({
      'sport': _selectedSport.toLowerCase(),
      'session_type': _sessionType,
      'max_price': _maxPrice,
      'athlete_age': _age,
      'radius_miles': _radius,
      'soft_attributes': soft.toList(),
    });
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Filters',
          style: AppTypography.font(
            color: AppColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SporveIconButton(
              Icons.close,
              semanticLabel: 'Close filters',
              onTap: () => Get.back(),
              color: AppColors.negative,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('SPORT'),
            const SizedBox(height: 16),
            _buildSportGrid(),
            const SizedBox(height: 32),
            _buildSectionTitle('SESSION TYPE'),
            const SizedBox(height: 16),
            _buildSessionTypes(),
            const SizedBox(height: 32),
            _buildSectionTitle('MAX PRICE'),
            const SizedBox(height: 16),
            _buildPriceChips(),
            const SizedBox(height: 32),
            _buildSectionTitle('ATHLETE AGE'),
            const SizedBox(height: 16),
            _buildAgeChips(),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionTitle('RADIUS'),
                Text(
                  '${_radius.toInt()} mi',
                  style: AppTypography.font(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.slateText,
                inactiveTrackColor: AppColors.hairline,
                thumbColor: AppColors.slateText,
                overlayColor: AppColors.slateTint,
              ),
              child: Slider(
                value: _radius,
                min: 0,
                max: 100,
                onChanged: (v) => setState(() => _radius = v),
              ),
            ),
            const SizedBox(height: 32),
            _buildSectionTitle('SKILL LEVEL'),
            const SizedBox(height: 16),
            _buildSkillLevels(),
            const SizedBox(height: 48),
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    _radius = 25;
                    _selectedSport = 'VOLLEYBALL';
                    _sessionType = null;
                    _maxPrice = null;
                    _age = null;
                    _selectedSkill = 'INTERMEDIATE';
                  }),
                  child: Text(
                    'CLEAR ALL',
                    style: AppTypography.font(
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _applyFilters,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.slateText,
                      foregroundColor: AppColors.onSlate,
                      minimumSize: const Size(double.infinity, 60),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.tile),
                      ),
                    ),
                    child: Text(
                      'APPLY FILTERS',
                      style: AppTypography.font(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTypography.font(
        color: AppColors.textTertiary,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildSportGrid() {
    final sports = [
      {'icon': Icons.sports_basketball, 'label': 'BASKETBALL'},
      {'icon': Icons.sports_soccer, 'label': 'SOCCER'},
      {'icon': Icons.sports_tennis, 'label': 'TENNIS'},
      {'icon': Icons.sports_football, 'label': 'FOOTBALL'},
      {'icon': Icons.pool, 'label': 'SWIMMING'},
      {'icon': Icons.sports_golf, 'label': 'GOLF'},
      {'icon': Icons.sports_baseball, 'label': 'BASEBALL'},
      {'icon': Icons.sports_volleyball, 'label': 'VOLLEYBALL'},
      {'icon': Icons.accessibility_new, 'label': 'GYMNASTICS'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: sports.length,
      itemBuilder: (context, index) {
        final sport = sports[index];
        bool isSelected = _selectedSport == sport['label'];
        return GestureDetector(
          onTap: () =>
              setState(() => _selectedSport = sport['label'] as String),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? AppColors.slateText : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.tile),
              border: Border.all(
                color: isSelected ? Colors.transparent : AppColors.hairline,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  sport['icon'] as IconData,
                  color: isSelected ? AppColors.onSlate : AppColors.textPrimary,
                  size: 24,
                ),
                const SizedBox(height: 8),
                Text(
                  sport['label'] as String,
                  style: AppTypography.font(
                    color: isSelected
                        ? AppColors.onSlate
                        : AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Generic selectable chip.
  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? AppColors.slateText : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.tile),
          border: Border.all(
            color: selected ? Colors.transparent : AppColors.hairline,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.font(
            color: selected ? AppColors.onSlate : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSessionTypes() {
    const options = <String, String?>{
      'ANY': null,
      'PRIVATE (1-ON-1)': 'one_on_one',
      'GROUP': 'group',
    };
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: options.entries
          .map((e) => _chip(
                e.key,
                _sessionType == e.value,
                () => setState(() => _sessionType = e.value),
              ))
          .toList(),
    );
  }

  Widget _buildPriceChips() {
    const options = <String, num?>{
      'ANY': null,
      'UNDER \$50': 50,
      'UNDER \$75': 75,
      'UNDER \$100': 100,
      'UNDER \$150': 150,
    };
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: options.entries
          .map((e) => _chip(
                e.key,
                _maxPrice == e.value,
                () => setState(() => _maxPrice = e.value),
              ))
          .toList(),
    );
  }

  Widget _buildAgeChips() {
    const options = <String, int?>{
      'ANY': null,
      'UNDER 8': 7,
      '8–12': 10,
      '13–18': 15,
    };
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: options.entries
          .map((e) => _chip(
                e.key,
                _age == e.value,
                () => setState(() => _age = e.value),
              ))
          .toList(),
    );
  }

  Widget _buildSkillLevels() {
    final levels = ['BEGINNER', 'INTERMEDIATE', 'ADVANCED', 'ELITE'];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.8,
      ),
      itemCount: levels.length,
      itemBuilder: (context, index) {
        final level = levels[index];
        bool isSelected = _selectedSkill == level;
        return GestureDetector(
          onTap: () => setState(() => _selectedSkill = level),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.slateText : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.tile),
              border: Border.all(
                color: isSelected ? Colors.transparent : AppColors.hairline,
              ),
            ),
            child: Text(
              level,
              style: AppTypography.font(
                color: isSelected ? AppColors.onSlate : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}
