class ThresholdList {
  final List<Threshold> thresholds;

  ThresholdList({required this.thresholds});

  factory ThresholdList.fromJson(Map<String, dynamic> json) {
    return ThresholdList(
      thresholds: (json['thresholds'] as List)
          .map((dataJson) => Threshold.fromJson(dataJson))
          .toList(),
    );
  }
}

class Threshold {
  final String tempThreshold;
  final String humThreshold;

  // Regular constructor
  const Threshold({
    required this.tempThreshold,
    required this.humThreshold,
  });

  // Factory constructor for JSON parsing
  factory Threshold.fromJson(Map<String, dynamic> json) {
    return Threshold(
      tempThreshold: json['temp_threshold']?.toString() ?? '0',
      humThreshold: json['hum_threshold']?.toString() ?? '0',
    );
  }

  // Convert to double with null safety
  double get tempThresholdAsDouble => double.tryParse(tempThreshold) ?? 0;
  double get humThresholdAsDouble => double.tryParse(humThreshold) ?? 0;

  // For converting back to JSON if needed
  Map<String, dynamic> toJson() => {
    'temp_threshold': tempThreshold,
    'hum_threshold': humThreshold,
  };
}