import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ms2026/Auth/Screen/signupscreen10.dart';
import 'package:ms2026/Chat/ChatlistScreen.dart';
import 'package:ms2026/Home/Screen/HomeScreenPage.dart';
import 'package:ms2026/Package/PackageScreen.dart';
import 'package:ms2026/ReUsable/loading_widgets.dart';
import 'package:ms2026/purposal/purposalservice.dart';
import 'package:ms2026/purposal/requestcard.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Chat/ChatdetailsScreen.dart';
import '../Models/masterdata.dart';
import 'Purposalmodel.dart';

class ProposalsPage extends StatefulWidget {
  const ProposalsPage({super.key});

  @override
  State<ProposalsPage> createState() => _ProposalsPageState();
}

class _ProposalsPageState extends State<ProposalsPage> {
  String userid = '';
  int selectedTab = 0;
  String usertye = '';
  String userimage = '';
  var pageno;

  // PageController for swiping between tabs
  late PageController _pageController;

  bool loading = true;
  List<ProposalModel> list = [];

  // Separate lists for each tab
  List<ProposalModel> receivedList = [];
  List<ProposalModel> sentList = [];
  List<ProposalModel> acceptedList = [];

  // Loading states for each tab
  bool loadingReceived = true;
  bool loadingSent = true;
  bool loadingAccepted = true;

