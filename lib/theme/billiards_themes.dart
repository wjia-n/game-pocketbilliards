import 'package:flutter/material.dart';

/// Billiards-hall visual catalog: real wood rails, brass trim, felt cloth.
/// Every theme stays in a physical pool-hall world — no neon, no cyberpunk.
class BilliardThemeDef {
  final String id;
  final String name;
  final Color woodDark; // outer rail shadow
  final Color woodMid; // main rail wood
  final Color woodLight; // rail highlight
  final Color accent; // brass/chrome trim
  final Color accentLight;
  final Color accentDark;
  final Color ivory; // text / light details
  final Color felt; // playfield cloth
  final Color feltDark; // cloth shading edge
  final Color cushionTop; // cushion highlight
  final Color pocket; // pocket mouths

  const BilliardThemeDef({
    required this.id,
    required this.name,
    required this.woodDark,
    required this.woodMid,
    required this.woodLight,
    required this.accent,
    required this.accentLight,
    required this.accentDark,
    required this.ivory,
    required this.felt,
    required this.feltDark,
    required this.cushionTop,
    required this.pocket,
  });
}

class BilliardThemes {
  /// First 4 are FREE. Everything after is PRO.
  static const List<String> freeThemeIds = [
    'classic',
    'burgundy',
    'midnight',
    'rustic',
  ];

