import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite_ffi/sqlite_ffi.dart' hide Row;
import 'package:sqlite_ffi/sqlite_ffi.dart' as sqlite show Row;

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _data;
  Database db;
  String path;
  bool tableCreate = false;
  bool tableInsert = false;

  Completer<void> initCompleter;
  Completer<void> operationsCompleter;

  @override
  void initState() {
    super.initState();
    initCompleter = Completer<void>();
    initDatabase();
  }

  Future<void> initDatabase() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final String path = '${dir.absolute.path}/test.db';
    db = Database(path);
    db.execute('drop table if exists Cookies;');
    setState(() => this.path = path);
    initCompleter.complete();
  }

  Future<void> createCookiesTable() async {
    if (!tableCreate) {
      db.execute('''
      create table Cookies (
        id integer primary key,
        name text not null,
        alternative_name text
      );''');

      setState(() => tableCreate = true);
    }
  }

  Future<void> insertIntoCookiesTable() async {
    if (!tableInsert) {
      db.execute('''
      insert into Cookies (id, name, alternative_name)
      values
        (1,'Chocolade chip cookie', 'Chocolade cookie'),
        (2,'Ginger cookie', null),
        (3,'Cinnamon roll', null);''');

      setState(() => tableInsert = true);
    }
  }

  Future<void> query() async {
    final Result result = db.query('''
      select
        id,
        name,
        alternative_name,
        case
          when id=1 then 'foo'
          when id=2 then 42
          when id=3 then null
        end as multi_typed_column
      from Cookies;''');

    final StringBuffer buffer = StringBuffer();
    for (sqlite.Row r in result) {
      final int id = r.readColumnAsInt('id');
      final String name = r.readColumnByIndex(1);
      final String alternativeName = r.readColumn('alternative_name');
      final dynamic multiTypedValue = r.readColumn('multi_typed_column');
      buffer.writeln('$id $name $alternativeName $multiTypedValue');
    }

    setState(() => _data = buffer.toString());
  }

  @override
  void dispose() {
    db.execute('drop table Cookies;');
    db.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Column(
          children: <Widget>[
            ListTile(
              title: Text(
                path != null ? 'Database created at:' : 'Creating db...',
              ),
              subtitle: path != null ? Text(path) : null,
              trailing: path != null ? Icon(Icons.check) : null,
            ),
            ListTile(
              title: Text(
                tableCreate ? 'Table created' : 'Tap to create table.',
              ),
              trailing: tableCreate ? Icon(Icons.check) : null,
              onTap: createCookiesTable,
            ),
            ListTile(
              title: Text(
                tableInsert ? 'Insert operation done' : 'Tap to insert into table.',
              ),
              trailing: tableInsert ? Icon(Icons.check) : null,
              onTap: insertIntoCookiesTable,
            ),
            ListTile(
              title: Text(
                _data == null ? 'Tap to read table.' : 'Done.',
              ),
              trailing: _data != null ? Icon(Icons.check) : null,
              onTap: query,
            ),
            if (_data != null) Text(_data),
          ],
        ),
      ),
    );
  }
}
