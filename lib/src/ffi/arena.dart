// File created by
// Lung Razvan <long1eu>
// on 22/08/2019

import 'dart:async';
import 'dart:ffi';

/// [Arena] manages allocated C memory.
///
/// Arenas are zoned.
class Arena {
  Arena();

  /// The last [Arena] in the zone.
  factory Arena.current() {
    return Zone.current[#_currentArena];
  }

  final List<Pointer<Void>> _allocations = <Pointer<Void>>[];

  /// Bound the lifetime of [ptr] to this [Arena].
  T scoped<T extends Pointer<Void>>(T ptr) {
    _allocations.add(ptr.cast());
    return ptr;
  }

  /// Frees all memory pointed to by [Pointer]s in this arena.
  void finalize() {
    for (final Pointer<Void> ptr in _allocations) {
      ptr.free();
    }
  }
}

/// Bound the lifetime of [ptr] to the current [Arena].
T scoped<T extends Pointer<Void>>(T ptr) => Arena.current().scoped(ptr);

class RethrownError {
  RethrownError(this.original, this.originalStackTrace);

  dynamic original;
  StackTrace originalStackTrace;

  @override
  String toString() => 'RethrownError($original)\n$originalStackTrace';
}

/// Runs the [body] in an [Arena] freeing all memory which is [scoped] during
/// execution of [body] at the end of the execution.
R runArena<R>(R Function(Arena) body) {
  final Arena arena = Arena();
  try {
    return runZoned(() => body(arena),
        zoneValues: <Symbol, Arena>{#_currentArena: arena},
        onError: (dynamic error, StackTrace st) => throw RethrownError(error, st));
  } finally {
    arena.finalize();
  }
}
