import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The bundled avatars a member may pick (Migration 021): "preset:1" to
/// "preset:12". Illustrations from DiceBear "Notionists" by Zoish, CC0 1.0,
/// in assets/avatars/ so they work offline.
const presetAvatarCount = 12;

String presetAvatarKey(int n) => 'preset:$n';

/// The asset for an avatar key, or null for none or an unknown key.
String? presetAvatarAsset(String? key) {
  final n = int.tryParse(key?.replaceFirst('preset:', '') ?? '');
  if (key == null || !key.startsWith('preset:') || n == null) return null;
  if (n < 1 || n > presetAvatarCount) return null;
  return 'assets/avatars/avatar-${n.toString().padLeft(2, '0')}.svg';
}

/// A picked avatar, round.
class PresetAvatar extends StatelessWidget {
  const PresetAvatar({required this.asset, required this.size, super.key});

  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ClipOval(
        child: SvgPicture.asset(
          asset,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
