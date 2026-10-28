import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Diálogo modal de precisión para seleccionar un color personalizado
/// con espectro cromático (Hue), saturación, brillo y entrada de código HEX.
class CustomColorPickerDialog extends StatefulWidget {
  final Color initialColor;

  const CustomColorPickerDialog({
    Key? key,
    required this.initialColor,
  }) : super(key: key);

  static Future<Color?> show(BuildContext context, Color initialColor) {
    return showDialog<Color>(
      context: context,
      barrierDismissible: true,
      builder: (context) => CustomColorPickerDialog(initialColor: initialColor),
    );
  }

  @override
  State<CustomColorPickerDialog> createState() => _CustomColorPickerDialogState();
}

class _CustomColorPickerDialogState extends State<CustomColorPickerDialog> {
  late HSVColor _hsvColor;
  late TextEditingController _hexController;
  bool _isUpdatingFromHex = false;

  @override
  void initState() {
    super.initState();
    _hsvColor = HSVColor.fromColor(widget.initialColor);
    _hexController = TextEditingController(text: _colorToHex(_hsvColor.toColor()));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  String _colorToHex(Color color) {
    return color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
  }

  void _updateFromHsv(HSVColor newHsv) {
    setState(() {
      _hsvColor = newHsv;
      if (!_isUpdatingFromHex) {
        _hexController.text = _colorToHex(_hsvColor.toColor());
      }
    });
  }

  void _onHexChanged(String val) {
    final clean = val.replaceAll('#', '').trim();
    if (clean.length == 6) {
      final intVal = int.tryParse(clean, radix: 16);
      if (intVal != null) {
        final color = Color(0xFF000000 | intVal);
        _isUpdatingFromHex = true;
        setState(() {
          _hsvColor = HSVColor.fromColor(color);
        });
        _isUpdatingFromHex = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentColor = _hsvColor.toColor();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.obsidianSurface : AppTheme.boneSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabecera
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Color Personalizado',
                      style: AppTheme.displayStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppTheme.obsidianTextPrimary
                            : AppTheme.boneTextPrimary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: isDark
                            ? AppTheme.obsidianTextMuted
                            : AppTheme.boneTextMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Previsualización y Selector HEX
                Row(
                  children: [
                    // Muestra en vivo del color resultante
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: currentColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? Colors.white24 : Colors.black12,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: currentColor.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Campo de código Hexadecimal
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.obsidianCanvas : AppTheme.boneCanvas,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '#',
                              style: AppTheme.monoStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppTheme.obsidianTextMuted
                                    : AppTheme.boneTextMuted,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: TextField(
                                controller: _hexController,
                                maxLength: 6,
                                textCapitalization: TextCapitalization.characters,
                                onChanged: _onHexChanged,
                                style: AppTheme.monoStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? AppTheme.obsidianTextPrimary
                                      : AppTheme.boneTextPrimary,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  counterText: '',
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // 1. Deslizador de Tono (Hue: 0..360)
                _buildSliderLabel('Tono', '${_hsvColor.hue.toInt()}°', isDark),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 22,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFFFF0000),
                          Color(0xFFFFFF00),
                          Color(0xFF00FF00),
                          Color(0xFF00FFFF),
                          Color(0xFF0000FF),
                          Color(0xFFFF00FF),
                          Color(0xFFFF0000),
                        ],
                      ),
                    ),
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 22,
                        trackShape: const RectangularSliderTrackShape(),
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 11,
                          elevation: 2,
                        ),
                        thumbColor: Colors.white,
                        activeTrackColor: Colors.transparent,
                        inactiveTrackColor: Colors.transparent,
                        overlayColor: Colors.transparent,
                      ),
                      child: Slider(
                        value: _hsvColor.hue,
                        min: 0.0,
                        max: 360.0,
                        onChanged: (val) {
                          _updateFromHsv(_hsvColor.withHue(val));
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Deslizador de Saturación (0..100%)
                _buildSliderLabel(
                  'Intensidad',
                  '${(_hsvColor.saturation * 100).toInt()}%',
                  isDark,
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 22,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          HSVColor.fromAHSV(1.0, _hsvColor.hue, 0.0, _hsvColor.value).toColor(),
                          HSVColor.fromAHSV(1.0, _hsvColor.hue, 1.0, _hsvColor.value).toColor(),
                        ],
                      ),
                    ),
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 22,
                        trackShape: const RectangularSliderTrackShape(),
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 11,
                          elevation: 2,
                        ),
                        thumbColor: Colors.white,
                        activeTrackColor: Colors.transparent,
                        inactiveTrackColor: Colors.transparent,
                        overlayColor: Colors.transparent,
                      ),
                      child: Slider(
                        value: _hsvColor.saturation,
                        min: 0.0,
                        max: 1.0,
                        onChanged: (val) {
                          _updateFromHsv(_hsvColor.withSaturation(val));
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Deslizador de Brillo / Luminosidad (0.2..1.0)
                _buildSliderLabel(
                  'Luminosidad',
                  '${(_hsvColor.value * 100).toInt()}%',
                  isDark,
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 22,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          HSVColor.fromAHSV(1.0, _hsvColor.hue, _hsvColor.saturation, 0.15).toColor(),
                          HSVColor.fromAHSV(1.0, _hsvColor.hue, _hsvColor.saturation, 1.0).toColor(),
                        ],
                      ),
                    ),
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 22,
                        trackShape: const RectangularSliderTrackShape(),
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 11,
                          elevation: 2,
                        ),
                        thumbColor: Colors.white,
                        activeTrackColor: Colors.transparent,
                        inactiveTrackColor: Colors.transparent,
                        overlayColor: Colors.transparent,
                      ),
                      child: Slider(
                        value: _hsvColor.value,
                        min: 0.15,
                        max: 1.0,
                        onChanged: (val) {
                          _updateFromHsv(_hsvColor.withValue(val));
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Botones de Acción
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'Cancelar',
                          style: AppTheme.bodyStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppTheme.obsidianTextSecondary
                                : AppTheme.boneTextSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          Navigator.of(context).pop(currentColor);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: currentColor,
                          foregroundColor: currentColor.computeLuminance() > 0.5
                              ? Colors.black
                              : Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text(
                          'Aplicar Color',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSliderLabel(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTheme.bodyStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? AppTheme.obsidianTextSecondary : AppTheme.boneTextSecondary,
          ),
        ),
        Text(
          value,
          style: AppTheme.monoStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
          ),
        ),
      ],
    );
  }
}