  static const List<BilliardThemeDef> all = [
    BilliardThemeDef(
      id: 'classic',
      name: 'Classic Hall',
      woodDark: Color(0xFF2A1708),
      woodMid: Color(0xFF5A3618),
      woodLight: Color(0xFF7D5228),
      accent: Color(0xFFC9A227),
      accentLight: Color(0xFFE8CE7A),
      accentDark: Color(0xFF8A6D1A),
      ivory: Color(0xFFF5EFE0),
      felt: Color(0xFF1E5B40),
      feltDark: Color(0xFF14402E),
      cushionTop: Color(0xFF2A7A55),
      pocket: Color(0xFF0B0B0D),
    ),
    BilliardThemeDef(
      id: 'burgundy',
      name: 'Burgundy Club',
      woodDark: Color(0xFF381408),
      woodMid: Color(0xFF6E2F1C),
      woodLight: Color(0xFF93502E),
      accent: Color(0xFFD4AF37),
      accentLight: Color(0xFFF3DC8E),
      accentDark: Color(0xFF96702A),
      ivory: Color(0xFFF8F1E2),
      felt: Color(0xFF6E1E28),
      feltDark: Color(0xFF4E141D),
      cushionTop: Color(0xFF8E2A36),
      pocket: Color(0xFF0D0B0C),
    ),
    BilliardThemeDef(
      id: 'midnight',
      name: 'Midnight League',
      woodDark: Color(0xFF101624),
      woodMid: Color(0xFF2C3A55),
      woodLight: Color(0xFF44587C),
      accent: Color(0xFFC0C6D4),
      accentLight: Color(0xFFE8ECF5),
      accentDark: Color(0xFF7E8698),
      ivory: Color(0xFFF2EEE4),
      felt: Color(0xFF1B3A5C),
      feltDark: Color(0xFF122741),
      cushionTop: Color(0xFF27517E),
      pocket: Color(0xFF08090C),
    ),
    BilliardThemeDef(
      id: 'rustic',
      name: 'Rustic Tavern',
      woodDark: Color(0xFF3E2A14),
      woodMid: Color(0xFF6E4E24),
      woodLight: Color(0xFF907040),
      accent: Color(0xFFB87333),
      accentLight: Color(0xFFE09E5A),
      accentDark: Color(0xFF7E4F22),
      ivory: Color(0xFFF1EAD8),
      felt: Color(0xFF4A5A2E),
      feltDark: Color(0xFF353F21),
      cushionTop: Color(0xFF61733C),
      pocket: Color(0xFF0B0A09),
    ),
    BilliardThemeDef(
      id: 'cherry',
      name: 'Cherrywood',
      woodDark: Color(0xFF3F1206),
      woodMid: Color(0xFF74281A),
      woodLight: Color(0xFF9A4A2E),
      accent: Color(0xFFC9A227),
      accentLight: Color(0xFFE8CE7A),
      accentDark: Color(0xFF8A6D1A),
      ivory: Color(0xFFF7EFE0),
      felt: Color(0xFF14532F),
      feltDark: Color(0xFF0E3A22),
      cushionTop: Color(0xFF1F7042),
      pocket: Color(0xFF0A0A0B),
    ),
    BilliardThemeDef(
      id: 'ebony',
      name: 'Ebony Pro',
      woodDark: Color(0xFF0C0C0E),
      woodMid: Color(0xFF232326),
      woodLight: Color(0xFF3A3A3E),
      accent: Color(0xFFC0C6D4),
      accentLight: Color(0xFFF0F2F8),
      accentDark: Color(0xFF7E8698),
      ivory: Color(0xFFF2EEE4),
      felt: Color(0xFF2E3440),
      feltDark: Color(0xFF1F242D),
      cushionTop: Color(0xFF434C5E),
      pocket: Color(0xFF050506),
    ),
    BilliardThemeDef(
      id: 'ivory',
      name: 'Ivory Ballroom',
      woodDark: Color(0xFF6E5A38),
      woodMid: Color(0xFF9A8256),
      woodLight: Color(0xFFBCA474),
      accent: Color(0xFF9A7B1E),
      accentLight: Color(0xFFD4AF37),
      accentDark: Color(0xFF6E5514),
      ivory: Color(0xFF2E2118),
      felt: Color(0xFF0F6E5A),
      feltDark: Color(0xFF0B4E40),
      cushionTop: Color(0xFF149078),
      pocket: Color(0xFF11100E),
    ),
    BilliardThemeDef(
      id: 'goldenoak',
      name: 'Golden Oak',
      woodDark: Color(0xFF4A3614),
      woodMid: Color(0xFF8A6A34),
      woodLight: Color(0xFFB08E4E),
      accent: Color(0xFF8C6A2F),
      accentLight: Color(0xFFD4A94E),
      accentDark: Color(0xFF5F471E),
      ivory: Color(0xFF2E2118),
      felt: Color(0xFF7A3A1E),
      feltDark: Color(0xFF552914),
      cushionTop: Color(0xFF9A4D28),
      pocket: Color(0xFF0D0B09),
    ),
    BilliardThemeDef(
      id: 'wine',
      name: 'Wine Cellar',
      woodDark: Color(0xFF180E18),
      woodMid: Color(0xFF3E1E3E),
      woodLight: Color(0xFF5E2E5E),
      accent: Color(0xFFD4AF37),
      accentLight: Color(0xFFF3DC8E),
      accentDark: Color(0xFF96702A),
      ivory: Color(0xFFF5EFE0),
      felt: Color(0xFF4A1E42),
      feltDark: Color(0xFF35152F),
      cushionTop: Color(0xFF612A58),
      pocket: Color(0xFF0B080C),
    ),
    BilliardThemeDef(
      id: 'forest',
      name: 'Forest Lodge',
      woodDark: Color(0xFF26201A),
      woodMid: Color(0xFF54402A),
      woodLight: Color(0xFF726044),
      accent: Color(0xFFC9A227),
      accentLight: Color(0xFFE8CE7A),
      accentDark: Color(0xFF8A6D1A),
      ivory: Color(0xFFF1EAD8),
      felt: Color(0xFF2F5A28),
      feltDark: Color(0xFF213F1C),
      cushionTop: Color(0xFF3E7536),
      pocket: Color(0xFF090A08),
    ),
    BilliardThemeDef(
      id: 'copper',
      name: 'Copper Line',
      woodDark: Color(0xFF241309),
      woodMid: Color(0xFF4A2E14),
      woodLight: Color(0xFF6E4A24),
      accent: Color(0xFFB87333),
      accentLight: Color(0xFFE09E5A),
      accentDark: Color(0xFF7E4F22),
      ivory: Color(0xFFF5EFE0),
      felt: Color(0xFF3F4A5E),
      feltDark: Color(0xFF2C3442),
      cushionTop: Color(0xFF56647E),
      pocket: Color(0xFF090A0B),
    ),
    BilliardThemeDef(
      id: 'rosewood',
      name: 'Rosewood',
      woodDark: Color(0xFF241016),
      woodMid: Color(0xFF4A1F28),
      woodLight: Color(0xFF68303C),
      accent: Color(0xFFC9A227),
      accentLight: Color(0xFFE8CE7A),
      accentDark: Color(0xFF8A6D1A),
      ivory: Color(0xFFF5EFE0),
      felt: Color(0xFF1E5B54),
      feltDark: Color(0xFF15403B),
      cushionTop: Color(0xFF2A766E),
      pocket: Color(0xFF0B090A),
    ),
    BilliardThemeDef(
      id: 'slate',
      name: 'Slate & Brass',
      woodDark: Color(0xFF1A1E26),
      woodMid: Color(0xFF363D4A),
      woodLight: Color(0xFF4E586A),
      accent: Color(0xFFC9A227),
      accentLight: Color(0xFFE8CE7A),
      accentDark: Color(0xFF8A6D1A),
      ivory: Color(0xFFECEFF4),
      felt: Color(0xFF4A6E62),
      feltDark: Color(0xFF354F46),
      cushionTop: Color(0xFF5E8E80),
      pocket: Color(0xFF07080A),
    ),
    BilliardThemeDef(
      id: 'charcoal',
      name: 'Charcoal Club',
      woodDark: Color(0xFF121212),
      woodMid: Color(0xFF2E2A26),
      woodLight: Color(0xFF463F38),
      accent: Color(0xFFB87333),
      accentLight: Color(0xFFE09E5A),
      accentDark: Color(0xFF7E4F22),
      ivory: Color(0xFFF0EBE0),
      felt: Color(0xFF8A2E20),
      feltDark: Color(0xFF611F16),
      cushionTop: Color(0xFFAE3C2A),
      pocket: Color(0xFF0A0908),
    ),
    BilliardThemeDef(
      id: 'sandalwood',
      name: 'Sandalwood',
      woodDark: Color(0xFF54402A),
      woodMid: Color(0xFF7D6440),
      woodLight: Color(0xFF9A825E),
      accent: Color(0xFF7A5A2E),
      accentLight: Color(0xFFC49A5A),
      accentDark: Color(0xFF54401E),
      ivory: Color(0xFF2E2118),
      felt: Color(0xFF2E6E5E),
      feltDark: Color(0xFF204E42),
      cushionTop: Color(0xFF3E8E7A),
      pocket: Color(0xFF100E0B),
    ),
    BilliardThemeDef(
      id: 'olive',
      name: 'Olive Grove',
      woodDark: Color(0xFF242614),
      woodMid: Color(0xFF4A4E2A),
      woodLight: Color(0xFF686E42),
      accent: Color(0xFFC9A227),
      accentLight: Color(0xFFE8CE7A),
      accentDark: Color(0xFF8A6D1A),
      ivory: Color(0xFFF1EAD8),
      felt: Color(0xFF6E7422),
      feltDark: Color(0xFF4E5218),
      cushionTop: Color(0xFF8E942E),
      pocket: Color(0xFF0A0B07),
    ),
  ];

