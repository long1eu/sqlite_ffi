// File created by
// Lung Razvan <long1eu>
// on 22/08/2019

import 'dart:collection';
import 'dart:ffi';

import 'bindings/bindings.dart';
import 'bindings/constants.dart';
import 'bindings/types.dart' as types;
import 'bindings/types.dart' hide Database;
import 'collections/closable_iterator.dart';
import 'ffi/utf8.dart';

/// [Database] represents an open connection to a SQLite database.
///
/// All functions against a database may throw [SQLiteError].
///
/// This database interacts with SQLite synchronously.
class Database {
  /// Open a database located at the file [path].
  Database(String path, [int flags = Flags.SQLITE_OPEN_READWRITE | Flags.SQLITE_OPEN_CREATE]) {
    final Pointer<Pointer<types.Database>> dbOut = Pointer<Pointer<types.Database>>.allocate();
    final Pointer<Utf8> pathC = Utf8.allocate(path);
    final int resultCode = bindings.sqlite3_open_v2(pathC, dbOut, flags, Pointer<Utf8>.fromAddress(0));
    print('resultCode: $resultCode');
    _database = dbOut.load();
    dbOut.free();
    pathC.free();

    if (resultCode == Errors.SQLITE_OK) {
      _open = true;
    } else {
      // Even if 'open' fails, sqlite3 will still create a database object. We
      // can just destroy it.
      final SQLiteException exception = _loadError(resultCode);
      close();
      throw exception;
    }
  }

  Pointer<types.Database> _database;
  bool _open = false;

  /// Close the database.
  ///
  /// This should only be called once on a database unless an exception is
  /// thrown. It should be called at least once to finalize the database and
  /// avoid resource leaks.
  void close() {
    assert(_open);
    final int resultCode = bindings.sqlite3_close_v2(_database);
    if (resultCode == Errors.SQLITE_OK) {
      _open = false;
    } else {
      throw _loadError(resultCode);
    }
  }

  /// Execute a query, discarding any returned rows.
  void execute(String query) {
    final Pointer<Pointer<Statement>> statementOut = Pointer<Pointer<Statement>>.allocate();
    final Pointer<Utf8> queryC = Utf8.allocate(query);
    int resultCode =
        bindings.sqlite3_prepare_v2(_database, queryC, -1, statementOut, Pointer<Pointer<Utf8>>.fromAddress(0));
    final Pointer<Statement> statement = statementOut.load();
    statementOut.free();
    queryC.free();

    while (resultCode == Errors.SQLITE_ROW || resultCode == Errors.SQLITE_OK) {
      resultCode = bindings.sqlite3_step(statement);
    }
    bindings.sqlite3_finalize(statement);
    if (resultCode != Errors.SQLITE_DONE) {
      throw _loadError(resultCode);
    }
  }

  /// Evaluate a query and return the resulting rows as an iterable.
  Result query(String query) {
    final Pointer<Pointer<Statement>> statementOut = Pointer<Pointer<Statement>>.allocate();
    final Pointer<Utf8> queryC = Utf8.allocate(query);
    final int resultCode =
        bindings.sqlite3_prepare_v2(_database, queryC, -1, statementOut, Pointer<Pointer<Utf8>>.fromAddress(0));
    final Pointer<Statement> statement = statementOut.load();
    statementOut.free();
    queryC.free();

    if (resultCode != Errors.SQLITE_OK) {
      bindings.sqlite3_finalize(statement);
      throw _loadError(resultCode);
    }

    final Map<String, int> columnIndices = <String, int>{};
    final int columnCount = bindings.sqlite3_column_count(statement);
    for (int i = 0; i < columnCount; i++) {
      final String columnName = bindings.sqlite3_column_name(statement, i).load<Utf8>().toString();
      columnIndices[columnName] = i;
    }

    return Result._(this, statement, columnIndices);
  }

  SQLiteException _loadError([int errorCode]) {
    final String errorMessage = bindings.sqlite3_errmsg(_database).load<Utf8>().toString();
    if (errorCode == null) {
      return SQLiteException(errorMessage);
    }
    final String errorCodeExplanation = bindings.sqlite3_errstr(errorCode).load<Utf8>().toString();
    return SQLiteException('$errorMessage (Code $errorCode: $errorCodeExplanation)');
  }
}

/// [Result] represents a [Database.query]'s result and provides an [Iterable]
/// interface for the results to be consumed.
///
/// Please note that this iterator should be [close]d manually if not all [Row]s
/// are consumed.
class Result extends IterableBase<Row> implements ClosableIterable<Row> {
  Result._(
    this._database,
    this._statement,
    this._columnIndices,
  ) : _iterator = _ResultIterator(_statement, _columnIndices);

  final Database _database;
  final ClosableIterator<Row> _iterator;
  final Pointer<Statement> _statement;
  final Map<String, int> _columnIndices;

