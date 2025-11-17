import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

class IconHelper {
  // Centralized icon mapping from string names to IconData
  // All icons now use Ionicons (outline versions as default)
  // Maintains backwards compatibility with existing database entries
  static IconData getIconData(String iconName) {
    final iconMap = {
      // Common
      'inventory_2': Ionicons.cube_outline,
      'home': Ionicons.home_outline,
      'folder': Ionicons.folder_outline,
      'category': Ionicons.apps_outline,
      'label': Ionicons.pricetag_outline,
      'star': Ionicons.star_outline,
      'favorite': Ionicons.heart_outline,
      'bookmark': Ionicons.bookmark_outline,
      'flag': Ionicons.flag_outline,
      'grade': Ionicons.ribbon_outline,

      // Home & Rooms
      'meeting_room': Ionicons.business_outline,
      'bed': Ionicons.bed_outline,
      'bedroom_parent': Ionicons.bed_outline,
      'bedroom_child': Ionicons.bed_outline,
      'bedroom_baby': Ionicons.bed_outline,
      'kitchen': Ionicons.restaurant_outline,
      'dining_outlined': Ionicons.restaurant_outline,
      'bathroom': Ionicons.water_outline,
      'bathtub': Ionicons.water_outline,
      'weekend': Ionicons.easel_outline,
      'living': Ionicons.tv_outline,
      'chair': Ionicons.cafe_outline,
      'garage': Ionicons.car_outline,
      'door_sliding': Ionicons.exit_outline,
      'door_front': Ionicons.enter_outline,
      'door_back': Ionicons.exit_outline,
      'countertops': Ionicons.tablet_landscape_outline,
      'shelves': Ionicons.albums_outline,
      'desk': Ionicons.desktop_outline,
      'table_restaurant': Ionicons.restaurant_outline,
      'yard': Ionicons.leaf_outline,
      'deck': Ionicons.home_outline,
      'balcony': Ionicons.home_outline,

      // Storage
      'archive': Ionicons.archive_outline,
      'folder_special': Ionicons.folder_open_outline,
      'source': Ionicons.file_tray_outline,
      'work_outline': Ionicons.briefcase_outline,
      'backpack': Ionicons.bag_outline,
      'business_center': Ionicons.briefcase_outline,
      'shopping_bag': Ionicons.bag_handle_outline,
      'luggage': Ionicons.briefcase_outline,
      'cases': Ionicons.briefcase_outline,
      'inbox': Ionicons.mail_outline,
      'delete_outline': Ionicons.trash_outline,
      'storage': Ionicons.server_outline,

      // Items & Entertainment
      'menu_book': Ionicons.book_outline,
      'book': Ionicons.book_outline,
      'library_books': Ionicons.library_outline,
      'album': Ionicons.disc_outline,
      'music_note': Ionicons.musical_note_outline,
      'library_music': Ionicons.musical_notes_outline,
      'headphones': Ionicons.headset_outline,
      'speaker': Ionicons.volume_high_outline,
      'sports_esports': Ionicons.game_controller_outline,
      'videogame_asset': Ionicons.game_controller_outline,
      'movie': Ionicons.film_outline,
      'theaters': Ionicons.film_outline,
      'tv': Ionicons.tv_outline,
      'video_library': Ionicons.videocam_outline,

      // Electronics & Tools
      'devices': Ionicons.phone_portrait_outline,
      'phone_android': Ionicons.phone_portrait_outline,
      'tablet': Ionicons.tablet_portrait_outline,
      'laptop': Ionicons.laptop_outline,
      'computer': Ionicons.desktop_outline,
      'keyboard': Ionicons.keypad_outline,
      'mouse': Ionicons.radio_button_on_outline,
      'watch': Ionicons.watch_outline,
      'camera_alt': Ionicons.camera_outline,
      'photo_camera': Ionicons.camera_outline,
      'videocam': Ionicons.videocam_outline,
      'print': Ionicons.print_outline,
      'build': Ionicons.build_outline,
      'construction': Ionicons.construct_outline,
      'handyman': Ionicons.hammer_outline,
      'hardware': Ionicons.hardware_chip_outline,
      'plumbing': Ionicons.water_outline,
      'electrical_services': Ionicons.flash_outline,
      'carpenter': Ionicons.hammer_outline,
      'engineering': Ionicons.settings_outline,

      // Clothing & Fashion
      'checkroom': Ionicons.shirt_outline,
      'dry_cleaning': Ionicons.shirt_outline,
      'diamond': Ionicons.diamond_outline,
      'umbrella': Ionicons.umbrella_outline,

      // Kitchen & Food
      'restaurant': Ionicons.restaurant_outline,
      'restaurant_menu': Ionicons.fast_food_outline,
      'fastfood': Ionicons.fast_food_outline,
      'local_dining': Ionicons.restaurant_outline,
      'local_pizza': Ionicons.pizza_outline,
      'local_cafe': Ionicons.cafe_outline,
      'local_bar': Ionicons.beer_outline,
      'coffee': Ionicons.cafe_outline,
      'cake': Ionicons.ice_cream_outline,
      'icecream': Ionicons.ice_cream_outline,
      'brunch_dining': Ionicons.restaurant_outline,
      'lunch_dining': Ionicons.fast_food_outline,
      'dinner_dining': Ionicons.restaurant_outline,
      'breakfast_dining': Ionicons.cafe_outline,
      'microwave': Ionicons.square_outline,
      'blender': Ionicons.nutrition_outline,
      'soup_kitchen': Ionicons.restaurant_outline,

      // Sports & Fitness
      'sports_basketball': Ionicons.basketball_outline,
      'sports_football': Ionicons.football_outline,
      'sports_soccer': Ionicons.football_outline,
      'sports_baseball': Ionicons.baseball_outline,
      'sports_tennis': Ionicons.tennisball_outline,
      'sports_golf': Ionicons.golf_outline,
      'sports_hockey': Ionicons.american_football_outline,
      'sports_volleyball': Ionicons.american_football_outline,
      'sports_cricket': Ionicons.american_football_outline,
      'sports_martial_arts': Ionicons.barbell_outline,
      'fitness_center': Ionicons.fitness_outline,
      'pool': Ionicons.water_outline,
      'surfing': Ionicons.boat_outline,
      'hiking': Ionicons.walk_outline,
      'snowboarding': Ionicons.snow_outline,
      'downhill_skiing': Ionicons.snow_outline,

      // Outdoor & Nature
      'park': Ionicons.leaf_outline,
      'local_florist': Ionicons.flower_outline,
      'nature': Ionicons.leaf_outline,
      'eco': Ionicons.leaf_outline,
      'forest': Ionicons.leaf_outline,
      'grass': Ionicons.leaf_outline,
      'outdoor_grill': Ionicons.flame_outline,
      'fireplace': Ionicons.flame_outline,
      'agriculture': Ionicons.leaf_outline,

      // Pets & Animals
      'pets': Ionicons.paw_outline,
      'cruelty_free': Ionicons.paw_outline,

      // Transportation
      'directions_car': Ionicons.car_outline,
      'directions_bike': Ionicons.bicycle_outline,
      'directions_bus': Ionicons.bus_outline,
      'directions_boat': Ionicons.boat_outline,
      'flight': Ionicons.airplane_outline,
      'train': Ionicons.train_outline,
      'two_wheeler': Ionicons.bicycle_outline,
      'electric_scooter': Ionicons.bicycle_outline,
      'electric_bike': Ionicons.bicycle_outline,
      'electric_car': Ionicons.car_sport_outline,
      'local_shipping': Ionicons.bus_outline,

      // Health & Medical
      'medical_services': Ionicons.medical_outline,
      'medication': Ionicons.medical_outline,
      'vaccines': Ionicons.medical_outline,
      'healing': Ionicons.pulse_outline,
      'monitor_heart': Ionicons.pulse_outline,

      // Office & School
      'work': Ionicons.briefcase_outline,
      'school': Ionicons.school_outline,
      'science': Ionicons.flask_outline,
      'calculate': Ionicons.calculator_outline,
      'edit': Ionicons.pencil_outline,
      'draw': Ionicons.brush_outline,
      'palette': Ionicons.color_palette_outline,
      'brush': Ionicons.brush_outline,

      // Miscellaneous
      'lightbulb': Ionicons.bulb_outline,
      'wb_sunny': Ionicons.sunny_outline,
      'ac_unit': Ionicons.snow_outline,
      'thermostat': Ionicons.thermometer_outline,
      'toys': Ionicons.game_controller_outline,
      'child_care': Ionicons.happy_outline,
      'nightlight': Ionicons.moon_outline,
      'flashlight_on': Ionicons.flashlight_outline,
      'celebration': Ionicons.trophy_outline,
      'card_giftcard': Ionicons.gift_outline,
      'redeem': Ionicons.gift_outline,
      'shopping_cart': Ionicons.cart_outline,
      'wallet': Ionicons.wallet_outline,
      'savings': Ionicons.cash_outline,
      'attach_money': Ionicons.cash_outline,
    };

    return iconMap[iconName] ?? Ionicons.cube_outline;
  }

