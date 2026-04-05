import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'SearchResult.dart';
import '../constant/constant.dart';

class FilterPage extends StatefulWidget {
  const FilterPage({super.key});

  @override
  State<FilterPage> createState() => _FilterPageState();
}

class _FilterPageState extends State<FilterPage> {
  RangeValues ageRange = const RangeValues(22, 60);
  RangeValues heightRange = const RangeValues(121, 215);

  String lookingFor = "Single";
  String religion = "Hindu";
  String education = "Bachelor";
  String income = "5 To 10 Lakh";
  String smoking = "No";
  String drinking = "No";

  // Add these variables for real-time count
  int _matchesCount = 0;
  int _initialTotalCount = 0; // Store initial total count without filters
  bool _isLoadingCount = true;
  bool _isInitialLoad = true; // Track if this is the initial load
  int _currentUserId = 0;
  Map<String, dynamic> _filterParams = {};
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  // Load user data
  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');

      if (userDataString != null) {
        final userData = jsonDecode(userDataString);
        final userId = int.tryParse(userData["id"].toString()) ?? 0;
        setState(() {
          _currentUserId = userId;
        });

        // Fetch initial count WITHOUT any filters
        _fetchInitialTotalCount();
      } else {
        setState(() {
          _isLoadingCount = false;
          _matchesCount = 0;
          _initialTotalCount = 0;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoadingCount = false;
        _matchesCount = 0;
        _initialTotalCount = 0;
      });
    }
  }

  // Fetch initial total count WITHOUT filters
  Future<void> _fetchInitialTotalCount() async {
    if (_currentUserId == 0) {
      setState(() {
        _isLoadingCount = false;
        _matchesCount = 0;
        _initialTotalCount = 0;
      });
      return;
    }

    try {
      // Fetch without any filter parameters
      final url = Uri.parse('${ApiConfig.baseUrl}/search_opposite_gender.php?user_id=$_currentUserId');

      print('Fetching initial count from: $url'); // Debug log

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          setState(() {
            _initialTotalCount = result['total_count'] ?? 0;
            _matchesCount = _initialTotalCount; // Start with total count
            _isLoadingCount = false;
            _isInitialLoad = false;
          });
        } else {
          throw Exception(result['message'] ?? 'Failed to load initial count');
        }
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching initial count: $e');
      setState(() {
        _isLoadingCount = false;
        _matchesCount = 0;
        _initialTotalCount = 0;
        _isInitialLoad = false;
      });
    }
  }

  // Map religion to ID
  int? _getReligionId(String religion) {
    switch (religion) {
      case "Hindu": return 1;
      case "Buddhist": return 4;
      case "Muslim": return 3;
      default: return null;
    }
  }

  // Check if any filters are applied (different from defaults)
  bool _areFiltersApplied() {
    // Check if any filter is different from default values
    bool ageChanged = ageRange.start != 22 || ageRange.end != 60;
    bool heightChanged = heightRange.start != 121 || heightRange.end != 215;
    bool religionChanged = religion != "Hindu";
    bool educationChanged = education != "Bachelor";
    bool incomeChanged = income != "5 To 10 Lakh";
    bool smokingChanged = smoking != "No";
    bool drinkingChanged = drinking != "No";

    return ageChanged || heightChanged || religionChanged ||
        educationChanged || incomeChanged || smokingChanged || drinkingChanged;
  }

  // Build filter parameters map
  Map<String, dynamic> _buildFilterParams() {
    Map<String, dynamic> params = {};

    // Only add age if changed from default
    if (ageRange.start != 22 || ageRange.end != 60) {
      params['minage'] = ageRange.start.round();
      params['maxage'] = ageRange.end.round();
    }

    // Only add height if changed from default
    if (heightRange.start != 121 || heightRange.end != 215) {
      params['minheight'] = heightRange.start.round();
      params['maxheight'] = heightRange.end.round();
    }

    // Only add religion if changed from default
    if (religion != "Hindu") {
      final religionId = _getReligionId(religion);
      if (religionId != null) {
        params['religion'] = religionId;
      }
    }

    return params;
  }

  // Fetch matches count from API with debouncing
  Future<void> _fetchMatchesCount() async {
    if (_currentUserId == 0) {
      setState(() {
        _matchesCount = 0;
        _isLoadingCount = false;
      });
      return;
    }

    // Cancel previous timer
    _debounceTimer?.cancel();

    // Set new timer for debouncing
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      setState(() {
        _isLoadingCount = true;
      });

      try {
        // Build filter parameters
        _filterParams = _buildFilterParams();

        // If no filters are applied, show initial total count
        if (_filterParams.isEmpty) {
          setState(() {
            _matchesCount = _initialTotalCount;
            _isLoadingCount = false;
          });
          return;
        }

        // Remove null values
        final filteredParams = Map<String, dynamic>.from(_filterParams)
          ..removeWhere((key, value) => value == null);

        // Build query parameters
        final params = {
          'user_id': _currentUserId.toString(),
          ...filteredParams.map((key, value) => MapEntry(key, value.toString())),
        };

        // Build URL
        final queryString = Uri(queryParameters: params).query;
        final url = Uri.parse('${ApiConfig.baseUrl}/search_opposite_gender.php?$queryString');

        print('Fetching filtered count from: $url'); // Debug log

        final response = await http.get(url);

        if (response.statusCode == 200) {
          final result = jsonDecode(response.body);

          if (result['success'] == true) {
            setState(() {
              _matchesCount = result['total_count'] ?? 0;
              _isLoadingCount = false;
            });
          } else {
            throw Exception(result['message'] ?? 'Failed to load count');
          }
        } else {
          throw Exception('Failed to load data: ${response.statusCode}');
        }
      } catch (e) {
        print('Error fetching matches count: $e');
        setState(() {
          _matchesCount = 0;
          _isLoadingCount = false;
        });
      }
    });
  }

  // Handle filter change with debouncing
  void _handleFilterChange() {
    _fetchMatchesCount();
  }

  // Clear all filters
  void _clearAllFilters() {
    setState(() {
      ageRange = const RangeValues(22, 60);
      heightRange = const RangeValues(121, 215);
      lookingFor = "Single";
      religion = "Hindu";
      education = "Bachelor";
      income = "5 To 10 Lakh";
      smoking = "No";
      drinking = "No";
    });

    // After clearing, show initial total count
    setState(() {
      _matchesCount = _initialTotalCount;
      _filterParams = {}; // Clear filter params
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      _buildFilterTitle(),
                      const SizedBox(height: 20),
                      _buildLabel("Looking For"),
                      _buildDropdown(lookingFor, ["Single", "Married", "Widow"], (v) {
                        setState(() => lookingFor = v!);
                        _handleFilterChange();
                      }),
                      const SizedBox(height: 20),
                      _buildLabel("Age Range*"),
                      _buildRangeSlider(ageRange, 18, 70, (v) {
                        setState(() => ageRange = v);
                        _handleFilterChange();
                      }),
                      const SizedBox(height: 20),
                      _buildLabel("Height Range (In Cm)*"),
                      _buildRangeSlider(heightRange, 100, 250, (v) {
                        setState(() => heightRange = v);
                        _handleFilterChange();
                      }),
                      const SizedBox(height: 20),
                      _buildLabel("Religion"),
                      _buildDropdown(religion, ["Hindu", "Buddhist", "Muslim"], (v) {
                        setState(() => religion = v!);
                        _handleFilterChange();
                      }),
                      const SizedBox(height: 20),
                      _buildLabel("Education"),
                      _buildDropdown(education, ["Bachelor", "Master", "PhD"], (v) {
                        setState(() => education = v!);
                        _handleFilterChange();
                      }),
                      const SizedBox(height: 20),
                      _buildLabel("Annual Income"),
                      _buildDropdown(income, ["5 To 10 Lakh", "10 To 20 Lakh"], (v) {
                        setState(() => income = v!);
                        _handleFilterChange();
                      }),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel("Smoking"),
                                _buildDropdown(smoking, ["No", "Yes"], (v) {
                                  setState(() => smoking = v!);
                                  _handleFilterChange();
                                }),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel("Drinking"),
                                _buildDropdown(drinking, ["No", "Yes"], (v) {
                                  setState(() => drinking = v!);
                                  _handleFilterChange();
                                }),
                              ],
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
            _buildBottomSummary(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 70, bottom: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xffFF1500), Color(0xffFF5A60)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              height: 50,
              alignment: Alignment.center,
              padding: const EdgeInsets.only(right: 8),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
            ),
          ),
          Expanded(
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: const [
                  SizedBox(width: 15),
                  Icon(Icons.search, color: Colors.grey),
                  SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                          hintText: "Search by profile id",
                          border: InputBorder.none),
                    ),
                  )
                ],
              ),
            ),
          ),

          const SizedBox(width: 10),
          _circleIcon(Icons.tune),
        ],
      ),
    );
  }

  Widget _circleIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      child: Icon(icon, color: Colors.black, size: 20),
    );
  }

  Widget _buildFilterTitle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("Filter", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Row(
          children: [
            GestureDetector(
              onTap: _clearAllFilters,
              child: const Text(
                "Clear all",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(20),
              ),
              child: _isLoadingCount
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : Text(
                _matchesCount.toString(),
                style: const TextStyle(color: Colors.white),
              ),
            )
          ],
        ),
      ],
    );
  }

  Widget _buildLabel(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        Container(height: 2, width: 40, color: Colors.red, margin: const EdgeInsets.only(top: 3)),
      ],
    );
  }

  Widget _buildDropdown(String value, List<String> list, Function(String?) onChange) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.black12),
      ),
      child: ExcludeFocus(
        excluding: true,
        child: DropdownButton<String>(
          value: value,
          underline: const SizedBox(),
          isExpanded: true,
          items: list.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChange,
        ),
      ),
    );
  }

  Widget _buildRangeSlider(RangeValues range, double min, double max, Function(RangeValues) onChange) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _bubble(range.start.round().toString()),
            _bubble(range.end.round().toString()),
          ],
        ),
        RangeSlider(
          values: range,
          min: min,
          max: max,
          activeColor: const Color(0xffFF1500),
          inactiveColor: const Color(0xfffbc0c7),
          onChanged: onChange,
        )
      ],
    );
  }

  Widget _bubble(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildBottomSummary() {
    final bool filtersApplied = _areFiltersApplied();

    return Column(
      children: [
        Container(
          height: 50,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: Color(0xfff1f1f1)),
          child: _isLoadingCount
              ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                ),
              ),
              SizedBox(width: 8),
              Text(
                "Calculating matches...",
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ],
          )
              : Text(
            _matchesCount == 1
                ? "1 match${filtersApplied ? ' based on your filter' : ''}"
                : "$_matchesCount matches${filtersApplied ? ' based on your filter' : ''}",
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ),
        GestureDetector(
          onTap: _matchesCount > 0 ? () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SearchResultPage(filterParams: filtersApplied ? _filterParams : null),
              ),
            );
          } : null,
          child: Container(
            width: double.infinity,
            height: 55,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _matchesCount > 0
                    ? [const Color(0xffFF1500), const Color(0xfff88fb1)]
                    : [Colors.grey, Colors.grey[600]!],
              ),
            ),
            child: Center(
              child: Text(
                "Search",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        )
      ],
    );
  }
}