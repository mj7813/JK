import 'package:flutter/material.dart';
import 'models/db_helper.dart';

class AddAccountPage extends StatefulWidget {
  final Map<String, dynamic>? account;

  const AddAccountPage({super.key, this.account});

  @override
  State<AddAccountPage> createState() => _AddAccountPageState();
}

class _AddAccountPageState extends State<AddAccountPage> {
  final DBHelper _dbHelper = DBHelper();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _balanceController = TextEditingController();
  final TextEditingController _statementDayController = TextEditingController();
  final TextEditingController _dueDayController = TextEditingController();

  @override
  void initState() {
    super.initState();

    if (widget.account != null) {
      _nameController.text = widget.account!['name'];
      _accountType = widget.account!['type'];
      _balanceController.text =
          (widget.account!['balance'] as num).abs().toString();

      _statementDayController.text =
          widget.account!['statement_day']?.toString() ?? '';
      _dueDayController.text =
          widget.account!['due_day']?.toString() ?? '';
    }
  }

  String _accountType = 'cash'; // cash, bank, credit

  Future<void> _saveAccount() async {
    final name = _nameController.text.trim();
    final balance = double.tryParse(_balanceController.text) ?? 0;

    if (name.isEmpty) {
      _showError('Account name is required');
      return;
    }

    int? statementDay;
    int? dueDay;

    if (_accountType == 'credit') {
      statementDay =
          int.tryParse(_statementDayController.text);
      dueDay = int.tryParse(_dueDayController.text);

      if (statementDay == null ||
          dueDay == null ||
          statementDay < 1 ||
          statementDay > 31 ||
          dueDay < 1 ||
          dueDay > 31) {
        _showError('Enter valid statement & due days (1–31)');
        return;
      }
    }

    if (widget.account == null) {
      await _dbHelper.addAccount(
        name,
        _accountType,
        _accountType == 'credit' ? -balance.abs() : balance,
        statementDay: statementDay,
        dueDay: dueDay,
      );
    } else {
      final dbClient = await _dbHelper.db;
      await dbClient.update(
        'accounts',
        {
          'name': name,
          'type': _accountType,
          'balance':
              _accountType == 'credit' ? -balance.abs() : balance,
          'statement_day': statementDay,
          'due_day': dueDay,
        },
        where: 'id = ?',
        whereArgs: [widget.account!['id']],
      );
    }

    Navigator.pop(context, true);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.account == null ? 'Add Account' : 'Edit Account'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            /// ACCOUNT NAME
            TextField(
              controller: _nameController,
              decoration:
                  const InputDecoration(labelText: 'Account Name'),
            ),

            const SizedBox(height: 16),

            /// ACCOUNT TYPE
            DropdownButtonFormField<String>(
              initialValue: _accountType,
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'bank', child: Text('Bank')),
                DropdownMenuItem(
                    value: 'credit', child: Text('Credit Card')),
              ],
              onChanged: (val) {
                setState(() {
                  _accountType = val!;
                });
              },
              decoration:
                  const InputDecoration(labelText: 'Account Type'),
            ),

            const SizedBox(height: 16),

            /// OPENING BALANCE
            TextField(
              controller: _balanceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _accountType == 'credit'
                    ? 'Outstanding Amount'
                    : 'Opening Balance',
              ),
            ),

            /// CREDIT CARD EXTRA FIELDS
            if (_accountType == 'credit') ...[
              const SizedBox(height: 16),
              TextField(
                controller: _statementDayController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Statement Day (1–31)',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _dueDayController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Due Day (1–31)',
                ),
              ),
            ],

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _saveAccount,
              child: const Text('Save Account'),
            ),
          ],
        ),
      ),
    );
  }
}
