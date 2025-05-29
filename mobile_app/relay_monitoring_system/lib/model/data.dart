class DataList {
  final List<Data> data;

  DataList({required this.data});

  factory DataList.fromJson(List<dynamic> json) {
    return DataList(
      data: json.map((dataJson) => Data.fromJson(dataJson)).toList(),
    );
  }
}

class Data {
  final String? deviceId;
  final String? temperature;
  final String? humidity;
  final String? relayStatus;
  final String? timestamp;

  Data({
    this.deviceId,
    this.temperature,
    this.humidity,
    this.relayStatus,
    this.timestamp,
  });

  factory Data.fromJson(Map<String, dynamic> json) {
    return Data(
      deviceId: json['device_id']?.toString(),
      temperature: json['temperature']?.toString(),
      humidity: json['humidity']?.toString(),
      relayStatus: json['relay_status']?.toString(),
      timestamp: json['timestamp']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      'temperature': temperature,
      'humidity': humidity,
      'relay_status': relayStatus,
      'timestamp': timestamp,
    };
  }
}