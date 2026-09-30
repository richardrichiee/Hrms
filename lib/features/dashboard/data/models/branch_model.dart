class BranchModel {
  final int value;
  final String name;
  final double? latitude;
  final double? longitude;
  final double? radius;

  BranchModel({
    required this.value,
    required this.name,
    this.latitude,
    this.longitude,
    this.radius,
  });

  int get id => value;

  static double? _parseDouble(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    if (val is String) {
      final trimmed = val.trim();
      if (trimmed.isEmpty || trimmed.toLowerCase() == 'null') return null;
      return double.tryParse(trimmed);
    }
    return null;
  }

  factory BranchModel.fromJson(Map<String, dynamic> json) {
    return BranchModel(
      value: json['Value'] ?? 0,
      name: json['Name'] ?? 'Unknown Branch',
      latitude: _parseDouble(json['Latitude']),
      longitude: _parseDouble(json['Longitude']),
      radius: _parseDouble(json['Radius']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Value': value,
      'Name': name,
      'Latitude': latitude,
      'Longitude': longitude,
      'Radius': radius,
    };
  }
}

