import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:ms2026/Auth/Screen/signupscreen6.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../ReUsable/dropdownwidget.dart';
import '../../service/updatepage.dart';

class FamilyDetailsPage extends StatefulWidget {
  const FamilyDetailsPage({super.key});

  @override
  State<FamilyDetailsPage> createState() => _FamilyDetailsPageState();
}

class _FamilyDetailsPageState extends State<FamilyDetailsPage> {
  bool submitted = false;
  bool isLoading = false;

  // Form variables
  String? _selectedFamilyType;
  String? _selectedFamilyBackground;
  String? _fatherStatus;
  String? _motherStatus;
  String? _hasOtherFamilyMembers = '';
  String? _selectedFamilyOrigin;

  // Father details
  final TextEditingController _fatherNameController = TextEditingController();
  String? _fatherEducation;
  String? _fatherOccupation;

  // Mother details
  final TextEditingController _motherCastController = TextEditingController();
  final TextEditingController _motherContactController = TextEditingController();
  String? _motherEducation;
  String? _motherOccupation;

  // Other family members
  final List<FamilyMember> _familyMembers = [];
  String? _selectedMemberType;
  String? _selectedMemberMaritalStatus;
  String? _memberLivesWithUs = '';

  // Error messages
  final Map<String, String> _errors = {
    'familyType': '',
    'familyBackground': '',
    'fatherStatus': '',
    'motherStatus': '',
    'fatherName': '',
    'fatherEducation': '',
    'fatherOccupation': '',
    'motherCast': '',
    'motherContact': '',
    'motherEducation': '',
    'motherOccupation': '',
    'familyOrigin': '',
    'hasOtherFamilyMembers': '',
    'memberType': '',
    'memberMaritalStatus': '',
    'memberLivesWithUs': '',
  };

  // Dropdown options
  final List<String> _familyTypeOptions = [
    'Joint Family',
    'Nuclear Family',
    'Single Parent Family',
    'Extended Family',
    'Other'
  ];

  final List<String> _familyBackgroundOptions = [
    'Upper Class',
    'Upper Middle Class',
    'Middle Class',
    'Lower Middle Class',
    'Lower Class',
    'Other'
  ];

  final List<String> _familyOriginOptions = [
    'Urban',
    'Suburban',
    'Rural',
    'Metropolitan',
    'Other'
  ];

  final List<String> _educationOptions = [
    'Illiterate',
    'Primary School',
    'Secondary School',
    'High School',
    'Diploma',
    'Bachelor',
    'Master',
    'PhD',
    'Other'
  ];

  final List<String> _occupationOptions = [
    'Government Job',
    'Private Job',
    'Business',
    'Farmer',
    'Teacher',
    'Doctor',
    'Engineer',
    'Student',
    'Housewife',
    'Retired',
    'Unemployed',
    'Other'
  ];

  final List<String> _memberTypeOptions = [
    'Brother',
    'Sister',
    'Grandfather',
    'Grandmother',
    'Uncle',
    'Aunt',
    'Cousin',
    'Other Relative'
  ];

  final List<String> _maritalStatusOptions = [
    'Single',
    'Married',
    'Divorced',
    'Widowed'
  ];

