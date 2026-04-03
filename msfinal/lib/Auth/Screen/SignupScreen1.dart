// lib/Auth/Screen/your_details_page.dart
import 'dart:io';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:ms2026/Auth/Screen/signupscreen2.dart';

import '../../ReUsable/dateconverter.dart';
import '../../ReUsable/dropdownwidget.dart';
import '../../ReUsable/inlinedropdownSingle.dart';
import '../SuignupModel/signup_model.dart';

class YourDetailsPage extends StatefulWidget {
  const YourDetailsPage({super.key});

  @override
  State<YourDetailsPage> createState() => _YourDetailsPageState();
}

class _YourDetailsPageState extends State<YourDetailsPage> {
  String selectedNationality = "";
  bool submitted = false;

  // AD Date variables
  String selectedADMonth = "";
  String selectedADDay = "";
  String selectedADYear = "";

  // BS Date variables
  String selectedBSMonth = "";
  String selectedBSDay = "";
  String selectedBSYear = "";

  bool isAD = true; // true = AD, false = BS

  List<String> selectedLanguages = ["Nepali"];

  // Text editing controllers - PROPERLY INITIALIZED
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late TextEditingController _confirmPasswordController;

  // AD Months
  final List<String> adMonths = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  // BS Months (in English)
  final List<String> bsMonths = NepaliDateConverter.nepaliMonthsEnglish;

  // Validation error states
  bool _hasValidationErrors = false;
  Map<String, bool> _fieldErrors = {
    'firstName': false,
    'lastName': false,
    'email': false,
    'password': false,
    'confirmPassword': false,
    'phone': false,
    'dob': false,
    'languages': false,
    'nationality': false,
  };

  // Track which fields have been touched
  Map<String, bool> _fieldTouched = {
    'firstName': false,
    'lastName': false,
    'email': false,
    'password': false,
    'confirmPassword': false,
    'phone': false,
    'dob': false,
    'languages': false,
    'nationality': false,
  };

  // Focus nodes for validation
  final Map<String, FocusNode> _focusNodes = {
    'firstName': FocusNode(),
    'lastName': FocusNode(),
    'email': FocusNode(),
    'password': FocusNode(),
    'confirmPassword': FocusNode(),
  };

  // AD Years (1950-2025)
  List<String> get adYears {
    final now = DateTime.now();

    // Latest year allowed (must be at least 21 years old)
    final maxYear = now.year - 21;

    final years = <String>[];

    for (int year = maxYear - 100; year <= maxYear; year++) {
      years.add(year.toString());
    }

    return years.reversed.toList();
  }

  // BS Years (from converter)
  List<String> get bsYears {
    return NepaliDateConverter.getBsYearsList();
  }

  late String completeNumberr = '';
  String? countryCode;

  // Profile picture variables
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  // Password visibility
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String _confirmPassword = '';

  // Sample data
  final languagesList = [
    "Nepali",
    "English",
    "Hindi",
    "Chinese",
    "Spanish",
    "French",
    "German",
    "Japanese",
    "Korean",
    "Arabic",
    "Russian",
    "Portuguese",
    "Italian",
    "Turkish"
  ];

  final List<String> nationalityList = [
    "Nepali",
    "Indian",
    "American",
    "Chinese",
    "British",
    "Canadian",
    "Australian",
    "Japanese",
    "Korean",
    "French",
    "German",
    "Spanish",
    "Italian",
    "Brazilian",
    "Mexican",
    "Russian"
  ];

