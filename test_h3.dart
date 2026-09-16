import 'dart:mirrors';
import 'package:h3_ffi/h3_ffi.dart';

void main() {
  final h3 = const H3FfiFactory().build(); 
  // Wait, I can't guess the class name.
  print('done');
}
