import 'package:flutter/material.dart';

/// Kısayol ikonları için seçilebilir ikon kataloğu.
class IconRegistry {
  IconRegistry._();

  static const Map<String, IconData> icons = {
    'navigation': Icons.navigation_rounded,
    'map': Icons.map_rounded,
    'music': Icons.music_note_rounded,
    'radio': Icons.radio_rounded,
    'phone': Icons.phone_in_talk_rounded,
    'settings': Icons.settings_rounded,
    'apps': Icons.apps_rounded,
    'video': Icons.play_circle_rounded,
    'youtube': Icons.smart_display_rounded,
    'camera': Icons.videocam_rounded,
    'car': Icons.directions_car_rounded,
    'gas': Icons.local_gas_station_rounded,
    'parking': Icons.local_parking_rounded,
    'bluetooth': Icons.bluetooth_rounded,
    'wifi': Icons.wifi_rounded,
    'mic': Icons.mic_rounded,
    'folder': Icons.folder_rounded,
    'web': Icons.public_rounded,
    'message': Icons.chat_rounded,
    'mail': Icons.mail_rounded,
    'cloud': Icons.wb_sunny_rounded,
    'calendar': Icons.calendar_month_rounded,
    'calc': Icons.calculate_rounded,
    'home': Icons.home_rounded,
    'star': Icons.star_rounded,
    'bolt': Icons.bolt_rounded,
    'shop': Icons.shopping_bag_rounded,
    'game': Icons.sports_esports_rounded,
    'headset': Icons.headphones_rounded,
    'speed': Icons.speed_rounded,
    'build': Icons.build_rounded,
    'tune': Icons.tune_rounded,
  };

  static IconData byKey(String key) => icons[key] ?? Icons.apps_rounded;
}
