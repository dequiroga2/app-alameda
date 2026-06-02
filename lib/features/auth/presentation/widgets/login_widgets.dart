import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class FieldLabel extends StatelessWidget {
  const FieldLabel({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label, style: AppTextStyles.labelMd.copyWith(letterSpacing: 0.2));
  }
}

/// Torres reales del conjunto. El valor es el string que se guarda en DB.
const kTowerOptions = ['1', '2', '3', '4A', '4B', '8', '9', 'Casa'];

class TowerSelector extends StatelessWidget {
  const TowerSelector({super.key, required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: kTowerOptions.map((t) {
        final on = selected == t;
        return GestureDetector(
          onTap: () => onChanged(t),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: on ? AppColors.accentStrong : AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: on ? AppColors.accentStrong : AppColors.hair,
                width: 1.5,
              ),
            ),
            child: Text(
              t,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: on ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class AppInput extends StatefulWidget {
  const AppInput({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;

  @override
  State<AppInput> createState() => _AppInputState();
}

class _AppInputState extends State<AppInput> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // El borde va en AnimatedContainer (exterior, no se recorta).
    // El contenido va en ClipRRect interior con radio ligeramente menor.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _focused ? AppColors.secondary : AppColors.hair,
          width: _focused ? 2 : 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.5),
        child: ColoredBox(
          color: AppColors.background,
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(widget.icon, size: 18, color: _focused ? AppColors.secondary : AppColors.textFaint),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  obscureText: widget.obscure,
                  keyboardType: widget.keyboardType,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 16, color: AppColors.textFaint),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 15),
                    isDense: true,
                  ),
                ),
              ),
              if (widget.suffix != null)
                SizedBox(
                  width: 44,
                  height: 44,
                  child: widget.suffix!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
