import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Set<String> _extract(RegExp pattern) {
  final names = <String>{};
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final source = entity.readAsStringSync();
    names.addAll(pattern.allMatches(source).map((match) => match.group(1)!));
  }
  return names;
}

void main() {
  test('every literal Edge Function invocation has a manifest contract', () {
    final manifest =
        jsonDecode(File('contracts/backend_functions.json').readAsStringSync())
            as Map<String, dynamic>;
    final registered = (manifest['functions'] as Map).keys
        .map((name) => name.toString())
        .toSet();
    final invoked = _extract(
      RegExp(r'''\.functions\s*\.invoke\s*\(\s*['"]([^'"]+)['"]'''),
    );

    expect(invoked, isNotEmpty);
    expect(
      invoked.difference(registered),
      isEmpty,
      reason: 'Add every new literal functions.invoke name to the contract.',
    );
  });

  test('every literal RPC invocation has a manifest contract', () {
    final manifest =
        jsonDecode(File('contracts/backend_rpcs.json').readAsStringSync())
            as Map<String, dynamic>;
    final registered = (manifest['rpcs'] as List)
        .map((name) => name.toString())
        .toSet();
    final invoked = _extract(RegExp(r'''\.rpc\s*\(\s*['"]([^'"]+)['"]'''));

    expect(invoked, isNotEmpty);
    expect(
      invoked.difference(registered),
      isEmpty,
      reason: 'Add every new literal rpc name to the contract.',
    );
  });
}