  // Refresh shimmer state for each tab
  bool _refreshingReceived = false;
  bool _refreshingSent = false;
  bool _refreshingAccepted = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: selectedTab);
    _loadInitialData();
    loadMasterData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// LOAD INITIAL DATA
  Future<void> _loadInitialData() async {
    // Load all tabs data initially
    await Future.wait([
      _loadDataForTab(0),
      _loadDataForTab(1),
      _loadDataForTab(2),
    ]);
  }

  void loadMasterData() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    final userData = jsonDecode(userDataString!);
    final userId = int.tryParse(userData["id"].toString());
    try {
      UserMasterData user = await fetchUserMasterData(userId.toString());

      print("Name: ${user.firstName} ${user.lastName}");
      print("Usertype: ${user.usertype}");
      print("Page No: ${user.pageno}");
      print("Profile: ${user.profilePicture}");
      setState(() {
        usertye = user.usertype;
        userimage = user.profilePicture;
        pageno = user.pageno;
      });
    } catch (e) {
      print("Error: $e");
    }
  }

  Future<UserMasterData> fetchUserMasterData(String userId) async {
    final url = Uri.parse(
      "https://digitallami.com/Api2/masterdata.php?userid=$userId",
    );

    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception("Failed: ${response.statusCode}");
    }

    final res = json.decode(response.body);

    if (res['success'] != true) {
      throw Exception(res['message'] ?? "API error");
    }

    return UserMasterData.fromJson(res['data']);
  }

  /// LOAD DATA FOR SPECIFIC TAB
  Future<void> _loadDataForTab(int tabIndex) async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    final userData = jsonDecode(userDataString!);
    final userId = int.tryParse(userData["id"].toString());

    if (mounted) {
      setState(() {
        userid = userId.toString();
        // Set loading state for specific tab
        switch (tabIndex) {
          case 0:
            loadingReceived = true;
            break;
          case 1:
            loadingSent = true;
            break;
          case 2:
            loadingAccepted = true;
            break;
        }
      });
    }

    try {
      String type = _getTypeFromTab(tabIndex);
      final result = await ProposalService.fetchProposals(userId.toString(), type);

      if (mounted) {
        setState(() {
          switch (tabIndex) {
            case 0:
              receivedList = result;
              loadingReceived = false;
              break;
            case 1:
              sentList = result;
              loadingSent = false;
              break;
            case 2:
              acceptedList = result;
              loadingAccepted = false;
              break;
          }
        });
      }
    } catch (e) {
      print("Error loading proposals: $e");
      if (mounted) {
        setState(() {
          switch (tabIndex) {
            case 0:
              receivedList = [];
              loadingReceived = false;
              break;
            case 1:
              sentList = [];
              loadingSent = false;
              break;
            case 2:
              acceptedList = [];
              loadingAccepted = false;
              break;
          }
        });
      }
    }
  }

  String _getTypeFromTab(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return "received";
      case 1:
        return "sent";
      case 2:
        return "accepted";
      default:
        return "received";
    }
  }

  /// HANDLE TAB SELECTION
  void _onTabSelected(int index) {
    if (selectedTab != index) {
      setState(() => selectedTab = index);
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      // Refresh the selected tab if needed
      _refreshTabData(index);
    }
  }

  /// REFRESH DATA FOR A SPECIFIC TAB
  void _refreshTabData(int tabIndex) {
    _loadDataForTab(tabIndex);
  }

  /// REFRESH ALL TABS
  void _refreshAllTabs() {
    Future.wait([
      _loadDataForTab(0),
      _loadDataForTab(1),
      _loadDataForTab(2),
    ]);
  }

  /// HANDLE PAGE CHANGE (from swipe)
  void _onPageChanged(int index) {
    setState(() {
      selectedTab = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),

            const Center(
              child: Text(
                "Proposals",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
            ),

            const SizedBox(height: 20),

            // TABS - From screenshot: Received, Sent, Accepted
            Container(
              height: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildTabItem("Received", 0),
                  _buildTabItem("Sent", 1),
                  _buildTabItem("Accepted", 2),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // PAGE VIEW FOR SWIPEABLE CONTENT
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                children: [
                  // Received Tab
                  _buildTabContent(
                    isLoading: loadingReceived,
                    isRefreshing: _refreshingReceived,
                    list: receivedList,
                    tabIndex: 0,
                  ),

                  // Sent Tab
                  _buildTabContent(
                    isLoading: loadingSent,
                    isRefreshing: _refreshingSent,
                    list: sentList,
                    tabIndex: 1,
                  ),

                  // Accepted Tab
                  _buildTabContent(
                    isLoading: loadingAccepted,
                    isRefreshing: _refreshingAccepted,
                    list: acceptedList,
                    tabIndex: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent({
    required bool isLoading,
    required bool isRefreshing,
    required List<ProposalModel> list,
    required int tabIndex,
  }) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getEmptyStateIcon(tabIndex),
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _getEmptyStateText(tabIndex),
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          if (tabIndex == 0) _refreshingReceived = true;
          else if (tabIndex == 1) _refreshingSent = true;
          else _refreshingAccepted = true;
        });
        await _loadDataForTab(tabIndex);
        if (mounted) {
          setState(() {
            if (tabIndex == 0) _refreshingReceived = false;
            else if (tabIndex == 1) _refreshingSent = false;
            else _refreshingAccepted = false;
          });
        }
      },
      child: ShimmerLoading(
        isLoading: isRefreshing,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: list.length,
          itemBuilder: (context, index) {
            return RequestCardDynamic(
              data: list[index],
              tabIndex: tabIndex,
              userid: userid,
              onActionComplete: () {
                // Refresh this tab after action
                _loadDataForTab(tabIndex);
              },
            );
          },
        ),
      ),
    );
  }

  IconData _getEmptyStateIcon(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return Icons.inbox_outlined;
      case 1:
        return Icons.send_outlined;
      case 2:
        return Icons.check_circle_outline;
      default:
        return Icons.inbox_outlined;
    }
  }

  String _getEmptyStateText(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return "No received proposals";
      case 1:
        return "No sent proposals";
      case 2:
        return "No accepted proposals";
      default:
        return "No proposals found";
    }
  }

  Widget _buildTabItem(String title, int index) {
    final bool active = selectedTab == index;
    return GestureDetector(
      onTap: () => _onTabSelected(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                color: active ? Colors.red : Colors.black54,
                fontSize: 16,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              height: 3,
              width: 50,
              decoration: BoxDecoration(
                color: active ? Colors.red : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

