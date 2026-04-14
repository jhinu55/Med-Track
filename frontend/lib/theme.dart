// lib/theme.dart
// Central colour palette and ThemeData.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const kPrimary    = Color(0xFF1565C0);
const kAccent     = Color(0xFF00ACC1);
const kSuccess    = Color(0xFF2E7D32);
const kWarning    = Color(0xFFF57F17);
const kDanger     = Color(0xFFC62828);
const kBackground = Color(0xFFF4F6FA);
const kSurface    = Color(0xFFFFFFFF);
const kCardShadow = Color(0x1A000000);

Color statusColor(String status) {
  switch (status) {
    case 'Received':   return kSuccess;
    case 'In-Transit': return kAccent;
    case 'Rejected':   return kDanger;
    default:           return kWarning;
  }
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: kPrimary,
      primary: kPrimary,
      secondary: kAccent,
      surface: kSurface,
      background: kBackground,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: kBackground,
  );

  return base.copyWith(
    textTheme: GoogleFonts.interTextTheme(base.textTheme),
    appBarTheme: AppBarTheme(
      backgroundColor: kPrimary,
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: GoogleFonts.inter(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardTheme(
      color: kSurface,
      elevation: 2,
      shadowColor: kCardShadow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kPrimary, width: 2),
      ),
    ),
  );
}
