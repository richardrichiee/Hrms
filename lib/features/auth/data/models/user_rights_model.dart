class UserRightsModel {
  final bool addRight;
  final bool modiRight;
  final bool delRight;
  final bool viewRight;
  final int transactions;
  final int hierarchyId;
  final int userCode;
  final int tempSave;
  final int heirarchyNeeded;

  UserRightsModel({
    required this.addRight,
    required this.modiRight,
    required this.delRight,
    required this.viewRight,
    required this.transactions,
    required this.hierarchyId,
    required this.userCode,
    required this.tempSave,
    required this.heirarchyNeeded,
  });

  factory UserRightsModel.fromJson(Map<String, dynamic> json) {
    return UserRightsModel(
      addRight: json['AddRight'] ?? false,
      modiRight: json['ModiRight'] ?? false,
      delRight: json['DelRight'] ?? false,
      viewRight: json['ViewRight'] ?? false,
      transactions: json['Transactions'] ?? 0,
      hierarchyId: json['HierarchyID'] ?? 0,
      userCode: json['UserCode'] ?? 0,
      tempSave: json['TempSave'] ?? 0,
      heirarchyNeeded: json['HeirarchyNeeded'] ?? 0,
    );
  }

  factory UserRightsModel.noAccess() {
    return UserRightsModel(
      addRight: false,
      modiRight: false,
      delRight: false,
      viewRight: false,
      transactions: 0,
      hierarchyId: 0,
      userCode: 0,
      tempSave: 0,
      heirarchyNeeded: 0,
    );
  }

  factory UserRightsModel.fullAccess() {
    return UserRightsModel(
      addRight: true,
      modiRight: true,
      delRight: true,
      viewRight: true,
      transactions: 3,
      hierarchyId: 20,
      userCode: 2,
      tempSave: 0,
      heirarchyNeeded: 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'AddRight': addRight,
      'ModiRight': modiRight,
      'DelRight': delRight,
      'ViewRight': viewRight,
      'Transactions': transactions,
      'HierarchyID': hierarchyId,
      'UserCode': userCode,
      'TempSave': tempSave,
      'HeirarchyNeeded': heirarchyNeeded,
    };
  }
}
