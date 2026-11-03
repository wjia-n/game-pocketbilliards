import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/billiards_themes.dart';
import '../theme/felt_ui.dart';

/// Pocket Billiards PRO: Free-vs-Pro comparison, real purchase, restore,
/// and tip jar. Prices come from the store — never hardcoded.
class ProScreen extends StatefulWidget {
  final BilliardAudio audio;
  final BilliardSettings settings;
  final StoreService store;

  const ProScreen({
    super.key,
    required this.audio,
    required this.settings,
    required this.store,
  });

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  BilliardThemeDef get _t => BilliardThemes.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );

  @override
  void initState() {
    super.initState();
    widget.store.lastThanks.addListener(_onThanks);
  }

  
  void _onThanks() {
    final msg = widget.store.lastThanks.value;
    if (msg == null || !mounted) return;
    widget.audio.win();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: Felt.body(15, theme: _t)),
        backgroundColor: _t.woodDark,
        behavior: SnackBarBehavior.floating,
      ),
    );
    widget.store.lastThanks.value = null;
  }

  @override
  void dispose() {
    widget.store.lastThanks.removeListener(_onThanks);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _IosGoldStarScreen(store: widget.store);
    }
    final t = _t;
    final s = widget.settings;
    final store = widget.store;
    return Felt.backdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: t.accentLight),
            onPressed: () {
              widget.audio.click();
              Navigator.of(context).pop();
            },
          ),
          title: Text('Pocket Billiards PRO', style: Felt.display(20, theme: t)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: s,
            builder: (_, _) => SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              child: Column(
                children: [
                                    _TipsCard(
                    theme: t,
                    store: store,
                    audio: widget.audio,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------


// ---------------------------------------------------------------------------
class _TipsCard extends StatelessWidget {
  final BilliardThemeDef theme;
  final StoreService store;
  final BilliardAudio audio;
  const _TipsCard(
      {required this.theme, required this.store, required this.audio});

  @override
  Widget build(BuildContext context) {
    final tips = [
      store.coffeeProduct,
      store.chocolateProduct,
    ].whereType<ProductDetails>().toList();
    return Felt.card(
      theme: theme,
      child: Column(
        children: [
          Text('Tip the Maker', style: Felt.display(20, theme: theme)),
          const SizedBox(height: 8),
          Text(
            'Pocket Billiards is free forever. A small tip keeps new games coming!',
            style: Felt.body(14, theme: theme),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          if (!store.storeReady)
            Text(
              store.error ?? 'Available after store setup.',
              style: Felt.body(13,
                  theme: theme,
                  color: theme.ivory.withValues(alpha: 0.6)),
              textAlign: TextAlign.center,
            )
          else if (tips.isEmpty)
            Text('Tips coming soon.',
                style: Felt.body(13,
                    theme: theme,
                    color: theme.ivory.withValues(alpha: 0.6)))
          else
            Wrap(
              spacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (final p in tips)
                  _TipChip(
                    theme: theme,
                    label:
                        '${p.id == StoreService.chocolateId ? '🍫' : '☕'} ${p.price}',
                    onTap: () {
                      audio.click();
                      store.buyTip(p);
                    },
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TipChip extends StatelessWidget {
  final BilliardThemeDef theme;
  final String label;
  final VoidCallback onTap;
  const _TipChip(
      {required this.theme, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.black.withValues(alpha: 0.3),
          border:
              Border.all(color: theme.accent.withValues(alpha: 0.6), width: 1.5),
        ),
        child: Text(label, style: Felt.label(14, theme: theme)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// iOS-only Gold Star screen: exactly one button, plus a badge once owned.
/// The game stays fully unlocked; the star is cosmetic only.
/// Android keeps the original screen below, byte-identical.
class _IosGoldStarScreen extends StatelessWidget {
  final StoreService store;
  const _IosGoldStarScreen({required this.store});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Gold Star'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('⭐', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 12),
                const Text(
                  'This game is fully unlocked.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<bool>(
                  valueListenable: store.goldStarOwned,
                  builder: (_, owned, _) => Text(
                    owned
                        ? '⭐ Gold Star earned — thank you!'
                        : 'Get a Gold Star!',
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                if (!store.storeReady)
                  Text(store.error ?? 'Available after store setup.',
                      textAlign: TextAlign.center)
                else if (store.starProduct == null)
                  const Text('Gold Star coming soon.',
                      textAlign: TextAlign.center)
                else
                  ValueListenableBuilder<bool>(
                    valueListenable: store.goldStarOwned,
                    builder: (_, owned, _) => owned
                        ? const Text('⭐', style: TextStyle(fontSize: 48))
                        : ElevatedButton(
                            onPressed: () =>
                                store.buyStar(store.starProduct!),
                            child: Text(
                                '⭐ Gold Star ${store.starProduct!.price}'),
                          ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
