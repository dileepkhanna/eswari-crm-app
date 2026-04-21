import 'package:flutter/material.dart';
import '../screens/biometric_lock_screen.dart';
import '../services/biometric_service.dart';

/// Wrapper widget that shows biometric lock screen when needed
class BiometricLockWrapper extends StatefulWidget {
  final Widget child;
  
  const BiometricLockWrapper({super.key, required this.child});

  @override
  State<BiometricLockWrapper> createState() => _BiometricLockWrapperState();
}

class _BiometricLockWrapperState extends State<BiometricLockWrapper> with WidgetsBindingObserver {
  bool _isLocked = false;
  bool _isEnabled = false;
  DateTime? _lastPausedTime;
  int _lockTimeoutMinutes = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkBiometricStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkBiometricStatus() async {
    final enabled = await BiometricService.isBiometricEnabled();
    if (mounted) {
      setState(() {
        _isEnabled = enabled;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (!_isEnabled) return;

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // App going to background
      _lastPausedTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      // App coming to foreground
      if (_lastPausedTime != null) {
        final now = DateTime.now();
        final diff = now.difference(_lastPausedTime!);
        
        // Lock if timeout exceeded
        if (diff.inMinutes >= _lockTimeoutMinutes) {
          setState(() {
            _isLocked = true;
          });
        }
      }
    }
  }

  void _onAuthenticated() {
    setState(() {
      _isLocked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLocked && _isEnabled) {
      return BiometricLockScreen(onAuthenticated: _onAuthenticated);
    }
    
    return widget.child;
  }
}
