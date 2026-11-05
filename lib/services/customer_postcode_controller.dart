import 'dart:async';

import 'package:flutter/material.dart';

import 'postcode_lookup.dart';
import 'store_fields.dart';

/// Uses the same offline postcode data and location rules as Create Store.
/// The containing form owns and disposes the text controllers.
class CustomerPostcodeController extends ChangeNotifier {
  CustomerPostcodeController({
    required this.postcode,
    required this.city,
    required this.state,
    this.lookup = MalaysianPostcodes.lookup,
  });

  final TextEditingController postcode, city, state;
  final PostcodeLookup lookup;
  Timer? _debounce;
  int _version = 0;
  bool _disposed = false;
  bool lookingUp = false, lookupFailed = false;
  String? resolvedPostcode, error;

  bool get ready =>
      !lookingUp &&
      resolvedPostcode == postcode.text &&
      postcodeError(postcode.text) == null &&
      state.text.isNotEmpty;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void invalidate() {
    _debounce?.cancel();
    _version++;
    resolvedPostcode = null;
    lookingUp = false;
    lookupFailed = false;
    error = null;
    city.clear();
    state.clear();
    _notify();
  }

  void changed(String value) {
    invalidate();
    lookingUp = postcodeError(value) == null;
    _notify();
    if (lookingUp) {
      _debounce = Timer(
        const Duration(milliseconds: 300),
        () => loadExisting(preserveCity: false),
      );
    }
  }

  Future<void> retry() => loadExisting();

  Future<void> loadExisting({bool preserveCity = true}) async {
    _debounce?.cancel();
    final version = ++_version;
    final value = postcode.text;
    resolvedPostcode = null;
    error = null;
    lookupFailed = false;
    state.clear();
    if (!preserveCity) city.clear();
    if (postcodeError(value) != null) {
      lookingUp = false;
      _notify();
      return;
    }
    lookingUp = true;
    _notify();
    try {
      final location = await lookup(value);
      if (_disposed || version != _version || postcode.text != value) return;
      lookingUp = false;
      if (location == null) {
        error = 'Postcode not found. Check the number.';
      } else {
        resolvedPostcode = value;
        if (!preserveCity || city.text.trim().isEmpty) {
          city.text = location.city;
        }
        state.text = location.state;
      }
      _notify();
    } catch (_) {
      if (_disposed || version != _version || postcode.text != value) return;
      lookingUp = false;
      lookupFailed = true;
      error = 'Could not look up this postcode.';
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _version++;
    super.dispose();
  }
}
