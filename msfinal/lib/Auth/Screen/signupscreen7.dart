import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ms2026/Auth/Screen/signupscreen8.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../ReUsable/dropdownwidget.dart';
import '../../service/updatepage.dart';

class AstrologicDetailsPage extends StatefulWidget {
  const AstrologicDetailsPage({super.key});

  @override
  State<AstrologicDetailsPage> createState() => _AstrologicDetailsPageState();
}

class _AstrologicDetailsPageState extends State<AstrologicDetailsPage> {
  bool submitted = false;
  bool isLoading = false;

  // Form variables
  String? _horoscopeBelief;
  String? _selectedCountryOfBirth;
  String? _selectedCityOfBirth;
  String? _selectedZodiacSign;
  TimeOfDay? _selectedTimeOfBirth;
  bool _isAD = true;
  String? _selectedMonth;
  String? _selectedDay;
  String? _selectedYear;
  String? _manglikStatus;

  // Nepali date variables
  List<String> _nepaliMonths = [];
  List<String> _nepaliDays = [];
  List<String> _nepaliYears = [];
  Map<String, int> _nepaliMonthDays = {};

  // Error messages
  final Map<String, String> _errors = {
    'horoscopeBelief': '',
    'countryOfBirth': '',
    'cityOfBirth': '',
    'zodiacSign': '',
    'timeOfBirth': '',
    'month': '',
    'day': '',
    'year': '',
    'manglikStatus': '',
  };

  // Dropdown options
  final List<String> _beliefOptions = ['Yes', 'No', 'Doesn\'t matter'];
  final List<String> _countryOptions = ['Nepal', 'India', 'USA', 'UK', 'Canada', 'Australia', 'Other'];
  final List<String> _cityOptions = ['Kathmandu', 'Pokhara', 'Lalitpur', 'Bharatpur', 'Biratnagar', 'Birgunj', 'Butwal', 'Dharan', 'Nepalgunj', 'Other'];
  final List<String> _zodiacSignOptions = ['Aries', 'Taurus', 'Gemini', 'Cancer', 'Leo', 'Virgo', 'Libra', 'Scorpio', 'Sagittarius', 'Capricorn', 'Aquarius', 'Pisces'];
  final List<String> _monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  final List<String> _dayOptions = List.generate(31, (index) => (index + 1).toString().padLeft(2, '0'));
  final List<String> _yearOptions = List.generate(100, (index) => (DateTime.now().year - 17 - index).toString());

  @override
  void initState() {
    super.initState();
    _initializeNepaliDate();
  }

  void _initializeNepaliDate() {
    // Initialize Nepali months (Bikram Sambat)
    _nepaliMonths = [
      'Baisakh', 'Jestha', 'Ashad', 'Shrawan', 'Bhadra', 'Ashwin',
      'Kartik', 'Mangsir', 'Poush', 'Magh', 'Falgun', 'Chaitra'
    ];

    // Initialize Nepali month days (approximate)
    _nepaliMonthDays = {
      'Baisakh': 31,
      'Jestha': 31,
      'Ashad': 31,
      'Shrawan': 31,
      'Bhadra': 31,
      'Ashwin': 30,
      'Kartik': 29,
      'Mangsir': 29,
      'Poush': 30,
      'Magh': 29,
      'Falgun': 30,
      'Chaitra': 30,
    };

    // Generate Nepali years (2000 BS to 2090 BS)
    _nepaliYears = List.generate(91, (index) => (2000 + index).toString());

    // Initialize with current values
    if (_selectedMonth == null) {
      _selectedMonth = _isAD ? _monthNames.first : _nepaliMonths.first;
    }
    if (_selectedYear == null) {
      _selectedYear = _isAD ? _yearOptions.first : '2080';
    }

    // Initialize days
    _updateDays();
  }