  // Get icon for a container type name (for backward compatibility)
  static IconData getContainerIcon(String containerType) {
    switch (containerType.toLowerCase()) {
      case 'room':
        return Ionicons.business_outline;
      case 'shelf':
        return Ionicons.albums_outline;
      case 'box':
        return Ionicons.cube_outline;
      case 'fridge':
        return Ionicons.restaurant_outline;
      case 'drawer':
        return Ionicons.file_tray_outline;
      case 'cabinet':
        return Ionicons.file_tray_outline;
      case 'closet':
        return Ionicons.exit_outline;
      case 'bin':
        return Ionicons.trash_outline;
      default:
        return Ionicons.cube_outline;
    }
  }

  // Get icon for an item type name (for backward compatibility)
  static IconData getItemIcon(String itemType) {
    switch (itemType.toLowerCase()) {
      case 'book':
        return Ionicons.book_outline;
      case 'vinyl':
      case 'music':
        return Ionicons.disc_outline;
      case 'game':
        return Ionicons.game_controller_outline;
      case 'tool':
        return Ionicons.build_outline;
      case 'camera':
        return Ionicons.camera_outline;
      case 'electronics':
        return Ionicons.phone_portrait_outline;
      case 'clothing':
        return Ionicons.shirt_outline;
      case 'kitchen':
        return Ionicons.restaurant_outline;
      case 'outdoor':
        return Ionicons.leaf_outline;
      case 'pantry':
        return Ionicons.restaurant_outline;
      default:
        return Ionicons.apps_outline;
    }
  }
}
