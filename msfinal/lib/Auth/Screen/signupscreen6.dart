import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ms2026/Auth/Screen/signupscreen7.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../ReUsable/dropdownwidget.dart';
import '../../service/updatepage.dart';

class EducationCareerPage extends StatefulWidget {
  const EducationCareerPage({super.key});

  @override
  State<EducationCareerPage> createState() => _EducationCareerPageState();
}

class _EducationCareerPageState extends State<EducationCareerPage> {
  bool submitted = false;
  bool isLoading = false;

  // Education Section
  String? _selectedEducationMedium;
  String? _selectedEducationType;
  String? _selectedFaculty;
  String? _selectedEducationDegree;

  // Career Section
  bool? _isWorking;
  String? _occupationType;

  // Job Details
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _designationController = TextEditingController();
  String? _selectedWorkingWith;
  String? _selectedAnnualIncome;

  // Business Details
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _businessDesignationController = TextEditingController();
  String? _selectedBusinessWorkingWith;
  String? _selectedBusinessAnnualIncome;

  // Designation dropdown
  String? _selectedDesignation;

  // Error messages
  final Map<String, String> _errors = {
    'educationMedium': '',
    'educationType': '',
    'faculty': '',
    'educationDegree': '',
    'isWorking': '',
    'occupationType': '',
    'companyName': '',
    'designation': '',
    'workingWith': '',
    'annualIncome': '',
    'businessName': '',
    'businessWorkingWith': '',
    'businessAnnualIncome': '',
  };

  // Dropdown options
  final List<String> _educationMediumOptions = [
    'English',
    'Nepali',
    'Hindi',
    'Other'
  ];

  final List<String> _educationTypeOptions = [
    'Regular',
    'Distance Learning',
    'Online',
    'Correspondence',
    'Other'
  ];

  final List<String> _facultyOptions = [
    'Science',
    'Management',
    'Humanities',
    'Education',
    'Engineering',
    'Medicine',
    'Law',
    'Agriculture',
    'Forestry',
    'Computer Science',
    'Other'
  ];

  final List<String> _educationDegreeOptions = [
    'SEE/SLC',
    '+2/Intermediate',
    'Diploma',
    'Bachelor',
    'Master',
    'PhD',
    'Post Doctoral',
    'Other'
  ];

  final List<String> _workingWithOptions = [
    'Private Company',
    'Government',
    'NGO/INGO',
    'Self Employed',
    'Family Business',
    'Startup',
    'Other'
  ];

  final List<String> _annualIncomeOptions = [
    'Below 2 Lakhs',
    '2-5 Lakhs',
    '5-10 Lakhs',
    '10-20 Lakhs',
    '20-50 Lakhs',
    '50 Lakhs - 1 Crore',
    'Above 1 Crore'
  ];

