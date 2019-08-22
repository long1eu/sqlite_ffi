// File created by
// Lung Razvan <long1eu>
// on 22/08/2019

import 'dart:convert';
import 'dart:ffi';

import 'arena.dart';

/// Represents a String in C memory, managed by an [Arena].
class Utf8 extends Struct<Utf8> {
  @Uint8()
  int char;

  /// Allocates a [CString] in the current [Arena] and populates it with
  /// [dartStr].
  static Pointer<Utf8> fromString(String dartStr) => Utf8.fromStringArena(Arena.current(), dartStr);

  /// Allocates a [CString] in [arena] and populates it with [dartStr].
  static Pointer<Utf8> fromStringArena(Arena arena, String dartStr) => arena.scoped(allocate(dartStr));

  /// Allocate a [CString] not managed in and populates it with [dartStr].
  ///
  /// This [CString] is not managed by an [Arena]. Please ensure to [free] the
  /// memory manually!
  static Pointer<Utf8> allocate(String dartStr) {
    final List<int> units = utf8.encode(dartStr);
    final Pointer<Utf8> str = Pointer<Utf8>.allocate(count: units.length + 1);
    for (int i = 0; i < units.length; ++i) {
      str.elementAt(i).load<Utf8>().char = units[i];
    }
    str.elementAt(units.length).load<Utf8>().char = 0;
    return str.cast();
  }

  /// Read the string for C memory into Dart.
  @override
  String toString() {
    final Pointer<Utf8> str = addressOf;
    // ignore: unrelated_type_equality_checks
    if (str == nullptr) {
      return null;
    }
    int len = 0;
    while (str.elementAt(++len).load<Utf8>().char != 0);
    final List<int> units = List<int>(len);
    for (int i = 0; i < len; ++i) {
      units[i] = str.elementAt(i).load<Utf8>().char;
    }
    return utf8.decode(units);
  }
}
