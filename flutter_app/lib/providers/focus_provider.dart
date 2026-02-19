import 'package:flutter/foundation.dart';

/// Tracks D-pad focus position in the EPG grid.
class FocusProvider extends ChangeNotifier {
  int _channelIndex = 0;
  int _programIndex = 0;
  bool _sidebarFocused = false; // true = focus is in channel sidebar

  int get channelIndex => _channelIndex;
  int get programIndex => _programIndex;
  bool get sidebarFocused => _sidebarFocused;

  void moveTo(int channelIndex, int programIndex) {
    _channelIndex = channelIndex;
    _programIndex = programIndex;
    _sidebarFocused = false;
    notifyListeners();
  }

  void moveUp(int maxChannels) {
    if (_channelIndex > 0) {
      _channelIndex--;
      notifyListeners();
    }
  }

  void moveDown(int maxChannels) {
    if (_channelIndex < maxChannels - 1) {
      _channelIndex++;
      notifyListeners();
    }
  }

  void moveLeft() {
    if (_programIndex > 0) {
      _programIndex--;
      notifyListeners();
    }
  }

  void moveRight(int maxPrograms) {
    if (_programIndex < maxPrograms - 1) {
      _programIndex++;
      notifyListeners();
    }
  }

  void focusSidebar() {
    _sidebarFocused = true;
    notifyListeners();
  }

  void focusGrid() {
    _sidebarFocused = false;
    notifyListeners();
  }

  void reset() {
    _channelIndex = 0;
    _programIndex = 0;
    _sidebarFocused = false;
    notifyListeners();
  }
}
