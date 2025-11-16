import 'package:flutter/material.dart';

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

  // Curated list of common Material icons
  static const Map<String, List<Map<String, dynamic>>> iconCategories = {
    'Common': [
      {'name': 'inventory_2', 'icon': Icons.inventory_2},
      {'name': 'home', 'icon': Icons.home},
      {'name': 'folder', 'icon': Icons.folder},
      {'name': 'category', 'icon': Icons.category},
      {'name': 'label', 'icon': Icons.label},
      {'name': 'star', 'icon': Icons.star},
      {'name': 'favorite', 'icon': Icons.favorite},
      {'name': 'bookmark', 'icon': Icons.bookmark},
      {'name': 'flag', 'icon': Icons.flag},
      {'name': 'grade', 'icon': Icons.grade},
    ],
    'Home & Rooms': [
      {'name': 'meeting_room', 'icon': Icons.meeting_room},
      {'name': 'bed', 'icon': Icons.bed},
      {'name': 'bedroom_parent', 'icon': Icons.bedroom_parent},
      {'name': 'bedroom_child', 'icon': Icons.bedroom_child},
      {'name': 'bedroom_baby', 'icon': Icons.bedroom_baby},
      {'name': 'kitchen', 'icon': Icons.kitchen},
      {'name': 'dining_outlined', 'icon': Icons.dining_outlined},
      {'name': 'bathroom', 'icon': Icons.bathroom},
      {'name': 'bathtub', 'icon': Icons.bathtub},
      {'name': 'weekend', 'icon': Icons.weekend},
      {'name': 'living', 'icon': Icons.living},
      {'name': 'chair', 'icon': Icons.chair},
      {'name': 'garage', 'icon': Icons.garage},
      {'name': 'door_sliding', 'icon': Icons.door_sliding},
      {'name': 'door_front', 'icon': Icons.door_front_door},
      {'name': 'door_back', 'icon': Icons.door_back_door},
      {'name': 'countertops', 'icon': Icons.countertops},
      {'name': 'shelves', 'icon': Icons.shelves},
      {'name': 'desk', 'icon': Icons.desk},
      {'name': 'table_restaurant', 'icon': Icons.table_restaurant},
      {'name': 'yard', 'icon': Icons.yard},
      {'name': 'deck', 'icon': Icons.deck},
      {'name': 'balcony', 'icon': Icons.balcony},
    ],
    'Storage': [
      {'name': 'inventory_2', 'icon': Icons.inventory_2},
      {'name': 'archive', 'icon': Icons.archive},
      {'name': 'folder', 'icon': Icons.folder},
      {'name': 'folder_special', 'icon': Icons.folder_special},
      {'name': 'source', 'icon': Icons.source},
      {'name': 'work_outline', 'icon': Icons.work_outline},
      {'name': 'backpack', 'icon': Icons.backpack},
      {'name': 'business_center', 'icon': Icons.business_center},
      {'name': 'shopping_bag', 'icon': Icons.shopping_bag},
      {'name': 'luggage', 'icon': Icons.luggage},
      {'name': 'cases', 'icon': Icons.cases},
      {'name': 'inbox', 'icon': Icons.inbox},
      {'name': 'delete_outline', 'icon': Icons.delete_outline},
      {'name': 'storage', 'icon': Icons.storage},
      {'name': 'shelves', 'icon': Icons.shelves},
    ],
    'Items & Entertainment': [
      {'name': 'menu_book', 'icon': Icons.menu_book},
      {'name': 'book', 'icon': Icons.book},
      {'name': 'library_books', 'icon': Icons.library_books},
      {'name': 'album', 'icon': Icons.album},
      {'name': 'music_note', 'icon': Icons.music_note},
      {'name': 'library_music', 'icon': Icons.library_music},
      {'name': 'headphones', 'icon': Icons.headphones},
      {'name': 'speaker', 'icon': Icons.speaker},
      {'name': 'sports_esports', 'icon': Icons.sports_esports},
      {'name': 'videogame_asset', 'icon': Icons.videogame_asset},
      {'name': 'movie', 'icon': Icons.movie},
      {'name': 'theaters', 'icon': Icons.theaters},
      {'name': 'tv', 'icon': Icons.tv},
      {'name': 'video_library', 'icon': Icons.video_library},
    ],
    'Electronics & Tools': [
      {'name': 'devices', 'icon': Icons.devices},
      {'name': 'phone_android', 'icon': Icons.phone_android},
      {'name': 'tablet', 'icon': Icons.tablet},
      {'name': 'laptop', 'icon': Icons.laptop},
      {'name': 'computer', 'icon': Icons.computer},
      {'name': 'keyboard', 'icon': Icons.keyboard},
      {'name': 'mouse', 'icon': Icons.mouse},
      {'name': 'watch', 'icon': Icons.watch},
      {'name': 'camera_alt', 'icon': Icons.camera_alt},
      {'name': 'photo_camera', 'icon': Icons.photo_camera},
      {'name': 'videocam', 'icon': Icons.videocam},
      {'name': 'print', 'icon': Icons.print},
      {'name': 'build', 'icon': Icons.build},
      {'name': 'construction', 'icon': Icons.construction},
      {'name': 'handyman', 'icon': Icons.handyman},
      {'name': 'hardware', 'icon': Icons.hardware},
      {'name': 'plumbing', 'icon': Icons.plumbing},
      {'name': 'electrical_services', 'icon': Icons.electrical_services},
      {'name': 'carpenter', 'icon': Icons.carpenter},
      {'name': 'engineering', 'icon': Icons.engineering},
    ],
    'Clothing & Fashion': [
      {'name': 'checkroom', 'icon': Icons.checkroom},
      {'name': 'dry_cleaning', 'icon': Icons.dry_cleaning},
      {'name': 'shopping_bag', 'icon': Icons.shopping_bag},
      {'name': 'watch', 'icon': Icons.watch},
      {'name': 'diamond', 'icon': Icons.diamond},
      {'name': 'umbrella', 'icon': Icons.umbrella},
    ],
    'Kitchen & Food': [
      {'name': 'restaurant', 'icon': Icons.restaurant},
      {'name': 'restaurant_menu', 'icon': Icons.restaurant_menu},
      {'name': 'fastfood', 'icon': Icons.fastfood},
      {'name': 'local_dining', 'icon': Icons.local_dining},
      {'name': 'local_pizza', 'icon': Icons.local_pizza},
      {'name': 'local_cafe', 'icon': Icons.local_cafe},
      {'name': 'local_bar', 'icon': Icons.local_bar},
      {'name': 'coffee', 'icon': Icons.coffee},
      {'name': 'cake', 'icon': Icons.cake},
      {'name': 'icecream', 'icon': Icons.icecream},
      {'name': 'brunch_dining', 'icon': Icons.brunch_dining},
      {'name': 'lunch_dining', 'icon': Icons.lunch_dining},
      {'name': 'dinner_dining', 'icon': Icons.dinner_dining},
      {'name': 'breakfast_dining', 'icon': Icons.breakfast_dining},
      {'name': 'kitchen', 'icon': Icons.kitchen},
      {'name': 'microwave', 'icon': Icons.microwave},
      {'name': 'blender', 'icon': Icons.blender},
      {'name': 'soup_kitchen', 'icon': Icons.soup_kitchen},
    ],
    'Sports & Fitness': [
      {'name': 'sports_basketball', 'icon': Icons.sports_basketball},
      {'name': 'sports_football', 'icon': Icons.sports_football},
      {'name': 'sports_soccer', 'icon': Icons.sports_soccer},
      {'name': 'sports_baseball', 'icon': Icons.sports_baseball},
      {'name': 'sports_tennis', 'icon': Icons.sports_tennis},
      {'name': 'sports_golf', 'icon': Icons.sports_golf},
      {'name': 'sports_hockey', 'icon': Icons.sports_hockey},
      {'name': 'sports_volleyball', 'icon': Icons.sports_volleyball},
      {'name': 'sports_cricket', 'icon': Icons.sports_cricket},
      {'name': 'sports_martial_arts', 'icon': Icons.sports_martial_arts},
      {'name': 'fitness_center', 'icon': Icons.fitness_center},
      {'name': 'pool', 'icon': Icons.pool},
      {'name': 'surfing', 'icon': Icons.surfing},
      {'name': 'hiking', 'icon': Icons.hiking},
      {'name': 'snowboarding', 'icon': Icons.snowboarding},
      {'name': 'downhill_skiing', 'icon': Icons.downhill_skiing},
    ],
    'Outdoor & Nature': [
      {'name': 'park', 'icon': Icons.park},
      {'name': 'local_florist', 'icon': Icons.local_florist},
      {'name': 'nature', 'icon': Icons.nature},
      {'name': 'eco', 'icon': Icons.eco},
      {'name': 'forest', 'icon': Icons.forest},
      {'name': 'grass', 'icon': Icons.grass},
      {'name': 'yard', 'icon': Icons.yard},
      {'name': 'outdoor_grill', 'icon': Icons.outdoor_grill},
      {'name': 'fireplace', 'icon': Icons.fireplace},
      {'name': 'agriculture', 'icon': Icons.agriculture},
    ],
    'Pets & Animals': [
      {'name': 'pets', 'icon': Icons.pets},
      {'name': 'cruelty_free', 'icon': Icons.cruelty_free},
    ],
    'Transportation': [
      {'name': 'directions_car', 'icon': Icons.directions_car},
      {'name': 'directions_bike', 'icon': Icons.directions_bike},
      {'name': 'directions_bus', 'icon': Icons.directions_bus},
      {'name': 'directions_boat', 'icon': Icons.directions_boat},
      {'name': 'flight', 'icon': Icons.flight},
      {'name': 'train', 'icon': Icons.train},
      {'name': 'two_wheeler', 'icon': Icons.two_wheeler},
      {'name': 'electric_scooter', 'icon': Icons.electric_scooter},
      {'name': 'electric_bike', 'icon': Icons.electric_bike},
      {'name': 'electric_car', 'icon': Icons.electric_car},
      {'name': 'local_shipping', 'icon': Icons.local_shipping},
    ],
    'Health & Medical': [
      {'name': 'medical_services', 'icon': Icons.medical_services},
      {'name': 'medication', 'icon': Icons.medication},
      {'name': 'vaccines', 'icon': Icons.vaccines},
      {'name': 'healing', 'icon': Icons.healing},
      {'name': 'favorite', 'icon': Icons.favorite},
      {'name': 'monitor_heart', 'icon': Icons.monitor_heart},
    ],
    'Office & School': [
      {'name': 'work', 'icon': Icons.work},
      {'name': 'school', 'icon': Icons.school},
      {'name': 'backpack', 'icon': Icons.backpack},
      {'name': 'science', 'icon': Icons.science},
      {'name': 'calculate', 'icon': Icons.calculate},
      {'name': 'edit', 'icon': Icons.edit},
      {'name': 'draw', 'icon': Icons.draw},
      {'name': 'palette', 'icon': Icons.palette},
      {'name': 'brush', 'icon': Icons.brush},
    ],
    'Miscellaneous': [
      {'name': 'lightbulb', 'icon': Icons.lightbulb},
      {'name': 'wb_sunny', 'icon': Icons.wb_sunny},
      {'name': 'ac_unit', 'icon': Icons.ac_unit},
      {'name': 'thermostat', 'icon': Icons.thermostat},
      {'name': 'toys', 'icon': Icons.toys},
      {'name': 'child_care', 'icon': Icons.child_care},
      {'name': 'nightlight', 'icon': Icons.nightlight},
      {'name': 'flashlight_on', 'icon': Icons.flashlight_on},
      {'name': 'celebration', 'icon': Icons.celebration},
      {'name': 'card_giftcard', 'icon': Icons.card_giftcard},
      {'name': 'redeem', 'icon': Icons.redeem},
      {'name': 'shopping_cart', 'icon': Icons.shopping_cart},
      {'name': 'wallet', 'icon': Icons.wallet},
      {'name': 'savings', 'icon': Icons.savings},
      {'name': 'attach_money', 'icon': Icons.attach_money},
    ],
  };

  List<Map<String, dynamic>> get filteredIcons {
    if (_searchQuery.isEmpty) {
      // Return all icons from all categories
      return iconCategories.values.expand((list) => list).toList();
    }

    return iconCategories.values
        .expand((list) => list)
        .where((icon) =>
            icon['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 400,
        height: 500,
        padding: const EdgeInsets.all(16),
        child: Column(
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
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Search icons...',
                prefixIcon: const Icon(Icons.search),
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
            const SizedBox(height: 16),

            // Icon grid
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
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
                        color: isSelected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Colors.transparent,
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade300,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            icon,
                            size: 32,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : null,
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
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _selectedIcon != null
                      ? () => Navigator.pop(context, _selectedIcon)
                      : null,
                  child: const Text('Select'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
