import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class CarryGoLogo extends StatelessWidget {
  final double size;

  const CarryGoLogo({
    super.key,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.18),
      child: Image.asset(
        'assets/images/carrygo_logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

class CarryGoAppBarTitle extends StatelessWidget {
  final String label;

  const CarryGoAppBarTitle({
    super.key,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CarryGoLogo(size: 34),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            context.tr(label),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
