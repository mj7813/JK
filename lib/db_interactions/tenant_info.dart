import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../global/app_state.dart';
import '../payment_related/outstanding_view.dart';
import '../db_interactions/update_tenant.dart';

class TenantList extends StatefulWidget {
  const TenantList({super.key});

  @override
  State<TenantList> createState() => _TenantListState();
}

class _TenantListState extends State<TenantList> {
  final _supabase = Supabase.instance.client;

  // Realtime Stream: Automatically sorts by house_no and updates live
  late final Stream<List<Map<String, dynamic>>> _tenantStream;

  @override
  void initState() {
    super.initState();
    // Setting up the realtime stream with sorting
    _tenantStream = _supabase
        .from('tenant_details')
        .stream(primaryKey: ['id'])
        .order('id', ascending: true);
  }

  // Function to handle phone calls
  Future<void> _makePhoneCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) return;
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = AppState.instance.admin;
    return Scaffold(
      backgroundColor: Colors.grey[100], // Light grey background
      appBar: AppBar(
        title: const Text('Tenant Informations', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _tenantStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final tenants = snapshot.data ?? [];

          if (tenants.isEmpty) {
            return const Center(child: Text('No houses found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: tenants.length,
            itemBuilder: (context, index) {
              final tenant = tenants[index];
              final String name = tenant['tenant_name'] ?? 'Vacant';
              final String houseNo = tenant['house_no'] ?? 'N/A';
              final String? phone = tenant['contact_no']?.toString();
              final bool isVacant = name == 'Vacant';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: isVacant ? Colors.grey[300] : Colors.blue[100],
                    child: Icon(
                      isVacant ? Icons.home_outlined : Icons.person,
                      color: isVacant ? Colors.grey[600] : Colors.blue[800],
                    ),
                  ),
                  title: Text(
                    'House $houseNo',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        name,
                        style: TextStyle(
                          color: isVacant ? Colors.red[400] : Colors.black87,
                          fontWeight: isVacant ? FontWeight.normal : FontWeight.w500,
                        ),
                      ),
                      
                      if (!isVacant && phone != null) 
                        Text(phone, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ],
                  ),
                  
                  trailing: !isVacant && phone != null && isAdmin
                      ? IconButton(
                          icon: const Icon(Icons.call, color: Colors.green),
                          onPressed: () => _makePhoneCall(phone),
                        )
                      : const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                  onTap: () {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => TenantInfoPage(houseNo: houseNo, isEditable: false)));
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}






class TenantInfoPage extends StatefulWidget {
  final String houseNo;
  final bool isEditable;

  const TenantInfoPage({
    super.key,
    required this.houseNo,
    this.isEditable = true,
  });

  @override
  State<TenantInfoPage> createState() => _TenantInfoPageState();
}

class _TenantInfoPageState extends State<TenantInfoPage> {
  final _supabase = Supabase.instance.client;

  /// Fetches both Tenant Details and a summary of all Unpaid Bills
  Future<Map<String, dynamic>> _getPageData() async {
    final results = await Future.wait <dynamic>([
      // 1. Fetch Tenant Details
      _supabase
          .from('tenant_details')
          .select()
          .eq('house_no', widget.houseNo)
          .order('id', ascending: false)
          .limit(1)
          .maybeSingle(),

      // 2. Fetch all records with a balance to calculate total debt
      _supabase
          .from('payments')
          .select('outstanding_balance')
          .eq('house_no', widget.houseNo)
          .gt('outstanding_balance', 0),
    ]);

    final tenant = results[0] as Map<String, dynamic>?;
    final List unpaidRecords = results[1] as List;

    // Calculate Grand Total of all pending months
    double totalDebt = unpaidRecords.fold(0, (sum, item) => sum + (item['outstanding_balance'] ?? 0));

    return {
      'tenant': tenant,
      'total_outstanding': totalDebt,
      'unpaid_count': unpaidRecords.length,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('House ${widget.houseNo}'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          if (widget.isEditable)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => UpdateTenantForm(houseNo: widget.houseNo)));
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _getPageData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));

          final data = snapshot.data;
          final tenantData = data?['tenant'];
          final double totalOutstanding = data?['total_outstanding'] ?? 0.0;
          final int unpaidCount = data?['unpaid_count'] ?? 0;

          if (tenantData == null || tenantData['tenant_name'] == null) {
            return _buildVacantState();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildHeaderCard(tenantData),
                const SizedBox(height: 20),
                
                // Summary Billing Card with navigation to breakdown
                _buildSummaryBillingCard(totalOutstanding, unpaidCount),
                
                const SizedBox(height: 20),
                _buildDetailsCard(tenantData),
                const SizedBox(height: 20),
                _buildLeaseCard(tenantData),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- BILLING SUMMARY CARD ---
  Widget _buildSummaryBillingCard(double total, int count) {
    bool hasDebt = total > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: hasDebt ? Colors.red[50] : Colors.green[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: hasDebt ? Colors.red.shade200 : Colors.green.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("TOTAL OUTSTANDING", 
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: hasDebt ? Colors.red[900] : Colors.green[900])),
                  const SizedBox(height: 5),
                  Text("₹${total.toStringAsFixed(2)}",
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: hasDebt ? Colors.red[900] : Colors.green[900])),
                ],
              ),
              Icon(hasDebt ? Icons.warning_amber_rounded : Icons.check_circle, 
                   color: hasDebt ? Colors.red : Colors.green, size: 40),
            ],
          ),
          if (hasDebt) ...[
            const Divider(height: 30),
            ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => ArrearsDetailsPage(houseNo: widget.houseNo)));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Navigating to Breakdown...")));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[900],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size.fromHeight(50),
              ),
              child: Text("VIEW $count PENDING MONTHS"),
            ),
          ] else 
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text("All payments are up to date.", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  // --- EXISTING UI CARDS ---

  Widget _buildHeaderCard(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue[800],
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white.withValues(alpha: 0.24),
            child: const Icon(Icons.person, color: Colors.white, size: 35),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['tenant_name'] ?? 'N/A',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const Text('Current Tenant', style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.greenAccent[400], borderRadius: BorderRadius.circular(20)),
            child: const Text('ACTIVE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(Map<String, dynamic> data) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _infoRow(Icons.phone, 'Contact Number', data['contact_no']?.toString() ?? 'N/A'),
            const Divider(),
            _infoRow(Icons.people, 'Number of Persons', data['n_persons']?.toString() ?? '0'),
            const Divider(),
            _infoRow(Icons.account_balance_wallet, 'Advance Paid', '₹${data['advance_paid'] ?? 0}'),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaseCard(Map<String, dynamic> data) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Lease Period', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(child: _dateBox('Start Date', data['lease_start'] ?? 'N/A')),
                const Icon(Icons.arrow_forward, color: Colors.grey, size: 16),
                Expanded(child: _dateBox('End Date', data['lease_end'] ?? 'N/A')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue[800], size: 20),
          const SizedBox(width: 15),
          Text(label, style: const TextStyle(color: Colors.grey)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _dateBox(String label, String date) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 5),
        Text(date, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildVacantState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.house_outlined, size: 100, color: Colors.grey[300]),
          const SizedBox(height: 10),
          const Text('Currently Vacant', style: TextStyle(fontSize: 20, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          if (widget.isEditable)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white),
              onPressed: () {},
              child: const Text('Add Tenant Information'),
            )
        ],
      ),
    );
  }
}