  // Validation methods
  bool _validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      _errors[fieldName] = 'This field is required';
      return false;
    }
    _errors[fieldName] = '';
    return true;
  }

  bool _validateFatherDetails() {
    bool isValid = true;

    if (_fatherStatus == "Lives with us") {
      if (!_validateRequired(_fatherNameController.text.trim(), 'fatherName')) {
        isValid = false;
      }
      if (!_validateRequired(_fatherEducation, 'fatherEducation')) {
        isValid = false;
      }
      if (!_validateRequired(_fatherOccupation, 'fatherOccupation')) {
        isValid = false;
      }
    }

    return isValid;
  }

  bool _validateMotherDetails() {
    bool isValid = true;

    if (_motherStatus == "Lives with us") {
      if (!_validateRequired(_motherCastController.text.trim(), 'motherCast')) {
        isValid = false;
      }
      if (!_validateRequired(_motherEducation, 'motherEducation')) {
        isValid = false;
      }
      if (!_validateRequired(_motherOccupation, 'motherOccupation')) {
        isValid = false;
      }

      // Optional contact number validation
      if (_motherContactController.text.isNotEmpty) {
        if (!RegExp(r'^[0-9]{10,15}$').hasMatch(_motherContactController.text)) {
          _errors['motherContact'] = 'Please enter a valid contact number (10-15 digits)';
          isValid = false;
        } else {
          _errors['motherContact'] = '';
        }
      }
    }

    return isValid;
  }

  bool _validateFamilyMembers() {
    bool isValid = true;

    // Validate "Do You've Any Other Family Member?" selection
    if (_hasOtherFamilyMembers == null || _hasOtherFamilyMembers!.isEmpty) {
      _errors['hasOtherFamilyMembers'] = 'Please select an option';
      isValid = false;
    } else {
      _errors['hasOtherFamilyMembers'] = '';
    }

    if (_hasOtherFamilyMembers == 'Yes') {
      // Validate existing members
      for (int i = 0; i < _familyMembers.length; i++) {
        final member = _familyMembers[i];
        if (member.type.isEmpty) {
          _showError("Member ${i + 1}: Please select member type");
          isValid = false;
        }
        if (member.maritalStatus.isEmpty) {
          _showError("Member ${i + 1}: Please select marital status");
          isValid = false;
        }
        if (member.livesWithUs.isEmpty) {
          _showError("Member ${i + 1}: Please select if member lives with you");
          isValid = false;
        }
      }

      // Validate current form if trying to add or if no members added yet
      if (_familyMembers.isEmpty) {
        if (!_validateRequired(_selectedMemberType, 'memberType')) {
          isValid = false;
        }
        if (!_validateRequired(_selectedMemberMaritalStatus, 'memberMaritalStatus')) {
          isValid = false;
        }
        if (!_validateRequired(_memberLivesWithUs, 'memberLivesWithUs')) {
          isValid = false;
        }
      } else if (_selectedMemberType != null ||
          _selectedMemberMaritalStatus != null ||
          _memberLivesWithUs != null) {
        // Only validate if user is trying to add a new member
        if (!_validateRequired(_selectedMemberType, 'memberType')) {
          isValid = false;
        }
        if (!_validateRequired(_selectedMemberMaritalStatus, 'memberMaritalStatus')) {
          isValid = false;
        }
        if (!_validateRequired(_memberLivesWithUs, 'memberLivesWithUs')) {
          isValid = false;
        }
      }
    }

    return isValid;
  }

  bool _validateForm() {
    bool isValid = true;

    // Clear all errors
    _errors.forEach((key, value) {
      _errors[key] = '';
    });

    // Basic validation
    if (!_validateRequired(_selectedFamilyType, 'familyType')) {
      isValid = false;
    }
    if (!_validateRequired(_selectedFamilyBackground, 'familyBackground')) {
      isValid = false;
    }
    if (!_validateRequired(_fatherStatus, 'fatherStatus')) {
      isValid = false;
    }
    if (!_validateRequired(_motherStatus, 'motherStatus')) {
      isValid = false;
    }
    if (!_validateRequired(_selectedFamilyOrigin, 'familyOrigin')) {
      isValid = false;
    }

    // Validate father details
    if (!_validateFatherDetails()) {
      isValid = false;
    }

    // Validate mother details
    if (!_validateMotherDetails()) {
      isValid = false;
    }

    // Validate family members
    if (!_validateFamilyMembers()) {
      isValid = false;
    }

    setState(() {});
    return isValid;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  const Center(
                    child: Text(
                      "Family Details",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE64B37),
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  // Family Type
                  _buildSectionTitle("Family Type*"),
                  const SizedBox(height: 8),
                  Container(
                    child: TypingDropdown<String>(
                      items: _familyTypeOptions,
                      selectedItem: _selectedFamilyType,
                      itemLabel: (item) => item,
                      hint: "Select Family Type",
                      onChanged: (value) {
                        setState(() {
                          _selectedFamilyType = value;
                          _errors['familyType'] = '';
                        });
                      },
                      title: 'Family type',
                      showError: submitted && _errors['familyType']!.isNotEmpty,
                      //errorText: _errors['familyType'],
                    ),
                  ),
                  if (submitted && _errors['familyType']!.isNotEmpty)
                    _buildErrorText(_errors['familyType']!),

                  const SizedBox(height: 20),

                  // Family Background
                  _buildSectionTitle("Family Background*"),
                  const SizedBox(height: 8),
                  Container(
                    child: TypingDropdown<String>(
                      items: _familyBackgroundOptions,
                      selectedItem: _selectedFamilyBackground,
                      itemLabel: (item) => item,
                      hint: "Select Family Background",
                      onChanged: (value) {
                        setState(() {
                          _selectedFamilyBackground = value;
                          _errors['familyBackground'] = '';
                        });
                      },
                      title: 'Family background',
                      showError: submitted && _errors['familyBackground']!.isNotEmpty,
                      // errorText: _errors['familyBackground'],
                    ),
                  ),
                  if (submitted && _errors['familyBackground']!.isNotEmpty)
                    _buildErrorText(_errors['familyBackground']!),

                  const SizedBox(height: 25),
                  _buildDivider(),
                  const SizedBox(height: 25),

                  // Father Section
                  _buildSectionTitle("Father Status*"),
                  if (submitted && _errors['fatherStatus']!.isNotEmpty)
                    _buildErrorText(_errors['fatherStatus']!),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildRadioOption(
                          value: "Lives with us",
                          groupValue: _fatherStatus,
                          label: "Lives with us",
                          onChanged: (value) {
                            setState(() {
                              _fatherStatus = value;
                              _errors['fatherStatus'] = '';
                            });
                          },
                          hasError: submitted && _errors['fatherStatus']!.isNotEmpty,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildRadioOption(
                          value: "Passed Away",
                          groupValue: _fatherStatus,
                          label: "Passed Away",
                          onChanged: (value) {
                            setState(() {
                              _fatherStatus = value;
                              _errors['fatherStatus'] = '';
                            });
                          },
                          hasError: submitted && _errors['fatherStatus']!.isNotEmpty,
                        ),
                      ),
                    ],
                  ),

                  if (_fatherStatus == "Lives with us") ...[
                    const SizedBox(height: 20),
                    _buildSectionTitle("Father Name*"),
                    if (submitted && _errors['fatherName']!.isNotEmpty)
                      _buildErrorText(_errors['fatherName']!),
                    const SizedBox(height: 8),
                    _buildTextField(
                      _fatherNameController,
                      "Enter father's name",
                      errorText: submitted ? _errors['fatherName'] : null,
                    ),

                    const SizedBox(height: 15),

                    _buildSectionTitle("Education*"),
                    if (submitted && _errors['fatherEducation']!.isNotEmpty)
                      _buildErrorText(_errors['fatherEducation']!),
                    const SizedBox(height: 8),
                    Container(
                      child: TypingDropdown<String>(
                        items: _educationOptions,
                        selectedItem: _fatherEducation,
                        itemLabel: (item) => item,
                        hint: "Select Education",
                        onChanged: (value) {
                          setState(() {
                            _fatherEducation = value;
                            _errors['fatherEducation'] = '';
                          });
                        },
                        title: 'Education',
                        showError: submitted && _errors['fatherEducation']!.isNotEmpty,
                        // errorText: _errors['fatherEducation'],
                      ),
                    ),
                    if (submitted && _errors['fatherEducation']!.isNotEmpty)
                      _buildErrorText(_errors['fatherEducation']!),

                    const SizedBox(height: 15),

                    _buildSectionTitle("Occupation*"),
                    if (submitted && _errors['fatherOccupation']!.isNotEmpty)
                      _buildErrorText(_errors['fatherOccupation']!),
                    const SizedBox(height: 8),
                    Container(
                      child: TypingDropdown<String>(
                        items: _occupationOptions,
                        selectedItem: _fatherOccupation,
                        itemLabel: (item) => item,
                        hint: "Select Occupation",
                        onChanged: (value) {
                          setState(() {
                            _fatherOccupation = value;
                            _errors['fatherOccupation'] = '';
                          });
                        },
                        title: 'Occupation',
                        showError: submitted && _errors['fatherOccupation']!.isNotEmpty,
                        // errorText: _errors['fatherOccupation'],
                      ),
                    ),
                    if (submitted && _errors['fatherOccupation']!.isNotEmpty)
                      _buildErrorText(_errors['fatherOccupation']!),
                  ],

                  const SizedBox(height: 25),
                  _buildDivider(),
                  const SizedBox(height: 25),

                  // Mother Section
                  _buildSectionTitle("Mother Status*"),
                  if (submitted && _errors['motherStatus']!.isNotEmpty)
                    _buildErrorText(_errors['motherStatus']!),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildRadioOption(
                          value: "Lives with us",
                          groupValue: _motherStatus,
                          label: "Lives with us",
                          onChanged: (value) {
                            setState(() {
                              _motherStatus = value;
                              _errors['motherStatus'] = '';
                            });
                          },
                          hasError: submitted && _errors['motherStatus']!.isNotEmpty,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildRadioOption(
                          value: "Passed Away",
                          groupValue: _motherStatus,
                          label: "Passed Away",
                          onChanged: (value) {
                            setState(() {
                              _motherStatus = value;
                              _errors['motherStatus'] = '';
                            });
                          },
                          hasError: submitted && _errors['motherStatus']!.isNotEmpty,
                        ),
                      ),
                    ],
                  ),

                  if (_motherStatus == "Lives with us") ...[
                    const SizedBox(height: 20),
                    _buildSectionTitle("Mother Cast*"),
                    if (submitted && _errors['motherCast']!.isNotEmpty)
                      _buildErrorText(_errors['motherCast']!),
                    const SizedBox(height: 8),
                    _buildTextField(
                      _motherCastController,
                      "Enter mother's cast",
                      errorText: submitted ? _errors['motherCast'] : null,
                    ),

                    const SizedBox(height: 15),

                    _buildSectionTitle("Contact No."),
                    if (submitted && _errors['motherContact']!.isNotEmpty)
                      _buildErrorText(_errors['motherContact']!),
                    const SizedBox(height: 8),
                    _buildTextField(
                      _motherContactController,
                      "Enter mother's contact number",
                      keyboardType: TextInputType.phone,
                      errorText: submitted ? _errors['motherContact'] : null,
                    ),

                    const SizedBox(height: 15),

                    _buildSectionTitle("Education*"),
                    if (submitted && _errors['motherEducation']!.isNotEmpty)
                      _buildErrorText(_errors['motherEducation']!),
                    const SizedBox(height: 8),
                    Container(
                      child: TypingDropdown<String>(
                        items: _educationOptions,
                        selectedItem: _motherEducation,
                        itemLabel: (item) => item,
                        hint: "Select Education",
                        onChanged: (value) {
                          setState(() {
                            _motherEducation = value;
                            _errors['motherEducation'] = '';
                          });
                        },
                        title: 'Education',
                        showError: submitted && _errors['motherEducation']!.isNotEmpty,
                        // errorText: _errors['motherEducation'],
                      ),
                    ),
                    if (submitted && _errors['motherEducation']!.isNotEmpty)
                      _buildErrorText(_errors['motherEducation']!),

                    const SizedBox(height: 15),

                    _buildSectionTitle("Occupation*"),
                    if (submitted && _errors['motherOccupation']!.isNotEmpty)
                      _buildErrorText(_errors['motherOccupation']!),
                    const SizedBox(height: 8),
                    Container(
                      child: TypingDropdown<String>(
                        items: _occupationOptions,
                        selectedItem: _motherOccupation,
                        itemLabel: (item) => item,
                        hint: "Select Occupation",
                        onChanged: (value) {
                          setState(() {
                            _motherOccupation = value;
                            _errors['motherOccupation'] = '';
                          });
                        },
                        title: 'Occupation',
                        showError: submitted && _errors['motherOccupation']!.isNotEmpty,
                        // errorText: _errors['motherOccupation'],
                      ),
                    ),
                    if (submitted && _errors['motherOccupation']!.isNotEmpty)
                      _buildErrorText(_errors['motherOccupation']!),
                  ],

                  const SizedBox(height: 25),
                  _buildDivider(),
                  const SizedBox(height: 25),

                  // Other Family Members Section
                  _buildSectionTitle("Do You've Any Other Family Member?"),
                  if (submitted && _errors['hasOtherFamilyMembers']!.isNotEmpty)
                    _buildErrorText(_errors['hasOtherFamilyMembers']!),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildRadioOption(
                          value: "Yes",
                          groupValue: _hasOtherFamilyMembers,
                          label: "Yes",
                          onChanged: (value) {
                            setState(() {
                              _hasOtherFamilyMembers = value;
                              _errors['hasOtherFamilyMembers'] = '';
                              // Clear member form errors when changing selection
                              if (value == "NO") {
                                _errors['memberType'] = '';
                                _errors['memberMaritalStatus'] = '';
                                _errors['memberLivesWithUs'] = '';
                                _selectedMemberType = null;
                                _selectedMemberMaritalStatus = null;
                                _memberLivesWithUs = null;
                              }
                            });
                          },
                          hasError: submitted && _errors['hasOtherFamilyMembers']!.isNotEmpty,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildRadioOption(
                          value: "NO",
                          groupValue: _hasOtherFamilyMembers,
                          label: "No",
                          onChanged: (value) {
                            setState(() {
                              _hasOtherFamilyMembers = value;
                              _errors['hasOtherFamilyMembers'] = '';
                              // Clear member form errors when changing selection
                              if (value == "NO") {
                                _errors['memberType'] = '';
                                _errors['memberMaritalStatus'] = '';
                                _errors['memberLivesWithUs'] = '';
                                _selectedMemberType = null;
                                _selectedMemberMaritalStatus = null;
                                _memberLivesWithUs = null;
                              }
                            });
                          },
                          hasError: submitted && _errors['hasOtherFamilyMembers']!.isNotEmpty,
                        ),
                      ),
                    ],
                  ),

                  if (_hasOtherFamilyMembers == 'Yes') ...[
                    const SizedBox(height: 25),

                    // Add Family Member Form
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: (_familyMembers.isEmpty && submitted &&
                              (_errors['memberType']!.isNotEmpty ||
                                  _errors['memberMaritalStatus']!.isNotEmpty ||
                                  _errors['memberLivesWithUs']!.isNotEmpty))
                              ? Colors.red
                              : const Color(0xFF48A54C),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle("Member Type"),
                          if (submitted && _errors['memberType']!.isNotEmpty)
                            _buildErrorText(_errors['memberType']!),
                          const SizedBox(height: 8),
                          _buildDropdown(
                            value: _selectedMemberType,
                            hint: "Select Your Family Member",
                            items: _memberTypeOptions,
                            onChanged: (value) {
                              setState(() {
                                _selectedMemberType = value;
                                _errors['memberType'] = '';
                              });
                            },
                            errorText: submitted ? _errors['memberType'] : null,
                          ),

                          const SizedBox(height: 15),

                          _buildSectionTitle("Marital Status"),
                          if (submitted && _errors['memberMaritalStatus']!.isNotEmpty)
                            _buildErrorText(_errors['memberMaritalStatus']!),
                          const SizedBox(height: 8),
                          _buildDropdown(
                            value: _selectedMemberMaritalStatus,
                            hint: "Marital Status",
                            items: _maritalStatusOptions,
                            onChanged: (value) {
                              setState(() {
                                _selectedMemberMaritalStatus = value;
                                _errors['memberMaritalStatus'] = '';
                              });
                            },
                            errorText: submitted ? _errors['memberMaritalStatus'] : null,
                          ),

                          const SizedBox(height: 15),

                          _buildSectionTitle("Lives With Us?"),
                          if (submitted && _errors['memberLivesWithUs']!.isNotEmpty)
                            _buildErrorText(_errors['memberLivesWithUs']!),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildRadioOption(
                                  value: "Yes",
                                  groupValue: _memberLivesWithUs,
                                  label: "Yes",
                                  onChanged: (value) {
                                    setState(() {
                                      _memberLivesWithUs = value;
                                      _errors['memberLivesWithUs'] = '';
                                    });
                                  },
                                  hasError: submitted && _errors['memberLivesWithUs']!.isNotEmpty,
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: _buildRadioOption(
                                  value: "NO",
                                  groupValue: _memberLivesWithUs,
                                  label: "No",
                                  onChanged: (value) {
                                    setState(() {
                                      _memberLivesWithUs = value;
                                      _errors['memberLivesWithUs'] = '';
                                    });
                                  },
                                  hasError: submitted && _errors['memberLivesWithUs']!.isNotEmpty,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Add Member Button
                          Container(
                            height: 45,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFE64B37),
                                  Color(0xFFE62255),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(25),
                                onTap: _addFamilyMember,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.add, color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      "Add more family member",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Show warning if no members added
                    if (_familyMembers.isEmpty && submitted)
                      Container(
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red, width: 1),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning, color: Colors.red, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Please add at least one family member or select 'No'",
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // List of Added Family Members
                    if (_familyMembers.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildSectionTitle("Added Family Members"),
                      const SizedBox(height: 8),
                      ..._familyMembers.asMap().entries.map((entry) {
                        int index = entry.key;
                        FamilyMember member = entry.value;
                        return _buildFamilyMemberCard(member, index);
                      }).toList(),
                    ],
                  ],

                  const SizedBox(height: 25),
                  _buildDivider(),
                  const SizedBox(height: 25),

                  // Family Origin
                  _buildSectionTitle("Family Origin*"),
                  if (submitted && _errors['familyOrigin']!.isNotEmpty)
                    _buildErrorText(_errors['familyOrigin']!),
                  const SizedBox(height: 8),
                  Container(
                    child: TypingDropdown<String>(
                      items: _familyOriginOptions,
                      selectedItem: _selectedFamilyOrigin,
                      itemLabel: (item) => item,
                      hint: "Your Family Origin",
                      onChanged: (value) {
                        setState(() {
                          _selectedFamilyOrigin = value;
                          _errors['familyOrigin'] = '';
                        });
                      },
                      title: 'Family origin',
                      showError: submitted && _errors['familyOrigin']!.isNotEmpty,
                      // errorText: _errors['familyOrigin'],
                    ),
                  ),
                  if (submitted && _errors['familyOrigin']!.isNotEmpty)
                    _buildErrorText(_errors['familyOrigin']!),

                  const SizedBox(height: 35),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: _buildButton(
                          text: "Previous",
                          isPrimary: false,
                          onPressed: isLoading ? null : () {
                            Navigator.pop(context);
                          },
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildButton(
                          text: isLoading ? "Saving..." : "Continue",
                          isPrimary: true,
                          onPressed: isLoading ? null : _validateAndSubmit,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),

            // Progress bubble
            Positioned(
              right: 12,
              top: 8,
              child: _progressBubble(0.25, "60%"),
            ),

            // Loading overlay
            if (isLoading)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE64B37)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorText(String error) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0, top: 4.0),
      child: Text(
        error,
        style: const TextStyle(
          color: Colors.red,
          fontSize: 12,
        ),
      ),
    );
  }

  void _addFamilyMember() {
    setState(() {
      submitted = true;
    });

    // Validate the form
    bool isValid = true;

    if (_selectedMemberType == null) {
      _errors['memberType'] = 'Please select member type';
      isValid = false;
    } else {
      _errors['memberType'] = '';
    }

    if (_selectedMemberMaritalStatus == null) {
      _errors['memberMaritalStatus'] = 'Please select marital status';
      isValid = false;
    } else {
      _errors['memberMaritalStatus'] = '';
    }

    if (_memberLivesWithUs == null) {
      _errors['memberLivesWithUs'] = 'Please select if member lives with you';
      isValid = false;
    } else {
      _errors['memberLivesWithUs'] = '';
    }

    if (!isValid) {
      setState(() {});
      return;
    }

    setState(() {
      _familyMembers.add(FamilyMember(
        type: _selectedMemberType!,
        maritalStatus: _selectedMemberMaritalStatus!,
        livesWithUs: _memberLivesWithUs!,
      ));

      // Reset form
      _selectedMemberType = null;
      _selectedMemberMaritalStatus = null;
      _memberLivesWithUs = null;

      // Clear errors
      _errors['memberType'] = '';
      _errors['memberMaritalStatus'] = '';
      _errors['memberLivesWithUs'] = '';
    });
  }

  Widget _buildFamilyMemberCard(FamilyMember member, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF48A54C),
          width: 1,
        ),
        color: const Color(0xFFE64B37).withOpacity(0.05),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.type,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Marital Status: ${member.maritalStatus}",
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
                Text(
                  "Lives with us: ${member.livesWithUs}",
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Color(0xFFE64B37)),
            onPressed: () => _removeFamilyMember(index),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      color: Colors.grey,
      height: 1,
      thickness: 1,
    );
  }

  Widget _buildTextField(
      TextEditingController controller,
      String hintText, {
        TextInputType keyboardType = TextInputType.text,
        String? errorText,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 55,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: errorText != null && errorText.isNotEmpty
                  ? Colors.red
                  : const Color(0xFF48A54C),
              width: 1.6,
            ),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hintText,
              hintStyle: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
          ),
        ),
        if (errorText != null && errorText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              errorText,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required Function(String?) onChanged,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 55,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: errorText != null && errorText.isNotEmpty
                  ? Colors.red
                  : const Color(0xFF48A54C),
              width: 1.6,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
              hint: Text(
                hint,
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              ),
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item,
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
        if (errorText != null && errorText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              errorText,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRadioOption({
    required String value,
    required String? groupValue,
    required String label,
    required Function(String) onChanged,
    bool hasError = false,
  }) {
    bool isSelected = groupValue == value;

    return Container(
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasError ? Colors.red : const Color(0xFF48A54C),
          width: 1.2,
        ),
        color: isSelected ? const Color(0xFFE64B37).withOpacity(0.1) : Colors.transparent,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            onChanged(value);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? const Color(0xFFE64B37) : Colors.grey,
                      width: 2,
                    ),
                    color: isSelected ? const Color(0xFFE64B37) : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(
                    Icons.circle,
                    size: 10,
                    color: Colors.white,
                  )
                      : null,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton({
    required String text,
    required bool isPrimary,
    required VoidCallback? onPressed,
  }) {
    return Container(
      height: 55,
      decoration: BoxDecoration(
        gradient: isPrimary && onPressed != null
            ? const LinearGradient(
          colors: [
            Color(0xFFE64B37),
            Color(0xFFE62255),
          ],
        )
            : const LinearGradient(
          colors: [
            Color(0xFFEEA2A4),
            Color(0xFFF3C0C4),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onPressed,
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
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
            decoration:  BoxDecoration(
              color: Colors.red.shade100,
              shape: BoxShape.circle,
            ),
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
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFFE64B37),
            ),
          ),
        ],
      ),
    );
  }

  void _validateAndSubmit() async {
    setState(() {
      submitted = true;
    });

    if (!_validateForm()) {
      _showError("Please fill all required fields correctly");
      return;
    }

    setState(() {
      isLoading = true;
    });

    await _submitFamilyData();

    setState(() {
      isLoading = false;
    });
  }

  void _removeFamilyMember(int index) {
    setState(() {
      _familyMembers.removeAt(index);
    });
  }