  @override
  void initState() {
    super.initState();

    // Initialize controllers with empty values
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();

    // Initialize focus nodes
    _focusNodes.forEach((key, node) {
      node.addListener(() {
        if (!node.hasFocus) {
          setState(() {
            _fieldTouched[key] = true;
          });
        }
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final model = context.read<SignupModel>();
      if (model.languages.isEmpty) {
        model.setLanguages(selectedLanguages.join(', '));
      }

      // Sync initial values from model to controllers
      _syncControllersWithModel(model);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sync controllers with model values on rebuild
    final model = context.read<SignupModel>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncControllersWithModel(model);
    });
  }

  void _syncControllersWithModel(SignupModel model) {
    // Only update controllers if they differ from model values
    // This prevents cursor jumping
    if (_firstNameController.text != model.firstName) {
      _firstNameController.text = model.firstName;
    }
    if (_lastNameController.text != model.lastName) {
      _lastNameController.text = model.lastName;
    }
    if (_emailController.text != model.email) {
      _emailController.text = model.email;
    }
    if (_passwordController.text != model.password) {
      _passwordController.text = model.password;
    }
    // Don't sync confirm password as it's handled separately
  }

  @override
  void dispose() {
    // Dispose controllers
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    // Dispose focus nodes
    _focusNodes.forEach((key, node) {
      node.dispose();
    });
    super.dispose();
  }

  // Helper method to check if a field has error (handles null safety)
  bool _hasError(String fieldName) {
    return _fieldErrors[fieldName] ?? false;
  }

  // Check if field should show error (only after being touched or on validation)
  bool _shouldShowError(String fieldName) {
    return _fieldTouched[fieldName] == true || _hasValidationErrors;
  }

  // Helper method for error messages
  String _getErrorMessage(String fieldName) {
    switch (fieldName) {
      case 'firstName':
        return 'First name is required';
      case 'lastName':
        return 'Last name is required';
      case 'email':
        return 'Email address is required';
      case 'password':
        return 'Password is required';
      case 'confirmPassword':
        if (_confirmPassword.isEmpty) {
          return 'Please confirm your password';
        } else {
          return 'Passwords do not match';
        }
      case 'phone':
        return 'Phone number is required';
      case 'dob':
        return 'Date of birth is required';
      case 'languages':
        return 'Please select at least one language';
      case 'nationality':
        return 'Please select your nationality';
      default:
        return 'This field is required';
    }
  }

  // Get current BS days based on selected month and year
  List<String> get currentBsDays {
    try {
      if (selectedBSYear.isEmpty || selectedBSMonth.isEmpty) {
        // Return default days (1-32) when year/month not selected
        return List.generate(32, (index) => (index + 1).toString().padLeft(2, '0'));
      }

      final year = int.tryParse(selectedBSYear);
      final month = bsMonths.indexOf(selectedBSMonth) + 1;
      if (year != null && month > 0) {
        return NepaliDateConverter.getBsDaysList(year, month);
      }
    } catch (e) {
      print('Error getting BS days: $e');
    }
    return List.generate(32, (index) => (index + 1).toString().padLeft(2, '0'));
  }

  // Get current AD days based on selected month and year
  List<String> get currentAdDays {
    try {
      if (selectedADYear.isEmpty || selectedADMonth.isEmpty) {
        // Return default days (1-31) when year/month not selected
        return List.generate(31, (index) => (index + 1).toString().padLeft(2, '0'));
      }

      final year = int.tryParse(selectedADYear);
      final month = adMonths.indexOf(selectedADMonth) + 1;
      if (year != null && month > 0) {
        final daysInMonth = DateTime(year, month + 1, 0).day;
        return List.generate(daysInMonth, (index) => (index + 1).toString().padLeft(2, '0'));
      }
    } catch (e) {
      print('Error getting AD days: $e');
    }
    return List.generate(31, (index) => (index + 1).toString().padLeft(2, '0'));
  }

  // Convert BS to AD and update provider
  void _convertBsToAdAndUpdate() {
    try {
      final year = int.tryParse(selectedBSYear);
      final month = bsMonths.indexOf(selectedBSMonth) + 1;
      final day = int.tryParse(selectedBSDay);

      if (year != null && month > 0 && day != null) {
        final adDate = NepaliDateConverter.bsToAd(year, month, day);
        if (adDate != null) {
          setState(() {
            selectedADYear = adDate.year.toString();
            selectedADMonth = adMonths[adDate.month - 1];
            selectedADDay = adDate.day.toString().padLeft(2, '0');
            _fieldTouched['dob'] = true;
          });
          _updateDobToProvider();
        } else {
          setState(() {
            _fieldErrors['dob'] = true;
            _fieldTouched['dob'] = true;
          });
        }
      }
    } catch (e) {
      print('Error converting BS to AD: $e');
      setState(() {
        _fieldErrors['dob'] = true;
        _fieldTouched['dob'] = true;
      });
    }
  }

  // Convert AD to BS
  void _convertAdToBs() {
    try {
      final year = int.tryParse(selectedADYear);
      final month = adMonths.indexOf(selectedADMonth) + 1;
      final day = int.tryParse(selectedADDay);

      if (year != null && month > 0 && day != null) {
        final adDate = DateTime(year, month, day);
        final bsDate = NepaliDateConverter.adToBs(adDate);
        if (bsDate != null) {
          setState(() {
            selectedBSYear = bsDate['year']!.toString();
            selectedBSMonth = bsMonths[bsDate['month']! - 1];
            selectedBSDay = bsDate['day']!.toString().padLeft(2, '0');
          });
        }
      }
    } catch (e) {
      print('Error converting AD to BS: $e');
    }
  }

  // Update DOB in provider
  void _updateDobToProvider() {
    final model = context.read<SignupModel>();
    if (selectedADYear.isNotEmpty && selectedADMonth.isNotEmpty && selectedADDay.isNotEmpty) {
      final monthIndex = adMonths.indexOf(selectedADMonth) + 1;
      final monthS = monthIndex.toString().padLeft(2, '0');
      final dayS = selectedADDay.padLeft(2, '0');
      final dob = '${selectedADYear}-$monthS-$dayS';
      model.setDateOfBirth(dob);

      // Clear DOB error if date is valid
      setState(() {
        _fieldErrors['dob'] = false;
      });
    } else {
      setState(() {
        _fieldErrors['dob'] = true;
        _fieldTouched['dob'] = true;
      });
    }
  }

  // Get border color based on field state
  Color _getBorderColor(String fieldName) {
    final model = context.read<SignupModel>();

    // Check if field has error and should show it
    if (_hasError(fieldName) && _shouldShowError(fieldName)) {
      return Colors.red;
    }

    // Check if field has data
    bool hasData = false;
    switch (fieldName) {
      case 'firstName':
        hasData = model.firstName.isNotEmpty;
        break;
      case 'lastName':
        hasData = model.lastName.isNotEmpty;
        break;
      case 'email':
        hasData = model.email.isNotEmpty;
        break;
      case 'password':
        hasData = model.password.isNotEmpty;
        break;
      case 'confirmPassword':
        hasData = _confirmPassword.isNotEmpty;
        break;
      case 'phone':
        hasData = completeNumberr.isNotEmpty;
        break;
      case 'dob':
        if (isAD) {
          hasData = selectedADYear.isNotEmpty && selectedADMonth.isNotEmpty && selectedADDay.isNotEmpty;
        } else {
          hasData = selectedBSYear.isNotEmpty && selectedBSMonth.isNotEmpty && selectedBSDay.isNotEmpty;
        }
        break;
      case 'languages':
        hasData = selectedLanguages.isNotEmpty;
        break;
      case 'nationality':
        hasData = selectedNationality.isNotEmpty;
        break;
    }

    // Return green if has data, black if empty
    return hasData ? const Color(0xFF48A54C) : Colors.black;
  }

  // Validate form fields
  bool _validateForm() {
    final model = context.read<SignupModel>();

    // Mark all fields as touched when validating
    setState(() {
      for (var key in _fieldTouched.keys) {
        _fieldTouched[key] = true;
      }
    });

    Map<String, bool> newErrors = {
      'firstName': model.firstName.isEmpty,
      'lastName': model.lastName.isEmpty,
      'email': model.email.isEmpty,
      'password': model.password.isEmpty,
      'confirmPassword': _confirmPassword.isEmpty || model.password != _confirmPassword,
      'phone': completeNumberr.isEmpty,
      'dob': model.dateofbirth.isEmpty,
      'languages': selectedLanguages.isEmpty,
      'nationality': selectedNationality.isEmpty,
    };

    // Check if AD date fields are filled
    if (isAD) {
      newErrors['dob'] = selectedADYear.isEmpty || selectedADMonth.isEmpty || selectedADDay.isEmpty;
    } else {
      newErrors['dob'] = selectedBSYear.isEmpty || selectedBSMonth.isEmpty || selectedBSDay.isEmpty;
      if (!newErrors['dob']!) {
        // Validate BS date conversion
        final year = int.tryParse(selectedBSYear);
        final month = bsMonths.indexOf(selectedBSMonth) + 1;
        final day = int.tryParse(selectedBSDay);
        if (year == null || month <= 0 || day == null) {
          newErrors['dob'] = true;
        }
      }
    }

    setState(() {
      _fieldErrors = newErrors;
      _hasValidationErrors = newErrors.values.any((error) => error);
    });

    return !_hasValidationErrors;
  }

  // Profile picture upload function
  Future<void> _uploadProfilePicture() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        final file = File(image.path);
        setState(() {
          _profileImage = file;
        });
        context.read<SignupModel>().setProfilePicture(file);
      }
    } catch (e) {
      print('Error picking image: $e');
      _showErrorSnackBar('Failed to pick image');
    }
  }

  // Camera capture function
  Future<void> _takeProfilePicture() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        final file = File(image.path);
        setState(() {
          _profileImage = file;
        });
        context.read<SignupModel>().setProfilePicture(file);
      }
    } catch (e) {
      print('Error taking photo: $e');
      _showErrorSnackBar('Failed to take photo');
    }
  }

  void _showImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              const Text(
                "Choose Profile Picture",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE64B37),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFFE64B37)),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _uploadProfilePicture();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFFE64B37)),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _takeProfilePicture();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }



  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Country Code Picker
            Container(
              height: 65,
             // padding: const EdgeInsets.symmetric(horizontal: 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: _getBorderColor('phone'),
                  width: 1.6,
                ),
              ),
              child: CountryCodePicker(
                onChanged: (country) {
                  setState(() {
                    countryCode = country.dialCode ?? '+977';
                  });
                },
                initialSelection: 'NP',
                favorite: ['+977', 'US'],
                showCountryOnly: false,
                showOnlyCountryWhenClosed: false,
                alignLeft: false,
                textStyle: TextStyle(
                  color: (_hasError('phone') && _shouldShowError('phone'))
                      ? Colors.red
                      : Colors.black,
                  fontSize: 16,
                ),
              ),
            ),

            const SizedBox(width: 10),

            // Manual phone input
            Expanded(
              child: Container(
                height: 55,
                padding: const EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: _getBorderColor('phone'),
                    width: 1.6,
                  ),
                ),
                child: TextField(

                  keyboardType: TextInputType.phone,
                  style: TextStyle(
                    fontSize: 16,
                    color: (_hasError('phone') && _shouldShowError('phone'))
                        ? Colors.red
                        : Colors.black,
                  ),
                  decoration: InputDecoration(

                   // error: submitted,
                    border: InputBorder.none,
                    hintText: 'Enter mobile number',
                    alignLabelWithHint: true,
                    contentPadding:
                    const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onChanged: (value) {
                    String completeNumber = '$countryCode$value';
                    setState(() {
                      completeNumberr = completeNumber;
                      _fieldErrors['phone'] = value.isEmpty;
                      _fieldTouched['phone'] = true;
                    });
                    context.read<SignupModel>().setContactNo(completeNumber);
                  },
                ),
              ),
            ),
          ],
        ),

        // Show error text below phone field
        if (_hasError('phone') && _shouldShowError('phone'))
          Padding(
            padding: const EdgeInsets.only(left: 15, top: 4),
            child: Text(
              _getErrorMessage('phone'),
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }


  void _showLanguagePicker(BuildContext context) {
    List<String> available = languagesList.where((lang) => !selectedLanguages.contains(lang)).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(16),
              height: MediaQuery.of(context).size.height * 0.70,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Select Language",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE64B37),
                    ),
                  ),
                  const SizedBox(height: 15),
                  if (selectedLanguages.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: selectedLanguages.map((lang) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE64B37).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE64B37), width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(lang, style: const TextStyle(fontSize: 14, color: Colors.black)),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectedLanguages.remove(lang);
                                    context.read<SignupModel>().setLanguages(selectedLanguages.join(', '));
                                    _fieldErrors['languages'] = selectedLanguages.isEmpty;
                                    _fieldTouched['languages'] = true;
                                  });
                                  setSheetState(() {
                                    available = languagesList.where((l) => !selectedLanguages.contains(l)).toList();
                                  });
                                },
                                child: const Icon(Icons.close, size: 16, color: Color(0xFFE64B37)),
                              )
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 15),
                  TextField(
                    decoration: InputDecoration(
                      hintText: "Search...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: const BorderSide(
                          color: Color(0xFF48A54C),
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    onChanged: (value) {
                      setSheetState(() {
                        available = languagesList
                            .where((lang) => !selectedLanguages.contains(lang) && lang.toLowerCase().contains(value.toLowerCase()))
                            .toList();
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: available.isEmpty
                        ? const Center(
                      child: Text(
                        "No languages available",
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                    )
                        : ListView.builder(
                      itemCount: available.length,
                      itemBuilder: (_, index) {
                        String item = available[index];
                        return ListTile(
                          title: Text(item, style: const TextStyle(fontSize: 16, color: Colors.black87)),
                          onTap: () {
                            setState(() {
                              selectedLanguages.add(item);
                              context.read<SignupModel>().setLanguages(selectedLanguages.join(', '));
                              _fieldErrors['languages'] = false;
                              _fieldTouched['languages'] = true;
                            });
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitSignup() async {
    // Run validation first - this will update _fieldErrors and show red borders
    final isValid = _validateForm();

    if (!isValid) {
      // Don't show generic snackbar - let the red borders show which fields are invalid
      // The red borders and error text will already be visible from _validateForm()
      return;
    }

    final model = context.read<SignupModel>();

    final success = await model.submitSignup();
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signup successful')));
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const PersonalDetailsPage()));
    } else {
      _showErrorSnackBar(model.error ?? 'Signup failed');
    }
  }

  // Updated _inputField method that uses state-managed controllers
  Widget _inputField(IconData icon, String text, void Function(String) onChanged, {
    required FocusNode focusNode,
    required String fieldName,
    required TextEditingController controller,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 55,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: _getBorderColor(fieldName),
              width: 1.6,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: (_hasError(fieldName) && _shouldShowError(fieldName))
                    ? Colors.red
                    : Colors.black,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  focusNode: focusNode,
                  controller: controller,
                  obscureText: obscureText,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: text,
                    hintStyle: TextStyle(
                      fontSize: 16,
                      color: (_hasError(fieldName) && _shouldShowError(fieldName))
                          ? Colors.red.withOpacity(0.7)
                          : Colors.black54,
                    ),
                    suffixIcon: isPassword && onToggleVisibility != null
                        ? IconButton(
                      icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility),
                      onPressed: onToggleVisibility,
                    )
                        : null,
                  ),
                  onChanged: (value) {
                    onChanged(value);
                    // Clear error when user starts typing
                    if (value.isNotEmpty && _hasError(fieldName)) {
                      setState(() {
                        _fieldErrors[fieldName] = false;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        // Show error text below the field
        if (_hasError(fieldName) && _shouldShowError(fieldName))
          Padding(
            padding: const EdgeInsets.only(left: 15, top: 4),
            child: Text(
              _getErrorMessage(fieldName),
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _dropDown(String value, List<String> list, Function(String) onChanged, {
    required String fieldName,
    String? hintText,
  }) {
    final isEmpty = value.isEmpty;
    final hasError = _hasError(fieldName);
    final shouldShowError = _shouldShowError(fieldName);

    return Container(
      height: 55,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: (hasError && shouldShowError)
              ? Colors.red
              : (isEmpty ? Colors.black : const Color(0xFF48A54C)),
          width: 1.6,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: list.contains(value) ? value : (list.isNotEmpty && !isEmpty ? list.first : null),
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: (hasError && shouldShowError) ? Colors.red : Colors.black54,
          ),
          hint: Text(
            hintText ?? 'Select',
            style: TextStyle(
              fontSize: 16,
              color: (hasError && shouldShowError) ? Colors.red.withOpacity(0.7) : Colors.black54,
            ),
          ),
          items: list.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) {
            onChanged(v ?? '');
            // Clear error when user selects something
            if (v != null && v.isNotEmpty && hasError) {
              setState(() {
                _fieldErrors[fieldName] = false;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _progressBubble(double progress, String label) {
    final size = 42.0;
    return SizedBox(
      height: size,
      width: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: size,
            width: size,
            decoration: BoxDecoration(color: Colors.red.shade100, shape: BoxShape.circle),
          ),
          SizedBox(
            height: size,
            width: size,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 3.2,
              valueColor: const AlwaysStoppedAnimation(Color(0xFFE64B37)),
              backgroundColor: Colors.white,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFE64B37)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SignupModel>(
      builder: (context, model, child) {
        return Stack(
          children: [
            Scaffold(
              backgroundColor: Colors.white,
              body: SafeArea(
                top: true,
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            "Your Details",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE64B37),
                            ),
                          ),
                          const SizedBox(height: 15),

                          // Profile Picture
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              GestureDetector(
                                onTap: _showImageSourceOptions,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFE64B37),
                                      width: 3,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 55,
                                    backgroundImage: _profileImage != null
                                        ? FileImage(_profileImage!)
                                        : (model.profilePictureFile != null ? FileImage(model.profilePictureFile!) : const AssetImage("assets/profile.jpg")) as ImageProvider,
                                    child: _profileImage == null && model.profilePictureFile == null
                                        ? const Icon(Icons.person, size: 50, color: Colors.white)
                                        : null,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: _showImageSourceOptions,
                                child: Container(
                                  height: 35,
                                  width: 35,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE64B37),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          GestureDetector(
                            onTap: _showImageSourceOptions,
                            child: const Text(
                              "Tap to upload profile picture",
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFFE64B37),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),

                          const SizedBox(height: 25),

                          // First Name - FIXED
                          Row(
                            children: [
                              Expanded(
                                child: _inputField(
                                  Icons.person,
                                  "First Name*",
                                      (v) {
                                    model.setFirstName(v);
                                    setState(() {
                                      _fieldErrors['firstName'] = v.isEmpty;
                                      _fieldTouched['firstName'] = true;
                                    });
                                  },
                                  focusNode: _focusNodes['firstName']!,
                                  fieldName: 'firstName',
                                  controller: _firstNameController,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _inputField(
                                  Icons.person,
                                  "Last Name*",
                                      (v) {
                                    model.setLastName(v);
                                    setState(() {
                                      _fieldErrors['lastName'] = v.isEmpty;
                                      _fieldTouched['lastName'] = true;
                                    });
                                  },
                                  focusNode: _focusNodes['lastName']!,
                                  fieldName: 'lastName',
                                  controller: _lastNameController,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 15),

                          // Email - FIXED
                          _inputField(
                            Icons.email,
                            "Email Address*",
                                (v) {
                              model.setEmail(v);
                              setState(() {
                                _fieldErrors['email'] = v.isEmpty;
                                _fieldTouched['email'] = true;
                              });
                            },
                            focusNode: _focusNodes['email']!,
                            fieldName: 'email',
                            controller: _emailController,
                          ),

                          const SizedBox(height: 12),

                          // PASSWORD - FIXED
                          _inputField(
                            Icons.lock,
                            "Password*",
                                (v) {
                              model.setPassword(v);
                              setState(() {
                                _fieldErrors['password'] = v.isEmpty;
                                _fieldTouched['password'] = true;
                              });
                            },
                            focusNode: _focusNodes['password']!,
                            fieldName: 'password',
                            controller: _passwordController,
                            isPassword: true,
                            obscureText: _obscurePassword,
                            onToggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),

                          const SizedBox(height: 12),

                          // CONFIRM PASSWORD - FIXED
                          _inputField(
                            Icons.lock_outline,
                            "Confirm Password*",
                                (v) {
                              setState(() {
                                _confirmPassword = v;
                                _fieldErrors['confirmPassword'] = v.isEmpty || v != model.password;
                                _fieldTouched['confirmPassword'] = true;
                              });
                            },
                            focusNode: _focusNodes['confirmPassword']!,
                            fieldName: 'confirmPassword',
                            controller: _confirmPasswordController,
                            isPassword: true,
                            obscureText: _obscureConfirm,
                            onToggleVisibility: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          ),

                          const SizedBox(height: 15),

                          // PHONE FIELD
                          Container(child: _buildPhoneField()),

                          const SizedBox(height: 25),

                          // Date of birth label
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                                "Date Of Birth*",
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)
                            ),
                          ),
                          const SizedBox(height: 6),

                          // AD / BS Radio Buttons
                          Row(
                            children: [
                              Row(
                                children: [
                                  Radio<bool>(
                                    value: true,
                                    groupValue: isAD,
                                    onChanged: (v) {
                                      setState(() {
                                        isAD = true;
                                        _fieldTouched['dob'] = true;
                                      });
                                      if (selectedADYear.isEmpty || selectedADMonth.isEmpty || selectedADDay.isEmpty) {
                                        setState(() {
                                          _fieldErrors['dob'] = true;
                                        });
                                      } else {
                                        _updateDobToProvider();
                                      }
                                    },
                                    activeColor: const Color(0xFFE64B37),
                                  ),
                                  const Text("AD"),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Row(
                                children: [
                                  Radio<bool>(
                                    value: false,
                                    groupValue: isAD,
                                    onChanged: (v) {
                                      setState(() {
                                        isAD = false;
                                        _fieldTouched['dob'] = true;
                                      });
                                      if (selectedBSYear.isEmpty || selectedBSMonth.isEmpty || selectedBSDay.isEmpty) {
                                        setState(() {
                                          _fieldErrors['dob'] = true;
                                        });
                                      } else {
                                        _convertAdToBs();
                                        _convertBsToAdAndUpdate();
                                      }
                                    },
                                    activeColor: const Color(0xFFE64B37),
                                  ),
                                  const Text("BS"),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // DATE SELECTION
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isAD) // AD Date Selection
                                Row(
                                  children: [
                                    // Month dropdown
                                    Expanded(
                                      child: _dropDown(
                                        selectedADMonth,
                                        adMonths,
                                            (value) {
                                          setState(() {
                                            selectedADMonth = value;
                                            final days = currentAdDays;
                                            if (!days.contains(selectedADDay)) {
                                              selectedADDay = days.isNotEmpty ? days.first : '01';
                                            }
                                            _fieldTouched['dob'] = true;
                                          });
                                          _updateDobToProvider();
                                        },
                                        fieldName: 'dob',
                                        hintText: 'Month',
                                      ),
                                    ),
                                    const SizedBox(width: 10),

                                    // Day dropdown
                                    Expanded(
                                      child: _dropDown(
                                        selectedADDay,
                                        currentAdDays,
                                            (value) {
                                          setState(() {
                                            selectedADDay = value;
                                            _fieldTouched['dob'] = true;
                                          });
                                          _updateDobToProvider();
                                        },
                                        fieldName: 'dob',
                                        hintText: 'Day',
                                      ),
                                    ),
                                    const SizedBox(width: 10),

                                    // Year dropdown
                                    Expanded(
                                      child: _dropDown(
                                        selectedADYear,
                                        adYears,
                                            (value) {
                                          setState(() {
                                            selectedADYear = value ?? '';
                                            final days = currentAdDays;
                                            if (!days.contains(selectedADDay)) {
                                              selectedADDay = days.isNotEmpty ? days.first : '01';
                                            }
                                            _fieldTouched['dob'] = true;
                                          });
                                          _updateDobToProvider();
                                        },
                                        fieldName: 'dob',
                                        hintText: 'Year',
                                      ),
                                    ),
                                  ],
                                )
                              else // BS Date Selection
                                Row(
                                  children: [
                                    // Month dropdown
                                    Expanded(
                                      child: _dropDown(
                                        selectedBSMonth,
                                        bsMonths,
                                            (value) {
                                          setState(() {
                                            selectedBSMonth = value;
                                            final days = currentBsDays;
                                            if (!days.contains(selectedBSDay)) {
                                              selectedBSDay = days.isNotEmpty ? days.first : '01';
                                            }
                                            _fieldTouched['dob'] = true;
                                          });
                                          _convertBsToAdAndUpdate();
                                        },
                                        fieldName: 'dob',
                                        hintText: 'Month',
                                      ),
                                    ),
                                    const SizedBox(width: 10),

                                    // Day dropdown
                                    Expanded(
                                      child: _dropDown(
                                        selectedBSDay,
                                        currentBsDays,
                                            (value) {
                                          setState(() {
                                            selectedBSDay = value;
                                            _fieldTouched['dob'] = true;
                                          });
                                          _convertBsToAdAndUpdate();
                                        },
                                        fieldName: 'dob',
                                        hintText: 'Day',
                                      ),
                                    ),
                                    const SizedBox(width: 10),

                                    // Year dropdown
                                    Expanded(
                                      child: _dropDown(
                                        selectedBSYear,
                                        bsYears,
                                            (value) {
                                          setState(() {
                                            selectedBSYear = value ?? '';
                                            final days = currentBsDays;
                                            if (!days.contains(selectedBSDay)) {
                                              selectedBSDay = days.isNotEmpty ? days.first : '01';
                                            }
                                            _fieldTouched['dob'] = true;
                                          });
                                          _convertBsToAdAndUpdate();
                                        },
                                        fieldName: 'dob',
                                        hintText: 'Year',
                                      ),
                                    ),
                                  ],
                                ),
                              // Show error text below date field
                              if (_hasError('dob') && _shouldShowError('dob'))
                                Padding(
                                  padding: const EdgeInsets.only(left: 12, top: 4),
                                  child: Text(
                                    _getErrorMessage('dob'),
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          // Show converted date info
                          if (!isAD && selectedADYear.isNotEmpty && selectedADMonth.isNotEmpty && selectedADDay.isNotEmpty)
                            const SizedBox(height: 10),
                          if (!isAD && selectedADYear.isNotEmpty && selectedADMonth.isNotEmpty && selectedADDay.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(8),
                              margin: const EdgeInsets.only(top: 10),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green, width: 1),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info, color: Colors.green, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'BS: ${selectedBSYear.isNotEmpty ? "$selectedBSYear ${selectedBSMonth.isNotEmpty ? selectedBSMonth.substring(0, 3) : ""} $selectedBSDay" : "Not selected"} → '
                                          'AD: ${selectedADYear.isNotEmpty ? "$selectedADYear ${selectedADMonth.isNotEmpty ? selectedADMonth.substring(0, 3) : ""} $selectedADDay" : "Not converted"}',
                                      style: const TextStyle(fontSize: 12, color: Colors.green),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 20),

                          // LANGUAGES
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                                "Languages*",
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)
                            ),
                          ),
                          const SizedBox(height: 8),

                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: _getBorderColor('languages'),
                                    width: 1.6,
                                  ),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(22),
                                  onTap: () => _showLanguagePicker(context),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "Languages",
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: (_hasError('languages') && _shouldShowError('languages'))
                                                  ? Colors.red
                                                  : Colors.black87,
                                            ),
                                          ),
                                          Icon(
                                            Icons.keyboard_arrow_down,
                                            color: (_hasError('languages') && _shouldShowError('languages'))
                                                ? Colors.red
                                                : Colors.black54,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      selectedLanguages.isEmpty
                                          ? Text(
                                        "Select languages",
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: (_hasError('languages') && _shouldShowError('languages'))
                                              ? Colors.red.withOpacity(0.8)
                                              : Colors.black45,
                                        ),
                                      )
                                          : Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: selectedLanguages.map((lang) {
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE64B37).withOpacity(0.08),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: const Color(0xFFE64B37), width: 1),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(lang, style: const TextStyle(fontSize: 14)),
                                                const SizedBox(width: 6),
                                                GestureDetector(
                                                  onTap: () {
                                                    setState(() {
                                                      selectedLanguages.remove(lang);
                                                      model.setLanguages(selectedLanguages.join(', '));
                                                      _fieldErrors['languages'] = selectedLanguages.isEmpty;
                                                      _fieldTouched['languages'] = true;
                                                    });
                                                  },
                                                  child: const Icon(Icons.close, size: 16, color: Color(0xFFE64B37)),
                                                )
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (_hasError('languages') && _shouldShowError('languages'))
                                Padding(
                                  padding: const EdgeInsets.only(left: 12, top: 4),
                                  child: Text(
                                    _getErrorMessage('languages'),
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 25),

                          // NATIONALITY
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                                "Nationality*",
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)
                            ),
                          ),
                          const SizedBox(height: 8),

                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 55,
                                padding: const EdgeInsets.symmetric(horizontal: 12),

                                child: TypingDropdown(
                                  items: nationalityList,  itemLabel: (item) => item,  onChanged: (String? newValue) {
        setState(() {
        selectedNationality = newValue ?? '';
        _fieldErrors['nationality'] = newValue == null || newValue.isEmpty;
        _fieldTouched['nationality'] = true;
        });
        model.setNationality(newValue ?? '');
        }, title: 'Nationality', showError: submitted,

                                ),
                              ),
                              if (_hasError('nationality') && _shouldShowError('nationality'))
                                Padding(
                                  padding: const EdgeInsets.only(left: 12, top: 4),
                                  child: Text(
                                    _getErrorMessage('nationality'),
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 35),

                          // BUTTONS
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Container(
                                    height: 55,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(colors: [Color(0xFFEEA2A4), Color(0xFFF3C0C4)]),
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    child: const Center(
                                      child: Text(
                                          "Previous",
                                          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: GestureDetector(
                                  onTap: model.isSubmitting ? null : _submitSignup,
                                  child: Container(
                                    height: 55,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(colors: [Color(0xFFE64B37), Color(0xFFE62255)]),
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    child: Center(
                                      child: model.isSubmitting
                                          ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                                      )
                                          : const Text(
                                          "Submit",
                                          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 30),
                        ],
                      ),
                    ),

                    // Progress bubble
                    Positioned(right: 12, top: 8, child: _progressBubble(0.05, "5%")),
                  ],
                ),
              ),
            ),

            // Loading overlay
            if (model.isSubmitting)
              Positioned.fill(
                child: Container(
                  color: Colors.black45,
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        );
      },
    );
  }
}