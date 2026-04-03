import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;


class PackageHistoryPage extends StatefulWidget {
  final String userid;
  const PackageHistoryPage({super.key, required this.userid});

  @override
  State<PackageHistoryPage> createState() => _PackageHistoryPageState();
}

class _PackageHistoryPageState extends State<PackageHistoryPage> {
  List<dynamic> packages = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchPackages();
  }

  Future<void> fetchPackages() async {
    final url = Uri.parse(
        "http://digitallami.com/Api2/user_package.php?userid=${widget.userid}");
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            packages = data['data'];
            isLoading = false;
          });
        } else {
          setState(() {
            isLoading = false;
          });
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(data['message'])));
        }
      } else {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Failed to load packages")));
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Package History"),
        backgroundColor: Colors.red.shade700,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : packages.isEmpty
          ? const Center(child: Text("No packages found"))
          : ListView.builder(
          itemCount: packages.length,
          itemBuilder: (context, index) {
            final pkg = packages[index];
            return Card(
              margin: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pkg['package_name'] ?? 'Package',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text("Description: ${pkg['description'] ?? ''}"),
                      Text("Duration: ${pkg['duration']} month(s)"),
                      Text("Price: ${pkg['price']} NPR"),
                      const SizedBox(height: 8),
                      Text(
                          "Purchased on: ${pkg['purchasedate']?.substring(0, 10) ?? ''}"),
                      Text(
                          "Expires on: ${pkg['expiredate']?.substring(0, 10) ?? ''}"),
                      Text("Paid via: ${pkg['paidby'] ?? ''}"),
                    ]),
              ),
            );
          }),
    );
  }
}
