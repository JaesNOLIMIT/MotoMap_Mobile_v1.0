import 'package:flutter_test/flutter_test.dart';
import 'package:motomap_mobile/models/shared_ride.dart';

void main() {
  SharedRide rideWith(List<SharedRideMember> members) => SharedRide(
    id: 'ride-1',
    routePlanId: 'plan-1',
    leaderId: 'leader-1',
    joinCode: 'ABC123',
    status: 'planned',
    members: members,
  );

  SharedRideMember member(String id, {required bool ready}) => SharedRideMember(
    userId: id,
    role: id == 'leader-1' ? 'leader' : 'member',
    status: 'joined',
    riderName: id,
    joinedAt: DateTime.utc(2026, 8, 21),
    isReady: ready,
    readyAt: ready ? DateTime.utc(2026, 8, 21, 1) : null,
  );

  test('everyoneReady requires the leader and every joined rider', () {
    final waiting = rideWith([
      member('leader-1', ready: true),
      member('rider-2', ready: false),
    ]);
    final ready = rideWith([
      member('leader-1', ready: true),
      member('rider-2', ready: true),
    ]);

    expect(waiting.everyoneReady, isFalse);
    expect(ready.everyoneReady, isTrue);
  });

  test('left riders do not block a group start', () {
    final left = SharedRideMember(
      userId: 'rider-left',
      role: 'member',
      status: 'left',
      riderName: 'Left rider',
      joinedAt: DateTime.utc(2026, 8, 21),
      isReady: false,
    );
    final ride = rideWith([member('leader-1', ready: true), left]);

    expect(ride.everyoneReady, isTrue);
    expect(ride.joinedMembers, hasLength(1));
  });
}