_submitFamilyData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');

      if (userDataString == null) {
        _showError("User data not found. Please login again.");
        return;
      }

      final userData = jsonDecode(userDataString);
      final userId = int.tryParse(userData["id"]?.toString() ?? '0');

      if (userId == null || userId == 0) {
        _showError("Invalid user ID");
        return;
      }

      // Prepare family members data
      List<Map<String, String>> members = _familyMembers.map((m) {
        return {
          "membertype": m.type,
          "maritalstatus": m.maritalStatus,
          "livestatus": m.livesWithUs,
        };
      }).toList();

      // Prepare request body with proper null handling
      Map<String, String> requestBody = {
        "userid": userId.toString(),
        "familytype": _selectedFamilyType ?? "",
        "familybackground": _selectedFamilyBackground ?? "",
        "fatherstatus": _fatherStatus ?? "",
        "fathername": _fatherStatus == "Lives with us" ? (_fatherNameController.text.trim()) : "",
        "fathereducation": _fatherStatus == "Lives with us" ? (_fatherEducation ?? "") : "",
        "fatheroccupation": _fatherStatus == "Lives with us" ? (_fatherOccupation ?? "") : "",
        "motherstatus": _motherStatus ?? "",
        "mothercaste": _motherStatus == "Lives with us" ? (_motherCastController.text.trim()) : "",
        "mothercontact": _motherStatus == "Lives with us" ? (_motherContactController.text.trim()) : "",
        "mothereducation": _motherStatus == "Lives with us" ? (_motherEducation ?? "") : "",
        "motheroccupation": _motherStatus == "Lives with us" ? (_motherOccupation ?? "") : "",
        "familyorigin": _selectedFamilyOrigin ?? "",
        "members": jsonEncode(members),
      };

      print("Sending request: $requestBody");

      var response = await http.post(
        Uri.parse("https://digitallami.com/Api2/updatefamily.php"),
        body: requestBody,
      ).timeout(const Duration(seconds: 30));

      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200) {
        var data;
        try {
          data = jsonDecode(response.body);
        } catch (e) {
          _showError("Invalid response from server");
          return;
        }

        if (data['status'] == 'success') {
          // Update page number
          bool updated = await UpdateService.updatePageNumber(
            userId: userId.toString(),
            pageNo: 4,
          );

          if (updated) {
            _showSuccess("Family details saved successfully!");
            // Navigate after a short delay
            Future.delayed(const Duration(seconds: 1), () {
              Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => EducationCareerPage())
              );
            });
          } else {
            _showError("Failed to update progress");
          }
        } else {
          _showError(data['message'] ?? "Failed to save family details");
        }
      } else {
        _showError("Server error: ${response.statusCode}");
      }
    } on http.ClientException catch (e) {
      _showError("Network error: ${e.message}");
    } on TimeoutException catch (e) {
      _showError("Request timeout. Please try again.");
    } catch (e) {
      _showError("Unexpected error: $e");
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _fatherNameController.dispose();
    _motherCastController.dispose();
    _motherContactController.dispose();
    super.dispose();
  }
}

class FamilyMember {
  final String type;
  final String maritalStatus;
  final String livesWithUs;

  FamilyMember({
    required this.type,
    required this.maritalStatus,
    required this.livesWithUs,
  });
}