import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:synchronized/synchronized.dart';

class DatabaseHelper {
  // Singleton pattern for proper instance management
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  DatabaseHelper._privateConstructor();

  // Database filename and table constants
  static const String dbName = 'spendify.db';
  static const String tableName = 'transactions';

  // Internal connection instance and synchronized lock to prevent race conditions during initialization/write operations
  Database? _dbInstance;
  final Lock _lock = Lock();

  /// Exposes the single database connection. Initializes the connection if not already open.
  Future<Database> get database async {
    return await _lock.synchronized(() async {
      if (_dbInstance != null && _dbInstance!.isOpen) {
        return _dbInstance!;
      }
      
      _dbInstance = await _initDatabase();
      return _dbInstance!;
    });
  }

  /// Safely opens the database connection in a persistent application documents directory.
  Future<Database> _initDatabase() async {
    debugPrint("[DATABASE] Initializing SQLite database connection...");
    
    // Get application persistent documents directory (guaranteed not to be cleared/relocated by OS cleanup)
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, dbName);
    debugPrint("[DATABASE] SQLite persistent path: $path");

    return await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        debugPrint("[DATABASE] Creating table '$tableName'...");
        await db.execute('''
          CREATE TABLE $tableName (
            id TEXT PRIMARY KEY,
            fingerprint TEXT UNIQUE,
            amount TEXT,
            merchant TEXT,
            category TEXT,
            type TEXT,
            paymentMode TEXT,
            bank TEXT,
            sender TEXT,
            confidence INTEGER,
            autoAdded INTEGER,
            timestamp INTEGER,
            message TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        debugPrint("[DATABASE] Upgrading database from version $oldVersion to $newVersion...");
        if (oldVersion < 3) {
          await db.execute("DROP TABLE IF EXISTS $tableName");
          await db.execute('''
            CREATE TABLE $tableName (
              id TEXT PRIMARY KEY,
              fingerprint TEXT UNIQUE,
              amount TEXT,
              merchant TEXT,
              category TEXT,
              type TEXT,
              paymentMode TEXT,
              bank TEXT,
              sender TEXT,
              confidence INTEGER,
              autoAdded INTEGER,
              timestamp INTEGER,
              message TEXT
            )
          ''');
        }
      },
    );
  }

  /// Checks if an error is a SQLite readonly or lock relocation exception (code 1032 or similar)
  bool _isReadOnlyError(dynamic error) {
    if (error == null) return false;
    final errStr = error.toString().toLowerCase();
    return errStr.contains('readonly') || 
           errStr.contains('read-only') || 
           errStr.contains('1032') || 
           errStr.contains('code 1032') ||
           errStr.contains('sqlite_readonly');
  }

  /// INSERT TRANSACTION
  /// Inserts a transaction securely in a transaction block with auto-recovery on readonly exceptions.
  Future<void> insertTx(Map<String, dynamic> transaction) async {
    int attempts = 0;
    while (attempts < 2) {
      try {
        final db = await database;
        await db.transaction((txn) async {
          debugPrint("[DATABASE] Executing insert transaction inside transaction block (ID: ${transaction['id']}).");
          await txn.insert(
            tableName,
            transaction,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        });
        debugPrint("[DATABASE SUCCESS] Transaction (ID: ${transaction['id']}) inserted successfully.");
        return;
      } catch (e) {
        attempts++;
        debugPrint("[DATABASE WARNING] Error during insertTransaction (attempt $attempts): $e");
        
        if (_isReadOnlyError(e) && attempts < 2) {
          debugPrint("[DATABASE RECOVERY] SQLITE_READONLY/DBMOVED error detected! Initiating automatic recovery...");
          await closeDb();
          await Future.delayed(const Duration(milliseconds: 200));
          continue; // Retries by restarting the loop, which will re-fetch the database property inside lock
        } else {
          debugPrint("[DATABASE ERROR] insertTransaction failed permanently: $e");
          rethrow;
        }
      }
    }
  }

  /// GET ALL TRANSACTIONS
  Future<List<Map<String, dynamic>>> getTxList() async {
    int attempts = 0;
    while (attempts < 2) {
      try {
        final db = await database;
        debugPrint("[DATABASE] Querying all transactions ordered by timestamp.");
        return await db.query(
          tableName,
          orderBy: 'timestamp DESC',
        );
      } catch (e) {
        attempts++;
        debugPrint("[DATABASE WARNING] Error during getTransactions (attempt $attempts): $e");
        
        if (_isReadOnlyError(e) && attempts < 2) {
          debugPrint("[DATABASE RECOVERY] Readonly error in query. Recovering connection...");
          await closeDb();
          await Future.delayed(const Duration(milliseconds: 200));
          continue;
        } else {
          debugPrint("[DATABASE ERROR] getTransactions failed permanently: $e");
          rethrow;
        }
      }
    }
    return [];
  }

  /// CLEAR ALL TRANSACTIONS
  Future<void> clearTx() async {
    int attempts = 0;
    while (attempts < 2) {
      try {
        final db = await database;
        await db.transaction((txn) async {
          debugPrint("[DATABASE] Clearing all transactions.");
          await txn.delete(tableName);
        });
        debugPrint("[DATABASE SUCCESS] All transactions cleared successfully.");
        return;
      } catch (e) {
        attempts++;
        debugPrint("[DATABASE WARNING] Error during clearTransactions (attempt $attempts): $e");
        
        if (_isReadOnlyError(e) && attempts < 2) {
          debugPrint("[DATABASE RECOVERY] Readonly error in clear. Recovering connection...");
          await closeDb();
          await Future.delayed(const Duration(milliseconds: 200));
          continue;
        } else {
          debugPrint("[DATABASE ERROR] clearTransactions failed permanently: $e");
          rethrow;
        }
      }
    }
  }

  /// UPDATE TRANSACTION
  Future<void> updateTx(Map<String, dynamic> transaction) async {
    int attempts = 0;
    while (attempts < 2) {
      try {
        final db = await database;
        if (transaction['id'] != null) {
          await db.transaction((txn) async {
            debugPrint("[DATABASE] Updating transaction inside transaction block (ID: ${transaction['id']}).");
            await txn.update(
              tableName,
              transaction,
              where: 'id = ?',
              whereArgs: [transaction['id'].toString()],
            );
          });
          debugPrint("[DATABASE SUCCESS] Transaction (ID: ${transaction['id']}) updated successfully.");
        }
        return;
      } catch (e) {
        attempts++;
        debugPrint("[DATABASE WARNING] Error during updateTransaction (attempt $attempts): $e");
        
        if (_isReadOnlyError(e) && attempts < 2) {
          debugPrint("[DATABASE RECOVERY] Readonly error in update. Recovering connection...");
          await closeDb();
          await Future.delayed(const Duration(milliseconds: 200));
          continue;
        } else {
          debugPrint("[DATABASE ERROR] updateTransaction failed permanently: $e");
          rethrow;
        }
      }
    }
  }

  /// DELETE TRANSACTION
  Future<void> deleteTx(String id) async {
    int attempts = 0;
    while (attempts < 2) {
      try {
        final db = await database;
        await db.transaction((txn) async {
          debugPrint("[DATABASE] Deleting transaction inside transaction block (ID: $id).");
          await txn.delete(
            tableName,
            where: 'id = ?',
            whereArgs: [id],
          );
        });
        debugPrint("[DATABASE SUCCESS] Transaction (ID: $id) deleted successfully.");
        return;
      } catch (e) {
        attempts++;
        debugPrint("[DATABASE WARNING] Error during deleteTransaction (attempt $attempts): $e");
        
        if (_isReadOnlyError(e) && attempts < 2) {
          debugPrint("[DATABASE RECOVERY] Readonly error in delete. Recovering connection...");
          await closeDb();
          await Future.delayed(const Duration(milliseconds: 200));
          continue;
        } else {
          debugPrint("[DATABASE ERROR] deleteTransaction failed permanently: $e");
          rethrow;
        }
      }
    }
  }

  /// Safely closes the database connection.
  Future<void> closeDb() async {
    await _lock.synchronized(() async {
      if (_dbInstance != null) {
        try {
          if (_dbInstance!.isOpen) {
            debugPrint("[DATABASE] Closing SQLite connection...");
            await _dbInstance!.close();
            debugPrint("[DATABASE] SQLite connection closed successfully.");
          }
        } catch (e) {
          debugPrint("[DATABASE ERROR] Error during closeDb: $e");
        } finally {
          _dbInstance = null;
        }
      }
    });
  }

  /// Synchronously resets the instance variable (to allow database refresh/recreation safely).
  void resetDb() {
    debugPrint("[DATABASE] Resetting database singleton connection handle.");
    _dbInstance = null;
  }

  /// Safely deletes the database file from disk (capsule implementation for clean resets).
  Future<void> deleteDatabaseFile() async {
    await closeDb();
    resetDb();
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, dbName);
    final dbFile = File(path);
    if (await dbFile.exists()) {
      await dbFile.delete();
      debugPrint("[DATABASE SUCCESS] SQLite DB file deleted from disk successfully.");
    }
  }

  // =========================================================================
  // BACKWARD-COMPATIBLE STATIC WRAPPERS (To prevent breaking existing code)
  // =========================================================================

  /// Static getter wrapper for getDatabase()
  static Future<Database> getDatabase() => instance.database;

  /// Static insert wrapper
  static Future<void> insertTransaction(Map<String, dynamic> transaction) => instance.insertTx(transaction);

  /// Static query wrapper
  static Future<List<Map<String, dynamic>>> getTransactions() => instance.getTxList();

  /// Static clear wrapper
  static Future<void> clearTransactions() => instance.clearTx();

  /// Static reset wrapper (legacy resetDatabase)
  static void resetDatabase() => instance.resetDb();

  /// Static update wrapper
  static Future<void> updateTransaction(Map<String, dynamic> transaction) => instance.updateTx(transaction);

  /// Static delete wrapper
  static Future<void> deleteTransaction(String id) => instance.deleteTx(id);

  /// Static file deletion wrapper
  static Future<void> deleteDatabaseFileStatic() => instance.deleteDatabaseFile();
}