import 'package:ionicons/ionicons.dart';
import 'package:flutter/material.dart';
import '../widgets/icon_picker_dialog.dart';
import '../../data/models/container_type.dart';
import '../../data/models/item_type.dart';
import '../../utils/icon_helper.dart';

class TypeEditDialog extends StatefulWidget {
  final String mode; // 'container' or 'item'
  final bool isEdit;
  final ContainerType? containerType;
  final ItemType? itemType;

  const TypeEditDialog.container({
    super.key,
    required this.isEdit,
    this.containerType,
  })  : mode = 'container',
        itemType = null;

  const TypeEditDialog.item({
    super.key,
    required this.isEdit,
    this.itemType,
  })  : mode = 'item',
        containerType = null;

  @override
  State<TypeEditDialog> createState() => _TypeEditDialogState();
}

class _TypeEditDialogState extends State<TypeEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late String _selectedIcon;
  late bool _allowNested;

  @override
  void initState() {
    super.initState();

    if (widget.mode == 'container') {
      _nameController = TextEditingController(
        text: widget.containerType?.displayName ?? '',
      );
      _selectedIcon = widget.containerType?.icon ?? 'inventory_2';
      _allowNested = widget.containerType?.allowNested ?? true;
    } else {
      _nameController = TextEditingController(
        text: widget.itemType?.displayName ?? '',
      );
      _selectedIcon = widget.itemType?.icon ?? 'inventory_2';
      _allowNested = false; // Not used for items
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickIcon() async {
    final icon = await showDialog<String>(
      context: context,
      builder: (context) => IconPickerDialog(initialIcon: _selectedIcon),
    );

    if (icon != null) {
      setState(() {
        _selectedIcon = icon;
      });
    }
  }


  void _save() {
    if (_formKey.currentState!.validate()) {
      final result = {
        'displayName': _nameController.text.trim(),
        'icon': _selectedIcon,
        if (widget.mode == 'container') 'allowNested': _allowNested,
      };

      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isContainer = widget.mode == 'container';
    final title = widget.isEdit
        ? 'Edit ${isContainer ? 'Container' : 'Item'} Type'
        : 'Create ${isContainer ? 'Container' : 'Item'} Type';

    return AlertDialog(
      title: Text(title),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g., Wine Rack',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  if (value.trim().length > 30) {
                    return 'Name must be 30 characters or less';
                  }
                  return null;
                },
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              // Icon selector
              const Text('Icon', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickIcon,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(IconHelper.getIconData(_selectedIcon), size: 32),
                      const SizedBox(width: 12),
                      Text(_selectedIcon),
                      const Spacer(),
                      const Icon(Ionicons.create_outline, size: 20),
                    ],
                  ),
                ),
              ),

              // Allow nested checkbox (container types only)
              if (isContainer) ...[
                const SizedBox(height: 16),
                CheckboxListTile(
                  value: _allowNested,
                  onChanged: (value) {
                    setState(() {
                      _allowNested = value ?? true;
                    });
                  },
                  title: const Text('Allow nested containers'),
                  subtitle: const Text('Can this container hold other containers?'),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(widget.isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
