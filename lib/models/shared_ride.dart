class SharedRide {
  const SharedRide({
    required this.id,
    required this.routePlanId,
    required this.leaderId,
    required this.joinCode,
    required this.status,
    required this.members,
    this.startedAt,
  });

  final String id;
  final String routePlanId;
  final String leaderId;
  final String joinCode;
  final String status;
  final List<SharedRideMember> members;
  final DateTime? startedAt;

  List<SharedRideMember> get joinedMembers => members
      .where((member) => member.status == 'joined')
      .toList(growable: false);
  bool get everyoneReady =>
      joinedMembers.isNotEmpty &&
      joinedMembers.every((member) => member.isReady);
  bool get hasStarted => status == 'active';

  factory SharedRide.fromJson(Map<String, dynamic> json) => SharedRide(
    id: json['shared_ride_id'] as String,
    routePlanId: json['route_plan_id'] as String,
    leaderId: json['leader_id'] as String,
    joinCode: json['join_code'] as String,
    status: json['status'] as String? ?? 'planned',
    startedAt: json['started_at'] == null
        ? null
        : DateTime.parse(json['started_at'] as String),
    members: (json['shared_ride_members'] as List<dynamic>? ?? const [])
        .map(
          (item) =>
              SharedRideMember.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false),
  );
}

class SharedRideMember {
  const SharedRideMember({
    required this.userId,
    required this.role,
    required this.status,
    required this.riderName,
    required this.joinedAt,
    required this.isReady,
    this.motorcycleId,
    this.riderAvatarPath,
    this.motorcycleName,
    this.motorcyclePhotoPath,
    this.readyAt,
  });

  final String userId;
  final String role;
  final String status;
  final String riderName;
  final String? riderAvatarPath;
  final String? motorcycleId;
  final String? motorcycleName;
  final String? motorcyclePhotoPath;
  final DateTime joinedAt;
  final bool isReady;
  final DateTime? readyAt;

  bool get isLeader => role == 'leader';

  factory SharedRideMember.fromJson(Map<String, dynamic> json) =>
      SharedRideMember(
        userId: json['user_id'] as String,
        role: json['role'] as String? ?? 'member',
        status: json['status'] as String? ?? 'joined',
        riderName: json['rider_name'] as String? ?? 'Rider',
        riderAvatarPath: json['rider_avatar_path'] as String?,
        motorcycleId: json['motorcycle_id'] as String?,
        motorcycleName: json['motorcycle_name'] as String?,
        motorcyclePhotoPath: json['motorcycle_photo_path'] as String?,
        joinedAt: DateTime.parse(json['joined_at'] as String),
        isReady: json['is_ready'] as bool? ?? false,
        readyAt: json['ready_at'] == null
            ? null
            : DateTime.parse(json['ready_at'] as String),
      );
}

class SharedRideAction {
  const SharedRideAction({
    required this.id,
    required this.sharedRideId,
    required this.userId,
    required this.action,
    required this.createdAt,
  });

  final String id;
  final String sharedRideId;
  final String userId;
  final String action;
  final DateTime createdAt;

  factory SharedRideAction.fromJson(Map<String, dynamic> json) =>
      SharedRideAction(
        id: json['event_id'] as String,
        sharedRideId: json['shared_ride_id'] as String,
        userId: json['user_id'] as String,
        action: json['action'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