  final List<String> _designationOptions = [
    "Software Developer",
    "Senior Software Developer",
    "Mobile App Developer",
    "Flutter Developer",
    "Backend Developer",
    "Full Stack Developer",
    "Frontend Developer",
    "UI/UX Designer",
    "Graphic Designer",
    "Web Designer",
    "Project Manager",
    "Product Manager",
    "Team Lead",
    "CEO",
    "CTO",
    "COO",
    "Founder",
    "Co-Founder",
    "Business Analyst",
    "Data Analyst",
    "Data Scientist",
    "Machine Learning Engineer",
    "AI Engineer",
    "Cloud Engineer",
    "DevOps Engineer",
    "QA Tester",
    "QA Engineer",
    "Digital Marketer",
    "SEO Specialist",
    "Content Writer",
    "Copywriter",
    "Accountant",
    "Finance Manager",
    "HR Manager",
    "HR Executive",
    "Marketing Manager",
    "Sales Executive",
    "Sales Manager",
    "Customer Support",
    "Receptionist",
    "Teacher",
    "Professor",
    "Doctor",
    "Nurse",
    "Engineer",
    "Civil Engineer",
    "Mechanical Engineer",
    "Electrical Engineer",
    "Driver",
    "Security Guard",
    "Chef",
    "Entrepreneur",
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

  bool _validateWorkingDetails() {
    bool isValid = true;

    if (_isWorking == true) {
      if (!_validateRequired(_occupationType, 'occupationType')) {
        isValid = false;
      }

      if (_occupationType == "Job") {
        if (!_validateRequired(_companyNameController.text.trim(), 'companyName')) {
          isValid = false;
        }
        if (!_validateRequired(_selectedDesignation, 'designation')) {
          isValid = false;
        }
        if (!_validateRequired(_selectedWorkingWith, 'workingWith')) {
          isValid = false;
        }
        if (!_validateRequired(_selectedAnnualIncome, 'annualIncome')) {
          isValid = false;
        }
      } else if (_occupationType == "Business") {
        if (!_validateRequired(_businessNameController.text.trim(), 'businessName')) {
          isValid = false;
        }
        if (!_validateRequired(_selectedDesignation, 'designation')) {
          isValid = false;
        }
        if (!_validateRequired(_selectedBusinessWorkingWith, 'businessWorkingWith')) {
          isValid = false;
        }
        if (!_validateRequired(_selectedBusinessAnnualIncome, 'businessAnnualIncome')) {
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

    // Education validation
    if (!_validateRequired(_selectedEducationMedium, 'educationMedium')) {
      isValid = false;
    }
    if (!_validateRequired(_selectedEducationType, 'educationType')) {
      isValid = false;
    }
    if (!_validateRequired(_selectedFaculty, 'faculty')) {
      isValid = false;
    }
    if (!_validateRequired(_selectedEducationDegree, 'educationDegree')) {
      isValid = false;
    }

    // Career validation
    if (_isWorking == null) {
      _errors['isWorking'] = 'Please select if you are working';
      isValid = false;
    } else {
      _errors['isWorking'] = '';
    }

    // Validate working details
    if (!_validateWorkingDetails()) {
      isValid = false;
    }

    setState(() {});
    return isValid;
  }

  // Handler methods
  void _handleEducationMediumChange(String? value) {
    setState(() {
      _selectedEducationMedium = value;
      _errors['educationMedium'] = '';
    });
  }

  void _handleEducationTypeChange(String? value) {
    setState(() {
      _selectedEducationType = value;
      _errors['educationType'] = '';
    });
  }

  void _handleFacultyChange(String? value) {
    setState(() {
      _selectedFaculty = value;
      _errors['faculty'] = '';
    });
  }

  void _handleEducationDegreeChange(String? value) {
    setState(() {
      _selectedEducationDegree = value;
      _errors['educationDegree'] = '';
    });
  }

  void _handleIsWorkingChange(bool? value) {
    setState(() {
      _isWorking = value;
      _errors['isWorking'] = '';
      // Clear occupation type when changing working status
      _occupationType = null;
      _errors['occupationType'] = '';
    });
  }

  void _handleOccupationTypeChange(String? value) {
    setState(() {
      _occupationType = value;
      _errors['occupationType'] = '';
    });
  }

  void _handleDesignationChange(String? value) {
    setState(() {
      _selectedDesignation = value;
      _errors['designation'] = '';
    });
  }

  void _handleWorkingWithChange(String? value) {
    setState(() {
      _selectedWorkingWith = value;
      _errors['workingWith'] = '';
    });
  }

  void _handleAnnualIncomeChange(String? value) {
    setState(() {
      _selectedAnnualIncome = value;
      _errors['annualIncome'] = '';
    });
  }

  void _handleBusinessWorkingWithChange(String? value) {
    setState(() {
      _selectedBusinessWorkingWith = value;
      _errors['businessWorkingWith'] = '';
    });
  }

  void _handleBusinessAnnualIncomeChange(String? value) {
    setState(() {
      _selectedBusinessAnnualIncome = value;
      _errors['businessAnnualIncome'] = '';
    });
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
                      "Education & Career",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE64B37),
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  // Education Section
                  _buildSectionTitle("Education Medium*"),
                  if (submitted && _errors['educationMedium']!.isNotEmpty)
                    _buildErrorText(_errors['educationMedium']!),
                  const SizedBox(height: 8),
                  Container(
                    child: TypingDropdown<String>(
                      items: _educationMediumOptions,
                      selectedItem: _selectedEducationMedium,
                      itemLabel: (item) => item,
                      hint: "Medium*",
                      onChanged: _handleEducationMediumChange,
                      title: 'Medium',
                      showError: submitted && _errors['educationMedium']!.isNotEmpty,
                      /// errorText: _errors['educationMedium'],
                    ),
                  ),

                  const SizedBox(height: 15),

                  _buildSectionTitle("Education Type*"),
                  if (submitted && _errors['educationType']!.isNotEmpty)
                    _buildErrorText(_errors['educationType']!),
                  const SizedBox(height: 8),
                  Container(
                    child: TypingDropdown<String>(
                      items: _educationTypeOptions,
                      selectedItem: _selectedEducationType,
                      itemLabel: (item) => item,
                      hint: "Education Type*",
                      onChanged: _handleEducationTypeChange,
                      title: 'Education type',
                      showError: submitted && _errors['educationType']!.isNotEmpty,
                      /// errorText: _errors['educationType'],
                    ),
                  ),

                  const SizedBox(height: 15),

                  _buildSectionTitle("Faculty*"),
                  if (submitted && _errors['faculty']!.isNotEmpty)
                    _buildErrorText(_errors['faculty']!),
                  const SizedBox(height: 8),
                  Container(
                    child: TypingDropdown<String>(
                      items: _facultyOptions,
                      selectedItem: _selectedFaculty,
                      itemLabel: (item) => item,
                      hint: "Faculty*",
                      onChanged: _handleFacultyChange,
                      title: 'Faculty',
                      showError: submitted && _errors['faculty']!.isNotEmpty,
                      // errorText: _errors['faculty'],
                    ),
                  ),

                  const SizedBox(height: 15),

                  _buildSectionTitle("Education Degree*"),
                  if (submitted && _errors['educationDegree']!.isNotEmpty)
                    _buildErrorText(_errors['educationDegree']!),
                  const SizedBox(height: 8),
                  Container(
                    child: TypingDropdown<String>(
                      items: _educationDegreeOptions,
                      selectedItem: _selectedEducationDegree,
                      itemLabel: (item) => item,
                      hint: "Education Degree*",
                      onChanged: _handleEducationDegreeChange,
                      title: 'Education degree',
                      showError: submitted && _errors['educationDegree']!.isNotEmpty,
                      // errorText: _errors['educationDegree'],
                    ),
                  ),

                  const SizedBox(height: 25),
                  _buildDivider(),
                  const SizedBox(height: 25),

                  // Career Section
                  _buildSectionTitle("Career Details*"),
                  const SizedBox(height: 12),

                  _buildSectionTitle("Are You Working?*"),
                  if (submitted && _errors['isWorking']!.isNotEmpty)
                    _buildErrorText(_errors['isWorking']!),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildRadioOption(
                          value: true,
                          groupValue: _isWorking,
                          label: "Yes",
                          onChanged: (value) {
                            _handleIsWorkingChange(value);
                          },
                          hasError: submitted && _errors['isWorking']!.isNotEmpty,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildRadioOption(
                          value: false,
                          groupValue: _isWorking,
                          label: "No",
                          onChanged: (value) {
                            _handleIsWorkingChange(value);
                          },
                          hasError: submitted && _errors['isWorking']!.isNotEmpty,
                        ),
                      ),
                    ],
                  ),

                  // Show occupation type only if working
                  if (_isWorking == true) ...[
                    const SizedBox(height: 20),
                    _buildSectionTitle("Occupation Type?"),
                    if (submitted && _errors['occupationType']!.isNotEmpty)
                      _buildErrorText(_errors['occupationType']!),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildRadioOption(
                            value: "Job",
                            groupValue: _occupationType,
                            label: "Job",
                            onChanged: (value) {
                              _handleOccupationTypeChange(value);
                            },
                            hasError: submitted && _errors['occupationType']!.isNotEmpty,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: _buildRadioOption(
                            value: "Business",
                            groupValue: _occupationType,
                            label: "Business",
                            onChanged: (value) {
                              _handleOccupationTypeChange(value);
                            },
                            hasError: submitted && _errors['occupationType']!.isNotEmpty,
                          ),
                        ),
                      ],
                    ),

                    // Show Job Details
                    if (_occupationType == "Job") ...[
                      const SizedBox(height: 25),
                      _buildSectionTitle("Company Name*"),
                      if (submitted && _errors['companyName']!.isNotEmpty)
                        _buildErrorText(_errors['companyName']!),
                      const SizedBox(height: 8),
                      _buildTextField(
                        _companyNameController,
                        "Enter company name",
                        errorText: submitted ? _errors['companyName'] : null,
                      ),

                      const SizedBox(height: 15),

                      _buildSectionTitle("Designation*"),
                      if (submitted && _errors['designation']!.isNotEmpty)
                        _buildErrorText(_errors['designation']!),
                      const SizedBox(height: 8),
                      Container(
                        child: TypingDropdown<String>(
                          items: _designationOptions,
                          selectedItem: _selectedDesignation,
                          itemLabel: (item) => item,
                          hint: "Designation*",
                          onChanged: _handleDesignationChange,
                          title: 'Designation',
                          showError: submitted && _errors['designation']!.isNotEmpty,
                          // errorText: _errors['designation'],
                        ),
                      ),

                      const SizedBox(height: 15),

                      _buildSectionTitle("Working With*"),
                      if (submitted && _errors['workingWith']!.isNotEmpty)
                        _buildErrorText(_errors['workingWith']!),
                      const SizedBox(height: 8),
                      Container(
                        child: TypingDropdown<String>(
                          items: _workingWithOptions,
                          selectedItem: _selectedWorkingWith,
                          itemLabel: (item) => item,
                          hint: "Select working with*",
                          onChanged: _handleWorkingWithChange,
                          title: 'Working with',
                          showError: submitted && _errors['workingWith']!.isNotEmpty,
                          // errorText: _errors['workingWith'],
                        ),
                      ),

                      const SizedBox(height: 15),

                      _buildSectionTitle("Annual Income*"),
                      if (submitted && _errors['annualIncome']!.isNotEmpty)
                        _buildErrorText(_errors['annualIncome']!),
                      const SizedBox(height: 8),
                      Container(
                        child: TypingDropdown<String>(
                          items: _annualIncomeOptions,
                          selectedItem: _selectedAnnualIncome,
                          itemLabel: (item) => item,
                          hint: "Select annual income*",
                          onChanged: _handleAnnualIncomeChange,
                          title: 'Annual incomes',
                          showError: submitted && _errors['annualIncome']!.isNotEmpty,
                          // errorText: _errors['annualIncome'],
                        ),
                      ),
                    ],

                    // Show Business Details
                    if (_occupationType == "Business") ...[
                      const SizedBox(height: 25),
                      _buildSectionTitle("Business Name*"),
                      if (submitted && _errors['businessName']!.isNotEmpty)
                        _buildErrorText(_errors['businessName']!),
                      const SizedBox(height: 8),
                      _buildTextField(
                        _businessNameController,
                        "Enter business name",
                        errorText: submitted ? _errors['businessName'] : null,
                      ),

                      const SizedBox(height: 15),

                      _buildSectionTitle("Designation*"),
                      if (submitted && _errors['designation']!.isNotEmpty)
                        _buildErrorText(_errors['designation']!),
                      const SizedBox(height: 8),
                      Container(
                        child: TypingDropdown<String>(
                          items: _designationOptions,
                          selectedItem: _selectedDesignation,
                          itemLabel: (item) => item,
                          hint: "Enter your designation",
                          onChanged: _handleDesignationChange,
                          title: 'Designation',
                          showError: submitted && _errors['designation']!.isNotEmpty,
                          // errorText: _errors['designation'],
                        ),
                      ),

                      const SizedBox(height: 15),

                      _buildSectionTitle("Working With*"),
                      if (submitted && _errors['businessWorkingWith']!.isNotEmpty)
                        _buildErrorText(_errors['businessWorkingWith']!),
                      const SizedBox(height: 8),
                      _buildDropdown(
                        value: _selectedBusinessWorkingWith,
                        hint: "Select working with",
                        items: _workingWithOptions,
                        onChanged: (value) {
                          _handleBusinessWorkingWithChange(value);
                        },
                        errorText: submitted ? _errors['businessWorkingWith'] : null,
                      ),

                      const SizedBox(height: 15),

                      _buildSectionTitle("Annual Income*"),
                      if (submitted && _errors['businessAnnualIncome']!.isNotEmpty)
                        _buildErrorText(_errors['businessAnnualIncome']!),
                      const SizedBox(height: 8),
                      _buildDropdown(
                        value: _selectedBusinessAnnualIncome,
                        hint: "Select annual income",
                        items: _annualIncomeOptions,
                        onChanged: (value) {
                          _handleBusinessAnnualIncomeChange(value);
                        },
                        errorText: submitted ? _errors['businessAnnualIncome'] : null,
                      ),
                    ],
                  ],

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
              child: _progressBubble(0.30, "70%"),
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
        ));

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
    required dynamic value,
    required dynamic groupValue,
    required String label,
    required Function(dynamic) onChanged,
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

    await _submitEducationCareerData();

    setState(() {
      isLoading = false;
    });
  }

   _submitEducationCareerData() async {
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

      // Prepare request body based on occupation type
      Map<String, String> requestBody = {
        "userid": userId.toString(),
        "educationmedium": _selectedEducationMedium ?? "",
        "educationtype": _selectedEducationType ?? "",
        "faculty": _selectedFaculty ?? "",
        "degree": _selectedEducationDegree ?? "",
        "areyouworking": _isWorking == true ? "Yes" : "No",
        "occupationtype": _occupationType ?? "",
        "companyname": _companyNameController.text.trim(),
        "designation": _selectedDesignation ?? "",
        "workingwith": _selectedWorkingWith ?? _selectedBusinessWorkingWith ?? "",
        "annualincome": _selectedAnnualIncome ?? _selectedBusinessAnnualIncome ?? "",
        "businessname": _businessNameController.text.trim(),
      };

      print("Sending request: $requestBody");

      var response = await http.post(
        Uri.parse("https://digitallami.com/Api2/educationcareer.php"),
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
            pageNo: 5,
          );

          if (updated) {
            _showSuccess("Education & career details saved successfully!");
            // Navigate after a short delay
            Future.delayed(const Duration(seconds: 1), () {
              Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AstrologicDetailsPage())
              );
            });
          } else {
            _showError("Failed to update progress");
          }
        } else {
          _showError(data['message'] ?? "Failed to save data");
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
    _companyNameController.dispose();
    _designationController.dispose();
    _businessNameController.dispose();
    _businessDesignationController.dispose();
    super.dispose();
  }
}