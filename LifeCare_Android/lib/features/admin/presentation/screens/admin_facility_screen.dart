import 'package:flutter/material.dart';

class AdminFacilitiesScreen extends StatefulWidget {
  const AdminFacilitiesScreen({super.key});

  @override
  State<AdminFacilitiesScreen> createState() => _AdminFacilitiesScreenState();
}

class _AdminFacilitiesScreenState extends State<AdminFacilitiesScreen> {
  final List<Map<String, String>> facilities = [
    {
      "name": "Tula Yiri Primary Health Center",
      "location": "Gombe State",
      "type": "Hospital",
    },
    {
      "name": "Kabri Village Pharmacy",
      "location": "Taraba State",
      "type": "Pharmacy",
    },
    {"name": "Federal Lab Gombe", "location": "Gombe", "type": "Laboratory"},
    {
      "name": "Jalingo Diagnostic Scan Center",
      "location": "Taraba",
      "type": "Scan Center",
    },
  ];

  final List<Map<String, dynamic>> categories = [
    {"label": "Hospitals", "icon": Icons.local_hospital, "type": "Hospital"},
    {"label": "Pharmacies", "icon": Icons.local_pharmacy, "type": "Pharmacy"},
    {"label": "Laboratories", "icon": Icons.science, "type": "Laboratory"},
    {
      "label": "Scan Centers",
      "icon": Icons.monitor_heart,
      "type": "Scan Center",
    },
  ];

  String searchQuery = '';
  String selectedCategory =
      ''; // Holds selected category filter (Hospital, Pharmacy, etc)

  void _showAddFacilityModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Add Facility",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Choose a Category",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: categories.map((cat) {
                      return ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade100,
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "${cat["label"]} selected (UI only)",
                              ),
                            ),
                          );
                        },
                        icon: Icon(cat["icon"], size: 18, color: Colors.green),
                        label: Text(
                          cat["label"],
                          style: const TextStyle(color: Colors.green),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const Text(
                    "Registered Facilities",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  ...facilities.map((f) {
                    return ListTile(
                      leading: const Icon(
                        Icons.location_city,
                        color: Colors.green,
                      ),
                      title: Text(f['name']!),
                      subtitle: Text("${f['location']} • ${f['type']}"),
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Apply search + filter
    final filteredFacilities = facilities.where((facility) {
      final matchesSearch =
          facility["name"]!.toLowerCase().contains(searchQuery.toLowerCase()) ||
          facility["location"]!.toLowerCase().contains(
            searchQuery.toLowerCase(),
          );

      final matchesCategory = selectedCategory.isEmpty
          ? true
          : facility["type"] == selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Health Facilities"),
        backgroundColor: Colors.teal.shade800,
        actions: [
          if (selectedCategory.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() {
                  selectedCategory = '';
                });
              },
              child: const Text(
                "Show All",
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                decoration: InputDecoration(
                  hintText: "Search by name or location",
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    searchQuery = val;
                  });
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(
                "Facility Categories",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: categories.map((cat) {
                  final isSelected = selectedCategory == cat["type"];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (selectedCategory == cat["type"]) {
                          selectedCategory = '';
                        } else {
                          selectedCategory = cat["type"];
                        }
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.teal.shade100
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Colors.teal.shade800
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            cat["icon"],
                            size: 32,
                            color: isSelected
                                ? Colors.teal.shade800
                                : Colors.green,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            cat["label"],
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                "All Facilities",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredFacilities.length,
              itemBuilder: (context, index) {
                final f = filteredFacilities[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.local_hospital,
                      color: Colors.green,
                    ),
                    title: Text(f["name"]!),
                    subtitle: Text("${f["location"]} • ${f["type"]}"),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.green),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Edit '${f["name"]}' (UI only)"),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: "Add Facility",
        backgroundColor: Colors.teal.shade800,
        onPressed: _showAddFacilityModal,
        child: const Icon(Icons.add_location_alt),
      ),
    );
  }
}
