import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class PackageScreen extends StatelessWidget {
  const PackageScreen({super.key});



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Package Details"),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Center(
        child: Text(
          "This is the Package Upgrade page.",
          style: TextStyle(fontSize: 20, color: Theme.of(context).primaryColor),
        ),
      ),
    );
  }
}