  void _updateDays() {
    if (!_isAD && _selectedMonth != null) {
      // For BS months
      final daysInMonth = _nepaliMonthDays[_selectedMonth] ?? 30;
      _nepaliDays = List.generate(daysInMonth, (index) => (index + 1).toString().padLeft(2, '0'));

      // Adjust selected day if it's out of range
      if (_selectedDay != null) {
        final day = int.tryParse(_selectedDay!);
        if (day != null && day > daysInMonth) {
          _selectedDay = '01';
        }
      } else {
        _selectedDay = '01';
      }
    } else {
      // For AD months
      if (_selectedDay == null) {
        _selectedDay = '01';
      }
    }
  }

  // Simple AD to BS conversion (approximate)
  Map<String, String> _convertADtoBS(String adYear, String adMonth, String adDay) {
    // This is a simplified conversion
    int year = int.tryParse(adYear) ?? DateTime.now().year;
    int month = _monthNames.indexOf(adMonth) + 1;
    int day = int.tryParse(adDay) ?? 1;

    // Approximate conversion: AD Year - 57 = BS Year
    int bsYear = year - 57;

    // Approximate month conversion
    int bsMonth = month + 8;
    if (bsMonth > 12) {
      bsMonth -= 12;
      bsYear += 1;
    }

    // Approximate day (same day for simplicity)
    int bsDay = day;

    return {
      'year': bsYear.toString(),
      'month': _nepaliMonths[bsMonth - 1],
      'day': bsDay.toString().padLeft(2, '0'),
    };
  }

  // Simple BS to AD conversion (approximate)
  Map<String, String> _convertBStoAD(String bsYear, String bsMonth, String bsDay) {
    // This is a simplified conversion
    int year = int.tryParse(bsYear) ?? 2080;
    int month = _nepaliMonths.indexOf(bsMonth) + 1;
    int day = int.tryParse(bsDay) ?? 1;

    // Approximate conversion: BS Year + 57 = AD Year
    int adYear = year + 57;

    // Approximate month conversion
    int adMonth = month - 8;
    if (adMonth <= 0) {
      adMonth += 12;
      adYear -= 1;
    }

    // Approximate day (same day for simplicity)
    int adDay = day;

    return {
      'year': adYear.toString(),
      'month': _monthNames[adMonth - 1],
      'day': adDay.toString().padLeft(2, '0'),
    };
  }

