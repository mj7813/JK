import 'package:flutter/material.dart';
import 'add_transaction.dart';
import 'models/db_helper.dart';
import 'utils/finance_utils.dart';
import 'add_account.dart';
import 'account_transactions.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final DBHelper _dbHelper = DBHelper();
  DateTime? _startDate;
  DateTime? _endDate;
  int? _selectedAccountId;

  void _showAccountActions(Map<String, dynamic> acc) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Account'),
              onTap: () async {
                Navigator.pop(context);
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddAccountPage(account: acc),
                  ),
                );
                if (result == true) _loadDashboard();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Account'),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(acc);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTransactionActions(Map<String, dynamic> tx) {
  showModalBottomSheet(
    context: context,
    builder: (_) => SafeArea(
      child: ListTile(
        leading: const Icon(Icons.delete, color: Colors.red),
        title: const Text('Delete Transaction'),
        onTap: () {
          Navigator.pop(context);
          _confirmDeleteTransaction(tx);
        },
      ),
    ),
  );
}
  void _confirmDeleteTransaction(Map<String, dynamic> tx) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Delete Transaction'),
      content: const Text(
        'This will delete the transaction and rollback account balances.\n\nAre you sure?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            await _dbHelper
                .deleteTransactionWithRollback(tx['id']);
            _loadDashboard();
          },
          child: const Text(
            'Delete',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildRecentTransactions() {
  if (_recentTransactions.isEmpty) {
    return const Text(
      'No recent transactions',
      style: TextStyle(color: Colors.grey),
    );
  }

  return Column(
    children: _recentTransactions.map((tx) {
      final String type = tx['transaction_type'];
      final double amount = (tx['amount'] as num).toDouble();

      Color amountColor;
      String sign;
      String title;

      if (type == 'income') {
        amountColor = Colors.green;
        sign = '+';
        title = tx['from_account'] ?? 'Income';
      } else if (type == 'expense') {
        amountColor = Colors.red;
        sign = '-';
        title = tx['from_account'] ?? 'Expense';
      } else {
        amountColor = Colors.orange;
        sign = '';
        title =
            '${tx['from_account']} → ${tx['to_account']}';
      }

      return Card(
        child: ListTile(
          onLongPress: () => _showTransactionActions(tx),
          leading: Icon(
            type == 'income'
                ? Icons.arrow_downward
                : type == 'expense'
                    ? Icons.arrow_upward
                    : Icons.credit_card,
            color: amountColor,
          ),
          title: Text(title),
          subtitle: Text(
            tx['note']?.toString().isNotEmpty == true
                ? tx['note']
                : type,
          ),
          trailing: Text(
            '$sign₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              color: amountColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }).toList(),
  );
}
  
  void _confirmDelete(Map<String, dynamic> acc) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Delete Account'),
      content: Text(
        'Are you sure you want to delete "${acc['name']}"?\n\nAll related transactions will also be deleted.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            await _dbHelper.deleteAccount(acc['id']);
            _loadDashboard();
          },
          child:
              const Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}

void _openFilterSheet() {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Filter Transactions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 16),

          /// START DATE
          ListTile(
            leading: const Icon(Icons.date_range),
            title: Text(
              _startDate == null
                  ? 'Start Date'
                  : _startDate!.toLocal().toString().split(' ')[0],
            ),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
                initialDate: _startDate ?? DateTime.now(),
              );
              if (picked != null) {
                setState(() => _startDate = picked);
              }
            },
          ),

          /// END DATE
          ListTile(
            leading: const Icon(Icons.date_range),
            title: Text(
              _endDate == null
                  ? 'End Date'
                  : _endDate!.toLocal().toString().split(' ')[0],
            ),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
                initialDate: _endDate ?? DateTime.now(),
              );
              if (picked != null) {
                setState(() => _endDate = picked);
              }
            },
          ),

          /// ACCOUNT FILTER
          DropdownButtonFormField<int>(
            key: ValueKey(_selectedAccountId),
            initialValue: _selectedAccountId,
            hint: const Text('Select Account'),
            items: _accounts.map((acc) => DropdownMenuItem<int>(
              value: acc['id'],
              child: Text(acc['name']),
            )).toList(),
            onChanged: (val) {
              setState(() => _selectedAccountId = val);
            },
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _startDate = null;
                      _endDate = null;
                      _selectedAccountId = null;
                    });
                    Navigator.pop(context);
                    _loadFilteredTransactions();
                  },
                  child: const Text('Clear'),
                ),
              ),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _loadFilteredTransactions();
                  },
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
        ],
      ),
    ),
  );
}

  List<Map<String, dynamic>> _recentTransactions = [];
  List<Map<String, dynamic>> _accounts = [];

  double totalCashBank = 0;
  double totalCreditDue = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
  final accounts = await _dbHelper.getAccounts();
  final recentTx = await _dbHelper.getRecentTransactions(limit: 5);

  double cashBank = 0;
  double creditDue = 0;

  for (var acc in accounts) {
    final double balance = (acc['balance'] as num).toDouble();

    if (acc['type'] == 'credit') {
      creditDue += balance.abs();
    } else {
      cashBank += balance;
    }
  }

  setState(() {
    _accounts = accounts;
    _recentTransactions = recentTx;
    totalCashBank = cashBank;
    totalCreditDue = creditDue;
  });
}

