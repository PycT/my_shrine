import 'package:flutter/material.dart';

class Shrine {
  final String name;
  final Color color;

  Shrine({required this.name, required this.color});
}

final Shrine defaultShrine = Shrine(name: "Time", color: Colors.grey[300]!);
