import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../ReUsable/dropdownwidget.dart';
import '../../../service/personal_details_api.dart'; // Your existing service

class PersonalDetailsPagee extends StatefulWidget {
  const PersonalDetailsPagee({
    super.key,
    this.initialData,
  });

  final Map<String, dynamic>? initialData;

  @override
  State<PersonalDetailsPagee> createState() => _PersonalDetailsPageeState();
}

class _PersonalDetailsPageeState extends State<PersonalDetailsPagee> {
  // Form variables
  String? _selectedMaritalStatus;
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  bool _hasSpecs = false;
  bool submitted = false;

  bool _hasDisability = false;
  String _ChildStatus = '';
  String _Childlivewith = '';
  final TextEditingController _disabilityController = TextEditingController();
  String? _selectedBloodGroup;
  String? _selectedComplexion;
  String? _selectedBodyType;
  final TextEditingController _aboutYourselfController = TextEditingController();

  // Dropdown options
  final List<String> _maritalStatusOptions = [
    'Still Unmarried',
    'Widowed',
    'Divorced',
    'Waiting Divorce',
  ];

  final List<String> _bloodGroupOptions = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-'
  ];

  final List<String> _complexionOptions = [
    'Very Fair',
    'Fair',
    'Wheatish',
    'Olive',
    'Brown',
    'Dark'
  ];

  final List<String> _bodyTypeOptions = [
    'Slim',
    'Athletic',
    'Average',
    'Heavy',
    'Muscular'
  ];

  String _SelectedHeight = '';

  final List<String> _heightOptions = List.generate(121, (index) {
    int cm = 100 + index;
    double totalInches = cm / 2.54;
    int feet = totalInches ~/ 12;
    int inches = (totalInches % 12).round();
    return "$cm cm ($feet' $inches\").ft";
  });

  String _selectedWeight = '';

  final List<String> _weightOptions = List.generate(121, (index) {
    int kg = 30 + index; // 30 kg to 150 kg
    return "$kg kg";
  });

  // Loading and data state
  bool _isLoading = true;
  bool _hasSavedData = false;
  int? _userId;

  // Full profile data for About Me generation
  Map<String, dynamic> _fullProfileData = {};
  String _userFirstName = '';
  String _userLastName = '';

  // Service instance
  late UserPersonalDetailService _detailService;

  @override
  void initState() {
    super.initState();
    _detailService = UserPersonalDetailService(
      baseUrl: 'https://digitallami.com/Api2/get_personal_detail.php', // Use same endpoint
    );
    if (widget.initialData != null && widget.initialData!.isNotEmpty) {
      _populateFormWithData(widget.initialData!);
      _hasSavedData = true;
      _isLoading = false;
    } else {
      _loadUserData();
    }
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final firstName = prefs.getString('user_firstName') ?? '';
      final lastName = prefs.getString('user_lastName') ?? '';
      if (mounted) {
        setState(() {
          _userFirstName = firstName;
          _userLastName = lastName;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');

      if (userDataString != null) {
        final userData = jsonDecode(userDataString);
        _userId = int.tryParse(userData["id"].toString());

        if (_userId != null && _userId! > 0) {
          await _fetchPersonalDetails();
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchPersonalDetails() async {
    if (_userId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _detailService.fetchUserPersonalDetail(_userId!);

      if (mounted) {
        if (result['status'] == 'success') {
          final data = result['data'];

          if (data != null) {
            // Populate form fields with fetched data
            _populateFormWithData(data);
            _hasSavedData = true;
          } else {
            _hasSavedData = false;
          }
        } else {
          _showError(result['message'] ?? "Failed to fetch data");
        }

        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showError('Error fetching data: $e');
      }
    }
  }

  void _populateFormWithData(Map<String, dynamic> data) {
    print('Populating form with data: $data');

    // Store full data for About Me generation
    _fullProfileData = Map<String, dynamic>.from(data);

    // Also capture name if available in the data
    if (data['firstName'] != null && data['firstName'].toString().isNotEmpty) {
      _userFirstName = data['firstName'].toString();
    }
    if (data['lastName'] != null && data['lastName'].toString().isNotEmpty) {
      _userLastName = data['lastName'].toString();
    }

    // Marital Status
    final maritalId = data['maritalStatusId']?.toString();
    if (maritalId != null && int.tryParse(maritalId) != null) {
      final index = int.parse(maritalId) - 1;
      if (index >= 0 && index < _maritalStatusOptions.length) {
        _selectedMaritalStatus = _maritalStatusOptions[index];
      }
    }
    _selectedMaritalStatus ??= data['maritalStatusName']?.toString();

    // Height
    if (data['height_name'] != null && data['height_name'].toString().isNotEmpty) {
      _SelectedHeight = data['height_name'].toString();
    }

    // Weight
    if (data['weight_name'] != null && data['weight_name'].toString().isNotEmpty) {
      _selectedWeight = data['weight_name'].toString();
    }

    // Specs
    if (data['haveSpecs'] != null) {
      final value = data['haveSpecs'].toString().toLowerCase();
      _hasSpecs = value == 'true' || value == '1' || value == 'yes';
    }

    // Disability
    if (data['anyDisability'] != null) {
      final value = data['anyDisability'].toString().toLowerCase();
      _hasDisability = value == 'true' || value == '1' || value == 'yes';
    } else if (data['disability'] != null) {
      final value = data['disability'].toString().toLowerCase();
      _hasDisability = value == 'yes' || value == '1' || value == 'true';
    }

    // Disability description
    final disabilityText = data['Disability'] ?? data['disability'];
    if (disabilityText != null && disabilityText.toString().isNotEmpty) {
      _disabilityController.text = disabilityText.toString();
    }

    // Blood Group
    if (data['bloodGroup'] != null && data['bloodGroup'].toString().isNotEmpty) {
      _selectedBloodGroup = data['bloodGroup'].toString();
    }

    // Complexion
    if (data['complexion'] != null && data['complexion'].toString().isNotEmpty) {
      _selectedComplexion = data['complexion'].toString();
    }

    // Body Type
    if (data['bodyType'] != null && data['bodyType'].toString().isNotEmpty) {
      _selectedBodyType = data['bodyType'].toString();
    }

    // About Yourself
    if (data['aboutMe'] != null && data['aboutMe'].toString().isNotEmpty) {
      _aboutYourselfController.text = data['aboutMe'].toString();
    }

    // Child Status
    if (data['childStatus'] != null && data['childStatus'].toString().isNotEmpty) {
      _ChildStatus = data['childStatus'].toString();
    }

    // Child Live With
    if (data['childLiveWith'] != null && data['childLiveWith'].toString().isNotEmpty) {
      _Childlivewith = data['childLiveWith'].toString();
    }

    // Force UI update
    if (mounted) {
      setState(() {});
    }
  }

  String _generateAboutMeText() {
    final String name = [_userFirstName, _userLastName]
        .where((s) => s.isNotEmpty)
        .join(' ');

    String? birthDate = _fullProfileData['birthDate']?.toString();
    int age = 0;
    if (birthDate != null && birthDate.isNotEmpty) {
      try {
        final parts = birthDate.split('-');
        if (parts.length == 3) {
          final dob = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
          final today = DateTime.now();
          age = today.year - dob.year;
          if (today.month < dob.month ||
              (today.month == dob.month && today.day < dob.day)) {
            age--;
          }
        }
      } catch (_) {}
    }

    String _nonEmpty(String? v) =>
        (v == null || v.trim().isEmpty || v.trim().toLowerCase() == 'null') ? '' : v.trim();

    final marital = _nonEmpty(_selectedMaritalStatus);
    final location = _nonEmpty(_fullProfileData['city']?.toString());
    final country = _nonEmpty(_fullProfileData['country']?.toString());
    final religion = _nonEmpty(_fullProfileData['religionName']?.toString());
    final community = _nonEmpty(_fullProfileData['communityName']?.toString());
    final degree = _nonEmpty(_fullProfileData['degree']?.toString());
    final designation = _nonEmpty(_fullProfileData['designation']?.toString());
    final company = _nonEmpty(_fullProfileData['companyname']?.toString());

    final sentences = <String>[];

    final introBits = <String>[];
    if (name.isNotEmpty) introBits.add(name);
    if (age > 0) introBits.add('$age years old');
    if (location.isNotEmpty || country.isNotEmpty) {
      final loc = [location, country].where((s) => s.isNotEmpty).join(', ');
      introBits.add('based in $loc');
    }
    if (introBits.isNotEmpty) sentences.add('I am ${introBits.join(', ')}.');

    if (marital.isNotEmpty) sentences.add('My marital status is $marital.');

    final workBits = <String>[];
    if (designation.isNotEmpty) workBits.add('working as $designation');
    if (company.isNotEmpty) workBits.add('at $company');
    if (degree.isNotEmpty) workBits.add('with a degree in $degree');
    if (workBits.isNotEmpty) sentences.add('Professionally, I am ${workBits.join(' ')}.');

    final bgBits = <String>[];
    if (religion.isNotEmpty) bgBits.add(religion);
    if (community.isNotEmpty) bgBits.add(community);
    if (bgBits.isNotEmpty) sentences.add('My background is rooted in ${bgBits.join(', ')}.');

    return sentences.join(' ').trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Personal Details', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFE64B37),
        elevation: 0,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            if (_isLoading)
              const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: Color(0xFFE64B37),
                    ),
                    SizedBox(height: 16),
                    Text(
                      "Loading your personal details...",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
            else
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with saved indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Personal Details",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE64B37),
                          ),
                        ),
                        if (_hasSavedData)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.green,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 16,
                                  color: Colors.green[700],
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "Saved",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 25),

                    // Marital Status
                    _buildSectionTitle("Marital Status*"),

                    Container(
                      child: TypingDropdown<String>(
                        items: _maritalStatusOptions,
                        selectedItem: _selectedMaritalStatus,
                        itemLabel: (item) => item,
                        hint: "Select Marital",
                        onChanged: (value) {
                          setState(() {
                            _selectedMaritalStatus = value!;
                          });
                        },
                        title: 'Marital Status',
                        showError: submitted,
                      ),
                    ),

                    const SizedBox(height: 10),
                    if (_selectedMaritalStatus == 'Divorced' ||
                        _selectedMaritalStatus == 'Widowed' ||
                        _selectedMaritalStatus == 'Waiting Divorce') ...[
                      const SizedBox(height: 8),
                      _buildSectionTitle("Children Status"),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildRadioOptionn(
                              value: "No Child",
                              groupValue: _ChildStatus,
                              label: "No Child",
                              onChanged: (value) {
                                setState(() {
                                  _ChildStatus = value!;
                                });
                              },
                            ),
                          ),
                          SizedBox(
                            width: 15,
                          ),
                          Expanded(
                            child: _buildRadioOptionn(
                              value: 'One',
                              groupValue: _ChildStatus,
                              label: "One",
                              onChanged: (value) {
                                setState(() {
                                  _ChildStatus = value!;
                                });
                              },
                            ),
                          ),
                          SizedBox(
                            width: 15,
                          ),
                          Expanded(
                            child: _buildRadioOptionn(
                              value: 'Two +',
                              groupValue: _ChildStatus,
                              label: "Two +",
                              onChanged: (value) {
                                setState(() {
                                  _ChildStatus = value!;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),
                    ],

                    if (_ChildStatus == 'One' || _ChildStatus == 'Two +') ...[
                      _buildSectionTitle("Child live with?"),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildRadioOptionn(
                              value: "With Me",
                              groupValue: _Childlivewith,
                              label: "With Me",
                              onChanged: (value) {
                                setState(() {
                                  _Childlivewith = value!;
                                });
                              },
                            ),
                          ),
                          SizedBox(
                            width: 15,
                          ),
                          Expanded(
                            child: _buildRadioOptionn(
                              value: 'With Ex Husband',
                              groupValue: _Childlivewith,
                              label: "With Ex Husband",
                              onChanged: (value) {
                                setState(() {
                                  _Childlivewith = value!;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],

                    if (_ChildStatus == 'One' || _ChildStatus == 'Two +') ...[
                      Row(
                        children: [
                          Expanded(
                            child: _buildRadioOptionn(
                              value: 'Others',
                              groupValue: _Childlivewith,
                              label: "Others",
                              onChanged: (value) {
                                setState(() {
                                  _Childlivewith = value!;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Height and Weight Row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionTitle("Height (In Cm)*"),
                              Container(
                                child: TypingDropdown<String>(
                                  items: _heightOptions,
                                  selectedItem: _SelectedHeight,
                                  itemLabel: (item) => item,
                                  hint: "Select height",
                                  onChanged: (value) {
                                    setState(() {
                                      _SelectedHeight = value!;
                                    });
                                  },
                                  title: 'Height',
                                  showError: submitted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionTitle("Weight (In Kg)*"),
                              Container(
                                child: TypingDropdown<String>(
                                  items: _weightOptions,
                                  selectedItem: _selectedWeight,
                                  itemLabel: (item) => item,
                                  hint: "Select weight",
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedWeight = value!;
                                    });
                                  },
                                  title: 'Weight',
                                  showError: submitted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 25),

                    // Specs/Lenses Section
                    _buildSectionTitle("Specs/Lenses"),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildRadioOption(
                            value: true,
                            groupValue: _hasSpecs,
                            label: "Yes",
                            onChanged: (value) {
                              setState(() {
                                _hasSpecs = value ?? false;
                              });
                            },
                          ),
                        ),
                        SizedBox(
                          width: 15,
                        ),
                        Expanded(
                          child: _buildRadioOption(
                            value: false,
                            groupValue: _hasSpecs,
                            label: "No",
                            onChanged: (value) {
                              setState(() {
                                _hasSpecs = value ?? false;
                              });
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 25),
                    _buildDivider(),

                    // Any Disability Section
                    _buildSectionTitle("Any Disability"),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildRadioOption(
                            value: true,
                            groupValue: _hasDisability,
                            label: "Yes",
                            onChanged: (value) {
                              setState(() {
                                _hasDisability = value ?? false;
                              });
                            },
                          ),
                        ),
                        SizedBox(
                          width: 15,
                        ),
                        Expanded(
                          child: _buildRadioOption(
                            value: false,
                            groupValue: _hasDisability,
                            label: "No",
                            onChanged: (value) {
                              setState(() {
                                _hasDisability = value ?? false;
                              });
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 25),

                    // Disability Description (only show if disability is yes)
                    if (_hasDisability) ...[
                      _buildSectionTitle("What Disability You've?"),
                      const SizedBox(height: 8),
                      _buildTextField(
                        _disabilityController,
                        "Describe your disability",
                        maxLines: 3,
                      ),
                      const SizedBox(height: 25),
                    ],

                    _buildDivider(),

                    const SizedBox(height: 25),

                    // Blood Group
                    _buildSectionTitle("Blood Group*"),
                    Container(
                      child: TypingDropdown<String>(
                        items: _bloodGroupOptions,
                        selectedItem: _selectedBloodGroup,
                        itemLabel: (item) => item,
                        hint: "Select blood group",
                        onChanged: (value) {
                          setState(() {
                            _selectedBloodGroup = value!;
                          });
                        },
                        title: 'Blood Group',
                        showError: submitted,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Complexion
                    _buildSectionTitle("Complexion*"),
                    Container(
                      child: TypingDropdown<String>(
                        items: _complexionOptions,
                        selectedItem: _selectedComplexion,
                        itemLabel: (item) => item,
                        hint: "Select Complexion",
                        onChanged: (value) {
                          setState(() {
                            _selectedComplexion = value!;
                          });
                        },
                        title: 'Complexion',
                        showError: submitted,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Body Type
                    _buildSectionTitle("Body Type*"),
                    Container(
                      child: TypingDropdown<String>(
                        items: _bodyTypeOptions,
                        selectedItem: _selectedBodyType,
                        itemLabel: (item) => item,
                        hint: "Select Body Type",
                        onChanged: (value) {
                          setState(() {
                            _selectedBodyType = value!;
                          });
                        },
                        title: 'Body Type',
                        showError: submitted,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // About Yourself
                    _buildSectionTitle("About Yourself"),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.auto_awesome, color: Color(0xFF48A54C), size: 18),
                        label: const Text(
                          'Auto Generate Your About Me',
                          style: TextStyle(color: Color(0xFF48A54C), fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF48A54C)),
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          final generated = _generateAboutMeText();
                          if (generated.isNotEmpty) {
                            setState(() {
                              _aboutYourselfController.text = generated;
                            });
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please fill in more profile details to auto-generate.',
                                ),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 120,
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: const Color(0xFF48A54C),
                          width: 1.6,
                        ),
                      ),
                      child: TextField(
                        controller: _aboutYourselfController,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: "Tell us about yourself...",
                          hintStyle: TextStyle(fontSize: 16),
                        ),
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                      ),
                    ),

                    const SizedBox(height: 35),

                    // Buttons
                    Row(
                      children: [
                        const SizedBox(width: 15),
                        Expanded(
                          child: _buildButton(
                            text: "Continue",
                            isPrimary: true,
                            onPressed: () {
                              _validateAndSubmit();
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),

            // Progress bubble

          ],
        ),
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

  Widget _buildTextField(TextEditingController controller, String hintText,
      {int maxLines = 1}) {
    return Container(
      height: maxLines == 1 ? 55 : null,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFF48A54C),
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
        maxLines: maxLines,
      ),
    );
  }

  Widget _buildRadioOption({
    required bool value,
    required bool? groupValue,
    required String label,
    required Function(bool?) onChanged,
  }) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF48A54C),
          width: 1.2,
        ),
      ),
      child: RadioListTile<bool>(
        value: value,
        groupValue: groupValue,
        onChanged: onChanged,
        title: Text(
          label,
          style: const TextStyle(fontSize: 16),
        ),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        activeColor: const Color(0xFFE64B37),
      ),
    );
  }

  Widget _buildRadioOptionn({
    required String value,
    required String groupValue,
    required String label,
    required Function(String?) onChanged,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => onChanged(value),
      child: Container(
        height: 50,
        width: 200,
        padding: EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF48A54C),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: groupValue,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: onChanged,
              activeColor: const Color(0xFFE64B37),
            ),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton({
    required String text,
    required bool isPrimary,
    required VoidCallback onPressed,
  }) {
    return Container(
      height: 55,
      decoration: BoxDecoration(
        gradient: isPrimary
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



  void _validateAndSubmit() async {
    setState(() {
      submitted = true;
    });

    // Basic validation
    if (_selectedMaritalStatus == null) {
      _showError("Please select marital status");
      return;
    }

    if (_SelectedHeight.isEmpty) {
      _showError("Please enter height");
      return;
    }

    if (_selectedWeight.isEmpty) {
      _showError("Please enter weight");
      return;
    }

    if (_selectedBloodGroup == null) {
      _showError("Please select blood group");
      return;
    }

    if (_selectedComplexion == null) {
      _showError("Please select complexion");
      return;
    }

    if (_selectedBodyType == null) {
      _showError("Please select body type");
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');
      final userData = jsonDecode(userDataString!);
      final userId = int.tryParse(userData["id"].toString());

      if (userId == null) {
        Navigator.of(context).pop();
        _showError("User ID not found");
        return;
      }

      // Create save service instance (different URL for save)
      final saveService = UserPersonalDetailService(
        baseUrl: 'https://digitallami.com/Api2/save_personal_detail.php',
      );

      final result = await saveService.saveUserPersonalDetail(
        userId: userId,
        maritalStatusId: _maritalStatusOptions.indexOf(_selectedMaritalStatus!) + 1,
        heightName: _SelectedHeight,
        weightName: _selectedWeight,
        haveSpecs: _hasSpecs ? 1 : 0,
        anyDisability: _hasDisability ? 1 : 0,
        disability: _disabilityController.text.isNotEmpty ? _disabilityController.text : null,
        bloodGroup: _selectedBloodGroup,
        complexion: _selectedComplexion,
        bodyType: _selectedBodyType,
        aboutMe: _aboutYourselfController.text.isNotEmpty ? _aboutYourselfController.text : null,
        childStatus: _ChildStatus.isNotEmpty ? _ChildStatus : null,
        childLiveWith: _Childlivewith.isNotEmpty ? _Childlivewith : null,
      );

      Navigator.of(context).pop(); // close loading dialog

      if (result['status'] == 'success') {
        // Refresh data after saving
        await _fetchPersonalDetails();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Saved successfully'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
      } else {
        _showError(result['message'] ?? "Something went wrong");
      }
    } catch (e) {
      Navigator.of(context).pop();
      _showError('Error: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _disabilityController.dispose();
    _aboutYourselfController.dispose();
    super.dispose();
  }
}
