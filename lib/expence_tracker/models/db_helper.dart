import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

class DBHelper {
  static Database? _db;

  Future<void> setLastUsedAccount(int accountId) async {
  final dbClient = await db;
  await dbClient.insert(
    'settings',
    {'key': 'last_account_id', 'value': accountId.toString()},
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

Future<int?> getLastUsedAccount() async {
  final dbClient = await db;
  final result = await dbClient.query(
    'settings',
    where: 'key = ?',
    whereArgs: ['last_account_id'],
  );

  if (result.isEmpty) return null;
  return int.tryParse(result.first['value'] as String);
}

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await initDb();
    return _db!;
  }

  Future<Database> initDb() async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'expense_tracker.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        type TEXT,          -- cash, bank, credit
        balance REAL,
        statement_day INTEGER,
        due_day INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        from_account_id INTEGER,
        to_account_id INTEGER,
        amount REAL,
        transaction_type TEXT, -- expense, income, credit_payment
        note TEXT,
        date TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
  }

  // ================= ACCOUNTS =================

  Future<int> addAccount(
    String name,
    String type,
    double balance, {
    int? statementDay,
    int? dueDay,
  }) async {
    final dbClient = await db;
    return await dbClient.insert('accounts', {
      'name': name,
      'type': type,
      'balance': balance,
      'statement_day': statementDay,
      'due_day': dueDay,
    });
  }

  Future<List<Map<String, dynamic>>> getAccounts() async {
    final dbClient = await db;
    return await dbClient.query('accounts');
  }

  Future<void> deleteAccount(int accountId) async {
    final dbClient = await db;

    await dbClient.transaction((txn) async {
      // delete related transactions
      await txn.delete(
        'transactions',
        where: 'from_account_id = ? OR to_account_id = ?',
        whereArgs: [accountId, accountId],
      );

      // delete account
      await txn.delete(
        'accounts',
        where: 'id = ?',
        whereArgs: [accountId],
      );
    });
  }
  // ================= TRANSACTIONS =================

