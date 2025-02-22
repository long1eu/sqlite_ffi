// File created by
// Lung Razvan <long1eu>
// on 22/08/2019

/// This iterator should be [close]d after use.
///
/// [ClosableIterator]s often use resources which should be freed after use.
/// The consumer of the iterator can either manually [close] the iterator, or
/// consume all elements on which the iterator will automatically be closed.
abstract class ClosableIterator<T> extends Iterator<T> {
  /// Close this iterator.
  void close();

  /// Moves to the next element and [close]s the iterator if it was the last
  /// element.
  @override
  bool moveNext();
}

/// This iterable's iterator should be [close]d after use.
///
/// Companion class of [ClosableIterator].
abstract class ClosableIterable<T> extends Iterable<T> {
  /// Close this iterables iterator.
  void close();

  /// Returns a [ClosableIterator] that allows iterating the elements of this
  /// [ClosableIterable].
  @override
  ClosableIterator<T> get iterator;
}
