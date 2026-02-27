import 'package:flutter/foundation.dart';

class SettingsService extends ChangeNotifier {
  double _fontScale = 1.0;
  double get fontScale => _fontScale;

  void setFontScale(double v) {
    _fontScale = v.clamp(0.9, 1.4);
    notifyListeners();
  }
}
