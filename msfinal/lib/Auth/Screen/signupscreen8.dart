import 'package:flutter/material.dart';
import 'package:ms2026/Auth/Screen/signupscreen9.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// Make sure these imports are correct
import '../../ReUsable/dropdownwidget.dart';
import '../../service/updatepage.dart';

class LifestylePage extends StatefulWidget {
  const LifestylePage({super.key});

  @override
  State<LifestylePage> createState() => _LifestylePageState();
}

class _LifestylePageState extends State<LifestylePage> {
  bool submitted = false;

  // Form variables
  String? _selectedDiet;
  String? _selectedDrink;
  String? _selectedDrinkType;
  String? _selectedSmoke;
  String? _selectedSmokeType;

  // Dropdown options
  final List<String> _dietOptions = [
    'Vegetarian',
    'Non-Vegetarian',
    'Eggetarian',
    'Vegan',
    'Jain',
    'Other'
  ];

  final List<String> _drinkOptions = [
    'Yes',
    'No',
    'SomeTime',

  ];

  final List<String> _drinkTypeOptions = [
    'Beer',
    'Wine',
    'Whiskey',
    'Vodka',
    'Rum',
    'Other',
    'Non-Alcoholic'
  ];

  final List<String> _smokeOptions = [
    'Yes',
    'No',
    'Occasionally',
    'Socially'
  ];

  final List<String> _smokeTypeOptions = [
    'Cigarettes',
    'Cigars',
    'Vape',
    'Hookah',
    'Other'
  ];

