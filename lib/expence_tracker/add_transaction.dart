import 'package:flutter/material.dart';
import 'models/db_helper.dart';

class AddTransactionPage extends StatefulWidget {
  const AddTransactionPage({super.key});

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  final DBHelper _dbHelper = DBHelper();

  String _transactionType = 'expense';
  int? _fromAccountId;
  int? _toAccountId;
  double _amount = 0;
  String _note = '';

  List<Map<String, dynamic>> _accounts = [];

  @override
  void initState() {
    super.initState();
    _loadAccounts();
    _loadLastUsedAccount();
  }

  Map<String, dynamic>? _getAccountById(int? id) {
  if (id == null) return null;
  return _accounts.firstWhere(
    (acc) => acc['id'] == id,
    orElse: () => {},
  );
}

  Future<void> _loadAccounts() async {
    final data = await _dbHelper.getAccounts();
    setState(() {
      _accounts = data;
    });
  }

  Future<void> _loadLastUsedAccount() async {
    final lastId = await _dbHelper.getLastUsedAccount();
    if (lastId != null) {
      setState(() {
        _fromAccountId = lastId;
      });
    }
  }

  List<Map<String, dynamic>> get cashAndBankAccounts =>
      _accounts.where((a) => a['type'] != 'credit').toList();

  List<Map<String, dynamic>> get creditCardAccounts =>
      _accounts.where((a) => a['type'] == 'credit').toList();

  Future<void> _saveTransaction() async {
  if (_fromAccountId == null || _amount <= 0) {
    _showError('Please select account and enter amount');
    return;
  }

  final fromAccount = _getAccountById(_fromAccountId);

  if (fromAccount == null || fromAccount.isEmpty) {
    _showError('Invalid account selected');
    return;
  }

  final String accountType = fromAccount['type'];
  final double balance =
      (fromAccount['balance'] as num).toDouble();

  /// 🚫 BALANCE CONSTRAINT (IMPORTANT)
  if (_transactionType == 'expense' &&
      (accountType == 'cash' || accountType == 'bank') &&
      _amount > balance) {
    _showError(
      'Insufficient balance.\nAvailable: ₹${balance.toStringAsFixed(2)}',
    );
    return;
  }

  if (_transactionType == 'credit_payment' &&
      (accountType == 'cash' || accountType == 'bank') &&
      _amount > balance) {
    _showError(
      'Insufficient balance to pay credit card bill.\nAvailable: ₹${balance.toStringAsFixed(2)}',
    );
    return;
  }

    if (_transactionType == 'credit_payment' && _toAccountId == null) {
      _showError('Please select credit card');
      return;
    }

    await _dbHelper.addTransaction(
      fromAccountId: _fromAccountId!,
      toAccountId:
          _transactionType == 'credit_payment' ? _toAccountId : null,
      amount: _amount,
      transactionType: _transactionType,
      note: _note,
    );

    await _dbHelper.setLastUsedAccount(_fromAccountId!);

    Navigator.pop(context, true);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> fromAccounts =
        _transactionType == 'credit_payment' || _transactionType == 'income'
            ? cashAndBankAccounts
            : _accounts;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Transaction')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            /// TRANSACTION TYPE
            DropdownButtonFormField<String>(
              value: _transactionType,
              items: const [
                DropdownMenuItem(
                    value: 'expense', child: Text('Expense')),
                DropdownMenuItem(
                    value: 'income', child: Text('Income')),
                DropdownMenuItem(
                    value: 'credit_payment',
                    child: Text('Credit Card Payment')),
              ],
              onChanged: (val) {
                setState(() {
                  _transactionType = val!;
                  _fromAccountId = null;
                  _toAccountId = null;
                });
              },
              decoration:
                  const InputDecoration(labelText: 'Transaction Type'),
            ),

            const SizedBox(height: 16),

            /// FROM ACCOUNT (SAFE)
            DropdownButtonFormField<int?>(
              value: fromAccounts.any(
                      (a) => a['id'] == _fromAccountId)
                  ? _fromAccountId
                  : null,
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Select account'),
                ),
                ...fromAccounts.map(
                  (acc) => DropdownMenuItem<int?>(
                    value: acc['id'],
                    child:
                        Text('${acc['name']} (${acc['balance']})'),
                  ),
                ),
              ],
              onChanged: (val) {
                setState(() {
                  _fromAccountId = val;
                });
              },
              decoration: InputDecoration(
                labelText:
                    _transactionType == 'income' ? 'To Account' : 'From Account',
              ),
            ),

            /// CREDIT CARD
            if (_transactionType == 'credit_payment') ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<int?>(
                value: creditCardAccounts.any(
                        (a) => a['id'] == _toAccountId)
                    ? _toAccountId
                    : null,
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Select credit card'),
                  ),
                  ...creditCardAccounts.map(
                    (acc) => DropdownMenuItem<int?>(
                      value: acc['id'],
                      child: Text(
                          '${acc['name']} (${acc['balance']})'),
                    ),
                  ),
                ],
                onChanged: (val) {
                  setState(() {
                    _toAccountId = val;
                  });
                },
                decoration:
                    const InputDecoration(labelText: 'Credit Card'),
              ),
            ],

            const SizedBox(height: 16),

            TextFormField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount'),
              onChanged: (val) =>
                  _amount = double.tryParse(val) ?? 0,
            ),

            const SizedBox(height: 16),

            TextFormField(
              decoration: const InputDecoration(labelText: 'Note'),
              onChanged: (val) => _note = val,
            ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _saveTransaction,
              child: const Text('Save Transaction'),
            ),
          ],
        ),
      ),
    );
  }
}
