import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';

import '../constants/app_constants.dart';

enum NetworkState { online, offline, checking }

class ConnectivityService {
  final Connectivity _connectivity;
  final _stateSubject = BehaviorSubject<NetworkState>.seeded(NetworkState.checking);
  Timer? _verifyTimer;
  StreamSubscription? _connectivitySub;

  ConnectivityService(this._connectivity) {
    _init();
  }

  Stream<NetworkState> get onStateChange => _stateSubject.stream;
  NetworkState get currentState => _stateSubject.value;
  bool get isOnline => currentState == NetworkState.online;
  bool get isOffline => currentState == NetworkState.offline;

  void _init() {
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      final hasNetworkInterface = results.any(
        (r) => r != ConnectivityResult.none,
      );

      if (!hasNetworkInterface) {
        _updateState(NetworkState.offline);
      } else {
        // Network interface found — verify actual internet access
        _verifyInternetAccess();
      }
    });

    // Initial check
    _verifyInternetAccess();

    // Periodic re-check every 30s to detect silent disconnections
    _verifyTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_stateSubject.value != NetworkState.offline) {
        _verifyInternetAccess();
      }
    });
  }

  Future<void> _verifyInternetAccess() async {
    try {
      // Try to resolve the API host — fastest real connectivity check
      final uri = Uri.parse(AppConstants.apiBaseUrl);
      final addresses = await InternetAddress.lookup(uri.host).timeout(
        const Duration(seconds: 5),
      );
      if (addresses.isNotEmpty && addresses.first.rawAddress.isNotEmpty) {
        _updateState(NetworkState.online);
        return;
      }
    } catch (_) {}
    _updateState(NetworkState.offline);
  }

  void _updateState(NetworkState state) {
    if (_stateSubject.value != state) {
      _stateSubject.add(state);
    }
  }

  /// Force a connectivity check — useful after user taps "Retry"
  Future<NetworkState> checkNow() async {
    _updateState(NetworkState.checking);
    await _verifyInternetAccess();
    return currentState;
  }

  void dispose() {
    _verifyTimer?.cancel();
    _connectivitySub?.cancel();
    _stateSubject.close();
  }
}

// ──────────────────────────────────────────────
// Riverpod Provider
// ──────────────────────────────────────────────

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService(Connectivity());
  ref.onDispose(service.dispose);
  return service;
});

final networkStateProvider = StreamProvider<NetworkState>((ref) {
  return ref.watch(connectivityServiceProvider).onStateChange;
});

final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(networkStateProvider).valueOrNull == NetworkState.online;
});