  Row _currentRow;

  @override
  void close() => _iterator.close();

  @override
  ClosableIterator<Row> get iterator => _iterator;
}

class _ResultIterator implements ClosableIterator<Row> {
  _ResultIterator(this._statement, this._columnIndices);

  final Pointer<Statement> _statement;
  final Map<String, int> _columnIndices;

  Row _currentRow;
  bool _closed = false;

  @override
  bool moveNext() {
    if (_closed) {
      throw SQLiteException('The result has already been closed.');
    }
    _currentRow?._setNotCurrent();
    final int stepResult = bindings.sqlite3_step(_statement);
    if (stepResult == Errors.SQLITE_ROW) {
      _currentRow = Row._(_statement, _columnIndices);
      return true;
    } else {
      close();
      return false;
    }
  }

  @override
  Row get current {
    if (_closed) {
      throw SQLiteException('The result has already been closed.');
    }
    return _currentRow;
  }

  @override
  void close() {
    _currentRow?._setNotCurrent();
    _closed = true;
    bindings.sqlite3_finalize(_statement);
  }
}

class Row {
  Row._(this._statement, this._columnIndices);

  final Pointer<Statement> _statement;
  final Map<String, int> _columnIndices;

  bool _isCurrentRow = true;

  /// Reads column [columnName].
  ///
  /// By default it returns a dynamically typed value. If [convert] is set to
  /// [Convert.StaticType] the value is converted to the static type computed
  /// for the column by the query compiler.
  dynamic readColumn(String columnName, {Convert convert = Convert.DynamicType}) {
    return readColumnByIndex(_columnIndices[columnName], convert: convert);
  }

  /// Reads column [columnName].
  ///
  /// By default it returns a dynamically typed value. If [convert] is set to
  /// [Convert.StaticType] the value is converted to the static type computed
  /// for the column by the query compiler.
  dynamic readColumnByIndex(int columnIndex, {Convert convert = Convert.DynamicType}) {
    _checkIsCurrentRow();

    Type dynamicType;
    if (convert == Convert.DynamicType) {
      dynamicType = _typeFromCode(bindings.sqlite3_column_type(_statement, columnIndex));
    } else {
      dynamicType = _typeFromText(bindings.sqlite3_column_decltype(_statement, columnIndex).load<Utf8>().toString());
    }

    switch (dynamicType) {
      case Type.Integer:
        return readColumnByIndexAsInt(columnIndex);
      case Type.Text:
        return readColumnByIndexAsText(columnIndex);
      case Type.Null:
        return null;
        break;
      default:
    }
  }

  /// Reads column [columnName] and converts to [Type.Integer] if not an
  /// integer.
  int readColumnAsInt(String columnName) {
    return readColumnByIndexAsInt(_columnIndices[columnName]);
  }

  /// Reads column [columnIndex] and converts to [Type.Integer] if not an
  /// integer.
  int readColumnByIndexAsInt(int columnIndex) {
    _checkIsCurrentRow();
    return bindings.sqlite3_column_int(_statement, columnIndex);
  }

  /// Reads column [columnName] and converts to [Type.Text] if not text.
  String readColumnAsText(String columnName) {
    return readColumnByIndexAsText(_columnIndices[columnName]);
  }

  /// Reads column [columnIndex] and converts to [Type.Text] if not text.
  String readColumnByIndexAsText(int columnIndex) {
    _checkIsCurrentRow();
    return bindings.sqlite3_column_text(_statement, columnIndex).load<Utf8>().toString();
  }

  void _checkIsCurrentRow() {
    if (!_isCurrentRow) {
      throw Exception('This row is not the current row, reading data from the non-current'
          ' row is not supported by sqlite.');
    }
  }

  void _setNotCurrent() {
    _isCurrentRow = false;
  }
}

Type _typeFromCode(int code) {
  switch (code) {
    case Types.SQLITE_INTEGER:
      return Type.Integer;
    case Types.SQLITE_FLOAT:
      return Type.Float;
    case Types.SQLITE_TEXT:
      return Type.Text;
    case Types.SQLITE_BLOB:
      return Type.Blob;
    case Types.SQLITE_NULL:
      return Type.Null;
  }
  throw Exception('Unknown type [$code]');
}

Type _typeFromText(String textRepresentation) {
  switch (textRepresentation) {
    case 'integer':
      return Type.Integer;
    case 'float':
      return Type.Float;
    case 'text':
      return Type.Text;
    case 'blob':
      return Type.Blob;
    case 'null':
      return Type.Null;
  }
  if (textRepresentation == null) {
    return Type.Null;
  }
  throw Exception('Unknown type [$textRepresentation]');
}

enum Type { Integer, Float, Text, Blob, Null }

enum Convert { DynamicType, StaticType }

class SQLiteException {
  SQLiteException(this.message);

  final String message;

  @override
  String toString() => message;
}
