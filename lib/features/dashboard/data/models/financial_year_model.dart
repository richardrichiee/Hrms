class FinancialYearModel {
  final int value;
  final String name;

  FinancialYearModel({
    required this.value,
    required this.name,
  });

  factory FinancialYearModel.fromJson(Map<String, dynamic> json) {
    return FinancialYearModel(
      value: json['Value'] ?? 0,
      name: json['Name'] ?? '2025-26',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Value': value,
      'Name': name,
    };
  }
}
