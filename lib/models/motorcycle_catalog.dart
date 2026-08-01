class MotorcycleCatalogMake {
  const MotorcycleCatalogMake({required this.id, required this.name});

  final int id;
  final String name;

  factory MotorcycleCatalogMake.fromJson(Map<String, dynamic> json) =>
      MotorcycleCatalogMake(
        id: json['MakeId'] as int,
        name: (json['MakeName'] as String).trim(),
      );
}

class MotorcycleCatalogModel {
  const MotorcycleCatalogModel({
    required this.id,
    required this.makeId,
    required this.makeName,
    required this.name,
  });

  final int id;
  final int makeId;
  final String makeName;
  final String name;

  factory MotorcycleCatalogModel.fromJson(Map<String, dynamic> json) =>
      MotorcycleCatalogModel(
        id: json['Model_ID'] as int,
        makeId: json['Make_ID'] as int,
        makeName: (json['Make_Name'] as String).trim(),
        name: (json['Model_Name'] as String).trim(),
      );
}
