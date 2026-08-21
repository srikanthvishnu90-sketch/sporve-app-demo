import 'dart:convert';
import 'dart:io';

Iterable<File> dartFiles(String root) sync* {
  for (final entity in Directory(root).listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) yield entity;
  }
}

Never fail(String message) {
  stderr.writeln('FAIL: $message');
  exitCode = 1;
  throw StateError(message);
}

Set<String> extract(RegExp pattern) {
  final result = <String>{};
  for (final file in dartFiles('lib')) {
    result.addAll(
      pattern
          .allMatches(file.readAsStringSync())
          .map((match) => match.group(1)!),
    );
  }
  return result;
}

void main() {
  final functionsJson =
      jsonDecode(File('contracts/backend_functions.json').readAsStringSync())
          as Map<String, dynamic>;
  final registeredFunctions = (functionsJson['functions'] as Map).keys
      .map((name) => name.toString())
      .toSet();
  final invokedFunctions = extract(
    RegExp(r'''\.functions\s*\.invoke\s*\(\s*['"]([^'"]+)['"]'''),
  );
  final missingFunctions = invokedFunctions.difference(registeredFunctions);
  if (missingFunctions.isNotEmpty) {
    fail('Unregistered Edge Functions: $missingFunctions');
  }

  final rpcsJson =
      jsonDecode(File('contracts/backend_rpcs.json').readAsStringSync())
          as Map<String, dynamic>;
  final registeredRpcs = (rpcsJson['rpcs'] as List)
      .map((name) => name.toString())
      .toSet();
  final invokedRpcs = extract(RegExp(r'''\.rpc\s*\(\s*['"]([^'"]+)['"]'''));
  final missingRpcs = invokedRpcs.difference(registeredRpcs);
  if (missingRpcs.isNotEmpty) fail('Unregistered RPCs: $missingRpcs');

  final presentation = dartFiles(
    'lib/presentation',
  ).map((file) => file.readAsStringSync()).join('\n');
  if (RegExp(r'Color\s*\(\s*0x', caseSensitive: false).hasMatch(presentation)) {
    fail('Raw Color hex found in presentation code.');
  }
  if (RegExp(
    r'''import\s+['"]package:supabase_flutter|Supabase\.instance''',
  ).hasMatch(presentation)) {
    fail('Presentation code bypasses AppRepository for Supabase.');
  }

  final allLib = dartFiles(
    'lib',
  ).map((file) => file.readAsStringSync()).join('\n');
  if (RegExp(r'catch\s*\(\s*_\s*\)').hasMatch(allLib)) {
    fail('Anonymous catch found in lib/.');
  }
  if (allLib.contains('markBookingPaid')) {
    fail('Client payment-status shortcut found.');
  }
  if (RegExp(
    r'''update\s*\(\s*\{[^}]*['"]payment_status['"]''',
    dotAll: true,
  ).hasMatch(allLib)) {
    fail('Client payment_status update found.');
  }
  final supabaseSource = File(
    'lib/core/data/supabase_repository.dart',
  ).readAsStringSync();
  if (RegExp(r'''['"]payment_status['"]\s*:''').hasMatch(supabaseSource)) {
    fail('Client-authored payment_status value found.');
  }
  final bookingFlow = File(
    'lib/presentation/client/view/booking_flow_screen.dart',
  ).readAsStringSync();
  for (final key in [
    'paymentStatus',
    'originalPrice',
    'finalPrice',
    'currency',
  ]) {
    if (RegExp("['\"]$key['\"]\\s*:").hasMatch(bookingFlow)) {
      fail('Client-authored booking $key found in presentation.');
    }
  }
  if (RegExp(
    r'''['"]status['"]\s*:\s*['"]pending['"]''',
  ).hasMatch(bookingFlow)) {
    fail('Client-authored initial booking status found in presentation.');
  }

  stdout.writeln(
    'Implementation pack source checks passed: '
    '${invokedFunctions.length} functions, ${invokedRpcs.length} RPCs.',
  );
}
