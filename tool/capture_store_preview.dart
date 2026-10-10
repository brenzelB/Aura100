// Controls only the isolated, fixture-backed store preview's debug VM.
// Neither this controller nor its service extension is a release entrypoint.
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 3) {
    throw ArgumentError(
        'Expected capture log, simulator UDID and device index');
  }
  final log = File(arguments[0]);
  final device = arguments[1];
  final index = int.parse(arguments[2]);
  if (!RegExp(r'^[A-F0-9-]{36}$').hasMatch(device) || ![1, 2].contains(index)) {
    throw ArgumentError('Invalid simulator capture arguments');
  }
  final deadline = DateTime.now().add(const Duration(minutes: 6));
  VmService? service;
  String? isolateId;
  while (DateTime.now().isBefore(deadline)) {
    try {
      if (service == null && log.existsSync()) {
        final match =
            RegExp(r'A Dart VM Service .*?available at: (http://[^\s]+)')
                .firstMatch(log.readAsStringSync());
        if (match != null) {
          final address = Uri.parse(match.group(1)!);
          if (address.host != '127.0.0.1' && address.host != 'localhost') {
            throw StateError('Expected loopback debug service');
          }
          service = await vmServiceConnectUri(address
              .replace(scheme: 'ws', path: '${address.path}ws')
              .toString());
        }
      }
      if (service != null) {
        final vm = await service.getVM();
        for (final reference in vm.isolates ?? <IsolateRef>[]) {
          final isolate = await service.getIsolate(reference.id!);
          if (isolate.extensionRPCs?.contains('ext.auraquest.storeCapture') ??
              false) {
            isolateId = reference.id;
            break;
          }
        }
        if (isolateId != null) break;
      }
    } on SocketException {
      service = null;
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  if (service == null || isolateId == null) {
    throw StateError('Store preview debug connection did not become ready');
  }
  final captures = <String>{};
  try {
    for (var page = 0; page < 4; page++) {
      final result = await service.callServiceExtension(
        'ext.auraquest.storeCapture',
        isolateId: isolateId,
        args: {'page': '$page'},
      ).timeout(const Duration(seconds: 30));
      if (result.json?['page'] != page) throw StateError('Wrong capture page');
      final path =
          'build/apple-store-screenshots/device-$index-screen-$page.png';
      final capture = await Process.run(
              'xcrun', ['simctl', 'io', device, 'screenshot', path])
          .timeout(const Duration(seconds: 30));
      if (capture.exitCode != 0) {
        throw StateError('Simulator screenshot failed');
      }
      final bytes = File(path).readAsBytesSync();
      final size = ByteData.sublistView(bytes);
      final width = size.getUint32(16);
      final height = size.getUint32(20);
      final supported = index == 1
          ? [
              [1179, 2556],
              [1206, 2622]
            ]
          : [
              [2048, 2732],
              [2064, 2752]
            ];
      if (!supported.any((pair) => pair[0] == width && pair[1] == height)) {
        throw StateError(
            'Unsupported Apple screenshot dimensions: $width x $height');
      }
      if (!captures.add(sha256.convert(bytes).toString())) {
        throw StateError('Duplicate screenshot; page change did not render');
      }
      stdout.writeln('Captured device $index page $page: $width x $height');
    }
  } finally {
    await service.dispose();
  }
}
