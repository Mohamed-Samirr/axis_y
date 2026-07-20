import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class RatingStars extends StatelessWidget {
  final double rating;
  final double size;
  final int? count;

  const RatingStars({super.key, required this.rating, this.size = 16, this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 1; i <= 5; i++)
          Icon(
            i <= rating ? Icons.star : (i - 0.5 <= rating ? Icons.star_half : Icons.star_border),
            size: size,
            color: AppColors.gold,
          ),
        if (count != null) ...[
          const SizedBox(width: 6),
          Text('($count)', style: TextStyle(fontSize: size - 3, color: AppColors.textSecondary)),
        ],
      ],
    );
  }
}
