import 'package:flutter/material.dart';

class IconHelper {
  // Centralized icon mapping from string names to IconData
  static IconData getIconData(String iconName) {
    final iconMap = {
      // Common
      'inventory_2': Icons.inventory_2,
      'home': Icons.home,
      'folder': Icons.folder,
      'category': Icons.category,
      'label': Icons.label,
      'star': Icons.star,
      'favorite': Icons.favorite,
      'bookmark': Icons.bookmark,
      'flag': Icons.flag,
      'grade': Icons.grade,

      // Home & Rooms
      'meeting_room': Icons.meeting_room,
      'bed': Icons.bed,
      'bedroom_parent': Icons.bedroom_parent,
      'bedroom_child': Icons.bedroom_child,
      'bedroom_baby': Icons.bedroom_baby,
      'kitchen': Icons.kitchen,
      'dining_outlined': Icons.dining_outlined,
      'bathroom': Icons.bathroom,
      'bathtub': Icons.bathtub,
      'weekend': Icons.weekend,
      'living': Icons.living,
      'chair': Icons.chair,
      'garage': Icons.garage,
      'door_sliding': Icons.door_sliding,
      'door_front': Icons.door_front_door,
      'door_back': Icons.door_back_door,
      'countertops': Icons.countertops,
      'shelves': Icons.shelves,
      'desk': Icons.desk,
      'table_restaurant': Icons.table_restaurant,
      'yard': Icons.yard,
      'deck': Icons.deck,
      'balcony': Icons.balcony,

      // Storage
      'archive': Icons.archive,
      'folder_special': Icons.folder_special,
      'source': Icons.source,
      'work_outline': Icons.work_outline,
      'backpack': Icons.backpack,
      'business_center': Icons.business_center,
      'shopping_bag': Icons.shopping_bag,
      'luggage': Icons.luggage,
      'cases': Icons.cases,
      'inbox': Icons.inbox,
      'delete_outline': Icons.delete_outline,
      'storage': Icons.storage,

      // Items & Entertainment
      'menu_book': Icons.menu_book,
      'book': Icons.book,
      'library_books': Icons.library_books,
      'album': Icons.album,
      'music_note': Icons.music_note,
      'library_music': Icons.library_music,
      'headphones': Icons.headphones,
      'speaker': Icons.speaker,
      'sports_esports': Icons.sports_esports,
      'videogame_asset': Icons.videogame_asset,
      'movie': Icons.movie,
      'theaters': Icons.theaters,
      'tv': Icons.tv,
      'video_library': Icons.video_library,

      // Electronics & Tools
      'devices': Icons.devices,
      'phone_android': Icons.phone_android,
      'tablet': Icons.tablet,
      'laptop': Icons.laptop,
      'computer': Icons.computer,
      'keyboard': Icons.keyboard,
      'mouse': Icons.mouse,
      'watch': Icons.watch,
      'camera_alt': Icons.camera_alt,
      'photo_camera': Icons.photo_camera,
      'videocam': Icons.videocam,
      'print': Icons.print,
      'build': Icons.build,
      'construction': Icons.construction,
      'handyman': Icons.handyman,
      'hardware': Icons.hardware,
      'plumbing': Icons.plumbing,
      'electrical_services': Icons.electrical_services,
      'carpenter': Icons.carpenter,
      'engineering': Icons.engineering,

      // Clothing & Fashion
      'checkroom': Icons.checkroom,
      'dry_cleaning': Icons.dry_cleaning,
      'diamond': Icons.diamond,
      'umbrella': Icons.umbrella,

      // Kitchen & Food
      'restaurant': Icons.restaurant,
      'restaurant_menu': Icons.restaurant_menu,
      'fastfood': Icons.fastfood,
      'local_dining': Icons.local_dining,
      'local_pizza': Icons.local_pizza,
      'local_cafe': Icons.local_cafe,
      'local_bar': Icons.local_bar,
      'coffee': Icons.coffee,
      'cake': Icons.cake,
      'icecream': Icons.icecream,
      'brunch_dining': Icons.brunch_dining,
      'lunch_dining': Icons.lunch_dining,
      'dinner_dining': Icons.dinner_dining,
      'breakfast_dining': Icons.breakfast_dining,
      'microwave': Icons.microwave,
      'blender': Icons.blender,
      'soup_kitchen': Icons.soup_kitchen,

      // Sports & Fitness
      'sports_basketball': Icons.sports_basketball,
      'sports_football': Icons.sports_football,
      'sports_soccer': Icons.sports_soccer,
      'sports_baseball': Icons.sports_baseball,
      'sports_tennis': Icons.sports_tennis,
      'sports_golf': Icons.sports_golf,
      'sports_hockey': Icons.sports_hockey,
      'sports_volleyball': Icons.sports_volleyball,
      'sports_cricket': Icons.sports_cricket,
      'sports_martial_arts': Icons.sports_martial_arts,
      'fitness_center': Icons.fitness_center,
      'pool': Icons.pool,
      'surfing': Icons.surfing,
      'hiking': Icons.hiking,
      'snowboarding': Icons.snowboarding,
      'downhill_skiing': Icons.downhill_skiing,

      // Outdoor & Nature
      'park': Icons.park,
      'local_florist': Icons.local_florist,
      'nature': Icons.nature,
      'eco': Icons.eco,
      'forest': Icons.forest,
      'grass': Icons.grass,
      'outdoor_grill': Icons.outdoor_grill,
      'fireplace': Icons.fireplace,
      'agriculture': Icons.agriculture,

      // Pets & Animals
      'pets': Icons.pets,
      'cruelty_free': Icons.cruelty_free,

      // Transportation
      'directions_car': Icons.directions_car,
      'directions_bike': Icons.directions_bike,
      'directions_bus': Icons.directions_bus,
      'directions_boat': Icons.directions_boat,
      'flight': Icons.flight,
      'train': Icons.train,
      'two_wheeler': Icons.two_wheeler,
      'electric_scooter': Icons.electric_scooter,
      'electric_bike': Icons.electric_bike,
      'electric_car': Icons.electric_car,
      'local_shipping': Icons.local_shipping,

      // Health & Medical
      'medical_services': Icons.medical_services,
      'medication': Icons.medication,
      'vaccines': Icons.vaccines,
      'healing': Icons.healing,
      'monitor_heart': Icons.monitor_heart,

      // Office & School
      'work': Icons.work,
      'school': Icons.school,
      'science': Icons.science,
      'calculate': Icons.calculate,
      'edit': Icons.edit,
      'draw': Icons.draw,
      'palette': Icons.palette,
      'brush': Icons.brush,

      // Miscellaneous
      'lightbulb': Icons.lightbulb,
      'wb_sunny': Icons.wb_sunny,
      'ac_unit': Icons.ac_unit,
      'thermostat': Icons.thermostat,
      'toys': Icons.toys,
      'child_care': Icons.child_care,
      'nightlight': Icons.nightlight,
      'flashlight_on': Icons.flashlight_on,
      'celebration': Icons.celebration,
      'card_giftcard': Icons.card_giftcard,
      'redeem': Icons.redeem,
      'shopping_cart': Icons.shopping_cart,
      'wallet': Icons.wallet,
      'savings': Icons.savings,
      'attach_money': Icons.attach_money,
    };

    return iconMap[iconName] ?? Icons.inventory_2;
  }

