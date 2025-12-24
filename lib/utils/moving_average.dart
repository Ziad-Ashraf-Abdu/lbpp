// lib/utils/moving_average.dart

/// A simple moving average filter.
class MovingAverage {
  final int windowSize;
  final List<double> _values = [];
  double _sum = 0.0;

  MovingAverage({this.windowSize = 5}); // Default window size of 5

  /// Adds a new value to the filter and returns the new smoothed average.
  double add(double value) {
    if (_values.length == windowSize) {
      _sum -= _values.removeAt(0);
    }
    _values.add(value);
    _sum += value;
    return _sum / _values.length;
  }
}