  Future<void> addTransaction({
    required int fromAccountId,
    int? toAccountId,
    required double amount,
    required String transactionType, // expense, income, credit_payment
    String? note,
  }) async {
    final dbClient = await db;

    await dbClient.transaction((txn) async {
      // Insert transaction
      await txn.insert('transactions', {
        'from_account_id': fromAccountId,
        'to_account_id': toAccountId,
        'amount': amount,
        'transaction_type': transactionType,
        'note': note,
        'date': DateTime.now().toIso8601String(),
      });

      // Fetch FROM account
      final fromAcc = (await txn.query(
        'accounts',
        where: 'id = ?',
        whereArgs: [fromAccountId],
      ))
          .first;

      double fromBalance = (fromAcc['balance'] as num).toDouble();

      // ========= EXPENSE =========
      if (transactionType == 'expense') {
        fromBalance -= amount;

        await txn.update(
          'accounts',
          {'balance': fromBalance},
          where: 'id = ?',
          whereArgs: [fromAccountId],
        );
      }

      // ========= INCOME =========
      else if (transactionType == 'income') {
        fromBalance += amount;

        await txn.update(
          'accounts',
          {'balance': fromBalance},
          where: 'id = ?',
          whereArgs: [fromAccountId],
        );
      }

      // ========= CREDIT CARD PAYMENT =========
      else if (transactionType == 'credit_payment') {
        // Reduce cash/bank
        fromBalance -= amount;

        // Fetch credit card
        final toAcc = (await txn.query(
          'accounts',
          where: 'id = ?',
          whereArgs: [toAccountId],
        ))
            .first;

        double toBalance = (toAcc['balance'] as num).toDouble();
        toBalance += amount; // reduce debt

        await txn.update(
          'accounts',
          {'balance': fromBalance},
          where: 'id = ?',
          whereArgs: [fromAccountId],
        );

        await txn.update(
          'accounts',
          {'balance': toBalance},
          where: 'id = ?',
          whereArgs: [toAccountId],
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> getTransactions() async {
    final dbClient = await db;
    return await dbClient.query(
      'transactions',
      orderBy: 'date DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getFilteredTransactions({
  DateTime? startDate,
  DateTime? endDate,
  int? accountId,
}) async {
  final dbClient = await db;

  String whereClause = '';
  List<dynamic> args = [];

  if (startDate != null) {
    whereClause += 'date >= ?';
    args.add(startDate.toIso8601String());
  }

  if (endDate != null) {
    if (whereClause.isNotEmpty) whereClause += ' AND ';
    whereClause += 'date <= ?';
    args.add(endDate.toIso8601String());
  }

  if (accountId != null) {
    if (whereClause.isNotEmpty) whereClause += ' AND ';
    whereClause += '(from_account_id = ? OR to_account_id = ?)';
    args.add(accountId);
    args.add(accountId);
  }

  return await dbClient.rawQuery('''
    SELECT 
      t.id,
      t.amount,
      t.transaction_type,
      t.note,
      t.date,
      a1.name AS from_account,
      a2.name AS to_account
    FROM transactions t
    LEFT JOIN accounts a1 ON t.from_account_id = a1.id
    LEFT JOIN accounts a2 ON t.to_account_id = a2.id
    ${whereClause.isNotEmpty ? 'WHERE $whereClause' : ''}
    ORDER BY t.date DESC
  ''', args);
}

  Future<List<Map<String, dynamic>>> getRecentTransactions({int limit = 5}) async {
  final dbClient = await db;

  return await dbClient.rawQuery('''
    SELECT 
      t.id,
      t.amount,
      t.transaction_type,
      t.note,
      t.date,
      a1.name AS from_account,
      a2.name AS to_account
    FROM transactions t
    LEFT JOIN accounts a1 ON t.from_account_id = a1.id
    LEFT JOIN accounts a2 ON t.to_account_id = a2.id
    ORDER BY t.date DESC
    LIMIT ?
  ''', [limit]);
}

    // ============== Delete Transaction + Rollback ==============
Future<void> deleteTransactionWithRollback(int transactionId) async {
  final dbClient = await db;

  await dbClient.transaction((txn) async {
    // 1️⃣ Get transaction
    final tx = (await txn.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [transactionId],
    ))
        .first;

    final double amount = (tx['amount'] as num).toDouble();
    final String type = tx['transaction_type'] as String;
    final int fromId = tx['from_account_id'] as int;
    final int? toId = tx['to_account_id'] as int?;

    // 2️⃣ Fetch FROM account
    final fromAcc = (await txn.query(
      'accounts',
      where: 'id = ?',
      whereArgs: [fromId],
    ))
        .first;

    double fromBalance =
        (fromAcc['balance'] as num).toDouble();

    // 3️⃣ Rollback logic
    if (type == 'expense') {
      fromBalance += amount;
    } else if (type == 'income') {
      fromBalance -= amount;
    } else if (type == 'credit_payment') {
      fromBalance += amount;

      final toAcc = (await txn.query(
        'accounts',
        where: 'id = ?',
        whereArgs: [toId],
      ))
          .first;

      double toBalance =
          (toAcc['balance'] as num).toDouble();

      toBalance -= amount;

      await txn.update(
        'accounts',
        {'balance': toBalance},
        where: 'id = ?',
        whereArgs: [toId],
      );
    }

    // 4️⃣ Update FROM account
    await txn.update(
      'accounts',
      {'balance': fromBalance},
      where: 'id = ?',
      whereArgs: [fromId],
    );

    // 5️⃣ Delete transaction
    await txn.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [transactionId],
    );
  });
}

  // ============== Get Transactions by Account ==============
Future<List<Map<String, dynamic>>> getTransactionsByAccount(int accountId) async {
  final dbClient = await db;

  return await dbClient.rawQuery('''
    SELECT 
      t.id,
      t.amount,
      t.transaction_type,
      t.note,
      t.date,
      a1.name AS from_account,
      a2.name AS to_account
    FROM transactions t
    LEFT JOIN accounts a1 ON t.from_account_id = a1.id
    LEFT JOIN accounts a2 ON t.to_account_id = a2.id
    WHERE t.from_account_id = ? OR t.to_account_id = ?
    ORDER BY t.date DESC
  ''', [accountId, accountId]);
}

}
