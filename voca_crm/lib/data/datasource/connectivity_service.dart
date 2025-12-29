import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  
  /// Stream of connectivity status changes
  Stream<List<ConnectivityResult>> get connectivityStream => 
      _connectivity.onConnectivityChanged;
  
  /// Check current connectivity status
  Future<bool> isConnected() async {
    final List<ConnectivityResult> connectivityResult = 
        await _connectivity.checkConnectivity();
    
    // Consider connected if any connection type is available (wifi, mobile, ethernet)
    return connectivityResult.any((result) => 
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.ethernet);
  }
  
  /// Check if currently offline
  Future<bool> isOffline() async {
    return !(await isConnected());
  }
}
