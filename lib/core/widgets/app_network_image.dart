import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_colors.dart';

/// Cached network image with a shimmer placeholder and a graceful fallback.
class AppNetworkImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? radius;

  const AppNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radius,
  });

  Widget _fallback() => Container(
        width: width,
        height: height,
        color: AppColors.divider,
        child: const Icon(Icons.checkroom, color: AppColors.textSecondary, size: 40),
      );

  @override
  Widget build(BuildContext context) {
    // API products carry no imagery — the backend's product record is a fitting
    // record, not a storefront one — so an empty url is a normal case, not an
    // error. Short-circuit it rather than handing "" to the network layer.
    if (url.isEmpty) {
      return radius == null ? _fallback() : ClipRRect(borderRadius: radius!, child: _fallback());
    }
    final image = CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      placeholder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Container(width: width, height: height, color: Colors.white),
      ),
      errorWidget: (_, __, ___) => _fallback(),
    );
    if (radius == null) return image;
    return ClipRRect(borderRadius: radius!, child: image);
  }
}
