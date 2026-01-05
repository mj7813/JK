import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../global/app_state.dart';
import 'package:collection/collection.dart'; // This allows using firstWhereOrNull

class EBConsumptionPage extends StatefulWidget {
  const EBConsumptionPage({super.key});

  @override
  State<EBConsumptionPage> createState() => _EBConsumptionPageState();
}

class _EBConsumptionPageState extends State<EBConsumptionPage> {
  final _supabase = Supabase.instance.client;

  // Fetch unique house numbers that have readings
  Future<List<String>> _fetchUniqueHouses() async {
    try {
      final response = await _supabase
          .from('house_id')
          .select('house_no')
          .eq('EB', true)
          .order('id', ascending: true);
      
      // Extract unique house numbers from the list
      final List<dynamic> data = response as List<dynamic>;
      final Set<String> uniqueHouses = data.map((item) => item['house_no'].toString()).toSet();
      
      List<String> sortedHouses = uniqueHouses.toList();
      return sortedHouses;
    } catch (e) {
      debugPrint("FETCH ERROR: $e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
  return ListenableBuilder(
  listenable: AppState.instance,
    builder: (context, child) {
      final bool isAdmin = AppState.instance.admin;
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Electricity Consumption"),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.add_chart_rounded),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EBReadingUpdatePage()),
                );
                // This code runs when you come BACK from the update page
                setState(() {}); 
              },
            ),
        ],
      ),
      body: FutureBuilder<List<String>>(
        future: _fetchUniqueHouses(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final houses = snapshot.data ?? [];
          if (houses.isEmpty) return const Center(child: Text("No houses found."));

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, // 2 cards per row
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
            ),
            itemCount: houses.length,
            itemBuilder: (context, index) {
              return InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HouseHistoryPage(houseNo: houses[index]),
                  ),
                ),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  color: Colors.white,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.house_rounded, size: 40, color: Colors.blueAccent),
                      const SizedBox(height: 8),
                      Text(
                        "House ${houses[index]}",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
    }
  );
  }
}




class HouseHistoryPage extends StatelessWidget {
  final String houseNo;
  const HouseHistoryPage({super.key, required this.houseNo});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return Scaffold(
      appBar: AppBar(title: Text("Reading History - $houseNo")),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: supabase
            .from('electricity_readings')
            .select()
            .eq('house_no', houseNo)
            .order('reading_year', ascending: false)
            .order('reading_month', ascending: false),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final logs = snapshot.data!;

          return ListView.builder(
            itemCount: logs.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              final log = logs[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${_getMonthName(log['reading_month'])} ${log['reading_year']}",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8)),
                            child: Text("₹${log['total_cost'] ?? '0'}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildDetail("Prev", "${log['previous_reading']}"),
                          _buildDetail("Curr", "${log['current_reading']}"),
                          _buildDetail("Units", "${log['units_used']}", color: Colors.blue),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDetail(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
      ],
    );
  }

  String _getMonthName(int month) {
    return ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][month];
  }
}




//This is the Electricity Consumption Update Page
class EBReadingUpdatePage extends StatefulWidget {
  const EBReadingUpdatePage({super.key});

  @override
  State<EBReadingUpdatePage> createState() => _EBReadingUpdatePageState();
}

class _EBReadingUpdatePageState extends State<EBReadingUpdatePage> {
  final _supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _dataFuture;
  final Map<String, TextEditingController> _controllers = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // 2. Initialize the future ONLY ONCE when the page loads
    _dataFuture = _fetchAndGroupEB();
  }

  // 3. Helper to refresh data after saving
  void _refreshData() {
    setState(() {
      _dataFuture = _fetchAndGroupEB();
    });
  }

