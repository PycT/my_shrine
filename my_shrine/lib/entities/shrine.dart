import 'package:flutter/material.dart';

class Shrine {
  final String name;
  final String color;

  Shrine({required this.name, required this.color});
}

final Shrine defaultShrine = Shrine(name: "Time", color: "E0E0E0");

final List<Shrine> shrinesInitialList = [
  Shrine(name: "Family", color: "D1748B"),
  Shrine(name: "Health", color: "5CB870"),
  Shrine(name: "Security", color: "5A8DC8"),
  Shrine(name: "Soul", color: "9B72CF"),
  Shrine(name: "Education", color: "C49A3C"),
  Shrine(name: "Happiness", color: "E8C44A"),
  Shrine(name: "Hobby", color: "48B8A0"),
  Shrine(name: "Friends", color: "D4885C"),
  Shrine(name: "Recovery", color: "6AAEC8"),
  Shrine(name: "Fun", color: "CF6BA8"),
];