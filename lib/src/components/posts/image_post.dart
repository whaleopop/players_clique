import 'package:flutter/material.dart';

import '../../models/post.dart';

class ImagePost extends StatelessWidget {
  final void Function()? onTap;
  final String imageUrl;
  const ImagePost({
    super.key,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        child: Image.network(imageUrl),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: Colors.grey, // Цвет обводки
            width: 1.0, // Толщина обводки
          ),
        ),
      ),
    );
  }
}
