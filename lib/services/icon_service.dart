import 'package:flutter/material.dart';

/// Service for auto-assigning icons based on todo title keywords.
class IconService {
  IconService._();

  /// Map of keywords to icon code points
  static final Map<String, IconData> _keywordIconMap = {
    // Exercise/Fitness
    'exercise': Icons.fitness_center_outlined,
    'workout': Icons.fitness_center_outlined,
    'gym': Icons.fitness_center_outlined,
    'run': Icons.directions_run_outlined,
    'running': Icons.directions_run_outlined,
    'jog': Icons.directions_run_outlined,
    'walk': Icons.directions_walk_outlined,
    'walking': Icons.directions_walk_outlined,
    'yoga': Icons.self_improvement_outlined,
    'meditation': Icons.self_improvement_outlined,
    'meditate': Icons.self_improvement_outlined,
    'stretch': Icons.accessibility_new_outlined,
    'stretching': Icons.accessibility_new_outlined,

    // Health/Wellness
    'water': Icons.water_drop_outlined,
    'drink': Icons.local_drink_outlined,
    'vitamin': Icons.medication_outlined,
    'medicine': Icons.medication_outlined,
    'sleep': Icons.bedtime_outlined,
    'bed': Icons.bed_outlined,
    'nap': Icons.bedtime_outlined,
    'shower': Icons.shower_outlined,
    'bath': Icons.bathtub_outlined,

    // Food/Meals
    'breakfast': Icons.breakfast_dining_outlined,
    'lunch': Icons.lunch_dining_outlined,
    'dinner': Icons.dinner_dining_outlined,
    'meal': Icons.restaurant_outlined,
    'eat': Icons.restaurant_outlined,
    'cook': Icons.restaurant_menu_outlined,
    'coffee': Icons.local_cafe_outlined,
    'tea': Icons.local_cafe_outlined,

    // Learning/Education
    'read': Icons.menu_book_outlined,
    'reading': Icons.menu_book_outlined,
    'book': Icons.book_outlined,
    'study': Icons.school_outlined,
    'learn': Icons.school_outlined,
    'homework': Icons.assignment_outlined,
    'practice': Icons.practice_outlined,

    // Work/Productivity
    'work': Icons.work_outline,
    'email': Icons.email_outlined,
    'meeting': Icons.groups_outlined,
    'call': Icons.phone_outlined,
    'phone': Icons.phone_outlined,
    'code': Icons.code_outlined,
    'coding': Icons.code_outlined,
    'write': Icons.edit_outlined,
    'writing': Icons.edit_outlined,

    // Personal Care
    'brush': Icons.cleaning_services_outlined,
    'teeth': Icons.cleaning_services_outlined,
    'skincare': Icons.face_outlined,
    'face': Icons.face_outlined,
    'hair': Icons.content_cut_outlined,

    // Household
    'clean': Icons.cleaning_services_outlined,
    'cleaning': Icons.cleaning_services_outlined,
    'laundry': Icons.local_laundry_service_outlined,
    'dishes': Icons.dinner_dining_outlined,
    'grocery': Icons.shopping_cart_outlined,
    'shop': Icons.shopping_cart_outlined,
    'shopping': Icons.shopping_cart_outlined,

    // Social/Communication
    'call': Icons.phone_outlined,
    'message': Icons.message_outlined,
    'text': Icons.sms_outlined,
    'chat': Icons.chat_bubble_outline,
    'friend': Icons.people_outline,
    'family': Icons.family_restroom_outlined,

    // Hobbies/Entertainment
    'music': Icons.music_note_outlined,
    'play': Icons.play_circle_outline,
    'game': Icons.sports_esports_outlined,
    'movie': Icons.movie_outlined,
    'watch': Icons.play_circle_outline,
    'draw': Icons.brush_outlined,
    'drawing': Icons.brush_outlined,
    'paint': Icons.palette_outlined,
    'art': Icons.palette_outlined,

    // Travel/Transportation
    'drive': Icons.drive_eta_outlined,
    'car': Icons.directions_car_outlined,
    'bus': Icons.directions_bus_outlined,
    'train': Icons.train_outlined,
    'flight': Icons.flight_outlined,
    'travel': Icons.flight_outlined,

    // Financial
    'pay': Icons.payment_outlined,
    'bill': Icons.receipt_outlined,
    'budget': Icons.account_balance_wallet_outlined,
    'money': Icons.attach_money,
    'bank': Icons.account_balance_outlined,

    // Technology
    'phone': Icons.phone_android_outlined,
    'computer': Icons.computer_outlined,
    'laptop': Icons.laptop_outlined,
    'internet': Icons.wifi_outlined,
    'app': Icons.apps_outlined,

    // Nature/Outdoor
    'garden': Icons.local_florist_outlined,
    'plant': Icons.local_florist_outlined,
    'park': Icons.park_outlined,
    'outdoor': Icons.nature_outlined,
    'nature': Icons.nature_outlined,
  };

  /// Default icon if no keyword matches
  static const IconData defaultIcon = Icons.check_circle_outline;

  /// Get icon for a todo title by matching keywords
  static IconData getIconForTitle(String title) {
    final lowerTitle = title.toLowerCase().trim();
    
    // Check for exact matches first
    for (final entry in _keywordIconMap.entries) {
      if (lowerTitle.contains(entry.key)) {
        return entry.value;
      }
    }

    // Check for partial word matches (word boundaries)
    final words = lowerTitle.split(RegExp(r'\s+'));
    for (final word in words) {
      final cleanWord = word.replaceAll(RegExp(r'[^\w]'), '');
      if (_keywordIconMap.containsKey(cleanWord)) {
        return _keywordIconMap[cleanWord]!;
      }
    }

    return defaultIcon;
  }

  /// Get icon code point for a todo title
  static int getIconCodePointForTitle(String title) {
    return getIconForTitle(title).codePoint;
  }
}
