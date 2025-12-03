import 'package:flutter/material.dart';

ThemeData buildTheme() => ThemeData(
  useMaterial3: true,
  colorSchemeSeed: const Color(0xFF1769AA), // A&S blue vibe
  inputDecorationTheme: const InputDecorationTheme(
    border: OutlineInputBorder(),
  ),
);
