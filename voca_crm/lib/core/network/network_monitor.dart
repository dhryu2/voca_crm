import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// 네트워크 연결 상태
enum NetworkStatus {
  /// 연결됨
  connected,

  /// 연결 끊김
  disconnected,

  /// 연결 상태 확인 중
  checking,
}

/// 네트워크 연결 유형
enum NetworkType {
  /// Wi-Fi
  wifi,

  /// 모바일 데이터
  mobile,

  /// 이더넷
  ethernet,

  /// VPN
  vpn,

  /// 블루투스
  bluetooth,

  /// 없음
  none,

  /// 알 수 없음
  unknown,
}

/// 네트워크 상태 정보
class NetworkInfo {
  final NetworkStatus status;
  final NetworkType type;
  final DateTime timestamp;

  const NetworkInfo({
    required this.status,
    required this.type,
    required this.timestamp,
  });

  bool get isConnected => status == NetworkStatus.connected;
  bool get isDisconnected => status == NetworkStatus.disconnected;
  bool get isWifi => type == NetworkType.wifi;
  bool get isMobile => type == NetworkType.mobile;

  @override
  String toString() => 'NetworkInfo(status: $status, type: $type)';
}

/// 네트워크 상태 모니터
///
/// 앱 전체에서 네트워크 연결 상태를 실시간으로 모니터링합니다.
///
/// 사용 예:
/// ```dart
/// // 초기화
/// await NetworkMonitor.instance.initialize();
///
/// // 현재 상태 확인
/// if (NetworkMonitor.instance.isConnected) {
///   // 네트워크 연결됨
/// }
///
/// // 상태 변경 리스너
/// NetworkMonitor.instance.onStatusChange.listen((info) {
///   print('네트워크 상태: ${info.status}');
/// });
/// ```
class NetworkMonitor extends ChangeNotifier {
  static NetworkMonitor? _instance;
  static NetworkMonitor get instance => _instance ??= NetworkMonitor._();

  final Connectivity _connectivity;

  NetworkInfo _currentInfo = NetworkInfo(
    status: NetworkStatus.checking,
    type: NetworkType.unknown,
    timestamp: DateTime.now(),
  );

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  final StreamController<NetworkInfo> _statusController =
      StreamController<NetworkInfo>.broadcast();

  /// 연결 상태 변경 콜백
  VoidCallback? onConnected;
  VoidCallback? onDisconnected;

  NetworkMonitor._() : _connectivity = Connectivity();

  /// 현재 네트워크 정보
  NetworkInfo get currentInfo => _currentInfo;

  /// 현재 연결 상태
  NetworkStatus get status => _currentInfo.status;

  /// 현재 연결 유형
  NetworkType get type => _currentInfo.type;

  /// 연결 여부
  bool get isConnected => _currentInfo.isConnected;

  /// 연결 끊김 여부
  bool get isDisconnected => _currentInfo.isDisconnected;

  /// Wi-Fi 연결 여부
  bool get isWifi => _currentInfo.isWifi;

  /// 모바일 데이터 연결 여부
  bool get isMobile => _currentInfo.isMobile;

  /// 상태 변경 스트림
  Stream<NetworkInfo> get onStatusChange => _statusController.stream;

  /// 초기화
  Future<void> initialize() async {
    // 현재 상태 확인
    await _checkConnectivity();

    // 연결 상태 변경 모니터링
    _subscription = _connectivity.onConnectivityChanged.listen(
      _handleConnectivityChange,
    );
  }

  /// 현재 연결 상태 확인
  Future<NetworkInfo> checkConnectivity() async {
    await _checkConnectivity();
    return _currentInfo;
  }

  Future<void> _checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _handleConnectivityChange(results);
    } catch (e) {
      _updateInfo(NetworkInfo(
        status: NetworkStatus.disconnected,
        type: NetworkType.unknown,
        timestamp: DateTime.now(),
      ));
    }
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
    final type = _mapConnectivityResult(result);
    final status = type == NetworkType.none
        ? NetworkStatus.disconnected
        : NetworkStatus.connected;

    final newInfo = NetworkInfo(
      status: status,
      type: type,
      timestamp: DateTime.now(),
    );

    // 상태가 변경된 경우에만 업데이트
    if (_currentInfo.status != newInfo.status ||
        _currentInfo.type != newInfo.type) {
      final wasConnected = _currentInfo.isConnected;
      _updateInfo(newInfo);

      // 연결/해제 콜백 호출
      if (newInfo.isConnected && !wasConnected) {
        onConnected?.call();
      } else if (newInfo.isDisconnected && wasConnected) {
        onDisconnected?.call();
      }
    }
  }

  void _updateInfo(NetworkInfo info) {
    _currentInfo = info;
    _statusController.add(info);
    notifyListeners();
  }

  NetworkType _mapConnectivityResult(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
        return NetworkType.wifi;
      case ConnectivityResult.mobile:
        return NetworkType.mobile;
      case ConnectivityResult.ethernet:
        return NetworkType.ethernet;
      case ConnectivityResult.vpn:
        return NetworkType.vpn;
      case ConnectivityResult.bluetooth:
        return NetworkType.bluetooth;
      case ConnectivityResult.none:
        return NetworkType.none;
      case ConnectivityResult.other:
        return NetworkType.unknown;
    }
  }

  /// 네트워크 연결 대기
  ///
  /// 지정된 시간 동안 네트워크 연결을 기다립니다.
  /// 연결되면 true, 타임아웃되면 false를 반환합니다.
  Future<bool> waitForConnection({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (isConnected) return true;

    final completer = Completer<bool>();
    Timer? timer;
    StreamSubscription<NetworkInfo>? subscription;

    timer = Timer(timeout, () {
      subscription?.cancel();
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    });

    subscription = onStatusChange.listen((info) {
      if (info.isConnected) {
        timer?.cancel();
        subscription?.cancel();
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      }
    });

    return completer.future;
  }

  /// 리소스 해제
  @override
  void dispose() {
    _subscription?.cancel();
    _statusController.close();
    super.dispose();
  }

  /// 싱글톤 인스턴스 리셋 (테스트용)
  static void resetInstance() {
    _instance?.dispose();
    _instance = null;
  }
}
