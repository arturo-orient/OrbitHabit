import 'package:flutter/material.dart';

class UserSettings {
  final String userName;
  final String avatarEmoji;
  final int avatarColorValue;
  final int notificationHour;
  final int notificationMinute;
  final String themeMode; // 'light' (Crema), 'dark' (Pizarra), 'sage' (Bosque Salvia)
  final bool isFirstTime; // Onboarding guard
  final List<String> vacationDates; // Fechas en formato YYYY-MM-DD donde las rachas se congelan

  UserSettings({
    required this.userName,
    required this.avatarEmoji,
    required this.avatarColorValue,
    required this.notificationHour,
    required this.notificationMinute,
    required this.themeMode,
    required this.isFirstTime,
    required this.vacationDates,
  });

  Color get avatarColor => Color(avatarColorValue);

  UserSettings copyWith({
    String? userName,
    String? avatarEmoji,
    int? avatarColorValue,
    int? notificationHour,
    int? notificationMinute,
    String? themeMode,
    bool? isFirstTime,
    List<String>? vacationDates,
  }) {
    return UserSettings(
      userName: userName ?? this.userName,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      avatarColorValue: avatarColorValue ?? this.avatarColorValue,
      notificationHour: notificationHour ?? this.notificationHour,
      notificationMinute: notificationMinute ?? this.notificationMinute,
      themeMode: themeMode ?? this.themeMode,
      isFirstTime: isFirstTime ?? this.isFirstTime,
      vacationDates: vacationDates ?? this.vacationDates,
    );
  }

  // Robust Map conversion with default fallback values to prevent NullPointer crashes
  Map<String, dynamic> toMap() {
    return {
      'userName': userName,
      'avatarEmoji': avatarEmoji,
      'avatarColorValue': avatarColorValue,
      'notificationHour': notificationHour,
      'notificationMinute': notificationMinute,
      'themeMode': themeMode,
      'isFirstTime': isFirstTime,
      'vacationDates': vacationDates,
    };
  }

  factory UserSettings.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) {
      return UserSettings.defaultSettings();
    }
    return UserSettings(
      userName: map['userName'] as String? ?? 'Arturo',
      avatarEmoji: map['avatarEmoji'] as String? ?? '🧘',
      avatarColorValue: map['avatarColorValue'] as int? ?? 0xFF84A59D, // Verde Salvia
      notificationHour: map['notificationHour'] as int? ?? 21,
      notificationMinute: map['notificationMinute'] as int? ?? 0,
      themeMode: map['themeMode'] as String? ?? 'system',
      isFirstTime: map['isFirstTime'] as bool? ?? true,
      vacationDates: (map['vacationDates'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  factory UserSettings.defaultSettings() {
    return UserSettings(
      userName: 'Arturo',
      avatarEmoji: '🧘',
      avatarColorValue: 0xFF84A59D,
      notificationHour: 21,
      notificationMinute: 0,
      themeMode: 'system',
      isFirstTime: true,
      vacationDates: [],
    );
  }
}