  Future<List<Map<String, dynamic>>> _fetchAndGroupEB() async {
  try {
    final now = DateTime.now();

    // 1. Fetch houses
    final houseResponse = await _supabase
        .from('house_id')
        .select('*, address:add_id(*)')
        .eq('EB', true)
        .order('id', ascending: true);

    // 2. Fetch existing readings for THIS month
    final existingReadings = await _supabase
        .from('electricity_readings')
        .select()
        .eq('reading_month', now.month)
        .eq('reading_year', now.year);

    final List<dynamic> data = houseResponse as List<dynamic>;
    Map<String, Map<String, dynamic>> groupedData = {};

    for (var item in data) {
      final String hNo = item['house_no'];
      
      // 3. Pre-fill controller if a reading already exists
      final existing = existingReadings.firstWhereOrNull((r) => r['house_no'] == hNo);
      
      if (!_controllers.containsKey(hNo)) {
          _controllers[hNo] = TextEditingController(
            text: existing != null ? existing['current_reading'].toString() : ''
          );
        } else if (existing != null) {
          // Update text if data changed externally
          _controllers[hNo]!.text = existing['current_reading'].toString();
        }

      // ... rest of your grouping logic stays the same ...
      final addressMap = item['address'];
      final String addressKey = addressMap != null 
          ? "No. ${addressMap['house_no']} ${addressMap['street']} Street" 
          : "Unknown Address";

      if (!groupedData.containsKey(addressKey)) {
        groupedData[addressKey] = {'header': addressKey, 'houses': []};
      }
      groupedData[addressKey]!['houses'].add(item);
    }
    return groupedData.values.toList();
  } catch (e) {
    debugPrint("FETCH ERROR: $e");
    return [];
  }
}

  
  // --- NEW BULK SAVE FUNCTION ---
  // REPLACE your current build method's ListView.builder and _saveAddressGroup with this:

  // --- UPDATED SAVE FUNCTION WITH REFRESH ---
  Future<void> _saveAddressGroup(List<dynamic> houses) async {
    setState(() => _isSaving = true);
    final DateTime now = DateTime.now();
    List<Map<String, dynamic>> readingsToUpsert = [];

    try {
      for (var house in houses) {
        final hNo = house['house_no'];
        final String input = _controllers[hNo]?.text ?? '';
        final double? reading = double.tryParse(input);

        if (reading != null) {
          // Fetch previous reading
          final lastRecord = await _supabase
              .from('electricity_readings')
              .select('current_reading')
              .eq('house_no', hNo)
              .lt('reading_month', now.month) 
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();

          double prev = lastRecord?['current_reading']?.toDouble() ?? 0.0;

          readingsToUpsert.add({
            'house_no': hNo,
            'reading_month': now.month,
            'reading_year': now.year,
            'current_reading': reading,
            'previous_reading': prev,
          });
        }
      }

      if (readingsToUpsert.isEmpty) return;

      await _supabase
          .from('electricity_readings')
          .upsert(readingsToUpsert, onConflict: 'house_no, reading_month, reading_year');

      if (mounted) {
        // FIX 1: This tells the FutureBuilder to fetch fresh data from the DB
        _refreshData();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Readings Updated successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("SAVE ERROR: $e");
    
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("EB Reading Entry")),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final groups = snapshot.data ?? [];

          return ListView.builder(
            itemCount: groups.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              final group = groups[index];
              final houses = group['houses'] as List;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  leading: const Icon(Icons.location_on, color: Colors.orange),
                  title: Text(group['header'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  children: [
                    ...houses.map((house) {
                      final hNo = house['house_no'];
                      
                      // Ensure controller exists
                      _controllers.putIfAbsent(hNo, () => TextEditingController());
                      final controller = _controllers[hNo]!;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            Expanded(child: Text(hNo, style: const TextStyle(fontSize: 16))),
                            Expanded(
                              flex: 2,
                              // FIX 2: Listens to typing and updates border color immediately
                              child: ValueListenableBuilder(
                                valueListenable: controller,
                                builder: (context, value, child) {
                                  final bool hasValue = value.text.isNotEmpty;
                                  return TextField(
                                    controller: controller,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: "Current Reading",
                                      enabledBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: hasValue ? Colors.green : Colors.grey,
                                          width: hasValue ? 2.0 : 1.0,
                                        ),
                                      ),
                                      border: const OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(45),
                          backgroundColor: Colors.blueGrey[800],
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _isSaving ? null : () => _saveAddressGroup(houses),
                        icon: _isSaving 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                          : const Icon(Icons.cloud_upload),
                        label: const Text("SAVE ALL FOR THIS ADDRESS"),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}