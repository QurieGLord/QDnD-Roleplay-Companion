import 'package:hive/hive.dart';

part 'combat_state.g.dart';

@HiveType(typeId: 15)
class CombatState extends HiveObject {
  @HiveField(0)
  bool isInCombat;

  @HiveField(1)
  int currentRound;

  @HiveField(2)
  int initiative;

  @HiveField(3)
  List<CombatLogEntry> combatLog;

  @HiveField(4)
  int totalDamageDealt;

  @HiveField(5)
  int totalDamageTaken;

  @HiveField(6)
  int totalHealing;

  @HiveField(7)
  DateTime? combatStartTime;

  CombatState({
    this.isInCombat = false,
    this.currentRound = 0,
    this.initiative = 0,
    List<CombatLogEntry>? combatLog,
    this.totalDamageDealt = 0,
    this.totalDamageTaken = 0,
    this.totalHealing = 0,
    this.combatStartTime,
  }) : combatLog = combatLog ?? [];

  void startCombat(int initiativeRoll) {
    isInCombat = true;
    currentRound = 1;
    initiative = initiativeRoll;
    combatLog = [];
    totalDamageDealt = 0;
    totalDamageTaken = 0;
    totalHealing = 0;
    combatStartTime = DateTime.now();
    // Note: Don't save here - parent Character will save
  }

  void endCombat() {
    isInCombat = false;
    currentRound = 0;
    initiative = 0;
    combatStartTime = null;
    // Clear combat log and stats when ending combat
    combatLog.clear();
    totalDamageDealt = 0;
    totalDamageTaken = 0;
    totalHealing = 0;
    // Note: Don't save here - parent Character will save
  }

  void addLogEntry(CombatLogEntry entry) {
    combatLog.add(entry);
    // Note: Don't save here - parent Character will save
  }

  Map<String, dynamic> toJson() {
    return {
      'isInCombat': isInCombat,
      'currentRound': currentRound,
      'initiative': initiative,
      'combatLog': combatLog.map((e) => e.toJson()).toList(),
      'totalDamageDealt': totalDamageDealt,
      'totalDamageTaken': totalDamageTaken,
      'totalHealing': totalHealing,
      'combatStartTime': combatStartTime?.toIso8601String(),
    };
  }

  factory CombatState.fromJson(Map<String, dynamic> json) {
    return CombatState(
      isInCombat: json['isInCombat'] ?? false,
      currentRound: json['currentRound'] ?? 0,
      initiative: json['initiative'] ?? 0,
      combatLog: (json['combatLog'] as List?)
          ?.map((e) => CombatLogEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalDamageDealt: json['totalDamageDealt'] ?? 0,
      totalDamageTaken: json['totalDamageTaken'] ?? 0,
      totalHealing: json['totalHealing'] ?? 0,
      combatStartTime: json['combatStartTime'] != null
          ? DateTime.parse(json['combatStartTime'])
          : null,
    );
  }
}

@HiveType(typeId: 16)
class CombatLogEntry extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  DateTime timestamp;

  @HiveField(2)
  CombatLogType type;

  @HiveField(3)
  int? amount;

  @HiveField(4)
  String? description;

  @HiveField(5)
  int round;

  CombatLogEntry({
    required this.id,
    required this.timestamp,
    required this.type,
    this.amount,
    this.description,
    required this.round,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'type': type.name,
      'amount': amount,
      'description': description,
      'round': round,
    };
  }

  factory CombatLogEntry.fromJson(Map<String, dynamic> json) {
    return CombatLogEntry(
      id: json['id'],
      timestamp: DateTime.parse(json['timestamp']),
      type: CombatLogType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => CombatLogType.other,
      ),
      amount: json['amount'],
      description: json['description'],
      round: json['round'],
    );
  }
}

@HiveType(typeId: 17)
enum CombatLogType {
  @HiveField(0)
  damage,
  @HiveField(1)
  healing,
  @HiveField(2)
  deathSave,
  @HiveField(3)
  conditionAdded,
  @HiveField(4)
  conditionRemoved,
  @HiveField(5)
  concentrationCheck,
  @HiveField(6)
  roundStart,
  @HiveField(7)
  other,
}
