import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/db_interactions/tenant_info.dart';

class PropertyListPage extends StatefulWidget {
  const PropertyListPage({super.key});

  @override
  State<PropertyListPage> createState() => _PropertyListPageState();
}

class _PropertyListPageState extends State<PropertyListPage> {
  final _supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _groupedPropertiesFuture;

  @override
  void initState() {
    super.initState();
    _groupedPropertiesFuture = _fetchAndGroupProperties();
  }

  Future<List<Map<String, dynamic>>> _fetchAndGroupProperties() async {
    try {
      // 1. Fetch properties and their related address in one go
      final response = await _supabase
          .from('house_id')
          .select('*, address:add_id(*)')
          .order('id', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      Map<String, Map<String, dynamic>> groupedData = {};

      // 2. Group them by address string
      for (var item in data) {
        final addressMap = item['address'];
        final String addressKey = addressMap != null
            ? "No. ${addressMap['house_no']} ${addressMap['street']} Street"
            : "Unknown Address";

        if (!groupedData.containsKey(addressKey)) {
          groupedData[addressKey] = {
            'header': addressKey,
            'properties': [],
          };
        }
        groupedData[addressKey]!['properties'].add(item);
      }
      return groupedData.values.toList();
    } catch (e) {
      debugPrint("FETCH ERROR: $e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Properties")),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _groupedPropertiesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No properties found."));
          }

          final groups = snapshot.data!;

          return ListView.builder(
            itemCount: groups.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              final group = groups[index];
              final properties = group['properties'] as List;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  leading: const Icon(Icons.location_on, color: Colors.orange),
                  title: Text(group['header'], 
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  children: properties.map((prop) {
                    // Logic for totals
                    final int rent = (prop['rent'] ?? 0).toInt();
                    final int water = (prop['water'] ?? 0).toInt();
                    final String houseNo = prop['house_no'] ?? 'N/A';

                    return ListTile(
                      leading: const Icon(Icons.apartment, color: Colors.blue),
                      title: Text(houseNo),
                      subtitle: Text("Rooms: ${prop['rooms']} | Water: \$$water | Rent: \$$rent"),
                      trailing: Text(
                        "\$${rent + water}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TenantInfoPage(
                              houseNo: houseNo, 
                              isEditable: true
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}