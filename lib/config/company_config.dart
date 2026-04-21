import 'package:flutter/material.dart';

/// Maps company codes to their branding config
class CompanyConfig {
  final String code;
  final String name;
  final String logoAsset;      // local asset path
  final Color primaryColor;
  final Color accentColor;

  const CompanyConfig({
    required this.code,
    required this.name,
    required this.logoAsset,
    required this.primaryColor,
    required this.accentColor,
  });

  static const Map<String, CompanyConfig> _configs = {
    'ASE': CompanyConfig(
      code: 'ASE',
      name: 'ASE Technologies',
      logoAsset: 'asserts/ase_tech.png',
      primaryColor: Color(0xFF1565C0),   // blue
      accentColor:  Color(0xFF1976D2),
    ),
    'ASE_TECH': CompanyConfig(
      code: 'ASE_TECH',
      name: 'ASE Technologies',
      logoAsset: 'asserts/ase_tech.png',
      primaryColor: Color(0xFF1565C0),
      accentColor:  Color(0xFF1976D2),
    ),
    'ESWARI': CompanyConfig(
      code: 'ESWARI',
      name: 'Eswari Group',
      logoAsset: 'asserts/eswari.png',
      primaryColor: Color(0xFF2E7D32),   // green
      accentColor:  Color(0xFF388E3C),
    ),
    'ESWARI_GROUP': CompanyConfig(
      code: 'ESWARI_GROUP',
      name: 'Eswari Group',
      logoAsset: 'asserts/eswari.png',
      primaryColor: Color(0xFF2E7D32),
      accentColor:  Color(0xFF388E3C),
    ),
    'ESWARI_CAP': CompanyConfig(
      code: 'ESWARI_CAP',
      name: 'Eswari Capital',
      logoAsset: 'asserts/eswari.png',
      primaryColor: Color(0xFF6A1B9A),   // purple
      accentColor:  Color(0xFF7B1FA2),
    ),
  };

  /// Get config by company code, fallback to default
  static CompanyConfig get(String? code) {
    return _configs[code] ?? _default;
  }

  static const CompanyConfig _default = CompanyConfig(
    code: '',
    name: 'Eswari Connects',
    logoAsset: 'asserts/eswari.png',
    primaryColor: Color(0xFF1A237E),
    accentColor:  Color(0xFF3949AB),
  );
}
