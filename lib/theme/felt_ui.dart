import 'package:flutter/material.dart';
import 'billiards_themes.dart';

/// Shared text styles + wood/felt UI building blocks for Pocket Billiards.
/// Everything stays in the physical billiards-hall world: wood, brass, felt.
class Felt {
  static TextStyle display(double size,
          {required BilliardThemeDef theme, Color? color}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: color ?? theme.accentLight,
        letterSpacing: 0.6,
        shadows: const [
          Shadow(
              color: Colors.black54, offset: Offset(0, 2), blurRadius: 4),
        ],
      );

  static TextStyle label(double size,
          {required BilliardThemeDef theme, Color? color}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color ?? theme.ivory,
        letterSpacing: 1.2,
      );

  static TextStyle body(double size,
          {required BilliardThemeDef theme, Color? color}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: color ?? theme.ivory.withValues(alpha: 0.92),
        height: 1.45,
      );

  /// Dark wood backdrop with a subtle vignette — behind every screen.
  static Widget backdrop(
      {required BilliardThemeDef theme, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [theme.woodDark, const Color(0xFF120A05)],
        ),
      ),
      child: child,
    );
  }

  /// Wood-framed card panel.
  static Widget card({required BilliardThemeDef theme, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.woodMid.withValues(alpha: 0.92),
            theme.woodDark.withValues(alpha: 0.96),
          ],
        ),
        border: Border.all(color: theme.accent.withValues(alpha: 0.55), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: child,
    );
  }

  /// Small brass-labeled chip (locks show 🔒).
  static Widget chip(
      {required BilliardThemeDef theme,
      required String text,
      bool selected = false,
      bool locked = false,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: selected
              ? theme.accent.withValues(alpha: 0.85)
              : Colors.black.withValues(alpha: 0.35),
          border: Border.all(
              color: selected
                  ? theme.accentLight
                  : theme.accent.withValues(alpha: 0.4),
              width: selected ? 2 : 1.5),
        ),
        child: Text(
          locked ? '🔒 $text' : text,
          style: label(13,
              theme: theme,
              color: selected ? theme.woodDark : theme.ivory),
        ),
      ),
    );
  }
}

/// Big wooden button with brass rim.
class FeltButton extends StatelessWidget {  final String label;
  final VoidCallback onTap;
  final BilliardThemeDef theme;
  final double width;
  final double fontSize;
  const FeltButton(
      {super.key,
      required this.label,
      required this.onTap,
      required this.theme,
      this.width = 240,
      this.fontSize = 18});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [theme.woodLight, theme.woodMid],
          ),
          border: Border.all(color: theme.accent, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              offset: const Offset(0, 5),
              blurRadius: 10,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: Felt.label(fontSize, theme: theme, color: theme.ivory)),
      ),
    );
  }
}

/// Renameable player-name field.
///
/// Saves on EVERY keystroke (onChanged) and commits on focus loss (in case an
/// IME held the last edit back). The controller is only rewritten from
/// [initial] when the field is not focused, so typing never jumps.
class FeltNameField extends StatefulWidget {
  final String initial;
  final String hint;
  final String label;
  final BilliardThemeDef theme;
  final ValueChanged<String> onCommit;

  const FeltNameField({
    super.key,
    required this.initial,
    required this.hint,
    required this.label,
    required this.theme,
    required this.onCommit,
  });

  @override
  State<FeltNameField> createState() => _FeltNameFieldState();
}

class _FeltNameFieldState extends State<FeltNameField> {
  late final TextEditingController _controller;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
    _focus = FocusNode();
    _focus.addListener(() {
      if (!_focus.hasFocus) {
        widget.onCommit(_controller.text); // commit on focus loss
      }
    });
  }

  @override
  void didUpdateWidget(covariant FeltNameField old) {
    super.didUpdateWidget(old);
    // External rename (e.g. from another screen): adopt it while idle.
    if (widget.initial != old.initial &&
        !_focus.hasFocus &&
        _controller.text != widget.initial) {
      _controller.text = widget.initial;
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return TextFormField(
      controller: _controller,
      focusNode: _focus,
      style: Felt.body(15, theme: t),
      decoration: InputDecoration(
        hintText: widget.hint,
        labelText: widget.label,
        labelStyle: Felt.label(12, theme: t),
        hintStyle: Felt.body(13,
            theme: t, color: t.ivory.withValues(alpha: 0.4)),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: t.accent.withValues(alpha: 0.4)),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: t.accentLight),
        ),
      ),
      onChanged: widget.onCommit, // save on every keystroke
    );
  }
}
