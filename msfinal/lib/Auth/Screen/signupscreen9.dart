// Professional Redesigned Partner Preferences Page - Step 10
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ms2026/Auth/Screen/signupscreen5.dart';
import 'package:ms2026/Auth/Screen/signupscreen10.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constant/app_colors.dart';
import '../../ReUsable/registration_progress.dart';
import '../../ReUsable/enhanced_form_fields.dart';
import '../../service/partner_pref_api.dart';
import '../../service/updatepage.dart';

class PartnerPreferencesPage extends StatefulWidget {
  const PartnerPreferencesPage({super.key});

  @override
  State<PartnerPreferencesPage> createState() => _PartnerPreferencesPageState();
}

class _PartnerPreferencesPageState extends State<PartnerPreferencesPage> with SingleTickerProviderStateMixin {
  // Form state
  String? _minAge;
  String? _maxAge;
  String? _minHeight;
  String? _maxHeight;
  List<String> _selectedMaritalStatus = [];
  List<String> _selectedReligion = [];
  List<String> _selectedCommunity = [];
  List<String> _selectedMotherTongue = [];
  List<String> _selectedCountry = [];
  List<String> _selectedState = [];
  List<String> _selectedDistrict = [];
  List<String> _selectedEducation = [];
  List<String> _selectedOccupation = [];

  // Validation
  bool _hasValidationErrors = false;
  Map<String, String?> _fieldErrors = {};
  bool _isSubmitting = false;

  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Options data
  final List<String> _ageOptions = List.generate(44, (index) => (18 + index).toString());

  List<String> get _heightOptions {
    return List.generate(121, (index) {
      int cm = 100 + index;
      double totalInches = cm / 2.54;
      int feet = totalInches ~/ 12;
      int inches = (totalInches % 12).round();
      return "$cm cm ($feet' $inches\")";
    });
  }

  final List<String> _maritalStatusOptions = [
    'Single',
    'Married',
    'Divorced',
    'Widowed',
    'Annulled',
  ];

  final List<String> _religionOptions = [
    'Hindu',
    'Buddhist',
    'Christian',
    'Islam',
    'Sikh',
    'Jain',
    'Other',
  ];

  final List<String> _communityOptions = [
    'Brahmin',
    'Chhetri',
    'Newar',
    'Tamang',
    'Magar',
    'Tharu',
    'Rai',
    'Gurung',
    'Limbu',
    'Sherpa',
    'Other',
  ];

  final List<String> _motherTongueOptions = [
    'Nepali',
    'Maithili',
    'Bhojpuri',
    'Tharu',
    'Tamang',
    'Newar',
    'Magar',
    'Bajjika',
    'Urdu',
    'Rai',
    'Other',
  ];

  final List<String> _countryOptions = [
    'Nepal',
    'India',
    'USA',
    'UK',
    'Canada',
    'Australia',
    'UAE',
    'Qatar',
    'Saudi Arabia',
    'Japan',
    'Other',
  ];

  final List<String> _educationOptions = [
    'High School',
    'Undergraduate',
    'Graduate',
    'Post Graduate',
    'Doctorate',
    'Diploma',
    'Professional',
  ];

