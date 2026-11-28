import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../ui/ui.dart';

/// Supported athletic country code entry
class CountryCodeItem {
  final String name;
  final String dialCode;
  final String isoCode;
  final String flagEmoji;

  const CountryCodeItem({
    required this.name,
    required this.dialCode,
    required this.isoCode,
    required this.flagEmoji,
  });
}

/// Curated list of popular athletic running regions
const List<CountryCodeItem> kSupportedCountryCodes = [
  CountryCodeItem(
    name: 'India',
    dialCode: '+91',
    isoCode: 'IN',
    flagEmoji: '🇮🇳',
  ),
  CountryCodeItem(
    name: 'United States',
    dialCode: '+1',
    isoCode: 'US',
    flagEmoji: '🇺🇸',
  ),
  CountryCodeItem(
    name: 'United Kingdom',
    dialCode: '+44',
    isoCode: 'GB',
    flagEmoji: '🇬🇧',
  ),
  CountryCodeItem(
    name: 'Kenya',
    dialCode: '+254',
    isoCode: 'KE',
    flagEmoji: '🇰🇪',
  ),
  CountryCodeItem(
    name: 'Ethiopia',
    dialCode: '+251',
    isoCode: 'ET',
    flagEmoji: '🇪🇹',
  ),
  CountryCodeItem(
    name: 'Canada',
    dialCode: '+1',
    isoCode: 'CA',
    flagEmoji: '🇨🇦',
  ),
  CountryCodeItem(
    name: 'Australia',
    dialCode: '+61',
    isoCode: 'AU',
    flagEmoji: '🇦🇺',
  ),
  CountryCodeItem(
    name: 'Germany',
    dialCode: '+49',
    isoCode: 'DE',
    flagEmoji: '🇩🇪',
  ),
  CountryCodeItem(
    name: 'Japan',
    dialCode: '+81',
    isoCode: 'JP',
    flagEmoji: '🇯🇵',
  ),
  CountryCodeItem(
    name: 'France',
    dialCode: '+33',
    isoCode: 'FR',
    flagEmoji: '🇫🇷',
  ),
  CountryCodeItem(
    name: 'United Arab Emirates',
    dialCode: '+971',
    isoCode: 'AE',
    flagEmoji: '🇦🇪',
  ),
  CountryCodeItem(
    name: 'Singapore',
    dialCode: '+65',
    isoCode: 'SG',
    flagEmoji: '🇸🇬',
  ),
  CountryCodeItem(
    name: 'Netherlands',
    dialCode: '+31',
    isoCode: 'NL',
    flagEmoji: '🇳🇱',
  ),
  CountryCodeItem(
    name: 'Spain',
    dialCode: '+34',
    isoCode: 'ES',
    flagEmoji: '🇪🇸',
  ),
  CountryCodeItem(
    name: 'Brazil',
    dialCode: '+55',
    isoCode: 'BR',
    flagEmoji: '🇧🇷',
  ),
];

/// Displays bottom sheet allowing athlete to pick country code
Future<CountryCodeItem?> showCountryCodePickerSheet(BuildContext context) {
  return AppSheet.show<CountryCodeItem>(
    context: context,
    builder: (ctx) => const _CountryPickerSheet(),
  );
}

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet();

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<CountryCodeItem> _filtered = kSupportedCountryCodes;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearch);
  }

  void _onSearch() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = kSupportedCountryCodes;
      } else {
        _filtered = kSupportedCountryCodes.where((c) {
          return c.name.toLowerCase().contains(q) ||
              c.dialCode.contains(q) ||
              c.isoCode.toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      padding: const EdgeInsets.all(AppSpacing.s20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Select Country Code',
                style: AppText.titleLarge.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close_rounded, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          TextField(
            controller: _searchController,
            style: AppText.bodyMedium.copyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search country or dialing code...',
              hintStyle: AppText.bodyMedium.copyWith(
                color: AppColors.textMuted,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: AppColors.textSecondary,
              ),
              filled: true,
              fillColor: AppColors.surface2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14.0,
                vertical: 12.0,
              ),
            ),
          ),
          const SizedBox(height: 14.0),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _filtered.length,
              separatorBuilder: (ctx, i) => Divider(
                height: 1.0,
                color: AppColors.borderSubtle.withValues(alpha: 0.5),
              ),
              itemBuilder: (ctx, i) {
                final item = _filtered[i];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 2.0,
                  ),
                  leading: Text(item.flagEmoji, style: AppText.titleLarge),
                  title: Text(
                    item.name,
                    style: AppText.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: Text(
                    item.dialCode,
                    style: AppText.labelLarge.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () => Navigator.of(context).pop(item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Formatter that automatically groups digits cleanly (e.g. 89200 47823)
class AthletePhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (i == 5 || i == 10)) {
        buffer.write(' ');
      }
      buffer.write(digits[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