  bool _isLoading = false;

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
                  // Header with Skip button - FIXED
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Skip Button
                      GestureDetector(
                        onTap: _skipPage,
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

                      // Title
                      const Text(
                        "Life Style",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE64B37),
                        ),
                      ),

                      // Empty container for balance
                      const SizedBox(width: 80),
                    ],
                  ),

                  const SizedBox(height: 25),

                  // Your Diet
                  _buildSectionTitle("Your Diet*"),
                  const SizedBox(height: 8),
                  Container(
                    child: TypingDropdown<String>(
                      items: _dietOptions,
                      selectedItem: _selectedDiet,
                      itemLabel: (item) => item,
                      hint: "Select your diet*",
                      onChanged: (value) {
                        setState(() {
                          _selectedDiet = value;
                        });
                      }, title: 'Diets', showError: submitted,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Drink
                  _buildSectionTitle("Drink*"),
                  const SizedBox(height: 8),
                  Container(
                    child: TypingDropdown<String>(
                      items: _drinkOptions,
                      selectedItem: _selectedDrink,
                      itemLabel: (item) => item,
                      hint: "Select drink habit*",
                      onChanged: (value) {
                        setState(() {
                          _selectedDrink = value;
                          // Reset drink type if "No" is selected
                          if (value == "No") {
                            _selectedDrinkType = null;
                          }
                        });
                      }, title: 'Drink habit', showError:  submitted,
                    ),
                  ),

                  // Drink Type (only show if not "No")
                  if (_selectedDrink != null && _selectedDrink != "No") ...[
                    const SizedBox(height: 15),
                    _buildSectionTitle("Select Drink Type*"),
                    const SizedBox(height: 8),
                    Container(
                      child: TypingDropdown<String>(
                        items: _drinkTypeOptions,
                        selectedItem: _selectedDrinkType,
                        itemLabel: (item) => item,
                        hint: "Select drink type*",
                        onChanged: (value) {
                          setState(() {
                            _selectedDrinkType = value;
                          });
                        }, title: 'Drink Type', showError:  submitted,
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Smoke
                  _buildSectionTitle("Smoke*"),
                  const SizedBox(height: 8),
                  Container(
                    child: TypingDropdown<String>(
                      items: _smokeOptions,
                      selectedItem: _selectedSmoke,
                      itemLabel: (item) => item,
                      hint: "Select smoke habit*",
                      onChanged: (value) {
                        setState(() {
                          _selectedSmoke = value;
                          // Reset smoke type if "No" is selected
                          if (value == "No") {
                            _selectedSmokeType = null;
                          }
                        });
                      }, title: 'Smoke habit', showError:  submitted,
                    ),
                  ),

                  // Smoke Type (only show if not "No")
                  if (_selectedSmoke != null && _selectedSmoke != "No") ...[
                    const SizedBox(height: 15),
                    _buildSectionTitle("Select Smoke Type*"),
                    const SizedBox(height: 8),
                    Container(
                      child: TypingDropdown<String>(
                        items: _smokeTypeOptions,
                        selectedItem: _selectedSmokeType,
                        itemLabel: (item) => item,
                        hint: "Select smoke type*",
                        onChanged: (value) {
                          setState(() {
                            _selectedSmokeType = value;
                          });
                        }, title: 'Smoke Type', showError:  submitted,
                      ),
                    ),
                  ],

                  const SizedBox(height: 35),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: _buildButton(
                          text: "Previous",
                          isPrimary: false,
                          onPressed: _isLoading ? null : () {
                            Navigator.pop(context);
                          },
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildButton(
                          text: _isLoading ? "Submitting..." : "Continue",
                          isPrimary: true,
                          onPressed: _isLoading ? null : _validateAndSubmit,
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
              child: _progressBubble(0.80, "80%"), // Fixed progress value to match your label
            ),

            // Loading overlay
            if (_isLoading)
              Container(
                color: Colors.black54,
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

  void _skipPage() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            "Skip Lifestyle Details?",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFFE64B37),
            ),
          ),
          content: const Text(
            "Are you sure you want to skip this section? You can fill it later.",
            style: TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                "Cancel",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                _proceedWithoutLifestyle();
              },
              child: const Text(
                "Skip",
                style: TextStyle(
                  color: Color(0xFFE64B37),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _proceedWithoutLifestyle() {
    print("Lifestyle section skipped");
    // Navigate to next page without saving lifestyle data
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PartnerPreferencesPage()),
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

  Widget _buildButton({
    required String text,
    required bool isPrimary,
    required VoidCallback? onPressed,
  }) {
    return Opacity(
      opacity: onPressed == null ? 0.6 : 1.0,
      child: Container(
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
    submitted = true;
    setState(() {
      submitted = true;

    });
    // Basic validation
    if (_selectedDiet == null) {
      _showError("Please select your diet");
      return;
    }

    if (_selectedDrink == null) {
      _showError("Please select your drink habit");
      return;
    }

    // Drink type validation (only if not "No")
    if (_selectedDrink != "No" && _selectedDrinkType == null) {
      _showError("Please select drink type");
      return;
    }

    if (_selectedSmoke == null) {
      _showError("Please select your smoke habit");
      return;
    }

    // Smoke type validation (only if not "No")
    if (_selectedSmoke != "No" && _selectedSmokeType == null) {
      _showError("Please select smoke type");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');

      if (userDataString == null) {
        _showError("User data not found. Please login again.");
        return;
      }

      final userData = jsonDecode(userDataString);
      final userId = int.tryParse(userData["id"].toString());

      if (userId == null) {
        _showError("Invalid user ID");
        return;
      }

      // Prepare data - handle null values properly
      Map<String, String> body = {
        "userid": userId.toString(),
        "diet": _selectedDiet!,
        "drinks": _selectedDrink!,
        "drinktype": _selectedDrink != "No" ? _selectedDrinkType ?? "" : "",
        "smoke": _selectedSmoke!,
        "smoketype": _selectedSmoke != "No" ? _selectedSmokeType ?? "" : "",
      };

      // Remove empty values to avoid sending null to API
      body.removeWhere((key, value) => value.isEmpty);

      // API URL
      String url = "https://digitallami.com/Api2/user_lifestyle.php";

      print("Submitting data: $body");

      final response = await http.post(
        Uri.parse(url),
        body: body,
      ).timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);
      print("API Response: $data");

      if (data['status'] == 'success') {
        _showSuccess(data['message'] ?? "Lifestyle details saved successfully!");

        // Update page number
        await UpdateService.updatePageNumber(
          userId: userId.toString(),
          pageNo: 7,
        );

        // Navigate to next page
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PartnerPreferencesPage()),
        );
      } else {
        _showError(data['message'] ?? "Submission failed. Please try again.");
      }
    } catch (e) {
      _showError("Network error: $e");
      print("Error details: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
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

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}