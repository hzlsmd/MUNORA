import 'dart:ui';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme.dart';
import 'bottom_nav.dart';

/// SVGs are bundled unchanged from the supplied design. The SVG's intrinsic
/// dimensions are preserved; the surrounding slot handles alignment.
class DesignIcon extends StatelessWidget {
  final String asset;
  const DesignIcon(this.asset, {super.key});
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/design/$asset.svg',
    excludeFromSemantics: true,
    fit: BoxFit.contain,
  );
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color = const Color(0xA6FFFFFF),
  });
  @override
  Widget build(BuildContext context) => Container(
    decoration: cardDecoration(color: color),
    padding: padding,
    child: Material(type: MaterialType.transparency, child: child),
  );
}

class AtmosphereScreen extends StatelessWidget {
  final String title;
  final String? subtitle;
  final AppScreen active;
  final ValueChanged<AppScreen> onNavigate;
  final Widget child;
  final List<Widget> actions;
  const AtmosphereScreen({
    super.key,
    required this.title,
    this.subtitle,
    required this.active,
    required this.onNavigate,
    required this.child,
    this.actions = const [],
  });
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(gradient: AppColors.skyGradient),
    child: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: DesignIcon(subtitle == null ? '96cf4' : 'd52de'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textBody,
                          ),
                        ),
                    ],
                  ),
                ),
                ...actions,
              ],
            ),
          ),
          Expanded(child: child),
          BottomNav(active: active, onNavigate: onNavigate),
        ],
      ),
    ),
  );
}

class FrostedSurface extends StatelessWidget {
  final Widget child;
  const FrostedSurface({super.key, required this.child});
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(40),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: ColoredBox(color: const Color(0x90FFFFFF), child: child),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;
  const SectionTitle(this.title, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 6,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: const TextStyle(fontSize: 11, color: AppColors.textBody),
          ),
      ],
    ),
  );
}
