import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:ms2026/Auth/Screen/signupscreen5.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../ReUsable/dropdownwidget.dart';
import '../../service/location_service.dart';
import '../../service/updatepage.dart';

class LivingStatusPage extends StatefulWidget {
  const LivingStatusPage({super.key});

  @override
  State<LivingStatusPage> createState() => _LivingStatusPageState();
}

class _LivingStatusPageState extends State<LivingStatusPage> {
  bool submitted = false;

  // Form variables
  String? _selectedPermanentCountry;
  String? _selectedPermanentState;
  String? _selectedPermanentCity;
  final TextEditingController _permanentToleController = TextEditingController();

  String? _selectedResidentialStatus;
  bool _sameAsPermanent = false;

  String? _selectedTemporaryCountry;
  String? _selectedTemporaryState;
  String? _selectedTemporaryCity;
  final TextEditingController _temporaryToleController = TextEditingController();

  String? _selectedResidentialStatus2;
  bool? _willingToGoAbroad;
  String? _selectedVisaStatus;

  bool _isGettingLocation = false;

  // Add this function inside your _LivingStatusPageState class
  Future<void> _submitAddress() async {
    // Show loading
    setState(() {
      _isGettingLocation = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');
      final userData = jsonDecode(userDataString!);
      final userId = int.tryParse(userData["id"].toString());
      // Prepare the data - ensure no null values are sent as empty strings
      Map<String, String> body = {
        'userid': userId.toString(), // Replace with actual user ID

        // Current Address
        'current_country': _selectedTemporaryCountry.toString(),
        'current_state': _selectedTemporaryState ?? '',
        'current_city': _selectedTemporaryCity ?? '',
        'current_tole': _temporaryToleController.text.isNotEmpty
            ? _temporaryToleController.text
            : 'Not specified',
        'current_residentalstatus': _selectedResidentialStatus2 ?? 'Own House',
        'current_willingtogoabroad': _willingToGoAbroad == true ? '1' : '0',
        'current_visastatus': _willingToGoAbroad == true
            ? (_selectedVisaStatus ?? 'No Visa')
            : 'No Visa',

        // Permanent Address - ensure these are not null
        'permanent_country': _selectedPermanentCountry ?? 'Nepal',
        'permanent_state': _selectedPermanentState ?? '',
        'permanent_city': _selectedPermanentCity ?? '',
        'permanent_tole': _permanentToleController.text.isNotEmpty
            ? _permanentToleController.text
            : 'Not specified',
        'permanent_residentalstatus': _selectedResidentialStatus ?? 'Own House',
      };

      // Log the request for debugging
      print('Sending request with body: $body');

      final response = await http.post(
        Uri.parse('https://digitallami.com/Api2/updateadress.php'),
        body: body,
      ).timeout(const Duration(seconds: 30));

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          bool updated = await UpdateService.updatePageNumber(
            userId: userId.toString(),     // <-- pass real user ID
            pageNo: 3,        // <-- page you want to update
          );

          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => FamilyDetailsPage()),
          );
        } else {
          _showError(data['message'] ?? 'Failed to save addresses');
        }
      } else {
        _showError('Server error: ${response.statusCode}');
      }
    } on http.ClientException catch (e) {
      print('HTTP Client Exception: $e');
      _showError('Network error: Please check your internet connection');
    } on SocketException catch (e) {
      print('Socket Exception: $e');
      _showError('Network error: Cannot connect to server');
    } on TimeoutException catch (e) {
      print('Timeout Exception: $e');
      _showError('Request timeout: Please try again');
    } catch (e) {
      print('Unexpected Error: $e');
      _showError('Failed to submit. Please try again.');
    } finally {
      setState(() {
        _isGettingLocation = false;
      });
    }
  }

  // Sample data for dropdowns
  List<String> _countryOptions = [];
  Map<String, int> _countryMap = {};

  List<String> _stateOptions = [];
  Map<String, int> _stateMap = {};


  List<String> _cityOptions = [];
  Map<String, int> _cityMap = {};

  final List<String> _residentialStatusOptions = [
    'Own House',
    'Rented',
    'With Family',
    'Hostel',
    'Other'
  ];

  final List<String> _visaStatusOptions = [
    'No Visa',
    'Tourist Visa',
    'Student Visa',
    'Work Visa',
    'Permanent Residence',
    'Citizenship'
  ];

  @override
  void initState() {
    super.initState();
    // Set default country to Nepal
    _selectedPermanentCountry;
    _selectedTemporaryCountry;
    loadCountries();
  }
  Future<void> loadCountries() async {
    final data = await LocationService.fetchCountries();

    _countryOptions.clear();
    _countryMap.clear();

    for (var item in data) {
      final name = item['name'];
      final id = int.parse(item['id'].toString());

      _countryOptions.add(name);
      _countryMap[name] = id;
    }

    setState(() {});
  }


  // Function to get current location
  Future<void> _getCurrentLocation(TextEditingController controller) async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError('Location permissions are denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showError('Location permissions are permanently denied, we cannot request permissions.');
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get address from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks.first;

        // Build address string
        String address = '';
        if (placemark.street != null && placemark.street!.isNotEmpty) {
          address = placemark.street!;
        } else if (placemark.name != null && placemark.name!.isNotEmpty) {
          address = placemark.name!;
        }

        if (placemark.locality != null && placemark.locality!.isNotEmpty) {
          address += address.isNotEmpty ? ', ${placemark.locality}' : placemark.locality!;
        }

        if (placemark.subAdministrativeArea != null && placemark.subAdministrativeArea!.isNotEmpty) {
          address += address.isNotEmpty ? ', ${placemark.subAdministrativeArea}' : placemark.subAdministrativeArea!;
        }

        // Update the controller with the detected address
        controller.text = address;

        // Also update dropdowns if they match our options
        if (placemark.country != null) {
          if (_countryOptions.contains(placemark.country)) {
            setState(() {
              _selectedTemporaryCountry = placemark.country;
            });
          }
        }

        if (placemark.administrativeArea != null) {
          // Try to match state/province
          String state = placemark.administrativeArea!;
          for (String option in _stateOptions) {
            if (state.toLowerCase().contains(option.toLowerCase()) ||
                option.toLowerCase().contains(state.toLowerCase())) {
              setState(() {
                _selectedTemporaryState = option;
              });
              break;
            }
          }
        }

        if (placemark.locality != null) {
          // Try to match city
          String city = placemark.locality!;
          for (String option in _cityOptions) {
            if (city.toLowerCase().contains(option.toLowerCase()) ||
                option.toLowerCase().contains(city.toLowerCase())) {
              setState(() {
                _selectedTemporaryCity = option;
              });
              break;
            }
          }
        }

        _showSuccess('Location detected successfully!');
      }
    } catch (e) {
      print('Error getting location: $e');
      _showError('Failed to get location. Please check your GPS and try again.');
    } finally {
      setState(() {
        _isGettingLocation = false;
      });
    }
  }

  Future<void> loadStates(int countryId) async {
    final data = await LocationService.fetchStates(countryId);

    _stateOptions.clear();
    _stateMap.clear();

    for (var item in data) {
      final name = item['name'];
      final id = int.parse(item['id'].toString());

      _stateOptions.add(name);
      _stateMap[name] = id;
    }

    setState(() {});
  }

  Future<void> loadCities(int stateId) async {
    print("Loading cities for stateId: $stateId");

    final data = await LocationService.fetchCities(stateId);

    final List<String> newCityOptions = [];
    final Map<String, int> newCityMap = {};

    for (var item in data) {
      final name = item['name'];
      final id = int.parse(item['id'].toString());

      newCityOptions.add(name);
      newCityMap[name] = id;
    }

    setState(() {
      _cityOptions = newCityOptions;
      _cityMap = newCityMap;
    });

    print("Cities loaded: ${_cityOptions.length}");
  }


  @override
  Widget build(BuildContext context) {
    final bool hasError =
       submitted && _permanentToleController.text.isEmpty && _temporaryToleController.text.isEmpty;
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
                      "Living Status",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE64B37),
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  // ================= CURRENT ADDRESS SECTION (NOW ON TOP) =================
                  _buildSectionTitle("Current Address*"),
                  const SizedBox(height: 12),

                  // Country (Nepal*)
                  _buildSectionTitle("Country*"),
                  Container(
                    child: TypingDropdown<String>(
                      items: _countryOptions,
                      selectedItem: _selectedTemporaryCountry,
                      itemLabel: (item) => item,
                      hint: "Select Country",
                      title: 'Countries',
                      showError: submitted,
                      onChanged: (value) async {
                        setState(() {
                          _selectedTemporaryCountry = value;
                          _selectedTemporaryState = null;
                          _selectedTemporaryCity = null;

                          _stateOptions.clear();
                          _cityOptions.clear();
                        });

                        if (value != null) {
                          final countryId = _countryMap[value]!;
                          await loadStates(countryId);
                        }
                      },
                    ),
                  ),


                  const SizedBox(height: 15),

                  // State/Province and City Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle("State / Province*"),
                            const SizedBox(height: 8),
                            Container(
                              child: TypingDropdown<String>(
                                items: _stateOptions,
                                selectedItem: _selectedTemporaryState,
                                itemLabel: (item) => item,
                                hint: "Select State",
                                onChanged: (value) async {
                                  print("Selected state: $value");

                                  setState(() {
                                    _selectedTemporaryState = value;
                                    _selectedTemporaryCity = null;
                                    _cityOptions.clear();
                                  });

                                  if (value != null && _stateMap.containsKey(value)) {
                                    final stateId = _stateMap[value]!;
                                    print("State ID: $stateId");

                                    await loadCities(stateId);
                                  } else {
                                    print("❌ State ID not found in map");
                                  }
                                },
                                title: 'States', showError: submitted,
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
                            _buildSectionTitle("City*"),
                            const SizedBox(height: 8),
                            Container(
                              child: TypingDropdown<String>(
                                items: _cityOptions,
                                selectedItem: _selectedTemporaryCity,
                                itemLabel: (item) => item,
                                hint: "Select City",
                                onChanged: (value) {
                                  setState(() {
                                    _selectedTemporaryCity = value;
                                  });
                                }, title: 'Cities', showError: submitted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),

                  // Tole, Landmark with GPS icon
                  _buildSectionTitle("Tole, Landmark......"),
                  const SizedBox(height: 8),
                  _buildTextFieldWithGPS(


                    _temporaryToleController,
                    "Enter your tole, landmark",
                    onGPSTap: () => _getCurrentLocation(_temporaryToleController),
                  ),
                  if (hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 8),
                      child: Text(
                        "Please select Tole Landmark",
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ),

                  const SizedBox(height: 25),

                  // Current Residential Status Section
                  _buildSectionTitle("Residential Status*"),
                  const SizedBox(height: 8),
                  Container(
                    child: TypingDropdown<String>(
                      items: _residentialStatusOptions,
                      selectedItem: _selectedResidentialStatus2,
                      itemLabel: (item) => item,
                      hint: "Select Residential Status",
                      onChanged: (value) {
                        setState(() {
                          _selectedResidentialStatus2 = value;
                        });
                      }, title: 'Residental Status', showError: submitted,
                    ),
                  ),

                  const SizedBox(height: 25),

                  // Willing to go abroad section
                  _buildSectionTitle("Willing To Go To Abroad?"),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildRadioOption(
                          value: true,
                          groupValue: _willingToGoAbroad,
                          label: "Yes",
                          onChanged: (value) {
                            setState(() {
                              _willingToGoAbroad = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildRadioOption(
                          value: false,
                          groupValue: _willingToGoAbroad,
                          label: "No",
                          onChanged: (value) {
                            setState(() {
                              _willingToGoAbroad = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Visa Status (only show if willing to go abroad is Yes)
                  if (_willingToGoAbroad == true) ...[
                    _buildSectionTitle("Visa Status*"),
                    const SizedBox(height: 8),
                    Container(
                      child: TypingDropdown<String>(
                        items: _visaStatusOptions,
                        selectedItem: _selectedVisaStatus,
                        itemLabel: (item) => item,
                        hint: "Select Visa Status",
                        onChanged: (value) {
                          setState(() {
                            _selectedVisaStatus = value;
                          });
                        }, title: 'Visa Status', showError: submitted,
                      ),
                    ),


                    const SizedBox(height: 15),
                  ],

                  const SizedBox(height: 20),
                  _buildDivider(),
                  const SizedBox(height: 30),

                  // ================= PERMANENT ADDRESS SECTION (NOW ON BOTTOM) =================
                  _buildSectionTitle("Permanent Address*"),
                  const SizedBox(height: 8),

                  // Same as current address checkbox
                  Row(
                    children: [
                      Checkbox(
                        value: _sameAsPermanent,
                        onChanged: (value) {
                          setState(() {
                            _sameAsPermanent = value ?? false;
                            if (_sameAsPermanent) {
                              _copyCurrentToPermanent();
                            }
                          });
                        },
                        activeColor: const Color(0xFFE64B37),
                      ),
                      const Text(
                        "Same As Current Address",
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),

                  if (!_sameAsPermanent) ...[
                    // Country (Nepal*)
                    _buildSectionTitle("Country*"),
                    const SizedBox(height: 8),
                    Container(
                      child: TypingDropdown<String>(
                        items: _countryOptions,
                        selectedItem: _selectedPermanentCountry,
                        itemLabel: (item) => item,
                        hint: "Select Country",
                        onChanged: (value) async {
                          setState(() {
                            _selectedPermanentCountry = value;
                          });

                          if (value != null) {
                            final countryId = _countryMap[value]!;
                            await loadStates(countryId);
                          }
                        },

                        title: 'Country', showError: submitted,
                      ),
                    ),

                    const SizedBox(height: 15),

                    // State/Province and City Row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionTitle("State / Province*"),
                              const SizedBox(height: 8),
                              Container(
                                child: TypingDropdown<String>(
                                  items: _stateOptions,
                                  selectedItem: _selectedPermanentState,
                                  itemLabel: (item) => item,
                                  hint: "Select State",
                                  onChanged: (value) async {
                                    setState(() {
                                      _selectedPermanentState = value;
                                    });

                                    if (value != null && _stateMap.containsKey(value)) {
                                      final stateId = _stateMap[value]!;
                                      print("State ID: $stateId");

                                      await loadCities(stateId);
                                    } else {
                                      print("❌ State ID not found in map");
                                    }
                                  }, title: 'States', showError: submitted,
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
                              _buildSectionTitle("City*"),
                              const SizedBox(height: 8),
                              Container(
                                child: TypingDropdown<String>(
                                  items: _cityOptions,
                                  selectedItem: _selectedPermanentCity,
                                  itemLabel: (item) => item,
                                  hint: "Select City",
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedPermanentCity = value;
                                    });
                                  }, title: 'Cities', showError: submitted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 15),

                    // Tole, Landmark with GPS icon
                    _buildSectionTitle("Tole, Landmark......"),
                    const SizedBox(height: 8),
                    _buildTextFieldWithGPS(
                      _permanentToleController,
                      "Enter your tole, landmark",
                      onGPSTap: () => _getCurrentLocation(_permanentToleController),
                    ),
                  ],
                  if (hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 8),
                      child: Text(
                        "Please select Tole Landmark",
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ),

                  const SizedBox(height: 25),
                  _buildDivider(),
                  const SizedBox(height: 25),

                  // Permanent Residential Status Section
                  _buildSectionTitle("Residential Status*"),
                  const SizedBox(height: 8),
                  Container(
                    child: TypingDropdown<String>(
                      items: _residentialStatusOptions,
                      selectedItem: _selectedResidentialStatus,
                      itemLabel: (item) => item,
                      hint: "Select Residential Status",
                      onChanged: (value) {
                        setState(() {
                          _selectedResidentialStatus = value;
                        });
                      }, title: 'Residental Status', showError: submitted,
                    ),
                  ),

                  const SizedBox(height: 35),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: _buildButton(
                          text: "Previous",
                          isPrimary: false,
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                      ),
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
            Positioned(
              right: 12,
              top: 8,
              child: _progressBubble(0.20, "40%"),
            ),

            // Loading overlay
            if (_isGettingLocation)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE64B37)),
                      ),
                      SizedBox(height: 16),
                      Text(
                        "Detecting your location...",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextFieldWithGPS(

      TextEditingController controller,
      String hintText, {
        required VoidCallback onGPSTap,
      }) {
    final bool hasError =
        submitted && _permanentToleController.text.isEmpty && _temporaryToleController.text.isEmpty;
    return Container(
      height: 55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border:
        Border.all(
          color: submitted
              ? Colors.red
              : controller.text.isEmpty
              ? Colors.black
              : Colors.green,
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: TextField(
                readOnly: true,
                controller: controller,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: hintText,
                  hintStyle: const TextStyle(fontSize: 16, color: Colors.black54),
                ),
              ),
            ),
          ),
          Container(
            width: 50,
            height: 55,
            decoration: BoxDecoration(
              color: const Color(0xFFE64B37).withOpacity(0.1),
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(15),
              ),
            ),
            child: IconButton(
              icon: _isGettingLocation
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE64B37)),
                ),
              )
                  : const Icon(
                Icons.gps_fixed,
                color: Color(0xFFE64B37),
                size: 20,
              ),
              onPressed: _isGettingLocation ? null : onGPSTap,
            ),
          ),


        ],
      ),
    );

  }

  void _copyCurrentToPermanent() {
    setState(() {
      _selectedPermanentCountry = _selectedTemporaryCountry;
      _selectedPermanentState = _selectedTemporaryState;
      _selectedPermanentCity = _selectedTemporaryCity;
      _permanentToleController.text = _temporaryToleController.text;
    });
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


  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      height: 55,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFF48A54C),
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

  void _validateAndSubmit() {
    setState(() {
      submitted = true;

    });
    // Basic validation - Current Address First
    if (_selectedTemporaryCountry == null) {
      _showError("Please select current country");
      return;
    }

    if (_selectedTemporaryState == null) {
      _showError("Please select current state/province");
      return;
    }

    if (_selectedTemporaryCity == null) {
      _showError("Please select current city");
      return;
    }

    if (_temporaryToleController.text.isEmpty) {
      _showError("Please enter current address landmark");
      return;
    }

    if (_selectedResidentialStatus2 == null) {
      _showError("Please select current residential status");
      return;
    }

    if (_willingToGoAbroad == null) {
      _showError("Please select if willing to go abroad");
      return;
    }

    if (_willingToGoAbroad == true && _selectedVisaStatus == null) {
      _showError("Please select visa status");
      return;
    }

    // Permanent Address Validation
    if (_selectedPermanentCountry == null) {
      _showError("Please select permanent country");
      return;
    }

    if (_selectedPermanentState == null) {
      _showError("Please select permanent state/province");
      return;
    }

    if (_selectedPermanentCity == null) {
      _showError("Please select permanent city");
      return;
    }

    if (_permanentToleController.text.isEmpty) {
      _showError("Please enter permanent address landmark");
      return;
    }

    if (_selectedResidentialStatus == null) {
      _showError("Please select permanent residential status");
      return;
    }

    _submitAddress();
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

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _permanentToleController.dispose();
    _temporaryToleController.dispose();
    super.dispose();
  }
}