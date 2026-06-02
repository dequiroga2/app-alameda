import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connectivity_provider.g.dart';

@riverpod
Stream<List<ConnectivityResult>> connectivityStream(Ref ref) {
  return Connectivity().onConnectivityChanged;
}

@riverpod
Future<bool> hasConnection(Ref ref) async {
  final result = await Connectivity().checkConnectivity();
  return !result.contains(ConnectivityResult.none);
}
