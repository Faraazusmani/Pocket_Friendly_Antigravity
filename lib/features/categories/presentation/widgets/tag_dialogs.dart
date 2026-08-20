import 'package:flutter/material.dart';
import '../../../../core/design_system/tokens.dart';
import '../../domain/tag.dart';

class CreateTagDialog extends StatefulWidget {
  final Function(String tagName) onSave;

  const CreateTagDialog({Key? key, required this.onSave}) : super(key: key);

  @override
  State<CreateTagDialog> createState() => _CreateTagDialogState();
}

class _CreateTagDialogState extends State<CreateTagDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark
        ? AppColors.darkSurfacePrimary
        : AppColors.lightSurfacePrimary;
    final borderCol = isDark
        ? AppColors.darkBorderSubtle
        : AppColors.lightBorderSubtle;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return AlertDialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        side: BorderSide(color: borderCol),
      ),
      title: Text(
        'NEW TAG',
        style: AppTypography.sectionHeading.copyWith(
          color: textPrimary,
          letterSpacing: 1.5,
        ),
      ),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          style: TextStyle(color: textPrimary),
          decoration: InputDecoration(
            labelText: 'Tag Name',
            labelStyle: TextStyle(color: textSecondary),
            hintText: 'e.g. business',
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: borderCol),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.darkAccentPrimary),
            ),
          ),
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return 'Please enter tag name';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          child: Text(
            'CANCEL',
            style: TextStyle(color: textSecondary, fontWeight: FontWeight.bold),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark
                ? AppColors.darkAccentPrimary
                : AppColors.lightAccentPrimary,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
          ),
          child: const Text(
            'CREATE',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onSave(_controller.text.trim());
              Navigator.pop(context);
            }
          },
        ),
      ],
    );
  }
}

class RenameTagDialog extends StatefulWidget {
  final Tag tag;
  final Function(String newName) onSave;

  const RenameTagDialog({Key? key, required this.tag, required this.onSave})
    : super(key: key);

  @override
  State<RenameTagDialog> createState() => _RenameTagDialogState();
}

class _RenameTagDialogState extends State<RenameTagDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.tag.name);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark
        ? AppColors.darkSurfacePrimary
        : AppColors.lightSurfacePrimary;
    final borderCol = isDark
        ? AppColors.darkBorderSubtle
        : AppColors.lightBorderSubtle;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return AlertDialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        side: BorderSide(color: borderCol),
      ),
      title: Text(
        'RENAME TAG',
        style: AppTypography.sectionHeading.copyWith(
          color: textPrimary,
          letterSpacing: 1.5,
        ),
      ),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          style: TextStyle(color: textPrimary),
          decoration: InputDecoration(
            labelText: 'Tag Name',
            labelStyle: TextStyle(color: textSecondary),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: borderCol),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.darkAccentPrimary),
            ),
          ),
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return 'Please enter tag name';
            }
            if (val.trim() == widget.tag.name) {
              return 'Enter a new name to rename';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          child: Text(
            'CANCEL',
            style: TextStyle(color: textSecondary, fontWeight: FontWeight.bold),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark
                ? AppColors.darkAccentPrimary
                : AppColors.lightAccentPrimary,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
          ),
          child: const Text(
            'SAVE',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onSave(_controller.text.trim());
              Navigator.pop(context);
            }
          },
        ),
      ],
    );
  }
}
