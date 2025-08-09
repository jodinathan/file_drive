import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ProviderIcon extends StatelessWidget {
  final String iconPath;
  final double size;
  final Color? fallbackColor;

  const ProviderIcon({
    Key? key,
    required this.iconPath,
    this.size = 20,
    this.fallbackColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (iconPath.endsWith('.svg')) {
      return SvgPicture.asset(
        iconPath,
        width: size,
        height: size,
        placeholderBuilder: (context) => Icon(
          Icons.cloud,
          size: size,
          color: fallbackColor ?? Colors.white,
        ),
      );
    }
    
    return Icon(
      Icons.cloud,
      size: size,
      color: fallbackColor ?? Colors.white,
    );
  }
}