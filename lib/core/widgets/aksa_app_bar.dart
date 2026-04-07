import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme.dart';

class AksaAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AksaAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.leading,
    this.bottom,
    this.showLogo = false,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;
  final PreferredSizeWidget? bottom;
  final bool showLogo;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AksaColors.bg,
      leading: leading,
      automaticallyImplyLeading: leading == null ? false : true,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showLogo)
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: AksaColors.gradPrimary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.favorite_rounded,
                      color: Colors.white, size: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: AksaColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            )
          else
            Text(
              title,
              style: GoogleFonts.inter(
                color: AksaColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: GoogleFonts.inter(
                color: AksaColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
        ],
      ),
      actions: trailing != null ? [trailing!, const SizedBox(width: 8)] : null,
      bottom: bottom,
    );
  }
}