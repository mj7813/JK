import 'package:supabase_flutter/supabase_flutter.dart';

class DbService {
  DbService._();
  static final DbService instance = DbService._();

  final SupabaseClient _supabase = Supabase.instance.client;

  bool _loaded = false;

  // ===== IN-MEMORY CACHE =====
  List<Map<String, dynamic>> _houses = [];
  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _readings = [];
  List<Map<String, dynamic>> _tenants = [];

  // ===== INITIAL LOAD =====
  Future<void> load() async {
    if (_loaded) return;

    final results = await Future.wait([
      _supabase.from('house_id').select(),
      _supabase.from('payments').select(),
      _supabase.from('elect_readings').select(),
      _supabase.from('tenant_details').select(),
    ]);

    _houses = List<Map<String, dynamic>>.from(results[0]);
    _payments = List<Map<String, dynamic>>.from(results[1]);
    _readings = List<Map<String, dynamic>>.from(results[2]);
    _tenants = List<Map<String, dynamic>>.from(results[3]);

    _loaded = true;
  }

  // ===== FORCE REFRESH (after save/update) =====
  Future<void> refresh() async {
    _loaded = false;
    await load();
  }

  // ===== GETTERS (READ ONLY) =====
  List<Map<String, dynamic>> get houses => _houses;
  List<Map<String, dynamic>> get payments => _payments;
  List<Map<String, dynamic>> get readings => _readings;
  List<Map<String, dynamic>> get tenants => _tenants;

  // ===== COMMON HELPERS =====

  /// EB enabled houses only
  List<Map<String, dynamic>> get ebHouses =>
      _houses.where((h) => h['EB'] == true).toList();

  /// EB enabled house numbers
  Set<String> get ebHouseNumbers =>
      ebHouses.map((h) => h['house_number'].toString()).toSet();

  /// Outstanding balance grouped by house
  Map<String, double> getOutstandingByHouse() {
    final Map<String, double> result = {};

    for (final p in _payments) {
      final houseNo = p['house_no']?.toString();
      if (houseNo == null) continue;

      final balance =
          double.tryParse(p['outstanding_balance']?.toString() ?? '0') ?? 0;

      result[houseNo] = (result[houseNo] ?? 0) + balance;
    }

    return result;
  }

  /// Get tenant by house
  Map<String, dynamic>? getTenant(String houseNo) {
    try {
      return _tenants.firstWhere((t) => t['house_no'] == houseNo);
    } catch (_) {
      return null;
    }
  }
}
