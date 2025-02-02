import 'package:flutter/material.dart';
import 'colors.dart';
import 'user.dart';

class CustomCircularImage extends StatelessWidget {
  final double size;
  final Users user;

  const CustomCircularImage(
      {super.key, required this.size, required this.user});

  bool get isImageProvided => user.picture != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isImageProvided ? null : greenColor,
          image: !isImageProvided
              ? null
              : DecorationImage(image: NetworkImage(user.picture!))),
      child: isImageProvided
          ? const SizedBox()
          : Center(
        child: Text(user.name[0].toUpperCase()),
      ),
    );
  }
}