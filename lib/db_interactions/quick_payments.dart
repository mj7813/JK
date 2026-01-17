import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/db_interactions/generate_payments.dart';

class PaymentCollectionPage extends StatefulWidget {
  final String? houseNo;
  const PaymentCollectionPage({super.key, this.houseNo});

  @override
  State<PaymentCollectionPage> createState() => _PaymentCollectionPageState();
}

class _PaymentCollectionPageState extends State<PaymentCollectionPage> {
  final _supabase = Supabase.instance.client;
  final _paymentController = TextEditingController();
  final String? email = Supabase.instance.client.auth.currentUser?.email;

  // --- State Variables ---
  List<String> allHouses = [];
  Map<String, double> houseDebtMap = {}; // Stores total debt per house
  String? selectedHouse; 
  Map<String, dynamic>? billData;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.houseNo != null) {
      selectedHouse = widget.houseNo;
      _fetchBill(widget.houseNo!);
    } else {
      _loadHouseList();
    }
  }

  // 1. Load houses and calculate total outstanding debt for color coding
  Future<void> _loadHouseList() async {
    setState(() => isLoading = true);
    try {
      // Fetch House IDs and all payments with a balance in parallel
      final results = await Future.wait([
        _supabase.from('house_id').select('house_no').order('id', ascending: true),
        _supabase.from('payments').select('house_no, outstanding_balance').gt('outstanding_balance', 0),
      ]);

      final List houses = results[0] as List;
      final List payments = results[1] as List;

      // Map total debt to each house
      Map<String, double> tempDebtMap = {};
      for (var h in houses) {
        String hNo = h['house_no'].toString();
        double total = payments
            .where((p) => p['house_no'].toString() == hNo)
            .fold(0.0, (sum, item) => sum + (double.tryParse(item['outstanding_balance'].toString()) ?? 0.0));
        tempDebtMap[hNo] = total;
      }

      setState(() {
        allHouses = houses.map((e) => e['house_no'].toString()).toList();
        houseDebtMap = tempDebtMap;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showSnack("Error loading houses: $e");
    }
  }

  // 2. Fetch details for a specific house
  Future<void> _fetchBill(String houseNo) async {
    setState(() {
      selectedHouse = houseNo;
      isLoading = true;
    });
    try {
      final data = await _supabase
          .from('payments')
          .select('total_amount, amount_paid, outstanding_balance, billing_month, billing_year, house_no')
          .eq('house_no', houseNo)
          .order('billing_year', ascending: false)
          .order('billing_month', ascending: false)
          .limit(1)
          .maybeSingle();

      setState(() {
        billData = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showSnack("Error: $e");
    }
  }

  // 3. Update payment
  Future<void> _processUpdate() async {
    final double? entry = double.tryParse(_paymentController.text);
    if (entry == null || entry <= 0 || billData == null) return;

    setState(() => isLoading = true);

    try {
      double currentPaid = (billData!['amount_paid'] ?? 0).toDouble();
      double updatedPaid = currentPaid + entry;

      await Future.wait([
        _supabase.from('payments').update({
          'amount_paid': updatedPaid,
        }).eq('house_no', billData!['house_no'])
          .eq('billing_month', billData!['billing_month'])
          .eq('billing_year', billData!['billing_year']),

        _supabase.from('payment_history').insert({
          'house_no': billData!['house_no'],
          'billing_month': billData!['billing_month'],
          'billing_year': billData!['billing_year'],
          'amount_paid': entry,
          'payment_date': DateTime.now().toIso8601String(),
          'recorded_by': email,
        }),
      ]);

      _paymentController.clear();
      _showSnack("Payment logged successfully!");
      
      // Refresh both the specific bill and the background grid data
      await _fetchBill(billData!['house_no']);
      _loadHouseList(); 
    } catch (e) {
      _showSnack("Update failed: $e");
      setState(() => isLoading = false);
    }
  }

  void _showSnack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(selectedHouse == null ? "Select House" : "Collect Payment"),
        leading: selectedHouse != null 
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() {
                selectedHouse = null;
                billData = null;
              }),
            )
          : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const PaymentGenerationPage()));
            },
          )
        ],
      ),
      body: isLoading && allHouses.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : selectedHouse == null
              ? _buildHouseGrid() 
              : _buildPaymentForm(),
    );
  }

  // --- UI Component: Grid of House Numbers with Color Logic ---
  Widget _buildHouseGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.1,
      ),
      itemCount: allHouses.length,
      itemBuilder: (context, index) {
        final house = allHouses[index];
        final double debt = houseDebtMap[house] ?? 0.0;
        final bool hasOutstanding = debt > 0;

        return InkWell(
          onTap: () => _fetchBill(house),
          child: Card(
            elevation: 4,
            // RED if debt exists, GREEN if cleared
            color: hasOutstanding ? Colors.red[400] : Colors.green[400],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  house,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                if (hasOutstanding)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "₹${debt.toStringAsFixed(0)}",
                      style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  )
                else
                  const Icon(Icons.check_circle, color: Colors.white, size: 28),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- UI Component: Payment Input Form ---
  Widget _buildPaymentForm() {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (billData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text("No pending bills found for this house."),
            TextButton(
              onPressed: () => setState(() => selectedHouse = null),
              child: const Text("Go Back"),
            )
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildDisplayCard(),
          const SizedBox(height: 25),
          TextField(
            controller: _paymentController,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              labelText: "Enter Paid Amount",
              prefixText: "₹ ",
              border: OutlineInputBorder(),
              filled: true,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _processUpdate,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(60),
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("UPDATE PAYMENT", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDisplayCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              "House ${billData!['house_no']} (${billData!['billing_month']}/${billData!['billing_year']})",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 30),
            _infoRow("Total Bill:", "₹${billData!['total_amount']}"),
            _infoRow("Already Paid:", "₹${billData!['amount_paid']}", color: Colors.green),
            const Divider(height: 30),
            const Text("CURRENT OUTSTANDING", style: TextStyle(fontSize: 12, color: Colors.grey, letterSpacing: 1.2)),
            Text(
              "₹${billData!['outstanding_balance']}",
              style: const TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: Colors.redAccent),
            ),
          ],
        ),
      ),
    );
  }
  Widget _infoRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}