  final List<String> _occupationOptions = [
    'Software Engineer',
    'Doctor',
    'Teacher',
    'Business Owner',
    'Government Employee',
    'Private Sector',
    'Freelancer',
    'Student',
    'Other',
  ];

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Validation
  bool _validateForm() {
    setState(() {
      _fieldErrors = {
        'age': (_minAge == null || _maxAge == null) ? 'Please select age range' : null,
        'height': (_minHeight == null || _maxHeight == null) ? 'Please select height range' : null,
        'maritalStatus': _selectedMaritalStatus.isEmpty ? 'Please select at least one option' : null,
        'religion': _selectedReligion.isEmpty ? 'Please select at least one option' : null,
      };

      // Validate age range
      if (_minAge != null && _maxAge != null) {
        final min = int.parse(_minAge!);
        final max = int.parse(_maxAge!);
        if (min > max) {
          _fieldErrors['age'] = 'Min age cannot be greater than max age';
        }
      }

      // Validate height range
      if (_minHeight != null && _maxHeight != null) {
        final minCm = int.parse(_minHeight!.split(' ').first);
        final maxCm = int.parse(_maxHeight!.split(' ').first);
        if (minCm > maxCm) {
          _fieldErrors['height'] = 'Min height cannot be greater than max height';
        }
      }

      _hasValidationErrors = _fieldErrors.values.any((error) => error != null);
    });

    return !_hasValidationErrors;
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _validateAndSubmit() async {
    if (!_validateForm()) {
      _showSnackBar('Please fill all required fields correctly', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');

      if (userDataString == null) {
        _showSnackBar('Session expired. Please login again', isError: true);
        setState(() => _isSubmitting = false);
        return;
      }

      final userData = jsonDecode(userDataString);
      final userId = int.tryParse(userData["id"].toString());

      if (userId == null) {
        _showSnackBar('Invalid user data', isError: true);
        setState(() => _isSubmitting = false);
        return;
      }

      final service = UserPartnerPreferenceService(
        baseUrl: 'https://digitallami.com/Api2/save_partner_preference.php',
      );

      // Extract cm values from height strings (e.g., "170 cm (5' 7")" -> "170")
      final minHeightCm = _minHeight!.split(' ').first;
      final maxHeightCm = _maxHeight!.split(' ').first;

      final result = await service.savePartnerPreference(
        userId: userId,
        ageFrom: _minAge!,
        ageTo: _maxAge!,
        heightFrom: minHeightCm,
        heightTo: maxHeightCm,
        maritalStatus: _selectedMaritalStatus.join(', '),
        religion: _selectedReligion.join(', '),
        community: _selectedCommunity.isNotEmpty ? _selectedCommunity.join(', ') : null,
        motherTongue: _selectedMotherTongue.isNotEmpty ? _selectedMotherTongue.join(', ') : null,
        country: _selectedCountry.isNotEmpty ? _selectedCountry.join(', ') : null,
        state: _selectedState.isNotEmpty ? _selectedState.join(', ') : null,
        district: _selectedDistrict.isNotEmpty ? _selectedDistrict.join(', ') : null,
        education: _selectedEducation.isNotEmpty ? _selectedEducation.join(', ') : null,
        occupation: _selectedOccupation.isNotEmpty ? _selectedOccupation.join(', ') : null,
      );

      setState(() => _isSubmitting = false);

      if (result['status'] == 'success') {
        await UpdateService.updatePageNumber(
          userId: userId.toString(),
          pageNo: 8,
        );

        _showSnackBar('Partner preferences saved successfully!');

        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => FamilyDetailsPage(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(1.0, 0.0);
              const end = Offset.zero;
              const curve = Curves.easeInOutCubic;
              var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
              var offsetAnimation = animation.drive(tween);
              return SlideTransition(position: offsetAnimation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      } else {
        final errorMsg = result['message'] ?? "Something went wrong";
        print('Partner preference save error: $errorMsg');
        print('Result: $result');
        _showSnackBar(errorMsg, isError: true);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      print('Partner preference save exception: $e');
      _showSnackBar('Error: ${e.toString()}', isError: true);
    }
  }

  void _showMultiSelectDialog({
    required String title,
    required List<String> options,
    required List<String> selectedOptions,
    required Function(List<String>) onConfirm,
    IconData? icon,
  }) {
    List<String> tempSelected = List.from(selectedOptions);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.all(20),
              height: MediaQuery.of(context).size.height * 0.75,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      if (icon != null) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icon, color: AppColors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.textSecondary),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Selected count
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.1),
                          AppColors.primaryLight.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${tempSelected.length} selected',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Options list
                  Expanded(
                    child: ListView.builder(
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options[index];
                        final isSelected = tempSelected.contains(option);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: () {
                              setModalState(() {
                                if (isSelected) {
                                  tempSelected.remove(option);
                                } else {
                                  tempSelected.add(option);
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: isSelected ? AppColors.primaryGradient : null,
                                color: isSelected ? null : AppColors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? Colors.transparent : AppColors.border,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isSelected
                                        ? AppColors.primary.withOpacity(0.3)
                                        : AppColors.shadowLight,
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected
                                          ? AppColors.white
                                          : AppColors.background,
                                    ),
                                    child: Icon(
                                      isSelected
                                          ? Icons.check_circle
                                          : Icons.circle_outlined,
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      option,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: isSelected
                                            ? AppColors.white
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setModalState(() => tempSelected.clear());
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: AppColors.border, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Clear All',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            onConfirm(tempSelected);
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Apply Selection',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMultiSelectField({
    required String label,
    required List<String> selectedItems,
    required VoidCallback onTap,
    required IconData icon,
    bool isRequired = false,
    String? errorText,
  }) {
    final hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              if (isRequired) ...[
                const SizedBox(width: 4),
                const Text(
                  '*',
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasError ? AppColors.error : AppColors.border,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: hasError
                      ? AppColors.error.withOpacity(0.1)
                      : AppColors.shadowLight,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      icon,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        selectedItems.isEmpty
                            ? 'Tap to select $label'
                            : '${selectedItems.length} ${label.toLowerCase()} selected',
                        style: TextStyle(
                          fontSize: 15,
                          color: selectedItems.isEmpty
                              ? AppColors.textHint
                              : AppColors.textPrimary,
                          fontWeight: selectedItems.isEmpty
                              ? FontWeight.w400
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(
                      selectedItems.isEmpty
                          ? Icons.keyboard_arrow_down
                          : Icons.edit,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
                if (selectedItems.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: selectedItems.take(5).map((item) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          item,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.white,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (selectedItems.length > 5) ...[
                    const SizedBox(height: 8),
                    Text(
                      '+${selectedItems.length - 5} more',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 14,
                  color: AppColors.error,
                ),
                const SizedBox(width: 6),
                Text(
                  errorText,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: RegistrationStepContainer(
            onContinue: _isSubmitting ? null : _validateAndSubmit,
            onBack: () => Navigator.pop(context),
            continueText: 'Continue',
            canContinue: !_isSubmitting,
            isLoading: _isSubmitting,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                RegistrationStepHeader(
                  title: 'Partner Preferences',
                  subtitle: 'Help us understand your ideal life partner. Your preferences help us find better matches.',
                  currentStep: 10,
                  totalSteps: 11,
                  onBack: () => Navigator.pop(context),
                ),

                const SizedBox(height: 32),

                // Age Range Section
                SectionHeader(
                  title: 'Age Range',
                  subtitle: 'Preferred age range for your partner',
                  icon: Icons.calendar_today,
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: EnhancedDropdown<String>(
                        label: 'Min Age',
                        value: _minAge,
                        items: _ageOptions,
                        itemLabel: (age) => '$age years',
                        hint: 'Min',
                        prefixIcon: Icons.calendar_today,
                        hasError: _fieldErrors['age'] != null && _minAge == null,
                        isRequired: true,
                        onChanged: (value) {
                          setState(() {
                            _minAge = value;
                            if (_hasValidationErrors) {
                              _fieldErrors['age'] = null;
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: EnhancedDropdown<String>(
                        label: 'Max Age',
                        value: _maxAge,
                        items: _ageOptions,
                        itemLabel: (age) => '$age years',
                        hint: 'Max',
                        prefixIcon: Icons.calendar_today,
                        hasError: _fieldErrors['age'] != null && _maxAge == null,
                        isRequired: true,
                        onChanged: (value) {
                          setState(() {
                            _maxAge = value;
                            if (_hasValidationErrors) {
                              _fieldErrors['age'] = null;
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),

                if (_fieldErrors['age'] != null) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 14,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _fieldErrors['age']!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Height Range Section
                SectionHeader(
                  title: 'Height Range',
                  subtitle: 'Preferred height range for your partner',
                  icon: Icons.height,
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: EnhancedDropdown<String>(
                        label: 'Min Height',
                        value: _minHeight,
                        items: _heightOptions,
                        itemLabel: (height) => height,
                        hint: 'Min',
                        prefixIcon: Icons.height,
                        hasError: _fieldErrors['height'] != null && _minHeight == null,
                        isRequired: true,
                        onChanged: (value) {
                          setState(() {
                            _minHeight = value;
                            if (_hasValidationErrors) {
                              _fieldErrors['height'] = null;
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: EnhancedDropdown<String>(
                        label: 'Max Height',
                        value: _maxHeight,
                        items: _heightOptions,
                        itemLabel: (height) => height,
                        hint: 'Max',
                        prefixIcon: Icons.height,
                        hasError: _fieldErrors['height'] != null && _maxHeight == null,
                        isRequired: true,
                        onChanged: (value) {
                          setState(() {
                            _maxHeight = value;
                            if (_hasValidationErrors) {
                              _fieldErrors['height'] = null;
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),

                if (_fieldErrors['height'] != null) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 14,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _fieldErrors['height']!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Personal Preferences Section
                SectionHeader(
                  title: 'Personal Preferences',
                  subtitle: 'Marital status and religious preferences',
                  icon: Icons.favorite_outline,
                ),

                const SizedBox(height: 16),

                // Marital Status
                _buildMultiSelectField(
                  label: 'Marital Status',
                  selectedItems: _selectedMaritalStatus,
                  icon: Icons.favorite_border,
                  isRequired: true,
                  errorText: _fieldErrors['maritalStatus'],
                  onTap: () {
                    _showMultiSelectDialog(
                      title: 'Select Marital Status',
                      options: _maritalStatusOptions,
                      selectedOptions: _selectedMaritalStatus,
                      icon: Icons.favorite_border,
                      onConfirm: (selected) {
                        setState(() {
                          _selectedMaritalStatus = selected;
                          if (_hasValidationErrors) {
                            _fieldErrors['maritalStatus'] = selected.isEmpty
                                ? 'Please select at least one option'
                                : null;
                          }
                        });
                      },
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Religion
                _buildMultiSelectField(
                  label: 'Religion',
                  selectedItems: _selectedReligion,
                  icon: Icons.church,
                  isRequired: true,
                  errorText: _fieldErrors['religion'],
                  onTap: () {
                    _showMultiSelectDialog(
                      title: 'Select Religion',
                      options: _religionOptions,
                      selectedOptions: _selectedReligion,
                      icon: Icons.church,
                      onConfirm: (selected) {
                        setState(() {
                          _selectedReligion = selected;
                          if (_hasValidationErrors) {
                            _fieldErrors['religion'] = selected.isEmpty
                                ? 'Please select at least one option'
                                : null;
                          }
                        });
                      },
                    );
                  },
                ),

                const SizedBox(height: 32),

                // Cultural Preferences Section
                SectionHeader(
                  title: 'Cultural Preferences',
                  subtitle: 'Community and language preferences (Optional)',
                  icon: Icons.public,
                ),

                const SizedBox(height: 16),

                // Community
                _buildMultiSelectField(
                  label: 'Community',
                  selectedItems: _selectedCommunity,
                  icon: Icons.group,
                  onTap: () {
                    _showMultiSelectDialog(
                      title: 'Select Community',
                      options: _communityOptions,
                      selectedOptions: _selectedCommunity,
                      icon: Icons.group,
                      onConfirm: (selected) {
                        setState(() => _selectedCommunity = selected);
                      },
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Mother Tongue
                _buildMultiSelectField(
                  label: 'Mother Tongue',
                  selectedItems: _selectedMotherTongue,
                  icon: Icons.language,
                  onTap: () {
                    _showMultiSelectDialog(
                      title: 'Select Mother Tongue',
                      options: _motherTongueOptions,
                      selectedOptions: _selectedMotherTongue,
                      icon: Icons.language,
                      onConfirm: (selected) {
                        setState(() => _selectedMotherTongue = selected);
                      },
                    );
                  },
                ),

                const SizedBox(height: 32),

                // Location Preferences Section
                SectionHeader(
                  title: 'Location Preferences',
                  subtitle: 'Country and state preferences (Optional)',
                  icon: Icons.location_on_outlined,
                ),

                const SizedBox(height: 16),

                // Country
                _buildMultiSelectField(
                  label: 'Country',
                  selectedItems: _selectedCountry,
                  icon: Icons.flag,
                  onTap: () {
                    _showMultiSelectDialog(
                      title: 'Select Country',
                      options: _countryOptions,
                      selectedOptions: _selectedCountry,
                      icon: Icons.flag,
                      onConfirm: (selected) {
                        setState(() => _selectedCountry = selected);
                      },
                    );
                  },
                ),

                const SizedBox(height: 32),

                // Professional Preferences Section
                SectionHeader(
                  title: 'Professional Preferences',
                  subtitle: 'Education and occupation preferences (Optional)',
                  icon: Icons.work_outline,
                ),

                const SizedBox(height: 16),

                // Education
                _buildMultiSelectField(
                  label: 'Education',
                  selectedItems: _selectedEducation,
                  icon: Icons.school,
                  onTap: () {
                    _showMultiSelectDialog(
                      title: 'Select Education',
                      options: _educationOptions,
                      selectedOptions: _selectedEducation,
                      icon: Icons.school,
                      onConfirm: (selected) {
                        setState(() => _selectedEducation = selected);
                      },
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Occupation
                _buildMultiSelectField(
                  label: 'Occupation',
                  selectedItems: _selectedOccupation,
                  icon: Icons.business_center,
                  onTap: () {
                    _showMultiSelectDialog(
                      title: 'Select Occupation',
                      options: _occupationOptions,
                      selectedOptions: _selectedOccupation,
                      icon: Icons.business_center,
                      onConfirm: (selected) {
                        setState(() => _selectedOccupation = selected);
                      },
                    );
                  },
                ),

                const SizedBox(height: 32),

                // Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.secondary.withOpacity(0.1),
                        AppColors.secondaryLight.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.secondary.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.tips_and_updates,
                          color: AppColors.secondary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Setting broader preferences increases your chances of finding compatible matches. You can always refine these later.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
