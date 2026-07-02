import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// The bundled Budgetify logo artwork — the gold wallet-and-sprout mark on
/// its midnight-navy tile, same art as the launcher icon.
const String kBrandLogoAsset = 'assets/branding/logo.png';

/// The Budgetify brand mark. Every surface that shows the logo (splash badge,
/// shareable cards, and the PDF export via [loadBrandLogoBytes]) renders this
/// same bundled artwork, so the brand never drifts from the real logo.
///
/// The artwork is a full-bleed navy square: [circular] crops it to a disc
/// (the splash badge); otherwise it gets launcher-style rounded corners.
class BrandLogo extends StatelessWidget {
  final double size;
  final bool circular;

  const BrandLogo({super.key, this.size = 48, this.circular = false});

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      kBrandLogoAsset,
      width: size,
      height: size,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
    );
    return circular
        ? ClipOval(child: image)
        : ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.22),
            child: image,
          );
  }
}

/// The logo PNG bytes, for surfaces that can't host a widget (the PDF
/// export). Same bundled artwork as [BrandLogo].
Future<Uint8List> loadBrandLogoBytes() async {
  final data = await rootBundle.load(kBrandLogoAsset);
  return data.buffer.asUint8List();
}
