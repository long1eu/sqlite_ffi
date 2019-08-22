// File created by
// Lung Razvan <long1eu>
// on 22/08/2019

import 'dart:ffi' as ffi;
import 'dart:io' show Platform;

String _platformPath(String name, {String path}) {
  path ??= '';

  if (Platform.isLinux || Platform.isAndroid)
    return path + 'lib' + name + '.so';
  if (Platform.isMacOS || Platform.isIOS)
    return path + 'lib' + name + '.dylib';
  if (Platform.isWindows)
    return path + name + '.dll';

  throw Exception('Platform not implemented');
}

ffi.DynamicLibrary dlopenPlatformSpecific(String name, {String path}) {
  final String fullPath = _platformPath(name, path: path);
  return ffi.DynamicLibrary.open(fullPath);
}
