import 'dart:io';
import 'package:flutter_structure/core/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/utils/image_validation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/sport_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../controllers/provider_controller.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/sporve_button.dart';
import '../../widgets/sporve_image.dart';

class CreateListingBottomSheet extends StatefulWidget {
  final int? editIndex;

  const CreateListingBottomSheet({super.key, this.editIndex});

  @override
  State<CreateListingBottomSheet> createState() =>
      _CreateListingBottomSheetState();
}

class _CreateListingBottomSheetState extends State<CreateListingBottomSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _maxCapacityController;
  late final TextEditingController _addressLine1Controller;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _zipController;
  late final TextEditingController _countryController;
  late final TextEditingController _minAgeController;
  late final TextEditingController _maxAgeController;
  late final TextEditingController _imageUrlController;
  String? _pickedImagePath;
  final List<String> _pickedGalleryPaths = [];

  String _selectedSport = 'Soccer';
  String _selectedListingType = 'Training';
  String _selectedSkillLevel = 'beginner';
  String _selectedAgeGroup = 'u12';
  String _selectedLanguage = 'English';
  String _selectedPricingModel = 'single_session';
  String _selectedCancellationPolicy = 'flexible';

  // The full catalogue, each with its identity color — no longer a hardcoded 5.
  final List<String> _sports = SportColors.pickerNames;
  final List<String> _listingTypes = const [
    'Training',
    'Camp',
    'Clinic',
    'Class',
    'League',
    'AAU',
    'Private Lesson',
    'Tournament',
  ];
  final List<String> _skillLevels = ['beginner', 'intermediate', 'advanced'];
  final List<String> _ageGroups = ['u8', 'u10', 'u12', 'u14', 'u16', 'u18'];
  final List<String> _languages = ['English', 'Spanish', 'French'];
  final List<String> _pricingModels = ['single_session', 'monthly', 'package'];
  final List<String> _cancellationPolicies = ['flexible', 'moderate', 'strict'];

  @override
  void initState() {
    super.initState();
    final controller = context.read<ProviderController>();

    if (widget.editIndex != null) {
      final listing = controller.listings[widget.editIndex!];
      _titleController = TextEditingController(text: listing.title);
      _descriptionController = TextEditingController(text: listing.description);
      _priceController = TextEditingController(text: listing.price.toString());
      _maxCapacityController = TextEditingController(
        text: listing.maxCapacity.toString(),
      );
      _addressLine1Controller = TextEditingController(
        text: listing.addressLine1,
      );
      _cityController = TextEditingController(text: listing.city);
      _stateController = TextEditingController(text: listing.state);
      _zipController = TextEditingController(text: listing.zip);
      _countryController = TextEditingController(text: listing.country);
      _minAgeController = TextEditingController(
        text: listing.minimumAge.toString(),
      );
      _maxAgeController = TextEditingController(
        text: listing.maximumAge.toString(),
      );
      _imageUrlController = TextEditingController(text: listing.image);
      if (listing.image.isNotEmpty && !listing.image.startsWith('http')) {
        _pickedImagePath = listing.image;
      }

      // Match case-insensitively so the dropdown value is always a valid item
      // (a stored 'soccer' must map to the 'Soccer' option, not crash).
      _selectedSport = _sports.firstWhere(
        (s) => s.toLowerCase() == listing.sportType.toLowerCase(),
        orElse: () => _sports.first,
      );
      _selectedListingType = _listingTypes.contains(listing.programType)
          ? listing.programType
          : _listingTypes.first;
      _selectedSkillLevel = listing.skillLevel;
      _selectedAgeGroup = listing.ageGroup;
      _selectedLanguage = listing.language;
      _selectedPricingModel = listing.pricingModel;
      _selectedCancellationPolicy = listing.cancellationPolicy;
    } else {
      _titleController = TextEditingController();
      _descriptionController = TextEditingController();
      _priceController = TextEditingController();
      _maxCapacityController = TextEditingController();
      _addressLine1Controller = TextEditingController();
      _cityController = TextEditingController();
      _stateController = TextEditingController();
      _zipController = TextEditingController();
      _countryController = TextEditingController();
      _minAgeController = TextEditingController();
      _maxAgeController = TextEditingController();
      _imageUrlController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _maxCapacityController.dispose();
    _addressLine1Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    _countryController.dispose();
    _minAgeController.dispose();
    _maxAgeController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  void _submitForm() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final priceStr = _priceController.text.trim();
    final maxCapacityStr = _maxCapacityController.text.trim();
    final addressLine1 = _addressLine1Controller.text.trim();
    final city = _cityController.text.trim();
    final state = _stateController.text.trim();
    final zip = _zipController.text.trim();
    final country = _countryController.text.trim();
    final minAgeStr = _minAgeController.text.trim();
    final maxAgeStr = _maxAgeController.text.trim();
    final imageUrl = _pickedImagePath ?? _imageUrlController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Title is required'),
          backgroundColor: AppColors.negative,
        ),
      );
      return;
    }

    // Price is REQUIRED and must be > $0 — otherwise the listing can't be paid
    // for and booking dead-ends with "no payable amount".
    final price = double.tryParse(priceStr);
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a price greater than \$0 so it can be booked.'),
          backgroundColor: AppColors.negative,
        ),
      );
      return;
    }

    final listing = ProviderListing(
      image: imageUrl,
      title: title,
      description: description,
      sportType: _selectedSport,
      programType: _selectedListingType,
      skillLevel: _selectedSkillLevel,
      ageGroup: _selectedAgeGroup,
      language: _selectedLanguage,
      price: price,
      pricingModel: _selectedPricingModel,
      maxCapacity: int.tryParse(maxCapacityStr) ?? 0,
      coordinates: [0.0, 0.0],
      addressLine1: addressLine1,
      city: city,
      state: state,
      zip: zip,
      country: country,
      cancellationPolicy: _selectedCancellationPolicy,
      minimumAge: int.tryParse(minAgeStr) ?? 0,
      maximumAge: int.tryParse(maxAgeStr) ?? 0,
    );

    final providerController = context.read<ProviderController>();
    if (widget.editIndex != null) {
      final success = await providerController.editProgram(
        widget.editIndex!,
        listing,
        galleryPaths: _pickedGalleryPaths,
      );
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing updated successfully')),
        );
        Navigator.pop(context);
      } else {
        final errorMsg =
            providerController.lastErrorMessage ??
            'Failed to update listing on server.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppColors.negative,
          ),
        );
      }
    } else {
      final success = await providerController.createProgram(
        listing,
        galleryPaths: _pickedGalleryPaths,
      );
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing created successfully')),
        );
        Navigator.pop(context);
      } else {
        final errorMsg =
            providerController.lastErrorMessage ??
            'Failed to create listing on server.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppColors.negative,
          ),
        );
        providerController.addListing(listing);
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editIndex != null;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: AppColors.navyDark,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.card),
        ),
      ),
      child: Column(
        children: [
          // Drag handle and close button
          Padding(
            padding: const EdgeInsets.only(
              top: 12,
              left: 24,
              right: 24,
              bottom: 8,
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.hairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEdit ? 'Edit Listing' : 'Create Listing',
                      style: AppTypography.font(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SporveIconButton(
                      Icons.close,
                      circle: true,
                      color: AppColors.negative,
                      iconSize: 20,
                      onTap: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: 'TITLE *',
                    hint: 'e.g., Elite Point Guard Training',
                    controller: _titleController,
                  ),
                  const SizedBox(height: 20),

                  _buildTextField(
                    label: 'DESCRIPTION',
                    hint:
                        'Describe your training session, program, or facility...',
                    maxLines: 4,
                    controller: _descriptionController,
                  ),
                  const SizedBox(height: 20),

                  _buildDropdownField(
                    label: 'LISTING TYPE',
                    value: _selectedListingType,
                    items: _listingTypes,
                    onChanged: (val) =>
                        setState(() => _selectedListingType = val),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdownField(
                          label: 'SPORT',
                          value: _selectedSport,
                          items: _sports,
                          sportColors: true,
                          onChanged: (val) =>
                              setState(() => _selectedSport = val),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDropdownField(
                          label: 'SKILL LEVEL',
                          value: _selectedSkillLevel,
                          items: _skillLevels,
                          onChanged: (val) =>
                              setState(() => _selectedSkillLevel = val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdownField(
                          label: 'AGE GROUP',
                          value: _selectedAgeGroup,
                          items: _ageGroups,
                          onChanged: (val) =>
                              setState(() => _selectedAgeGroup = val),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDropdownField(
                          label: 'LANGUAGE',
                          value: _selectedLanguage,
                          items: _languages,
                          onChanged: (val) =>
                              setState(() => _selectedLanguage = val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          label: 'PRICE (\$)',
                          hint: '150',
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDropdownField(
                          label: 'PRICING MODEL',
                          value: _selectedPricingModel,
                          items: _pricingModels,
                          onChanged: (val) =>
                              setState(() => _selectedPricingModel = val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          label: 'MAX CAPACITY',
                          hint: '20',
                          controller: _maxCapacityController,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDropdownField(
                          label: 'CANCELLATION POLICY',
                          value: _selectedCancellationPolicy,
                          items: _cancellationPolicies,
                          onChanged: (val) =>
                              setState(() => _selectedCancellationPolicy = val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'ADDRESS',
                    style: AppTypography.font(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    label: '',
                    hint: '123 Main St',
                    controller: _addressLine1Controller,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          label: '',
                          hint: 'City',
                          controller: _cityController,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          label: '',
                          hint: 'State',
                          controller: _stateController,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          label: '',
                          hint: 'Zip',
                          controller: _zipController,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          label: '',
                          hint: 'Country',
                          controller: _countryController,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          label: 'MIN AGE',
                          hint: '8',
                          controller: _minAgeController,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          label: 'MAX AGE',
                          hint: '12',
                          controller: _maxAgeController,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'COVER IMAGE',
                        style: AppTypography.font(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final res = await pickValidatedImage(ImagePicker());
                          if (res.hasError) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(res.error!),
                                backgroundColor: AppColors.negative,
                              ),
                            );
                          } else if (res.hasImage) {
                            setState(() {
                              _pickedImagePath = res.path!;
                            });
                          }
                        },
                        child: Container(
                          height: 150,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: BorderRadius.circular(AppRadii.tile),
                            border: Border.all(
                              color: AppColors.hairline,
                              width: 1,
                            ),
                          ),
                          child: _pickedImagePath != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.tile,
                                  ),
                                  child: Image.file(
                                    File(_pickedImagePath!),
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : (_imageUrlController.text.isNotEmpty
                                    ? SporveImage(
                                        _imageUrlController.text,
                                        width: double.infinity,
                                        height: 150,
                                        fit: BoxFit.cover,
                                        radius: AppRadii.tile,
                                      )
                                    : Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons
                                                  .add_photo_alternate_outlined,
                                              color: AppColors.textSecondary,
                                              size: 36,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Tap to choose program cover image',
                                              style: AppTypography.font(
                                                color: AppColors.textTertiary,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PROGRAM GALLERY (MAX 4)',
                        style: AppTypography.font(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 90,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount:
                              _pickedGalleryPaths.length +
                              (_pickedGalleryPaths.length < 4 ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _pickedGalleryPaths.length) {
                              return GestureDetector(
                                onTap: () async {
                                  final picker = ImagePicker();
                                  final images = await picker.pickMultiImage();
                                  if (!context.mounted) return;
                                  if (images.isNotEmpty) {
                                    if (_pickedGalleryPaths.length +
                                            images.length >
                                        4) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'You can upload a maximum of 4 gallery images.',
                                          ),
                                          backgroundColor: AppColors.warning,
                                        ),
                                      );
                                      final allowed =
                                          4 - _pickedGalleryPaths.length;
                                      setState(() {
                                        _pickedGalleryPaths.addAll(
                                          images
                                              .take(allowed)
                                              .map((img) => img.path),
                                        );
                                      });
                                    } else {
                                      setState(() {
                                        _pickedGalleryPaths.addAll(
                                          images.map((img) => img.path),
                                        );
                                      });
                                    }
                                  }
                                },
                                child: Container(
                                  width: 90,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface2,
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.tile,
                                    ),
                                    border: Border.all(
                                      color: AppColors.hairline,
                                      width: 1,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.add_a_photo_outlined,
                                      color: AppColors.textSecondary,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              );
                            }

                            final path = _pickedGalleryPaths[index];
                            return Stack(
                              children: [
                                Container(
                                  width: 90,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.tile,
                                    ),
                                    image: DecorationImage(
                                      image: FileImage(File(path)),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 12,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _pickedGalleryPaths.removeAt(index);
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  SporveButton(
                    isEdit ? 'Update listing' : 'Create listing',
                    onPressed: context.watch<ProviderController>().isLoading
                        ? null
                        : _submitForm,
                    variant: SporveButtonVariant.primary,
                    loading: context.watch<ProviderController>().isLoading,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.font(
            color: AppColors.textGrey,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 14,
            ),
            filled: true,
            fillColor: AppColors.surface2,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.tile),
              borderSide: const BorderSide(color: AppColors.hairline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.tile),
              borderSide: const BorderSide(color: AppColors.hairline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.tile),
              borderSide: const BorderSide(color: AppColors.slateText),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
    bool sportColors = false, // show each item's sport identity color as a dot
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.font(
            color: AppColors.textGrey,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Theme(
          data: Theme.of(context).copyWith(canvasColor: AppColors.surface2),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(AppRadii.tile),
              border: Border.all(color: AppColors.hairline),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                icon: const Icon(
                  Icons.arrow_drop_down_circle_outlined,
                  color: AppColors.textTertiary,
                  size: 20,
                ),
                dropdownColor: AppColors.surface2,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
                onChanged: (val) {
                  if (val != null) onChanged(val);
                },
                items: items.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: sportColors
                        ? Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: SportColors.of(value),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(value),
                            ],
                          )
                        : Text(value),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
