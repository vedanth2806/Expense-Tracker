import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:in_app_update/in_app_update.dart';

class UpdateService {
  /// Call this at app startup.
  /// Returns true if the app is ready to use (no update needed / offline).
  /// Returns false if an immediate update was triggered (app will restart).
  static Future<bool> checkAndForceUpdate(BuildContext context) async {
    // 1. Only check when connected to internet
    final connectivityResult = await Connectivity().checkConnectivity();
    final isOnline = connectivityResult.any(
      (r) =>
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet,
    );

    if (!isOnline) return true; // Offline: let user through

    try {
      final info = await InAppUpdate.checkForUpdate();

      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        // Trigger immediate update — this blocks the UI until the user
        // either updates or the Play Store download completes.
        await InAppUpdate.performImmediateUpdate();
        // After update the app restarts; we never reach here normally.
        return false;
      }
    } catch (e) {
      // Silently ignore: Play Store not available (debug builds, sideloads, etc.)
      debugPrint('[UpdateService] in_app_update error: $e');
    }

    return true; // No update needed
  }
}
