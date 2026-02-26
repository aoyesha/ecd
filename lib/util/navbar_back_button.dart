import 'package:flutter/material.dart';
import 'package:get/get.dart';

class NavbarBackButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const NavbarBackButton({Key? key, this.onPressed}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: IconButton(
        tooltip: "Back",
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 22,
          color: Colors.black,
        ),
        onPressed: onPressed ?? () {
          Get.back();
        },
      ),
    );
  }
}