  static BilliardThemeDef byId(String id, {BilliardThemeDef? custom}) {
    if (id == 'custom') return custom ?? all.first;
    return all.firstWhere((t) => t.id == id, orElse: () => all.first);
  }

  static bool isProTheme(String id) =>
      !freeThemeIds.contains(id) && id != 'custom';
}

/// Ball finishes — how the 16 balls are rendered. 0-3 FREE, 4+ PRO.
class BallStyles {
  static const names = [
    'Classic Gloss',
    'Tournament Pro',
    'Vintage Ivory',
    'Matte Club',
    'Pearl Sheen',
    'Marble Swirl',
    'Copper Shine',
    'Onyx & Gold',
  ];
  static const descriptions = [
    'High-gloss standard set',
    'Pro-tournament finish',
    'Aged ivory patina',
    'Soft matte club balls',
    'Pearly shimmer finish',
    'Swirled marble look',
    'Warm copper tint',
    'Dark onyx with gold',
  ];
  static const freeCount = 4;
  static bool isPro(int i) => i >= freeCount;
}

/// Cue stick finishes. 0-2 FREE, 3+ PRO.
class CueStyles {
  static const names = [
    'Maple Classic',
    'Dark Ebony',
    'Cherrywood',
    'Rosewood Inlay',
    'Carbon Pro',
    'Ivory Collar',
    'Brass Rings',
    'Golden Trim',
  ];
  static const descriptions = [
    'Natural maple shaft',
    'Sleek black ebony',
    'Warm cherrywood',
    'Rosewood with inlay',
    'Carbon-fiber pro',
    'Ivory collar detail',
    'Brass ring inlays',
    'Golden trim finish',
  ];
  static const freeCount = 3;
  static bool isPro(int i) => i >= freeCount;
}

/// Standard pool ball colors (1-15). Index by ball number.
Color ballColor(int n) {
  switch (n) {
    case 1:
    case 9:
      return const Color(0xFFE8B400);
    case 2:
    case 10:
      return const Color(0xFF1565C0);
    case 3:
    case 11:
      return const Color(0xFFD32F2F);
    case 4:
    case 12:
      return const Color(0xFF6A1B9A);
    case 5:
    case 13:
      return const Color(0xFFEF6C00);
    case 6:
    case 14:
      return const Color(0xFF2E7D32);
    case 7:
    case 15:
      return const Color(0xFF8D2B1B);
    case 8:
      return const Color(0xFF141414);
    default:
      return const Color(0xFFF5F2EA); // cue ball
  }
}