  // Time Picker Method
  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTimeOfBirth ?? TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFE64B37),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedTimeOfBirth) {
      setState(() {
        _selectedTimeOfBirth = picked;
        _errors['timeOfBirth'] = '';
      });
    }
  }

  // Format TimeOfDay to HH:MM:SS for API
  String _formatTimeForAPI(TimeOfDay time) {
    final hours = time.hour.toString().padLeft(2, '0');
    final minutes = time.minute.toString().padLeft(2, '0');
    return '$hours:$minutes:00';
  }

  // Format TimeOfDay for display
  String _formatTimeForDisplay(TimeOfDay time) {
    final hour = time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  // Month conversion function for AD
  String _getMonthNumber(String monthName) {
    final months = {
      'January': '01', 'February': '02', 'March': '03', 'April': '04',
      'May': '05', 'June': '06', 'July': '07', 'August': '08',
      'September': '09', 'October': '10', 'November': '11', 'December': '12'
    };
    return months[monthName] ?? '01';
  }

  // Validation methods
  bool _validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      _errors[fieldName] = 'This field is required';
      return false;
    }
    _errors[fieldName] = '';
    return true;
  }

  bool _validateForm() {
    bool isValid = true;

    // Clear all errors
    _errors.forEach((key, value) {
      _errors[key] = '';
    });

    // Validate horoscope belief
    if (!_validateRequired(_horoscopeBelief, 'horoscopeBelief')) {
      isValid = false;
    }

    // If belief is "Yes", validate all fields
    if (_horoscopeBelief == 'Yes') {
      if (!_validateRequired(_selectedCountryOfBirth, 'countryOfBirth')) {
        isValid = false;
      }
      if (!_validateRequired(_selectedCityOfBirth, 'cityOfBirth')) {
        isValid = false;
      }
      if (!_validateRequired(_selectedZodiacSign, 'zodiacSign')) {
        isValid = false;
      }
      if (_selectedTimeOfBirth == null) {
        _errors['timeOfBirth'] = 'Please select time of birth';
        isValid = false;
      } else {
        _errors['timeOfBirth'] = '';
      }
      if (!_validateRequired(_selectedMonth, 'month')) {
        isValid = false;
      }
      if (!_validateRequired(_selectedDay, 'day')) {
        isValid = false;
      }
      if (!_validateRequired(_selectedYear, 'year')) {
        isValid = false;
      }
      if (!_validateRequired(_manglikStatus, 'manglikStatus')) {
        isValid = false;
      }
    }

    setState(() {});
    return isValid;
  }

  // Handler methods
  void _handleHoroscopeBeliefChange(String? value) {
    setState(() {
      _horoscopeBelief = value;
      _errors['horoscopeBelief'] = '';
    });
  }

  void _handleCountryOfBirthChange(String? value) {
    setState(() {
      _selectedCountryOfBirth = value;
      _errors['countryOfBirth'] = '';
    });
  }

  void _handleCityOfBirthChange(String? value) {
    setState(() {
      _selectedCityOfBirth = value;
      _errors['cityOfBirth'] = '';
    });
  }

  void _handleZodiacSignChange(String? value) {
    setState(() {
      _selectedZodiacSign = value;
      _errors['zodiacSign'] = '';
    });
  }

  void _handleMonthChange(String? value) {
    setState(() {
      _selectedMonth = value;
      _errors['month'] = '';
      if (!_isAD) {
        _updateDays();
      }
    });
  }

  void _handleDayChange(String? value) {
    setState(() {
      _selectedDay = value;
      _errors['day'] = '';
    });
  }

  void _handleYearChange(String? value) {
    setState(() {
      _selectedYear = value;
      _errors['year'] = '';
      if (!_isAD) {
        _updateDays();
      }
    });
  }

  void _handleManglikStatusChange(String? value) {
    setState(() {
      _manglikStatus = value;
      _errors['manglikStatus'] = '';
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
                      "HeroScope Details",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE64B37),
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  // Horoscope Belief
                  _buildSectionTitle("Horoscope Belief"),
                  if (submitted && _errors['horoscopeBelief']!.isNotEmpty)
                    _buildErrorText(_errors['horoscopeBelief']!),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildRadioOption(
                          value: "Yes",
                          groupValue: _horoscopeBelief,
                          label: "Yes",
                          onChanged: _handleHoroscopeBeliefChange,
                          hasError: submitted && _errors['horoscopeBelief']!.isNotEmpty,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildRadioOption(
                          value: "No",
                          groupValue: _horoscopeBelief,
                          label: "No",
                          onChanged: _handleHoroscopeBeliefChange,
                          hasError: submitted && _errors['horoscopeBelief']!.isNotEmpty,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildRadioOption(
                          value: "Doesn't matter",
                          groupValue: _horoscopeBelief,
                          label: "Doesn't matter",
                          onChanged: _handleHoroscopeBeliefChange,
                          hasError: submitted && _errors['horoscopeBelief']!.isNotEmpty,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 25),
                  _buildDivider(),
                  const SizedBox(height: 25),

                  if (_horoscopeBelief == 'Yes') ...[
                    _buildSectionTitle("Country Of Birth*"),
                    if (submitted && _errors['countryOfBirth']!.isNotEmpty)
                      _buildErrorText(_errors['countryOfBirth']!),
                    const SizedBox(height: 8),
                    Container(
                      child: TypingDropdown<String>(
                        items: _countryOptions,
                        selectedItem: _selectedCountryOfBirth,
                        itemLabel: (item) => item,
                        hint: "Country Of Birth*",
                        onChanged: _handleCountryOfBirthChange,
                        title: 'Country',
                        showError: submitted && _errors['countryOfBirth']!.isNotEmpty,
                        // errorText: _errors['countryOfBirth'],
                      ),
                    ),

                    const SizedBox(height: 15),

                    // City of Birth
                    _buildSectionTitle("City Of Birth*"),
                    if (submitted && _errors['cityOfBirth']!.isNotEmpty)
                      _buildErrorText(_errors['cityOfBirth']!),
                    const SizedBox(height: 8),
                    Container(
                      child: TypingDropdown<String>(
                        items: _cityOptions,
                        selectedItem: _selectedCityOfBirth,
                        itemLabel: (item) => item,
                        hint: "City Of Birth*",
                        onChanged: _handleCityOfBirthChange,
                        title: 'Cities',
                        showError: submitted && _errors['cityOfBirth']!.isNotEmpty,
                        // errorText: _errors['cityOfBirth'],
                      ),
                    ),

                    const SizedBox(height: 15),

                    // Zodiac Sign
                    _buildSectionTitle("Zodiac Sign*"),
                    if (submitted && _errors['zodiacSign']!.isNotEmpty)
                      _buildErrorText(_errors['zodiacSign']!),
                    const SizedBox(height: 8),
                    Container(
                      child: TypingDropdown<String>(
                        items: _zodiacSignOptions,
                        selectedItem: _selectedZodiacSign,
                        itemLabel: (item) => item,
                        hint: "Zodiac Sign*",
                        onChanged: _handleZodiacSignChange,
                        title: 'Zodiac Sign',
                        showError: submitted && _errors['zodiacSign']!.isNotEmpty,
                        // errorText: _errors['zodiacSign'],
                      ),
                    ),

                    const SizedBox(height: 15),

                    // Time of Birth
                    _buildSectionTitle("Time Of Birth*"),
                    if (submitted && _errors['timeOfBirth']!.isNotEmpty)
                      _buildErrorText(_errors['timeOfBirth']!),
                    const SizedBox(height: 8),
                    _buildTimePicker(),

                    const SizedBox(height: 25),
                    _buildDivider(),
                    const SizedBox(height: 25),

                    // Date of Birth
                    _buildSectionTitle("Date Of Birth*"),
                    const SizedBox(height: 12),

                    // AD/BS Toggle
                    Row(
                      children: [
                        _buildDateTypeOption(
                          value: true,
                          groupValue: _isAD,
                          label: "AD",
                          onChanged: (value) {
                            setState(() {
                              _isAD = value;
                              if (!_isAD && _selectedMonth != null && _selectedDay != null && _selectedYear != null) {
                                // Convert AD to BS
                                final converted = _convertADtoBS(_selectedYear!, _selectedMonth!, _selectedDay!);
                                _selectedYear = converted['year'];
                                _selectedMonth = converted['month'];
                                _selectedDay = converted['day'];
                                _updateDays();
                              }
                            });
                          },
                        ),
                        const SizedBox(width: 20),
                        _buildDateTypeOption(
                          value: false,
                          groupValue: _isAD,
                          label: "BS",
                          onChanged: (value) {
                            setState(() {
                              _isAD = value;
                              if (!_isAD) {
                                // Initialize BS values if not set
                                if (_selectedMonth == null || !_nepaliMonths.contains(_selectedMonth)) {
                                  _selectedMonth = _nepaliMonths.first;
                                }
                                if (_selectedYear == null || !_nepaliYears.contains(_selectedYear)) {
                                  _selectedYear = '2080';
                                }
                                _updateDays();
                              } else if (_isAD && _selectedMonth != null && _selectedDay != null && _selectedYear != null) {
                                // Convert BS to AD if possible
                                if (_nepaliMonths.contains(_selectedMonth!) && _nepaliYears.contains(_selectedYear!)) {
                                  final converted = _convertBStoAD(_selectedYear!, _selectedMonth!, _selectedDay!);
                                  _selectedYear = converted['year'];
                                  _selectedMonth = converted['month'];
                                  _selectedDay = converted['day'];
                                }
                              }
                            });
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 15),

                    // Month, Day, Year Row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionTitle("Month*"),
                              if (submitted && _errors['month']!.isNotEmpty)
                                _buildErrorText(_errors['month']!),
                              const SizedBox(height: 8),
                              Container(
                                child: TypingDropdown<String>(
                                  items: _isAD ? _monthNames : _nepaliMonths,
                                  selectedItem: _selectedMonth,
                                  itemLabel: (item) => item,
                                  hint: "Month*",
                                  onChanged: _handleMonthChange,
                                  title: 'Month',
                                  showError: submitted && _errors['month']!.isNotEmpty,
                                  // errorText: _errors['month'],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionTitle("Day*"),
                              if (submitted && _errors['day']!.isNotEmpty)
                                _buildErrorText(_errors['day']!),
                              const SizedBox(height: 8),
                              Container(
                                child: TypingDropdown<String>(
                                  items: _isAD ? _dayOptions : _nepaliDays,
                                  selectedItem: _selectedDay,
                                  itemLabel: (item) => item,
                                  hint: "Day*",
                                  onChanged: _handleDayChange,
                                  title: 'Days',
                                  showError: submitted && _errors['day']!.isNotEmpty,
                                  // errorText: _errors['day'],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionTitle("Year*"),
                              if (submitted && _errors['year']!.isNotEmpty)
                                _buildErrorText(_errors['year']!),
                              const SizedBox(height: 8),
                              Container(
                                child: TypingDropdown<String>(
                                  items: _isAD ? _yearOptions : _nepaliYears,
                                  selectedItem: _selectedYear,
                                  itemLabel: (item) => item,
                                  hint: "Year*",
                                  onChanged: _handleYearChange,
                                  title: 'Years',
                                  showError: submitted && _errors['year']!.isNotEmpty,
                                  // errorText: _errors['year'],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Display converted date info
                    if (_selectedMonth != null && _selectedDay != null && _selectedYear != null) ...[
                      const SizedBox(height: 15),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info,
                              color: Colors.blue[700],
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _isAD
                                    ? "Selected: $_selectedMonth $_selectedDay, $_selectedYear AD"
                                    : "Selected: $_selectedMonth $_selectedDay, $_selectedYear BS",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 25),
                    _buildDivider(),
                    const SizedBox(height: 25),

                    // Manglik Status
                    _buildSectionTitle("Manglik*"),
                    if (submitted && _errors['manglikStatus']!.isNotEmpty)
                      _buildErrorText(_errors['manglikStatus']!),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildRadioOption(
                            value: "Yes",
                            groupValue: _manglikStatus,
                            label: "Yes",
                            onChanged: _handleManglikStatusChange,
                            hasError: submitted && _errors['manglikStatus']!.isNotEmpty,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildRadioOption(
                            value: "No",
                            groupValue: _manglikStatus,
                            label: "No",
                            onChanged: _handleManglikStatusChange,
                            hasError: submitted && _errors['manglikStatus']!.isNotEmpty,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildRadioOption(
                            value: "Doesn't matter",
                            groupValue: _manglikStatus,
                            label: "Doesn't matter",
                            onChanged: _handleManglikStatusChange,
                            hasError: submitted && _errors['manglikStatus']!.isNotEmpty,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                  ],

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
              child: _progressBubble(0.75, "75%"),
            ),

            Positioned(
              left: 18,
              top: 10,
              child: GestureDetector(
                onTap: isLoading ? null : () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => LifestylePage()));
                },
                child: Container(
                  height: 30,
                  width: 80,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Center(
                    child: Text(
                      'Skip',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
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

  // Time Picker Widget
  Widget _buildTimePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _selectTime,
          child: Container(
            height: 55,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: submitted && _errors['timeOfBirth']!.isNotEmpty
                    ? Colors.red
                    : const Color(0xFF48A54C),
                width: 1.6,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedTimeOfBirth != null
                        ? _formatTimeForDisplay(_selectedTimeOfBirth!)
                        : "Select Time (e.g., 09:41 AM)",
                    style: TextStyle(
                      fontSize: 16,
                      color: _selectedTimeOfBirth != null ? Colors.black87 : Colors.black54,
                    ),
                  ),
                ),
                Icon(
                  Icons.access_time,
                  color: const Color(0xFFE64B37),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (submitted && _errors['timeOfBirth']!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              _errors['timeOfBirth']!,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ),
      ],
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
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateTypeOption({
    required bool value,
    required bool groupValue,
    required String label,
    required Function(bool) onChanged,
  }) {
    bool isSelected = groupValue == value;

    return Expanded(
      child: Container(
        height: 45,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF48A54C),
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 18,
                    height: 18,
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
                      size: 8,
                      color: Colors.white,
                    )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
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
            decoration: BoxDecoration(
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

    await _submitAstrologicData();

    setState(() {
      isLoading = false;
    });
  }

_submitAstrologicData() async {
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

      // Prepare POST data
      Map<String, String> postData = {
        "userid": userId.toString(),
        "belief": _horoscopeBelief ?? "",
      };

      // Format data properly for API
      if (_horoscopeBelief == 'Yes') {
        // Format birth date to YYYY-MM-DD (API expects this format)
        String birthDate;
        if (_isAD) {
          // AD Date
          String monthNumber = _getMonthNumber(_selectedMonth!);
          birthDate = "${_selectedYear}-${monthNumber.padLeft(2, '0')}-${_selectedDay!.padLeft(2, '0')}";
        } else {
          // BS Date - We need to convert to AD for API
          final converted = _convertBStoAD(_selectedYear!, _selectedMonth!, _selectedDay!);
          String monthNumber = _getMonthNumber(converted['month']!);
          birthDate = "${converted['year']}-${monthNumber.padLeft(2, '0')}-${converted['day']!.padLeft(2, '0')}";
        }

        // Format time to HH:MM:SS (API expects this format)
        String formattedTime = _formatTimeForAPI(_selectedTimeOfBirth!);

        postData.addAll({
          "birthcountry": _selectedCountryOfBirth ?? "",
          "birthcity": _selectedCityOfBirth ?? "",
          "zodiacsign": _selectedZodiacSign ?? "",
          "birthtime": formattedTime,
          "birthdate": birthDate,
          "manglik": _manglikStatus ?? "",
        });

        // Debug info
        print("Birth Date being sent: $birthDate");
        print("Is AD: $_isAD");
        print("Selected Month: $_selectedMonth");
        print("Selected Day: $_selectedDay");
        print("Selected Year: $_selectedYear");
      } else {
        // For "No" or "Doesn't matter", send empty strings for other fields
        postData.addAll({
          "birthcountry": "",
          "birthcity": "",
          "zodiacsign": "",
          "birthtime": "",
          "birthdate": "",
          "manglik": "",
        });
      }

      // Debug print
      print("Sending to API: $postData");

      // Send POST request with better error handling
      final response = await http.post(
        Uri.parse("https://digitallami.com/Api2/user_astrologic.php"),
        body: postData,
      ).timeout(const Duration(seconds: 30));

      print("Raw response: ${response.body}");

      // Check if response is valid JSON
      final decodedResponse = json.decode(response.body);

      if (decodedResponse['status'] == 'success') {
        bool updated = await UpdateService.updatePageNumber(
          userId: userId.toString(),
          pageNo: 6,
        );

        if (updated) {
          _showSuccess("Astrologic details saved successfully!");
          // Navigate after a short delay
          Future.delayed(const Duration(seconds: 1), () {
            Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => LifestylePage())
            );
          });
        } else {
          _showError("Failed to update progress");
        }
      } else {
        _showError(decodedResponse['message'] ?? "Failed to save details");
      }
    } on FormatException catch (e) {
      print("JSON Format Error: $e");
      _showError("Server response format error. Please try again.");
    } on http.ClientException catch (e) {
      print("Network Error: $e");
      _showError("Network error. Please check your connection.");
    } on TimeoutException catch (e) {
      print("Timeout Error: $e");
      _showError("Request timeout. Please try again.");
    } catch (e) {
      print("Unexpected Error: $e");
      _showError("An unexpected error occurred: $e");
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
}