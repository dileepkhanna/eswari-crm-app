import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'biometric_service.dart';

/// Manages biometric lock state and app lifecycle
class BiometricLockManager extends ChangeNotifier {
  static const String _lockTimeoutKey = 'biometric_lock_timeout';
  static const String _lastBackgroundTimeKey = 'last_background_time';
  
  bool _isLocked = false;
  bool _isEnabled = false;
  int _lockTimeoutMinutes = 1; // Default: 1 minute
  DateTime? _lastBackgroundTime;
  
  bool get isLocked => _isLocked;
  bool get isEnabled => _isEnabled;
  int get lockTimeoutMinutes => _lockTimeoutMinutes;
  
  /// Initialize the manager
  Future<void> initialize() async {
    _isEnabled = await BiometricService.isBiometricEnabled();
    _lockTimeoutMinutes = await getLockTimeout();
    
    // Check if we should be locked based on last background time
    if (_isEnabled) {
      final prefs = await SharedPreferences.getInstance();
      final lastTimeStr = prefs.getString(_lastBackgroundTimeKey);
      if (lastTimeStr != null) {
        _lastBackgroundTime = DateTime.parse(lastTimeStr);
        final now = DateTime.now();
        final diff = now.difference(_lastBackgroundTime!);
        
        // Lock if timeout exceeded
        if (diff.inMinutes >= _lockTimeoutMinutes) {
          _isLocked = true;
        }
      }
    }
    
    notifyListeners();
  }
  
  /// Enable/disable biometric lock
  Future<void> setBiometricEnabled(bool enabled) async {
    await BiometricService.setBiometricEnabled(enabled);
    _isEnabled = enabled;
    
    if (!enabled) {
      _isLocked = false;
    }
    
    notifyListeners();
  }
  
  /// Set lock timeout in minutes
  Future<void> setLockTimeout(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lockTimeoutKey, minutes);
    _lockTimeoutMinutes = minutes;
    notifyListeners();
  }
  
  /// Get lock timeout from storage
  Future<int> getLockTimeout() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_lockTimeoutKey) ?? 1; // Default 1 minute
  }
  
  /// Lock the app
  void lock() {
    if (_isEnabled) {
      _isLocked = true;
      notifyListeners();
    }
  }
  
  /// Unlock the app
  void unlock() {
    _isLocked = false;
    notifyListeners();
  }
  
  /// Called when app goes to background
  Future<void> onAppPaused() async {
    if (_isEnabled) {
      _lastBackgroundTime = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastBackgroundTimeKey, _lastBackgroundTime!.toIso8601String());
    }
  }
  
  /// Called when app comes to foreground
  Future<void> onAppResumed() async {
    if (_isEnabled && _lastBackgroundTime != null) {
      final now = DateTime.now();
      final diff = now.difference(_lastBackgroundTime!);
      
      // Lock if timeout exceeded
      if (diff.inMinutes >= _lockTimeoutMinutes) {
        _isLocked = true;
        notifyListeners();
      }
    }
  }
  
  /// Check if should show biometric prompt (first time setup)
  static Future<bool> shouldShowBiometricPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    final hasShown = prefs.getBool('biometric_prompt_shown') ?? false;
    final isEnabled = await BiometricService.isBiometricEnabled();
    final isAvailable = await BiometricService.isBiometricAvailable();
    
    return !hasShown && !isEnabled && isAvailable;
  }
  
  /// Mark biometric prompt as shown
  static Future<void> markBiometricPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_prompt_shown', true);
  }
}
