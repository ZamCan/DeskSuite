import 'dart:convert';

import '../core/local_file_store.dart';

/// Currency labels for local transactions. These choices do not convert prices
/// or query exchange rates; the selected label is saved per sale.
class BusinessCurrency {
  const BusinessCurrency(this.code, this.name);
  final String code;
  final String name;
}

const supportedBusinessCurrencies = <BusinessCurrency>[
  BusinessCurrency('TSh', 'Tanzanian shilling (TSh)'),
  BusinessCurrency('USD', 'US dollar (USD)'),
  BusinessCurrency('KSh', 'Kenyan shilling (KSh)'),
  BusinessCurrency('USh', 'Ugandan shilling (USh)'),
  BusinessCurrency('RWF', 'Rwandan franc (RWF)'),
  BusinessCurrency('EUR', 'Euro (EUR)'),
  BusinessCurrency('GBP', 'Pound sterling (GBP)'),
];

bool isSupportedBusinessCurrency(String code) =>
    supportedBusinessCurrencies.any((item) => item.code == code);

class BusinessSettings {
  const BusinessSettings({this.currency = 'TSh'});
  final String currency;

  BusinessSettings copyWith({String? currency}) =>
      BusinessSettings(currency: currency ?? this.currency);

  factory BusinessSettings.fromJson(Map<String, dynamic> json) {
    final currency = json['currency'] as String? ?? 'TSh';
    if (!isSupportedBusinessCurrency(currency)) {
      throw const FormatException('Unsupported shop currency setting.');
    }
    return BusinessSettings(currency: currency);
  }

  Map<String, Object?> toJson() => {'currency': currency};
}

/// Stores catalogue currency beside local products. Old installs default to
/// TSh. Corrupt settings are reported rather than silently overwritten.
class BusinessSettingsRepository {
  BusinessSettingsRepository(this.files);
  final LocalFileStore files;
  Future<void> _tail = Future<void>.value();

  Future<BusinessSettings> load() async {
    final text = await files.readText('business-settings.json', '');
    if (text.trim().isEmpty) return const BusinessSettings();
    try {
      final value = jsonDecode(text);
      if (value is! Map) {
        throw const FormatException('Invalid business settings.');
      }
      return BusinessSettings.fromJson(Map<String, dynamic>.from(value));
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Invalid business settings.');
    }
  }

  Future<void> save(BusinessSettings settings) async {
    if (!isSupportedBusinessCurrency(settings.currency)) {
      throw const FormatException('Unsupported shop currency.');
    }
    final result = _tail.then(
      (_) => files.writeText(
        'business-settings.json',
        jsonEncode(settings.toJson()),
      ),
    );
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}
