import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {

  static Database? _database;

  static const String tableName = 'transactions';

  static Future<Database> getDatabase() async {

    if (_database != null) {
      return _database!;
    }

    final databasePath = await getDatabasesPath();

    final path = join(databasePath, 'spendify.db');

    _database = await openDatabase(

      path,

      version: 1,

      onCreate: (db, version) async {

        await db.execute('''

          CREATE TABLE $tableName (

            id INTEGER PRIMARY KEY AUTOINCREMENT,

            amount TEXT,
            merchant TEXT,
            type TEXT,
            paymentMode TEXT,
            bank TEXT,
            sender TEXT,
            confidence INTEGER,
            timestamp INTEGER,
            message TEXT
          )

        ''');
      },
    );

    return _database!;
  }

  // INSERT TRANSACTION

  static Future<void> insertTransaction(
      Map<String, dynamic> transaction) async {

    final db = await getDatabase();

    await db.insert(
      tableName,
      transaction,
    );
  }

  // GET ALL TRANSACTIONS

  static Future<List<Map<String, dynamic>>>
      getTransactions() async {

    final db = await getDatabase();

    return await db.query(
      tableName,
      orderBy: 'timestamp DESC',
    );
  }

  // DELETE ALL

  static Future<void> clearTransactions() async {

    final db = await getDatabase();

    await db.delete(tableName);
  }

  // UPDATE TRANSACTION

  static Future<void> updateTransaction(
      Map<String, dynamic> transaction) async {

    final db = await getDatabase();

    if (transaction['id'] != null) {
      await db.update(
        tableName,
        transaction,
        where: 'id = ?',
        whereArgs: [transaction['id']],
      );
    }
  }

  // DELETE TRANSACTION

  static Future<void> deleteTransaction(int id) async {

    final db = await getDatabase();

    await db.delete(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}