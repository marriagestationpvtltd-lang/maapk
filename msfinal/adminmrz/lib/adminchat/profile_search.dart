import 'package:flutter/material.dart';

class ProfileSearch extends StatelessWidget {
  final List<Map<String, String>> profiles = [
    {"name": "Priya Patel", "age": "26", "match": "58%"},
    {"name": "Meera Shah", "age": "27", "match": "60%"},
    {"name": "Anaya Singh", "age": "29", "match": "62%"},
    {"name": "Sarita Kumari", "age": "28", "match": "64%"},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[100],
      child: Column(
        children: [
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: "Search by name, occupation...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
          Expanded( child: Container(
            child: ListView.builder(
              itemCount: profiles.length,
              itemBuilder: (context, index) {
                final profile = profiles[index];
                return ListTile(
                  leading: CircleAvatar(child: Icon(Icons.person)),
                  title: Text(profile["name"]!),
                  subtitle: Text("${profile["age"]} years, ${profile["match"]} Match"),
                );
              },
            ),
          ),)
        ],
      ),
    );
  }
}
