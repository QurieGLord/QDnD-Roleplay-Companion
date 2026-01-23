import 'package:hive/hive.dart';

part 'death_saves.g.dart';

@HiveType(typeId: 18)
class DeathSaves extends HiveObject {
  @HiveField(0)
  int successes;

  @HiveField(1)
  int failures;

  DeathSaves({
    this.successes = 0,
    this.failures = 0,
  });

  bool get isStabilized => successes >= 3;
  bool get isDead => failures >= 3;
  bool get isActive => !isStabilized && !isDead;

  void addSuccess() {
    if (successes < 3) {
      successes++;
      // Note: Don't save here - parent Character will save
    }
  }

  void addFailure() {
    if (failures < 3) {
      failures++;
      // Note: Don't save here - parent Character will save
    }
  }

  void reset() {
    successes = 0;
    failures = 0;
    // Note: Don't save here - parent Character will save
  }

  Map<String, dynamic> toJson() {
    return {
      'successes': successes,
      'failures': failures,
    };
  }

  factory DeathSaves.fromJson(Map<String, dynamic> json) {
    return DeathSaves(
      successes: json['successes'] ?? 0,
      failures: json['failures'] ?? 0,
    );
  }
}
