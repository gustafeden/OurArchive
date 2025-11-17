import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

class IconPickerDialog extends StatefulWidget {
  final String? initialIcon;

  const IconPickerDialog({super.key, this.initialIcon});

  @override
  State<IconPickerDialog> createState() => _IconPickerDialogState();
}

class _IconPickerDialogState extends State<IconPickerDialog> {
  String _searchQuery = '';
  String? _selectedIcon;

  @override
  void initState() {
    super.initState();
    _selectedIcon = widget.initialIcon;
  }

  // Curated list of Ionicons organized by category
  static final Map<String, List<Map<String, dynamic>>> iconCategories = {
    'Common': [
      {'name': 'inventory_2', 'icon': Ionicons.cube_outline},
      {'name': 'home', 'icon': Ionicons.home_outline},
      {'name': 'folder', 'icon': Ionicons.folder_outline},
      {'name': 'category', 'icon': Ionicons.apps_outline},
      {'name': 'label', 'icon': Ionicons.pricetag_outline},
      {'name': 'star', 'icon': Ionicons.star_outline},
      {'name': 'favorite', 'icon': Ionicons.heart_outline},
      {'name': 'bookmark', 'icon': Ionicons.bookmark_outline},
      {'name': 'flag', 'icon': Ionicons.flag_outline},
      {'name': 'grade', 'icon': Ionicons.ribbon_outline},
    ],
    'Home & Rooms': [
      {'name': 'meeting_room', 'icon': Ionicons.business_outline},
      {'name': 'bed', 'icon': Ionicons.bed_outline},
      {'name': 'bedroom_parent', 'icon': Ionicons.bed_outline},
      {'name': 'kitchen', 'icon': Ionicons.restaurant_outline},
      {'name': 'bathroom', 'icon': Ionicons.water_outline},
      {'name': 'living', 'icon': Ionicons.tv_outline},
      {'name': 'garage', 'icon': Ionicons.car_outline},
      {'name': 'door_sliding', 'icon': Ionicons.exit_outline},
      {'name': 'door_front', 'icon': Ionicons.enter_outline},
      {'name': 'shelves', 'icon': Ionicons.albums_outline},
      {'name': 'desk', 'icon': Ionicons.desktop_outline},
      {'name': 'yard', 'icon': Ionicons.leaf_outline},
    ],
    'Storage': [
      {'name': 'archive', 'icon': Ionicons.archive_outline},
      {'name': 'folder_special', 'icon': Ionicons.folder_open_outline},
      {'name': 'work_outline', 'icon': Ionicons.briefcase_outline},
      {'name': 'backpack', 'icon': Ionicons.bag_outline},
      {'name': 'shopping_bag', 'icon': Ionicons.bag_handle_outline},
      {'name': 'inbox', 'icon': Ionicons.mail_outline},
      {'name': 'delete_outline', 'icon': Ionicons.trash_outline},
      {'name': 'storage', 'icon': Ionicons.server_outline},
    ],
    'Items & Entertainment': [
      {'name': 'menu_book', 'icon': Ionicons.book_outline},
      {'name': 'book', 'icon': Ionicons.book_outline},
      {'name': 'library_books', 'icon': Ionicons.library_outline},
      {'name': 'album', 'icon': Ionicons.disc_outline},
      {'name': 'music_note', 'icon': Ionicons.musical_note_outline},
      {'name': 'library_music', 'icon': Ionicons.musical_notes_outline},
      {'name': 'headphones', 'icon': Ionicons.headset_outline},
      {'name': 'speaker', 'icon': Ionicons.volume_high_outline},
      {'name': 'sports_esports', 'icon': Ionicons.game_controller_outline},
      {'name': 'movie', 'icon': Ionicons.film_outline},
      {'name': 'tv', 'icon': Ionicons.tv_outline},
      {'name': 'videocam', 'icon': Ionicons.videocam_outline},
    ],
    'Electronics & Tools': [
      {'name': 'devices', 'icon': Ionicons.phone_portrait_outline},
      {'name': 'phone_android', 'icon': Ionicons.phone_portrait_outline},
      {'name': 'tablet', 'icon': Ionicons.tablet_portrait_outline},
      {'name': 'laptop', 'icon': Ionicons.laptop_outline},
      {'name': 'computer', 'icon': Ionicons.desktop_outline},
      {'name': 'watch', 'icon': Ionicons.watch_outline},
      {'name': 'camera_alt', 'icon': Ionicons.camera_outline},
      {'name': 'print', 'icon': Ionicons.print_outline},
      {'name': 'build', 'icon': Ionicons.build_outline},
      {'name': 'construction', 'icon': Ionicons.construct_outline},
      {'name': 'handyman', 'icon': Ionicons.hammer_outline},
      {'name': 'engineering', 'icon': Ionicons.settings_outline},
    ],
    'Clothing & Fashion': [
      {'name': 'checkroom', 'icon': Ionicons.shirt_outline},
      {'name': 'diamond', 'icon': Ionicons.diamond_outline},
      {'name': 'umbrella', 'icon': Ionicons.umbrella_outline},
    ],
    'Kitchen & Food': [
      {'name': 'restaurant', 'icon': Ionicons.restaurant_outline},
      {'name': 'fastfood', 'icon': Ionicons.fast_food_outline},
      {'name': 'local_pizza', 'icon': Ionicons.pizza_outline},
      {'name': 'local_cafe', 'icon': Ionicons.cafe_outline},
      {'name': 'local_bar', 'icon': Ionicons.beer_outline},
      {'name': 'coffee', 'icon': Ionicons.cafe_outline},
      {'name': 'icecream', 'icon': Ionicons.ice_cream_outline},
    ],
    'Sports & Fitness': [
      {'name': 'sports_basketball', 'icon': Ionicons.basketball_outline},
      {'name': 'sports_football', 'icon': Ionicons.football_outline},
      {'name': 'sports_baseball', 'icon': Ionicons.baseball_outline},
      {'name': 'sports_tennis', 'icon': Ionicons.tennisball_outline},
      {'name': 'sports_golf', 'icon': Ionicons.golf_outline},
      {'name': 'fitness_center', 'icon': Ionicons.fitness_outline},
      {'name': 'hiking', 'icon': Ionicons.walk_outline},
    ],
    'Outdoor & Nature': [
      {'name': 'park', 'icon': Ionicons.leaf_outline},
      {'name': 'local_florist', 'icon': Ionicons.flower_outline},
      {'name': 'nature', 'icon': Ionicons.leaf_outline},
      {'name': 'eco', 'icon': Ionicons.leaf_outline},
      {'name': 'outdoor_grill', 'icon': Ionicons.flame_outline},
      {'name': 'fireplace', 'icon': Ionicons.flame_outline},
    ],
    'Pets & Animals': [
      {'name': 'pets', 'icon': Ionicons.paw_outline},
    ],
    'Transportation': [
      {'name': 'directions_car', 'icon': Ionicons.car_outline},
      {'name': 'directions_bike', 'icon': Ionicons.bicycle_outline},
      {'name': 'directions_bus', 'icon': Ionicons.bus_outline},
      {'name': 'directions_boat', 'icon': Ionicons.boat_outline},
      {'name': 'flight', 'icon': Ionicons.airplane_outline},
      {'name': 'train', 'icon': Ionicons.train_outline},
      {'name': 'electric_car', 'icon': Ionicons.car_sport_outline},
    ],
    'Health & Medical': [
      {'name': 'medical_services', 'icon': Ionicons.medical_outline},
      {'name': 'healing', 'icon': Ionicons.pulse_outline},
      {'name': 'monitor_heart', 'icon': Ionicons.pulse_outline},
    ],
    'Office & School': [
      {'name': 'work', 'icon': Ionicons.briefcase_outline},
      {'name': 'school', 'icon': Ionicons.school_outline},
      {'name': 'science', 'icon': Ionicons.flask_outline},
      {'name': 'calculate', 'icon': Ionicons.calculator_outline},
      {'name': 'edit', 'icon': Ionicons.pencil_outline},
      {'name': 'draw', 'icon': Ionicons.brush_outline},
      {'name': 'palette', 'icon': Ionicons.color_palette_outline},
    ],
    'Miscellaneous': [
      {'name': 'lightbulb', 'icon': Ionicons.bulb_outline},
      {'name': 'wb_sunny', 'icon': Ionicons.sunny_outline},
      {'name': 'ac_unit', 'icon': Ionicons.snow_outline},
      {'name': 'flashlight_on', 'icon': Ionicons.flashlight_outline},
      {'name': 'celebration', 'icon': Ionicons.trophy_outline},
      {'name': 'card_giftcard', 'icon': Ionicons.gift_outline},
      {'name': 'shopping_cart', 'icon': Ionicons.cart_outline},
      {'name': 'wallet', 'icon': Ionicons.wallet_outline},
      {'name': 'attach_money', 'icon': Ionicons.cash_outline},
    ],
  };

  List<Map<String, dynamic>> get filteredIcons {
    if (_searchQuery.isEmpty) {
      // Return all icons from all categories
      return iconCategories.values.expand((list) => list).toList();
    }

    return iconCategories.values
        .expand((list) => list)
        .where((icon) => icon['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 400,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  const Text(
                    'Select Icon',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Ionicons.close_outline),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Search bar
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search icons...',
                  prefixIcon: const Icon(Ionicons.search_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
              const SizedBox(height: 12),

              // Icon grid
              SizedBox(
                height: 360,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: filteredIcons.length,
                  itemBuilder: (context, index) {
                    final iconData = filteredIcons[index];
                    final iconName = iconData['name'] as String;
                    final icon = iconData['icon'] as IconData;
                    final isSelected = _selectedIcon == iconName;

                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedIcon = iconName;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? Theme.of(context).colorScheme.primaryContainer : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 40,
                              child: Center(
                                child: Icon(
                                  icon,
                                  size: 32,
                                  color: isSelected ? Theme.of(context).colorScheme.primary : null,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              iconName.split('_').first,
                              style: const TextStyle(fontSize: 10),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Actions
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _selectedIcon != null ? () => Navigator.pop(context, _selectedIcon) : null,
                    child: const Text('Select'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