  // Get icon for a container type name (for backward compatibility)
  static IconData getContainerIcon(String containerType) {
    switch (containerType.toLowerCase()) {
      case 'room':
        return Icons.meeting_room;
      case 'shelf':
        return Icons.shelves;
      case 'box':
        return Icons.inventory_2;
      case 'fridge':
        return Icons.kitchen;
      case 'drawer':
        return Icons.countertops;
      case 'cabinet':
        return Icons.countertops;
      case 'closet':
        return Icons.door_sliding;
      case 'bin':
        return Icons.delete_outline;
      default:
        return Icons.inventory_2;
    }
  }

  // Get icon for an item type name (for backward compatibility)
  static IconData getItemIcon(String itemType) {
    switch (itemType.toLowerCase()) {
      case 'book':
        return Icons.menu_book;
      case 'vinyl':
      case 'music':
        return Icons.album;
      case 'game':
        return Icons.sports_esports;
      case 'tool':
        return Icons.build;
      case 'camera':
        return Icons.camera_alt;
      case 'electronics':
        return Icons.devices;
      case 'clothing':
        return Icons.checkroom;
      case 'kitchen':
        return Icons.restaurant;
      case 'outdoor':
        return Icons.park;
      case 'pantry':
        return Icons.kitchen;
      default:
        return Icons.category;
    }
  }
}
