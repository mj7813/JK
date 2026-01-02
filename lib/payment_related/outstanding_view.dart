import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/global/app_state.dart';
import '../db_interactions/quick_payments.dart';

class ArrearsDetailsPage extends StatelessWidget {
  final String houseNo;
  const ArrearsDetailsPage({super.key, required this.houseNo});

  Future<List<Map<String, dynamic>>> _fetchUnpaidBills() async {
    final List<dynamic> response = await Supabase.instance.client
        .rpc('get_unpaid_bills', params: {'target_house_no': houseNo});
    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = AppState.instance.admin;
    return Scaffold(
    appBar: AppBar(
      title: Text("Pending Payments - $houseNo"),
      actions: [
        // Only show the Pay button if the user is an admin
        if (isAdmin)
          IconButton(
            icon: const Icon(Icons.payment, color: Colors.green),
            tooltip: 'Collect Payment',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PaymentCollectionPage(houseNo: houseNo),
                ),
              );
            },
          ),
        const SizedBox(width: 8),
      ],
    ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchUnpaidBills(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final bills = snapshot.data!;
          
          if (bills.isEmpty) {
            return const Center(child: Text("All bills are fully paid!"));
          }

          // Calculate Grand Total
          double grandTotal = bills.fold(0, (sum, item) => sum + (item['outstanding_balance'] ?? 0));

          return Column(
            children: [
              // GRAND TOTAL SUMMARY CARD
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red[900],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Text("TOTAL OUTSTANDING", style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text("₹${grandTotal.toStringAsFixed(2)}", 
                         style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                    Text("Across ${bills.length} pending months", style: const TextStyle(color: Colors.white60)),
                  ],
                ),
              ),
              
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Align(alignment: Alignment.centerLeft, child: Text("Breakdown by Month", style: TextStyle(fontWeight: FontWeight.bold))),
              ),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: bills.length,
                  itemBuilder: (context, index) {
                    final bill = bills[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.red[50],
                          child: Text("${bill['billing_month']}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        ),
                        title: Text("Month ${bill['billing_month']}, ${bill['billing_year']}"),
                        subtitle: Text("Bill: ₹${bill['total_amount']} | Paid: ₹${bill['amount_paid']}"),
                        trailing: Text(
                          "₹${bill['outstanding_balance']}",
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}