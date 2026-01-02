import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UpdateTenantForm extends StatefulWidget {
  final String houseNo;
  const UpdateTenantForm({super.key, required this.houseNo});

  @override
  State<UpdateTenantForm> createState() => _UpdateTenantFormState();
}

class _UpdateTenantFormState extends State<UpdateTenantForm> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  // --- Controllers for ALL fields including Missing Lease Dates ---
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _advanceController = TextEditingController();
  final _personsController = TextEditingController();
  final _leasestartController = TextEditingController(); // Added
  final _leaseendController = TextEditingController();   // Added
  
  // Property fields
  final _roomsController = TextEditingController();
  final _rentController = TextEditingController();
  final _waterController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    try {
      final tenantData = await _supabase.from('tenant_details').select().eq('house_no', widget.houseNo).maybeSingle();
      final houseData = await _supabase.from('house_id').select().eq('house_no', widget.houseNo).maybeSingle();

      if (mounted && tenantData != null) {
        setState(() {
          _nameController.text = tenantData['tenant_name']?.toString() ?? '';
          _phoneController.text = tenantData['contact_no']?.toString() ?? '';
          _advanceController.text = tenantData['advance_paid']?.toString() ?? '';
          _personsController.text = tenantData['n_persons']?.toString() ?? '';
          _leasestartController.text = tenantData['lease_start']?.toString() ?? '';
          _leaseendController.text = tenantData['lease_end']?.toString() ?? '';
          
          if (houseData != null) {
            _roomsController.text = houseData['rooms']?.toString() ?? '';
            _rentController.text = houseData['rent']?.toString() ?? '';
            _waterController.text = houseData['water']?.toString() ?? '';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        controller.text = picked.toString().split(' ').first; // Format: YYYY-MM-DD
      });
    }
  }

  Future<void> _processUpdate({required bool isClearing}) async {
    setState(() => _isLoading = true);

    try {
      // 1. Verify existence
      final tenantCheck = await _supabase.from('tenant_details').select('house_no').eq('house_no', widget.houseNo).maybeSingle();

      if (tenantCheck == null) {
        await _supabase.from('audit_logs').insert({
          'house_no': widget.houseNo,
          'action_performed': isClearing ? 'CLEAR' : 'UPDATE',
          'status': 'FAILED - HOUSE NOT FOUND',
        });
        throw Exception("House ${widget.houseNo} does not exist in the database.");
      }

      // 2. Perform Update (Strictly eq house_no)
      await _supabase.from('tenant_details').update({
        'tenant_name': isClearing ? null : _nameController.text,
        'contact_no': isClearing ? null : num.tryParse(_phoneController.text),
        'advance_paid': isClearing ? null : (int.tryParse(_advanceController.text) ?? 0),
        'n_persons': isClearing ? null : (int.tryParse(_personsController.text) ?? 0),
        'lease_start': isClearing ? null : _leasestartController.text, // Re-added
        'lease_end': isClearing ? null : _leaseendController.text,     // Re-added
      }).eq('house_no', widget.houseNo);

      if (!isClearing) {
        await _supabase.from('house_id').update({
          'rooms': int.tryParse(_roomsController.text) ?? 0,
          'rent': int.tryParse(_rentController.text) ?? 0,
          'water': int.tryParse(_waterController.text) ?? 0,
        }).eq('house_no', widget.houseNo);
      }

      await _supabase.from('audit_logs').insert({
        'house_no': widget.houseNo,
        'tenant_name': _nameController.text,
        'contact_no': _phoneController.text,
        'advance_paid': _advanceController.text,
        'lease_start': _leasestartController.text,
        'lease_end': _leaseendController.text,
        'action_performed': isClearing ? 'CLEAR' : 'UPDATE',
        'status': 'SUCCESS',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Database Updated')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showErrorDialog(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Error"),
        content: Text(msg.replaceAll("Exception: ", "")),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('House ${widget.houseNo}')),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _field(_nameController, "Tenant Name", Icons.person),
            _field(_phoneController, "Contact", Icons.phone, isNum: true),
            _field(_advanceController, "Advance", Icons.payments, isNum: true),
            _field(_personsController, "Number of Persons", Icons.group, isNum: true),
            
            // --- Missing Date Fields Added Here ---
            _datePickerField(_leasestartController, "Lease Start Date"),
            _datePickerField(_leaseendController, "Lease End Date"),
            
            const Divider(height: 30),
            _field(_roomsController, "Rooms", Icons.meeting_room, isNum: true),
            _field(_rentController, "Rent", Icons.currency_rupee, isNum: true),
            _field(_waterController, "Water", Icons.water_drop, isNum: true),
            
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: Colors.blue[800]),
              onPressed: () => _processUpdate(isClearing: false),
              child: const Text("SAVE CHANGES", style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: () => _processUpdate(isClearing: true),
              child: const Text("CLEAR TENANT (VACATE)", style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String l, IconData i, {bool isNum = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: c,
        keyboardType: isNum ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(labelText: l, prefixIcon: Icon(i), border: const OutlineInputBorder()),
      ),
    );
  }

  Widget _datePickerField(TextEditingController c, String l) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: c,
        readOnly: true,
        onTap: () => _selectDate(context, c),
        decoration: InputDecoration(
          labelText: l,
          prefixIcon: const Icon(Icons.calendar_today),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}