Future<void> _loadFilteredTransactions() async {
  final filtered = await _dbHelper.getFilteredTransactions(
    startDate: _startDate,
    endDate: _endDate,
    accountId: _selectedAccountId,
  );

  setState(() {
    _recentTransactions = filtered;
  });
}

  Future<void> _goToAddTransaction() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddTransactionPage()),
    );

    if (result == true) {
      _loadDashboard();
    }
  }
  Future<void> _goToAddAccount() async {
  final result = await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const AddAccountPage()),
  );

  if (result == true) {
    _loadDashboard(); // refresh after adding account
  }
}

  Widget _summaryCard(String title, double amount, Color color) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              '₹ ${amount.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountTile(Map<String, dynamic> acc) {
    final double balance = (acc['balance'] as num).toDouble();
    final bool isCredit = acc['type'] == 'credit';

    Widget subtitle;

    if (isCredit) {
      final int dueDay = acc['due_day'] ?? 1;
      final int remainingDays =
          FinanceUtils.getRemainingDueDays(dueDay: dueDay);

      subtitle = Text(
        remainingDays > 0
            ? 'Due in $remainingDays days'
            : remainingDays == 0
                ? 'Due today'
                : 'Overdue',
        style: TextStyle(
          color: remainingDays <= 3 ? Colors.red : Colors.orange,
          fontWeight: FontWeight.w600,
        ),
      );
    } else {
      subtitle = Text(acc['type']);
    }

    return GestureDetector(
      onLongPress: () => _showAccountActions(acc),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AccountTransactionsPage(
              accountId: acc['id'],
              accountName: acc['name'],
            ),
          ),
        );
      },
    child: Card(
      child: ListTile(
        leading: Icon(
          isCredit ? Icons.credit_card : Icons.account_balance_wallet,
          color: isCredit ? Colors.red : Colors.green,
        ),
        title: Text(acc['name']),
        subtitle: subtitle,
        trailing: Text(
          '₹ ${balance.toStringAsFixed(2)}',
          style: TextStyle(
            color: isCredit ? Colors.red : Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter Transactions',
            onPressed: _openFilterSheet,
          ),
          IconButton(
            icon: const Icon(Icons.account_balance),
            tooltip: 'Add Account',
            onPressed: _goToAddAccount,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _goToAddTransaction,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            /// SUMMARY
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _summaryCard(
                  'Cash & Bank',
                  totalCashBank,
                  Colors.green,
                ),
                _summaryCard(
                  'Credit Due',
                  totalCreditDue,
                  Colors.red,
                ),
              ],
            ),

            const SizedBox(height: 24),

            /// ACCOUNTS LIST
            const Text(
              'Accounts',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 24),
            ..._accounts.map(_buildAccountTile),

            const SizedBox(height: 24),
            const Text(
              'Recent Transactions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            _buildRecentTransactions(),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
