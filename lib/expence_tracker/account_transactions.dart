import 'package:flutter/material.dart';
import 'models/db_helper.dart';

class AccountTransactionsPage extends StatefulWidget {
  final int accountId;
  final String accountName;

  const AccountTransactionsPage({
    super.key,
    required this.accountId,
    required this.accountName,
  });

  @override
  State<AccountTransactionsPage> createState() =>
      _AccountTransactionsPageState();
}

class _AccountTransactionsPageState
    extends State<AccountTransactionsPage> {
  final DBHelper _dbHelper = DBHelper();

  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final data =
        await _dbHelper.getTransactionsByAccount(widget.accountId);

    setState(() {
      _transactions = data;
    });
  }

  /// GROUP TRANSACTIONS BY DATE (dd-MM-yyyy)
  Map<String, List<Map<String, dynamic>>> _groupByDate(
    List<Map<String, dynamic>> transactions,
  ) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var tx in transactions) {
      final DateTime date =
          DateTime.parse(tx['date']).toLocal();

      final String key =
          '${date.day.toString().padLeft(2, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.year}';

      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(tx);
    }

    return grouped;
  }

  /// SINGLE TRANSACTION TILE
  Widget _buildTransactionTile(Map<String, dynamic> tx) {
    final double amount = (tx['amount'] as num).toDouble();
    final String type = tx['transaction_type'];

    Color color;
    IconData icon;
    String title;

    if (type == 'income') {
      color = Colors.green;
      icon = Icons.arrow_downward;
      title = tx['from_account'] ?? 'Income';
    } else if (type == 'expense') {
      color = Colors.red;
      icon = Icons.arrow_upward;
      title = tx['from_account'] ?? 'Expense';
    } else {
      color = Colors.orange;
      icon = Icons.credit_card;
      title =
          '${tx['from_account']} → ${tx['to_account']}';
    }

    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(
          tx['note']?.toString().isNotEmpty == true
              ? tx['note']
              : type,
        ),
        trailing: Text(
          '₹ ${amount.toStringAsFixed(2)}',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// DATE HEADER + TRANSACTIONS
  Widget _buildGroupedTransactions() {
    if (_transactions.isEmpty) {
      return const Center(
        child: Text(
          'No transactions found',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final grouped = _groupByDate(_transactions);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: grouped.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            /// DATE HEADER
            Text(
              entry.key,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),

            const SizedBox(height: 8),

            /// TRANSACTIONS FOR THIS DATE
            ...entry.value.map(_buildTransactionTile),
          ],
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.accountName),
      ),
      body: RefreshIndicator(
        onRefresh: _loadTransactions,
        child: _buildGroupedTransactions(),
      ),
    );
  }
}
