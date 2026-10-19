import 'package:flutter_test/flutter_test.dart';
import 'package:worker_app/features/schedule/worker_leave_repository.dart';

class _MemoryLeaveStorage implements WorkerLeaveStorage {
  String? value;
  bool failWrites = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String newValue) async {
    if (failWrites) throw StateError('Cannot save');
    value = newValue;
  }
}

void main() {
  test('draft persists across repository recreation', () async {
    final memory = _MemoryLeaveStorage();
    final first = WorkerLeaveRepository(memory, demoMode: true);
    await first.initialize();
    await first.saveDraft(
      from: DateTime(2026, 11, 4),
      to: DateTime(2026, 11, 6),
      reason: 'Personal',
    );
    final restored = WorkerLeaveRepository(memory, demoMode: true);
    await restored.initialize();
    expect(restored.requests, hasLength(1));
    expect(restored.requests.single.status, WorkerLeaveStatus.draft);
    expect(restored.requests.single.reason, 'Personal');
    first.dispose();
    restored.dispose();
  });

  test('overlapping dates are rejected including endpoints', () async {
    final repo = WorkerLeaveRepository(_MemoryLeaveStorage(), demoMode: true);
    await repo.initialize();
    await repo.saveDraft(
      from: DateTime(2026, 11, 4), to: DateTime(2026, 11, 6), reason: 'Family',
    );
    expect(repo.overlaps(DateTime(2026, 11, 6), DateTime(2026, 11, 8)), isTrue);
    await expectLater(
      repo.saveDraft(from: DateTime(2026, 11, 6),
          to: DateTime(2026, 11, 8), reason: 'Personal'),
      throwsA(isA<WorkerLeaveException>()),
    );
    repo.dispose();
  });

  test('failed write does not create draft in UI state', () async {
    final memory = _MemoryLeaveStorage();
    final repo = WorkerLeaveRepository(memory, demoMode: true);
    await repo.initialize();
    memory.failWrites = true;
    await expectLater(
      repo.saveDraft(from: DateTime(2026, 12, 1),
          to: DateTime(2026, 12, 1), reason: 'Other'),
      throwsStateError,
    );
    expect(repo.requests, isEmpty);
    repo.dispose();
  });

  test('corrupt storage is not silently reset', () async {
    final memory = _MemoryLeaveStorage()..value = 'not json';
    final repo = WorkerLeaveRepository(memory, demoMode: true);
    await expectLater(repo.initialize(), throwsFormatException);
    expect(repo.isInitialized, isFalse);
    repo.dispose();
  });
}
