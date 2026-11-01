// Ported narrowly from BusyMax's lib/src/l10n/app_locale.dart at
// bf98600229d803f24ca5295e408379d1537aad08. See third_party/BUSYMAX_NOTICE.
import 'package:flutter/widgets.dart';
import '../../l10n/generated/app_localizations.dart';

// The generator requires a base pt catalog for pt_PT. Expose the same
// European Portuguese support as BusyMax without silently selecting it for BR.
final busyDataSupportedLocales = AppLocalizations.supportedLocales
    .where(
      (locale) => locale.languageCode != 'pt' || locale.countryCode == 'PT',
    )
    .toList(growable: false);

const _traditionalChineseRegions = {'HK', 'MO', 'TW'};
const _simplifiedChineseRegions = {'CN', 'MY', 'SG'};

/// BusyMark's supported-tag normalization, using BusyData's locale policy.
/// Persist only selectable tags; regional variants resolve to their supported
/// language/script. Unsupported or malformed preferences mean System.
String? normalizeBusyDataLocaleTag(String? tag) {
  if (tag == null || tag.length > 24) return null;
  final parts = tag.trim().replaceAll('_', '-').split('-');
  if (parts.isEmpty || !RegExp(r'^[A-Za-z]{2,3}$').hasMatch(parts.first)) {
    return null;
  }
  final language = parts.first.toLowerCase();
  String? script, country;
  for (final part in parts.skip(1)) {
    if (script == null &&
        country == null &&
        RegExp(r'^[A-Za-z]{4}$').hasMatch(part)) {
      script = '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}';
    } else if (country == null &&
        RegExp(r'^(?:[A-Za-z]{2}|[0-9]{3})$').hasMatch(part)) {
      country = part.toUpperCase();
    } else {
      return null;
    }
  }
  if (language == 'pt' && country != 'PT') return null;
  if (!busyDataSupportedLocales.any(
    (locale) => locale.languageCode == language,
  )) {
    return null;
  }
  final parsed = _normalizeChineseLocale(
    Locale.fromSubtags(
      languageCode: language,
      scriptCode: script,
      countryCode: country,
    ),
  );
  return busyDataSupportedLocales
          .where((locale) => locale == parsed)
          .firstOrNull
          ?.toLanguageTag() ??
      busyDataSupportedLocales
          .where(
            (locale) =>
                locale.languageCode == language &&
                (parsed.scriptCode == null ||
                    locale.scriptCode == parsed.scriptCode),
          )
          .firstOrNull
          ?.toLanguageTag();
}

Locale? busyDataLocaleFromTag(String? tag) {
  final normalized = normalizeBusyDataLocaleTag(tag);
  return busyDataSupportedLocales
      .where((locale) => locale.toLanguageTag() == normalized)
      .firstOrNull;
}

Locale resolveBusyDataLocales(
  List<Locale>? requestedLocales,
  Iterable<Locale> supportedLocales,
) {
  final supported = supportedLocales.toList(growable: false);
  if (supported.isEmpty) return const Locale('en');
  final english = supported.cast<Locale?>().firstWhere(
    (locale) => locale?.languageCode == 'en',
    orElse: () => null,
  );
  final orderedSupported = <Locale>[
    ?english,
    for (final locale in supported)
      if (locale != english) locale,
  ];
  final normalizedRequested = requestedLocales
      ?.map(_normalizeChineseLocale)
      .where(
        (locale) => locale.languageCode != 'pt' || locale.countryCode == 'PT',
      )
      .toList(growable: false);
  return basicLocaleListResolution(normalizedRequested, orderedSupported);
}

Locale _normalizeChineseLocale(Locale locale) {
  if (locale.languageCode.toLowerCase() != 'zh' || locale.scriptCode != null) {
    return locale;
  }
  final region = locale.countryCode?.toUpperCase();
  if (_traditionalChineseRegions.contains(region)) {
    return const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
  }
  if (_simplifiedChineseRegions.contains(region)) {
    return const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans');
  }
  return locale;
}

String busyDataLocaleLabel(Locale locale) => switch (locale.toLanguageTag()) {
  'en' => 'English',
  'de' => 'Deutsch',
  'ar' => 'العربية',
  'es' => 'Español',
  'et' => 'Eesti',
  'fa' => 'فارسی',
  'fi' => 'Suomi',
  'fr' => 'Français',
  'hi' => 'हिन्दी',
  'it' => 'Italiano',
  'ja' => '日本語',
  'ko' => '한국어',
  'pl' => 'Polski',
  'pt-PT' => 'Português (Portugal)',
  'ru' => 'Русский',
  'vi' => 'Tiếng Việt',
  'zh' || 'zh-Hans' => '简体中文',
  'zh-Hant' => '繁體中文',
  _ => locale.toLanguageTag(),
};
