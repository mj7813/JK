import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/db_interactions/tenant_info.dart';
import 'package:flutter_application_1/db_interactions/elect_reading.dart';

class UserPage extends StatefulWidget {
  const UserPage({super.key});

  @override
  State<UserPage> createState() => _UserPageState();
}


class _UserPageState extends State<UserPage> {
  final User? user = Supabase.instance.client.auth.currentUser;
  String? houseNo;
  Future<void> _fetchHouseNo() async {
  try {
    // 1. Call the postgres function using .rpc
    // 2. Cast the result to String?
    houseNo = await Supabase.instance.client.rpc('get_user_house_no');

    print("Variable houseNo is now: $houseNo");
  } catch (e) {
    debugPrint("Error fetching house_no: $e");
  }
}
  @override
  void initState() {
    super.initState();
    _fetchHouseNo();
  }
  

  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("RentMaster Pro", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [IconButton(onPressed: _signOut, icon: const Icon(Icons.logout))],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 25),
            
            // --- SECTION: MANAGEMENT HUB ---
            const Text("Management Hub", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 1.1,
              children: [
                _buildActionCard(
                  context,
                  title: "Tenants",
                  subtitle: "8 Active",
                  icon: Icons.people_alt_rounded,
                  color: Colors.blue,
                  onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TenantInfoPage(houseNo: houseNo ?? ""),
                      ),
                    );
                  }
                ),
                
                _buildActionCard(
                  context,
                  title: "Electricity",
                  subtitle: "View EB Consumption",
                  icon: Icons.electric_bolt_rounded,
                  color: Colors.orange,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => HouseHistoryPage(houseNo: houseNo ?? ""))),
                ),
              ],
            ),
            
            const SizedBox(height: 30),
           // --- SECTION: RECENT TRANSACTIONS ---
            const SizedBox(height: 10),
            _buildRecentPaymentsList(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.blue.shade700, Colors.blue.shade500]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const CircleAvatar(radius: 30, backgroundColor: Colors.white24, child: Icon(Icons.person, color: Colors.white, size: 35)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Welcome", style: TextStyle(color: Colors.white70, fontSize: 14)),
                Text(user?.userMetadata?['display_name'] ?? "User Account", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildRecentPaymentsList() {
  final supabase = Supabase.instance.client;

  return StreamBuilder<List<Map<String, dynamic>>>(
    // Using a stream so it updates in real-time
    stream: supabase
        .from('payment_history')
        .stream(primaryKey: ['id'])
        .order('payment_date', ascending: false)
        .limit(5),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      
      if (!snapshot.hasData || snapshot.data!.isEmpty) {
        return const Padding(
          padding: EdgeInsets.all(20.0),
          child: Text("No payments recorded yet.", style: TextStyle(color: Colors.grey)),
        );
      }

      final payments = snapshot.data!;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Recent Payment Received", 
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
          ),
          const SizedBox(height: 10),
          ListView.builder(
            shrinkWrap: true, // Important for use inside a SingleChildScrollView
            physics: const NeverScrollableScrollPhysics(),
            itemCount: payments.length,
            itemBuilder: (context, index) {
              final item = payments[index];
              final String house = item['house_no'] ?? 'N/A';
              final String amount = "₹${item['amount_paid']}";
              final String rawDate = item['payment_date'] ?? '';
              
              // Simple date formatting
              String displayDate = rawDate.split('T')[0]; 

              return _buildRecentPaymentTile("Unit $house", amount, displayDate);
            },
          ),
        ],
      );
    },
  );
}

Widget _buildRecentPaymentTile(String title, String amount, String date) {
  return Card(
    margin: const EdgeInsets.only(bottom: 10),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.green[100],
        child: const Icon(Icons.arrow_downward, color: Colors.green),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(date),
      trailing: Text(
        amount,
        style: const TextStyle(
          color: Colors.green, 
          fontWeight: FontWeight.bold, 
          fontSize: 16
        ),
      ),
    ),
  );
}
}

