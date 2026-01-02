import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentService {
  final _supabase = Supabase.instance.client;

  // 1. Fetch data from the RPC function
  Future<List<Map<String, dynamic>>> getGeneratedBillData(int month, int year) async {
    final List<dynamic> response = await _supabase.rpc(
      'get_full_property_details',
      params: {'p_month': month, 'p_year': year},
    );
    return List<Map<String, dynamic>>.from(response);
  }

  // 2. Save/Upsert data into the payments table
  Future<void> saveBillsToDatabase(List<Map<String, dynamic>> orderedPreviewData, int month, int year) async {
  // The map function preserves the index/order of the original list
  final List<Map<String, dynamic>> records = orderedPreviewData.map((item) {
    return {
      'house_no': item['house_number'], // Ensure this matches your Table Column name
      'tenant_name': item['tenant_name'],
      'billing_month': month.toString(),
      'billing_year': year.toString(),
      'electricity_cost': item['electricity_cost'],
      'water_cost': item['water_charge'],
      'rent_cost': item['rent_charge'],
      'amount_paid': 0,
      'status': 'unpaid',
    };
  }).toList();

  // Performing a single upsert with the ordered list
  await _supabase.from('payments').upsert(
    records,
    onConflict: 'house_no, billing_month, billing_year',
  );
}
}