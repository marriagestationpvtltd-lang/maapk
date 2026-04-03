import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ms2026/Auth/Screen/signupscreen8.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../ReUsable/dropdownwidget.dart';
import '../../ReUsable/registration_progress.dart';
import '../../ReUsable/enhanced_form_fields.dart';
import '../../constant/app_colors.dart';
import '../../service/updatepage.dart';

class AstrologicDetailsPage extends StatefulWidget {
  const AstrologicDetailsPage({super.key});

  @override
  State<AstrologicDetailsPage> createState() => _AstrologicDetailsPageState();
}

class _AstrologicDetailsPageState extends State<AstrologicDetailsPage> with SingleTickerProviderStateMixin {
  bool submitted = false;
  bool isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

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
    // Set Nepal as default country
    _selectedCountryOfBirth = 'Nepal';
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
              primary: AppColors.primary,
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RegistrationStepContainer(
          onBack: () => Navigator.pop(context),
          onContinue: _validateAndSubmit,
          isLoading: isLoading,
          canContinue: !isLoading,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                RegistrationStepHeader(
                  title: 'Astrological Details',
                  subtitle: 'Share your horoscope and birth details for better compatibility',
                  currentStep: 8,
                  totalSteps: 11,
                  onBack: () => Navigator.pop(context),
                ),
                const SizedBox(height: 32),

                // Skip Button
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: isLoading ? null : _skipPage,
                    icon: const Icon(Icons.skip_next, size: 18),
                    label: const Text('Skip this step'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Horoscope Belief Section
                const SectionHeader(
                  title: 'Horoscope Belief',
                  subtitle: 'Do you believe in horoscope matching?',
                  icon: Icons.auto_awesome_rounded,
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: EnhancedRadioOption<String>(
                        label: 'Yes',
                        value: 'Yes',
                        groupValue: _horoscopeBelief,
                        onChanged: _handleHoroscopeBeliefChange,
                        icon: Icons.check_circle_outline,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: EnhancedRadioOption<String>(
                        label: 'No',
                        value: 'No',
                        groupValue: _horoscopeBelief,
                        onChanged: _handleHoroscopeBeliefChange,
                        icon: Icons.cancel_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: EnhancedRadioOption<String>(
                        label: 'Doesn\'t matter',
                        value: 'Doesn\'t matter',
                        groupValue: _horoscopeBelief,
                        onChanged: _handleHoroscopeBeliefChange,
                        icon: Icons.help_outline,
                      ),
                    ),
                  ],
                ),
                if (submitted && _errors['horoscopeBelief']!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildErrorText(_errors['horoscopeBelief']!),
                ],

                // Show details only if belief is "Yes"
                if (_horoscopeBelief == 'Yes') ...[
                  const SizedBox(height: 32),

                  // Birth Location Section
                  const SectionHeader(
                    title: 'Birth Location',
                    subtitle: 'Where were you born?',
                    icon: Icons.location_on_outlined,
                  ),
                  const SizedBox(height: 20),

                  EnhancedDropdown<String>(
                    label: 'Country of Birth',
                    value: _selectedCountryOfBirth,
                    items: _countryOptions,
                    itemLabel: (item) => item,
                    hint: 'Select your birth country',
                    onChanged: _handleCountryOfBirthChange,
                    hasError: submitted && _errors['countryOfBirth']!.isNotEmpty,
                    errorText: _errors['countryOfBirth'],
                    isRequired: true,
                  ),
                  const SizedBox(height: 16),

                  EnhancedDropdown<String>(
                    label: 'City of Birth',
                    value: _selectedCityOfBirth,
                    items: _cityOptions,
                    itemLabel: (item) => item,
                    hint: 'Select your birth city',
                    onChanged: _handleCityOfBirthChange,
                    hasError: submitted && _errors['cityOfBirth']!.isNotEmpty,
                    errorText: _errors['cityOfBirth'],
                    isRequired: true,
                  ),
                  const SizedBox(height: 32),

                  // Birth Date & Time Section
                  const SectionHeader(
                    title: 'Birth Date & Time',
                    subtitle: 'When were you born?',
                    icon: Icons.calendar_today_outlined,
                  ),
                  const SizedBox(height: 20),

                  // Date Type Toggle (AD/BS)
                  _buildFieldLabel('Date Type', isRequired: true),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: EnhancedRadioOption<bool>(
                          label: 'AD (Anno Domini)',
                          value: true,
                          groupValue: _isAD,
                          onChanged: (value) {
                            setState(() {
                              _isAD = value!;
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
                          icon: Icons.calendar_month,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: EnhancedRadioOption<bool>(
                          label: 'BS (Bikram Sambat)',
                          value: false,
                          groupValue: _isAD,
                          onChanged: (value) {
                            setState(() {
                              _isAD = value!;
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
                          icon: Icons.event_note,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Date Fields
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: EnhancedDropdown<String>(
                          label: 'Month',
                          value: _selectedMonth,
                          items: _isAD ? _monthNames : _nepaliMonths,
                          itemLabel: (item) => item,
                          hint: 'Month',
                          onChanged: _handleMonthChange,
                          hasError: submitted && _errors['month']!.isNotEmpty,
                          errorText: _errors['month'],
                          isRequired: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: EnhancedDropdown<String>(
                          label: 'Day',
                          value: _selectedDay,
                          items: _isAD ? _dayOptions : _nepaliDays,
                          itemLabel: (item) => item,
                          hint: 'Day',
                          onChanged: _handleDayChange,
                          hasError: submitted && _errors['day']!.isNotEmpty,
                          errorText: _errors['day'],
                          isRequired: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TypingDropdown<String>(
                          title: 'Year',
                          selectedItem: _selectedYear,
                          items: _isAD ? _yearOptions : _nepaliYears,
                          itemLabel: (item) => item,
                          hint: 'Year',
                          showError: submitted,
                          onChanged: _handleYearChange,
                        ),
                      ),
                    ],
                  ),

                  // Display selected date
                  if (_selectedMonth != null && _selectedDay != null && _selectedYear != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _isAD
                                  ? "Birth Date: $_selectedMonth $_selectedDay, $_selectedYear AD"
                                  : "Birth Date: $_selectedMonth $_selectedDay, $_selectedYear BS",
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Time of Birth
                  _buildFieldLabel('Time of Birth', isRequired: true),
                  const SizedBox(height: 12),
                  _buildTimePicker(),

                  const SizedBox(height: 32),

                  // Zodiac Details Section
                  const SectionHeader(
                    title: 'Zodiac Details',
                    subtitle: 'Your astrological information',
                    icon: Icons.stars_rounded,
                  ),
                  const SizedBox(height: 20),

                  EnhancedDropdown<String>(
                    label: 'Zodiac Sign',
                    value: _selectedZodiacSign,
                    items: _zodiacSignOptions,
                    itemLabel: (item) => item,
                    hint: 'Select your zodiac sign',
                    onChanged: _handleZodiacSignChange,
                    hasError: submitted && _errors['zodiacSign']!.isNotEmpty,
                    errorText: _errors['zodiacSign'],
                    isRequired: true,
                    prefixIcon: Icons.auto_awesome,
                  ),
                  const SizedBox(height: 20),

                  // Manglik Status
                  _buildFieldLabel('Manglik Status', isRequired: true),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: EnhancedRadioOption<String>(
                          label: 'Yes',
                          value: 'Yes',
                          groupValue: _manglikStatus,
                          onChanged: _handleManglikStatusChange,
                          icon: Icons.check_circle_outline,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: EnhancedRadioOption<String>(
                          label: 'No',
                          value: 'No',
                          groupValue: _manglikStatus,
                          onChanged: _handleManglikStatusChange,
                          icon: Icons.cancel_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: EnhancedRadioOption<String>(
                          label: 'Doesn\'t matter',
                          value: 'Doesn\'t matter',
                          groupValue: _manglikStatus,
                          onChanged: _handleManglikStatusChange,
                          icon: Icons.help_outline,
                        ),
                      ),
                    ],
                  ),
                  if (submitted && _errors['manglikStatus']!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildErrorText(_errors['manglikStatus']!),
                  ],
                ],

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimePicker() {
    return InkWell(
      onTap: _selectTime,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: submitted && _errors['timeOfBirth']!.isNotEmpty
                ? AppColors.error
                : AppColors.border,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: submitted && _errors['timeOfBirth']!.isNotEmpty
                  ? AppColors.error.withOpacity(0.1)
                  : AppColors.shadowLight,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              Icons.access_time_rounded,
              color: _selectedTimeOfBirth != null
                  ? AppColors.primary
                  : AppColors.textSecondary,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedTimeOfBirth != null
                    ? _formatTimeForDisplay(_selectedTimeOfBirth!)
                    : "Select time of birth",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: _selectedTimeOfBirth != null
                      ? FontWeight.w500
                      : FontWeight.w400,
                  color: _selectedTimeOfBirth != null
                      ? AppColors.textPrimary
                      : AppColors.textHint,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.textSecondary,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
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
    );
  }

  Widget _buildErrorText(String error) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            size: 14,
            color: AppColors.error,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _skipPage() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.primary),
              SizedBox(width: 12),
              Text(
                "Skip Astrological Details?",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: const Text(
            "You can fill in your astrological details later from your profile settings.",
            style: TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Cancel",
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LifestylePage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                "Skip",
                style: TextStyle(color: AppColors.white),
              ),
            ),
          ],
        );
      },
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
          _showSuccess("Astrological details saved successfully!");
          // Navigate after a short delay
          Future.delayed(const Duration(seconds: 1), () {
            Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LifestylePage())
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
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: AppColors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
