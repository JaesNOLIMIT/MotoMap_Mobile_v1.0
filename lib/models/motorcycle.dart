enum ElmTransport {
  bluetoothClassic('bluetooth_classic'),
  ble('ble'),
  wifi('wifi');

  const ElmTransport(this.databaseValue);
  final String databaseValue;

  static ElmTransport? fromDatabase(String? value) {
    for (final transport in values) {
      if (transport.databaseValue == value) return transport;
    }
    return null;
  }
}

class Motorcycle {
  const Motorcycle({
    required this.id,
    required this.userId,
    required this.make,
    required this.model,
    required this.modelYear,
    required this.type,
    required this.isPrimary,
    required this.elmAutoConnect,
    required this.createdAt,
    this.nickname,
    this.engineDisplacementCc,
    this.elmDeviceName,
    this.elmDeviceIdentifier,
    this.elmTransport,
    this.lastElmConnectedAt,
    this.photoPath,
    this.catalogSource,
    this.catalogMakeId,
    this.catalogModelId,
  });

  final String id;
  final String userId;
  final String? nickname;
  final String make;
  final String model;
  final int modelYear;
  final String type;
  final int? engineDisplacementCc;
  final bool isPrimary;
  final String? elmDeviceName;
  final String? elmDeviceIdentifier;
  final ElmTransport? elmTransport;
  final bool elmAutoConnect;
  final DateTime? lastElmConnectedAt;
  final String? photoPath;
  final String? catalogSource;
  final int? catalogMakeId;
  final int? catalogModelId;
  final DateTime createdAt;

  String get displayName => '$make $model';
  String get subtitle {
    final name = nickname?.trim();
    return name == null || name.isEmpty
        ? '$modelYear model'
        : '$name · $modelYear';
  }

  String get typeLabel => type
      .split('_')
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');

  bool get hasElmAdapter => elmDeviceIdentifier != null && elmTransport != null;

  factory Motorcycle.fromJson(Map<String, dynamic> json) => Motorcycle(
    id: json['motorcycle_id'] as String,
    userId: json['user_id'] as String,
    nickname: json['nickname'] as String?,
    make: json['make'] as String,
    model: json['model'] as String,
    modelYear: json['model_year'] as int,
    type: json['motorcycle_type'] as String,
    engineDisplacementCc: json['engine_displacement_cc'] as int?,
    isPrimary: json['is_primary'] as bool? ?? false,
    elmDeviceName: json['elm_device_name'] as String?,
    elmDeviceIdentifier: json['elm_device_identifier'] as String?,
    elmTransport: ElmTransport.fromDatabase(json['elm_transport'] as String?),
    elmAutoConnect: json['elm_auto_connect'] as bool? ?? true,
    lastElmConnectedAt: json['last_elm_connected_at'] == null
        ? null
        : DateTime.parse(json['last_elm_connected_at'] as String),
    photoPath: json['photo_path'] as String?,
    catalogSource: json['catalog_source'] as String?,
    catalogMakeId: json['catalog_make_id'] as int?,
    catalogModelId: json['catalog_model_id'] as int?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Motorcycle copyWith({
    String? nickname,
    String? make,
    String? model,
    int? modelYear,
    String? type,
    int? engineDisplacementCc,
    bool? isPrimary,
    String? elmDeviceName,
    String? elmDeviceIdentifier,
    ElmTransport? elmTransport,
    bool? elmAutoConnect,
    String? photoPath,
    String? catalogSource,
    int? catalogMakeId,
    int? catalogModelId,
  }) => Motorcycle(
    id: id,
    userId: userId,
    nickname: nickname ?? this.nickname,
    make: make ?? this.make,
    model: model ?? this.model,
    modelYear: modelYear ?? this.modelYear,
    type: type ?? this.type,
    engineDisplacementCc: engineDisplacementCc ?? this.engineDisplacementCc,
    isPrimary: isPrimary ?? this.isPrimary,
    elmDeviceName: elmDeviceName ?? this.elmDeviceName,
    elmDeviceIdentifier: elmDeviceIdentifier ?? this.elmDeviceIdentifier,
    elmTransport: elmTransport ?? this.elmTransport,
    elmAutoConnect: elmAutoConnect ?? this.elmAutoConnect,
    lastElmConnectedAt: lastElmConnectedAt,
    photoPath: photoPath ?? this.photoPath,
    catalogSource: catalogSource ?? this.catalogSource,
    catalogMakeId: catalogMakeId ?? this.catalogMakeId,
    catalogModelId: catalogModelId ?? this.catalogModelId,
    createdAt: createdAt,
  );
}

class NewMotorcycle {
  const NewMotorcycle({
    required this.make,
    required this.model,
    required this.modelYear,
    required this.type,
    this.nickname,
    this.engineDisplacementCc,
    this.catalogSource,
    this.catalogMakeId,
    this.catalogModelId,
    this.makePrimary = false,
  });

  final String? nickname;
  final String make;
  final String model;
  final int modelYear;
  final String type;
  final int? engineDisplacementCc;
  final String? catalogSource;
  final int? catalogMakeId;
  final int? catalogModelId;
  final bool makePrimary;
}
