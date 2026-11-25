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

  /// True when the module requires an approval hierarchy (HeirarchyNeeded == 1),
  /// but no approval hierarchy has been assigned to this user for the active branch
  /// (HierarchyID == 0, Transactions <= 0, or UserCode == 0 with Transactions <= 1).
  bool get isHierarchyMissing =>
      heirarchyNeeded == 1 &&
      (hierarchyId == 0 || transactions <= 0 || (userCode == 0 && transactions <= 1));

  factory UserRightsModel.fromJson(Map<String, dynamic> json) {
    return UserRightsModel(
      addRight: json['AddRight'] ?? false,
      modiRight: json['ModiRight'] ?? false,
      delRight: json['DelRight'] ?? false,
      viewRight: json['ViewRight'] ?? false,
      transactions: json['Transactions'] ?? 0,
      hierarchyId: json['HierarchyID'] ?? json['HierarchyId'] ?? 0,
      userCode: json['UserCode'] ?? json['Usercode'] ?? 0,
      tempSave: json['TempSave'] ?? 0,
      heirarchyNeeded: json['HeirarchyNeeded'] ?? json['HierarchyNeeded'] ?? 0,
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
