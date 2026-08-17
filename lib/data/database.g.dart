// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $UserProfilesTable extends UserProfiles
    with TableInfo<$UserProfilesTable, UserProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    check: () => id.equals(1),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _heightCmMeta = const VerificationMeta(
    'heightCm',
  );
  @override
  late final GeneratedColumn<double> heightCm = GeneratedColumn<double>(
    'height_cm',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unitSystemMeta = const VerificationMeta(
    'unitSystem',
  );
  @override
  late final GeneratedColumn<String> unitSystem = GeneratedColumn<String>(
    'unit_system',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 6,
      maxTextLength: 8,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('imperial'),
  );
  static const VerificationMeta _defaultPairRestSecondsMeta =
      const VerificationMeta('defaultPairRestSeconds');
  @override
  late final GeneratedColumn<int> defaultPairRestSeconds = GeneratedColumn<int>(
    'default_pair_rest_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(90),
  );
  static const VerificationMeta _defaultTripletRestSecondsMeta =
      const VerificationMeta('defaultTripletRestSeconds');
  @override
  late final GeneratedColumn<int> defaultTripletRestSeconds =
      GeneratedColumn<int>(
        'default_triplet_rest_seconds',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(60),
      );
  static const VerificationMeta _rotatePairOrderMeta = const VerificationMeta(
    'rotatePairOrder',
  );
  @override
  late final GeneratedColumn<bool> rotatePairOrder = GeneratedColumn<bool>(
    'rotate_pair_order',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("rotate_pair_order" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    heightCm,
    unitSystem,
    defaultPairRestSeconds,
    defaultTripletRestSeconds,
    rotatePairOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserProfile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('height_cm')) {
      context.handle(
        _heightCmMeta,
        heightCm.isAcceptableOrUnknown(data['height_cm']!, _heightCmMeta),
      );
    }
    if (data.containsKey('unit_system')) {
      context.handle(
        _unitSystemMeta,
        unitSystem.isAcceptableOrUnknown(data['unit_system']!, _unitSystemMeta),
      );
    }
    if (data.containsKey('default_pair_rest_seconds')) {
      context.handle(
        _defaultPairRestSecondsMeta,
        defaultPairRestSeconds.isAcceptableOrUnknown(
          data['default_pair_rest_seconds']!,
          _defaultPairRestSecondsMeta,
        ),
      );
    }
    if (data.containsKey('default_triplet_rest_seconds')) {
      context.handle(
        _defaultTripletRestSecondsMeta,
        defaultTripletRestSeconds.isAcceptableOrUnknown(
          data['default_triplet_rest_seconds']!,
          _defaultTripletRestSecondsMeta,
        ),
      );
    }
    if (data.containsKey('rotate_pair_order')) {
      context.handle(
        _rotatePairOrderMeta,
        rotatePairOrder.isAcceptableOrUnknown(
          data['rotate_pair_order']!,
          _rotatePairOrderMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserProfile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      heightCm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}height_cm'],
      ),
      unitSystem: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit_system'],
      )!,
      defaultPairRestSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}default_pair_rest_seconds'],
      )!,
      defaultTripletRestSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}default_triplet_rest_seconds'],
      )!,
      rotatePairOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}rotate_pair_order'],
      )!,
    );
  }

  @override
  $UserProfilesTable createAlias(String alias) {
    return $UserProfilesTable(attachedDatabase, alias);
  }
}

class UserProfile extends DataClass implements Insertable<UserProfile> {
  final int id;

  /// Null until the user personalizes. Height does not change for adults, so
  /// it lives here rather than in a time series.
  final double? heightCm;

  /// 'imperial' | 'metric'. Imperial is the default.
  final String unitSystem;
  final int defaultPairRestSeconds;
  final int defaultTripletRestSeconds;

  /// Whether to rotate which pair comes first each session. Not part of the
  /// Recommended Routine — see `docs/PLAN.md` §5.1.
  final bool rotatePairOrder;
  const UserProfile({
    required this.id,
    this.heightCm,
    required this.unitSystem,
    required this.defaultPairRestSeconds,
    required this.defaultTripletRestSeconds,
    required this.rotatePairOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || heightCm != null) {
      map['height_cm'] = Variable<double>(heightCm);
    }
    map['unit_system'] = Variable<String>(unitSystem);
    map['default_pair_rest_seconds'] = Variable<int>(defaultPairRestSeconds);
    map['default_triplet_rest_seconds'] = Variable<int>(
      defaultTripletRestSeconds,
    );
    map['rotate_pair_order'] = Variable<bool>(rotatePairOrder);
    return map;
  }

  UserProfilesCompanion toCompanion(bool nullToAbsent) {
    return UserProfilesCompanion(
      id: Value(id),
      heightCm: heightCm == null && nullToAbsent
          ? const Value.absent()
          : Value(heightCm),
      unitSystem: Value(unitSystem),
      defaultPairRestSeconds: Value(defaultPairRestSeconds),
      defaultTripletRestSeconds: Value(defaultTripletRestSeconds),
      rotatePairOrder: Value(rotatePairOrder),
    );
  }

  factory UserProfile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserProfile(
      id: serializer.fromJson<int>(json['id']),
      heightCm: serializer.fromJson<double?>(json['heightCm']),
      unitSystem: serializer.fromJson<String>(json['unitSystem']),
      defaultPairRestSeconds: serializer.fromJson<int>(
        json['defaultPairRestSeconds'],
      ),
      defaultTripletRestSeconds: serializer.fromJson<int>(
        json['defaultTripletRestSeconds'],
      ),
      rotatePairOrder: serializer.fromJson<bool>(json['rotatePairOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'heightCm': serializer.toJson<double?>(heightCm),
      'unitSystem': serializer.toJson<String>(unitSystem),
      'defaultPairRestSeconds': serializer.toJson<int>(defaultPairRestSeconds),
      'defaultTripletRestSeconds': serializer.toJson<int>(
        defaultTripletRestSeconds,
      ),
      'rotatePairOrder': serializer.toJson<bool>(rotatePairOrder),
    };
  }

  UserProfile copyWith({
    int? id,
    Value<double?> heightCm = const Value.absent(),
    String? unitSystem,
    int? defaultPairRestSeconds,
    int? defaultTripletRestSeconds,
    bool? rotatePairOrder,
  }) => UserProfile(
    id: id ?? this.id,
    heightCm: heightCm.present ? heightCm.value : this.heightCm,
    unitSystem: unitSystem ?? this.unitSystem,
    defaultPairRestSeconds:
        defaultPairRestSeconds ?? this.defaultPairRestSeconds,
    defaultTripletRestSeconds:
        defaultTripletRestSeconds ?? this.defaultTripletRestSeconds,
    rotatePairOrder: rotatePairOrder ?? this.rotatePairOrder,
  );
  UserProfile copyWithCompanion(UserProfilesCompanion data) {
    return UserProfile(
      id: data.id.present ? data.id.value : this.id,
      heightCm: data.heightCm.present ? data.heightCm.value : this.heightCm,
      unitSystem: data.unitSystem.present
          ? data.unitSystem.value
          : this.unitSystem,
      defaultPairRestSeconds: data.defaultPairRestSeconds.present
          ? data.defaultPairRestSeconds.value
          : this.defaultPairRestSeconds,
      defaultTripletRestSeconds: data.defaultTripletRestSeconds.present
          ? data.defaultTripletRestSeconds.value
          : this.defaultTripletRestSeconds,
      rotatePairOrder: data.rotatePairOrder.present
          ? data.rotatePairOrder.value
          : this.rotatePairOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserProfile(')
          ..write('id: $id, ')
          ..write('heightCm: $heightCm, ')
          ..write('unitSystem: $unitSystem, ')
          ..write('defaultPairRestSeconds: $defaultPairRestSeconds, ')
          ..write('defaultTripletRestSeconds: $defaultTripletRestSeconds, ')
          ..write('rotatePairOrder: $rotatePairOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    heightCm,
    unitSystem,
    defaultPairRestSeconds,
    defaultTripletRestSeconds,
    rotatePairOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserProfile &&
          other.id == this.id &&
          other.heightCm == this.heightCm &&
          other.unitSystem == this.unitSystem &&
          other.defaultPairRestSeconds == this.defaultPairRestSeconds &&
          other.defaultTripletRestSeconds == this.defaultTripletRestSeconds &&
          other.rotatePairOrder == this.rotatePairOrder);
}

class UserProfilesCompanion extends UpdateCompanion<UserProfile> {
  final Value<int> id;
  final Value<double?> heightCm;
  final Value<String> unitSystem;
  final Value<int> defaultPairRestSeconds;
  final Value<int> defaultTripletRestSeconds;
  final Value<bool> rotatePairOrder;
  const UserProfilesCompanion({
    this.id = const Value.absent(),
    this.heightCm = const Value.absent(),
    this.unitSystem = const Value.absent(),
    this.defaultPairRestSeconds = const Value.absent(),
    this.defaultTripletRestSeconds = const Value.absent(),
    this.rotatePairOrder = const Value.absent(),
  });
  UserProfilesCompanion.insert({
    this.id = const Value.absent(),
    this.heightCm = const Value.absent(),
    this.unitSystem = const Value.absent(),
    this.defaultPairRestSeconds = const Value.absent(),
    this.defaultTripletRestSeconds = const Value.absent(),
    this.rotatePairOrder = const Value.absent(),
  });
  static Insertable<UserProfile> custom({
    Expression<int>? id,
    Expression<double>? heightCm,
    Expression<String>? unitSystem,
    Expression<int>? defaultPairRestSeconds,
    Expression<int>? defaultTripletRestSeconds,
    Expression<bool>? rotatePairOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (heightCm != null) 'height_cm': heightCm,
      if (unitSystem != null) 'unit_system': unitSystem,
      if (defaultPairRestSeconds != null)
        'default_pair_rest_seconds': defaultPairRestSeconds,
      if (defaultTripletRestSeconds != null)
        'default_triplet_rest_seconds': defaultTripletRestSeconds,
      if (rotatePairOrder != null) 'rotate_pair_order': rotatePairOrder,
    });
  }

  UserProfilesCompanion copyWith({
    Value<int>? id,
    Value<double?>? heightCm,
    Value<String>? unitSystem,
    Value<int>? defaultPairRestSeconds,
    Value<int>? defaultTripletRestSeconds,
    Value<bool>? rotatePairOrder,
  }) {
    return UserProfilesCompanion(
      id: id ?? this.id,
      heightCm: heightCm ?? this.heightCm,
      unitSystem: unitSystem ?? this.unitSystem,
      defaultPairRestSeconds:
          defaultPairRestSeconds ?? this.defaultPairRestSeconds,
      defaultTripletRestSeconds:
          defaultTripletRestSeconds ?? this.defaultTripletRestSeconds,
      rotatePairOrder: rotatePairOrder ?? this.rotatePairOrder,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (heightCm.present) {
      map['height_cm'] = Variable<double>(heightCm.value);
    }
    if (unitSystem.present) {
      map['unit_system'] = Variable<String>(unitSystem.value);
    }
    if (defaultPairRestSeconds.present) {
      map['default_pair_rest_seconds'] = Variable<int>(
        defaultPairRestSeconds.value,
      );
    }
    if (defaultTripletRestSeconds.present) {
      map['default_triplet_rest_seconds'] = Variable<int>(
        defaultTripletRestSeconds.value,
      );
    }
    if (rotatePairOrder.present) {
      map['rotate_pair_order'] = Variable<bool>(rotatePairOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserProfilesCompanion(')
          ..write('id: $id, ')
          ..write('heightCm: $heightCm, ')
          ..write('unitSystem: $unitSystem, ')
          ..write('defaultPairRestSeconds: $defaultPairRestSeconds, ')
          ..write('defaultTripletRestSeconds: $defaultTripletRestSeconds, ')
          ..write('rotatePairOrder: $rotatePairOrder')
          ..write(')'))
        .toString();
  }
}

class $BodyWeightEntriesTable extends BodyWeightEntries
    with TableInfo<$BodyWeightEntriesTable, BodyWeightEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BodyWeightEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordedAtMeta = const VerificationMeta(
    'recordedAt',
  );
  @override
  late final GeneratedColumn<DateTime> recordedAt = GeneratedColumn<DateTime>(
    'recorded_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weightKgMeta = const VerificationMeta(
    'weightKg',
  );
  @override
  late final GeneratedColumn<double> weightKg = GeneratedColumn<double>(
    'weight_kg',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, recordedAt, weightKg];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'body_weight_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<BodyWeightEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('recorded_at')) {
      context.handle(
        _recordedAtMeta,
        recordedAt.isAcceptableOrUnknown(data['recorded_at']!, _recordedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_recordedAtMeta);
    }
    if (data.containsKey('weight_kg')) {
      context.handle(
        _weightKgMeta,
        weightKg.isAcceptableOrUnknown(data['weight_kg']!, _weightKgMeta),
      );
    } else if (isInserting) {
      context.missing(_weightKgMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BodyWeightEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BodyWeightEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      recordedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}recorded_at'],
      )!,
      weightKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight_kg'],
      )!,
    );
  }

  @override
  $BodyWeightEntriesTable createAlias(String alias) {
    return $BodyWeightEntriesTable(attachedDatabase, alias);
  }
}

class BodyWeightEntry extends DataClass implements Insertable<BodyWeightEntry> {
  final String id;
  final DateTime recordedAt;
  final double weightKg;
  const BodyWeightEntry({
    required this.id,
    required this.recordedAt,
    required this.weightKg,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['recorded_at'] = Variable<DateTime>(recordedAt);
    map['weight_kg'] = Variable<double>(weightKg);
    return map;
  }

  BodyWeightEntriesCompanion toCompanion(bool nullToAbsent) {
    return BodyWeightEntriesCompanion(
      id: Value(id),
      recordedAt: Value(recordedAt),
      weightKg: Value(weightKg),
    );
  }

  factory BodyWeightEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BodyWeightEntry(
      id: serializer.fromJson<String>(json['id']),
      recordedAt: serializer.fromJson<DateTime>(json['recordedAt']),
      weightKg: serializer.fromJson<double>(json['weightKg']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'recordedAt': serializer.toJson<DateTime>(recordedAt),
      'weightKg': serializer.toJson<double>(weightKg),
    };
  }

  BodyWeightEntry copyWith({
    String? id,
    DateTime? recordedAt,
    double? weightKg,
  }) => BodyWeightEntry(
    id: id ?? this.id,
    recordedAt: recordedAt ?? this.recordedAt,
    weightKg: weightKg ?? this.weightKg,
  );
  BodyWeightEntry copyWithCompanion(BodyWeightEntriesCompanion data) {
    return BodyWeightEntry(
      id: data.id.present ? data.id.value : this.id,
      recordedAt: data.recordedAt.present
          ? data.recordedAt.value
          : this.recordedAt,
      weightKg: data.weightKg.present ? data.weightKg.value : this.weightKg,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BodyWeightEntry(')
          ..write('id: $id, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('weightKg: $weightKg')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, recordedAt, weightKg);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BodyWeightEntry &&
          other.id == this.id &&
          other.recordedAt == this.recordedAt &&
          other.weightKg == this.weightKg);
}

class BodyWeightEntriesCompanion extends UpdateCompanion<BodyWeightEntry> {
  final Value<String> id;
  final Value<DateTime> recordedAt;
  final Value<double> weightKg;
  final Value<int> rowid;
  const BodyWeightEntriesCompanion({
    this.id = const Value.absent(),
    this.recordedAt = const Value.absent(),
    this.weightKg = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BodyWeightEntriesCompanion.insert({
    required String id,
    required DateTime recordedAt,
    required double weightKg,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       recordedAt = Value(recordedAt),
       weightKg = Value(weightKg);
  static Insertable<BodyWeightEntry> custom({
    Expression<String>? id,
    Expression<DateTime>? recordedAt,
    Expression<double>? weightKg,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (recordedAt != null) 'recorded_at': recordedAt,
      if (weightKg != null) 'weight_kg': weightKg,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BodyWeightEntriesCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? recordedAt,
    Value<double>? weightKg,
    Value<int>? rowid,
  }) {
    return BodyWeightEntriesCompanion(
      id: id ?? this.id,
      recordedAt: recordedAt ?? this.recordedAt,
      weightKg: weightKg ?? this.weightKg,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (recordedAt.present) {
      map['recorded_at'] = Variable<DateTime>(recordedAt.value);
    }
    if (weightKg.present) {
      map['weight_kg'] = Variable<double>(weightKg.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BodyWeightEntriesCompanion(')
          ..write('id: $id, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('weightKg: $weightKg, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProgressionConfigsTable extends ProgressionConfigs
    with TableInfo<$ProgressionConfigsTable, ProgressionConfig> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProgressionConfigsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pathIdMeta = const VerificationMeta('pathId');
  @override
  late final GeneratedColumn<String> pathId = GeneratedColumn<String>(
    'path_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _selectedBranchIdMeta = const VerificationMeta(
    'selectedBranchId',
  );
  @override
  late final GeneratedColumn<String> selectedBranchId = GeneratedColumn<String>(
    'selected_branch_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _selectedExerciseIdMeta =
      const VerificationMeta('selectedExerciseId');
  @override
  late final GeneratedColumn<String> selectedExerciseId =
      GeneratedColumn<String>(
        'selected_exercise_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    pathId,
    selectedBranchId,
    selectedExerciseId,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'progression_configs';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProgressionConfig> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('path_id')) {
      context.handle(
        _pathIdMeta,
        pathId.isAcceptableOrUnknown(data['path_id']!, _pathIdMeta),
      );
    } else if (isInserting) {
      context.missing(_pathIdMeta);
    }
    if (data.containsKey('selected_branch_id')) {
      context.handle(
        _selectedBranchIdMeta,
        selectedBranchId.isAcceptableOrUnknown(
          data['selected_branch_id']!,
          _selectedBranchIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_selectedBranchIdMeta);
    }
    if (data.containsKey('selected_exercise_id')) {
      context.handle(
        _selectedExerciseIdMeta,
        selectedExerciseId.isAcceptableOrUnknown(
          data['selected_exercise_id']!,
          _selectedExerciseIdMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {pathId};
  @override
  ProgressionConfig map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProgressionConfig(
      pathId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path_id'],
      )!,
      selectedBranchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}selected_branch_id'],
      )!,
      selectedExerciseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}selected_exercise_id'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ProgressionConfigsTable createAlias(String alias) {
    return $ProgressionConfigsTable(attachedDatabase, alias);
  }
}

class ProgressionConfig extends DataClass
    implements Insertable<ProgressionConfig> {
  final String pathId;
  final String selectedBranchId;

  /// Null for alternating branches, where two exercises are current at once
  /// and the session's exercise is resolved from the branch pattern instead.
  /// See `docs/PLAN.md` §2.2.2.
  final String? selectedExerciseId;
  final DateTime updatedAt;
  const ProgressionConfig({
    required this.pathId,
    required this.selectedBranchId,
    this.selectedExerciseId,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['path_id'] = Variable<String>(pathId);
    map['selected_branch_id'] = Variable<String>(selectedBranchId);
    if (!nullToAbsent || selectedExerciseId != null) {
      map['selected_exercise_id'] = Variable<String>(selectedExerciseId);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ProgressionConfigsCompanion toCompanion(bool nullToAbsent) {
    return ProgressionConfigsCompanion(
      pathId: Value(pathId),
      selectedBranchId: Value(selectedBranchId),
      selectedExerciseId: selectedExerciseId == null && nullToAbsent
          ? const Value.absent()
          : Value(selectedExerciseId),
      updatedAt: Value(updatedAt),
    );
  }

  factory ProgressionConfig.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProgressionConfig(
      pathId: serializer.fromJson<String>(json['pathId']),
      selectedBranchId: serializer.fromJson<String>(json['selectedBranchId']),
      selectedExerciseId: serializer.fromJson<String?>(
        json['selectedExerciseId'],
      ),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'pathId': serializer.toJson<String>(pathId),
      'selectedBranchId': serializer.toJson<String>(selectedBranchId),
      'selectedExerciseId': serializer.toJson<String?>(selectedExerciseId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ProgressionConfig copyWith({
    String? pathId,
    String? selectedBranchId,
    Value<String?> selectedExerciseId = const Value.absent(),
    DateTime? updatedAt,
  }) => ProgressionConfig(
    pathId: pathId ?? this.pathId,
    selectedBranchId: selectedBranchId ?? this.selectedBranchId,
    selectedExerciseId: selectedExerciseId.present
        ? selectedExerciseId.value
        : this.selectedExerciseId,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ProgressionConfig copyWithCompanion(ProgressionConfigsCompanion data) {
    return ProgressionConfig(
      pathId: data.pathId.present ? data.pathId.value : this.pathId,
      selectedBranchId: data.selectedBranchId.present
          ? data.selectedBranchId.value
          : this.selectedBranchId,
      selectedExerciseId: data.selectedExerciseId.present
          ? data.selectedExerciseId.value
          : this.selectedExerciseId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProgressionConfig(')
          ..write('pathId: $pathId, ')
          ..write('selectedBranchId: $selectedBranchId, ')
          ..write('selectedExerciseId: $selectedExerciseId, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(pathId, selectedBranchId, selectedExerciseId, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProgressionConfig &&
          other.pathId == this.pathId &&
          other.selectedBranchId == this.selectedBranchId &&
          other.selectedExerciseId == this.selectedExerciseId &&
          other.updatedAt == this.updatedAt);
}

class ProgressionConfigsCompanion extends UpdateCompanion<ProgressionConfig> {
  final Value<String> pathId;
  final Value<String> selectedBranchId;
  final Value<String?> selectedExerciseId;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ProgressionConfigsCompanion({
    this.pathId = const Value.absent(),
    this.selectedBranchId = const Value.absent(),
    this.selectedExerciseId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProgressionConfigsCompanion.insert({
    required String pathId,
    required String selectedBranchId,
    this.selectedExerciseId = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : pathId = Value(pathId),
       selectedBranchId = Value(selectedBranchId),
       updatedAt = Value(updatedAt);
  static Insertable<ProgressionConfig> custom({
    Expression<String>? pathId,
    Expression<String>? selectedBranchId,
    Expression<String>? selectedExerciseId,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (pathId != null) 'path_id': pathId,
      if (selectedBranchId != null) 'selected_branch_id': selectedBranchId,
      if (selectedExerciseId != null)
        'selected_exercise_id': selectedExerciseId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProgressionConfigsCompanion copyWith({
    Value<String>? pathId,
    Value<String>? selectedBranchId,
    Value<String?>? selectedExerciseId,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ProgressionConfigsCompanion(
      pathId: pathId ?? this.pathId,
      selectedBranchId: selectedBranchId ?? this.selectedBranchId,
      selectedExerciseId: selectedExerciseId ?? this.selectedExerciseId,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (pathId.present) {
      map['path_id'] = Variable<String>(pathId.value);
    }
    if (selectedBranchId.present) {
      map['selected_branch_id'] = Variable<String>(selectedBranchId.value);
    }
    if (selectedExerciseId.present) {
      map['selected_exercise_id'] = Variable<String>(selectedExerciseId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProgressionConfigsCompanion(')
          ..write('pathId: $pathId, ')
          ..write('selectedBranchId: $selectedBranchId, ')
          ..write('selectedExerciseId: $selectedExerciseId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExerciseStatesTable extends ExerciseStates
    with TableInfo<$ExerciseStatesTable, ExerciseState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExerciseStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _exerciseIdMeta = const VerificationMeta(
    'exerciseId',
  );
  @override
  late final GeneratedColumn<String> exerciseId = GeneratedColumn<String>(
    'exercise_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _workingLoadKgMeta = const VerificationMeta(
    'workingLoadKg',
  );
  @override
  late final GeneratedColumn<double> workingLoadKg = GeneratedColumn<double>(
    'working_load_kg',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastIncrementKgMeta = const VerificationMeta(
    'lastIncrementKg',
  );
  @override
  late final GeneratedColumn<double> lastIncrementKg = GeneratedColumn<double>(
    'last_increment_kg',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _consecutiveFailuresMeta =
      const VerificationMeta('consecutiveFailures');
  @override
  late final GeneratedColumn<int> consecutiveFailures = GeneratedColumn<int>(
    'consecutive_failures',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    exerciseId,
    workingLoadKg,
    lastIncrementKg,
    consecutiveFailures,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exercise_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExerciseState> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('exercise_id')) {
      context.handle(
        _exerciseIdMeta,
        exerciseId.isAcceptableOrUnknown(data['exercise_id']!, _exerciseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_exerciseIdMeta);
    }
    if (data.containsKey('working_load_kg')) {
      context.handle(
        _workingLoadKgMeta,
        workingLoadKg.isAcceptableOrUnknown(
          data['working_load_kg']!,
          _workingLoadKgMeta,
        ),
      );
    }
    if (data.containsKey('last_increment_kg')) {
      context.handle(
        _lastIncrementKgMeta,
        lastIncrementKg.isAcceptableOrUnknown(
          data['last_increment_kg']!,
          _lastIncrementKgMeta,
        ),
      );
    }
    if (data.containsKey('consecutive_failures')) {
      context.handle(
        _consecutiveFailuresMeta,
        consecutiveFailures.isAcceptableOrUnknown(
          data['consecutive_failures']!,
          _consecutiveFailuresMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {exerciseId};
  @override
  ExerciseState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExerciseState(
      exerciseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exercise_id'],
      )!,
      workingLoadKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}working_load_kg'],
      )!,
      lastIncrementKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}last_increment_kg'],
      ),
      consecutiveFailures: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}consecutive_failures'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ExerciseStatesTable createAlias(String alias) {
    return $ExerciseStatesTable(attachedDatabase, alias);
  }
}

class ExerciseState extends DataClass implements Insertable<ExerciseState> {
  final String exerciseId;

  /// The load prescribed for the *next* set. Past loads live on
  /// [SetRecords.weightKg]; raising this must not rewrite history.
  final double workingLoadKg;

  /// What the user last chose to add here, remembered so the "add weight?"
  /// prompt can pre-fill it. Null seeds the prompt at 2.5 lb / 1 kg.
  /// Deliberately not a setting — see `docs/PLAN.md` §2.2.1.
  final double? lastIncrementKg;
  final int consecutiveFailures;
  final DateTime updatedAt;
  const ExerciseState({
    required this.exerciseId,
    required this.workingLoadKg,
    this.lastIncrementKg,
    required this.consecutiveFailures,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['exercise_id'] = Variable<String>(exerciseId);
    map['working_load_kg'] = Variable<double>(workingLoadKg);
    if (!nullToAbsent || lastIncrementKg != null) {
      map['last_increment_kg'] = Variable<double>(lastIncrementKg);
    }
    map['consecutive_failures'] = Variable<int>(consecutiveFailures);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ExerciseStatesCompanion toCompanion(bool nullToAbsent) {
    return ExerciseStatesCompanion(
      exerciseId: Value(exerciseId),
      workingLoadKg: Value(workingLoadKg),
      lastIncrementKg: lastIncrementKg == null && nullToAbsent
          ? const Value.absent()
          : Value(lastIncrementKg),
      consecutiveFailures: Value(consecutiveFailures),
      updatedAt: Value(updatedAt),
    );
  }

  factory ExerciseState.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExerciseState(
      exerciseId: serializer.fromJson<String>(json['exerciseId']),
      workingLoadKg: serializer.fromJson<double>(json['workingLoadKg']),
      lastIncrementKg: serializer.fromJson<double?>(json['lastIncrementKg']),
      consecutiveFailures: serializer.fromJson<int>(
        json['consecutiveFailures'],
      ),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'exerciseId': serializer.toJson<String>(exerciseId),
      'workingLoadKg': serializer.toJson<double>(workingLoadKg),
      'lastIncrementKg': serializer.toJson<double?>(lastIncrementKg),
      'consecutiveFailures': serializer.toJson<int>(consecutiveFailures),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ExerciseState copyWith({
    String? exerciseId,
    double? workingLoadKg,
    Value<double?> lastIncrementKg = const Value.absent(),
    int? consecutiveFailures,
    DateTime? updatedAt,
  }) => ExerciseState(
    exerciseId: exerciseId ?? this.exerciseId,
    workingLoadKg: workingLoadKg ?? this.workingLoadKg,
    lastIncrementKg: lastIncrementKg.present
        ? lastIncrementKg.value
        : this.lastIncrementKg,
    consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ExerciseState copyWithCompanion(ExerciseStatesCompanion data) {
    return ExerciseState(
      exerciseId: data.exerciseId.present
          ? data.exerciseId.value
          : this.exerciseId,
      workingLoadKg: data.workingLoadKg.present
          ? data.workingLoadKg.value
          : this.workingLoadKg,
      lastIncrementKg: data.lastIncrementKg.present
          ? data.lastIncrementKg.value
          : this.lastIncrementKg,
      consecutiveFailures: data.consecutiveFailures.present
          ? data.consecutiveFailures.value
          : this.consecutiveFailures,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExerciseState(')
          ..write('exerciseId: $exerciseId, ')
          ..write('workingLoadKg: $workingLoadKg, ')
          ..write('lastIncrementKg: $lastIncrementKg, ')
          ..write('consecutiveFailures: $consecutiveFailures, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    exerciseId,
    workingLoadKg,
    lastIncrementKg,
    consecutiveFailures,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExerciseState &&
          other.exerciseId == this.exerciseId &&
          other.workingLoadKg == this.workingLoadKg &&
          other.lastIncrementKg == this.lastIncrementKg &&
          other.consecutiveFailures == this.consecutiveFailures &&
          other.updatedAt == this.updatedAt);
}

class ExerciseStatesCompanion extends UpdateCompanion<ExerciseState> {
  final Value<String> exerciseId;
  final Value<double> workingLoadKg;
  final Value<double?> lastIncrementKg;
  final Value<int> consecutiveFailures;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ExerciseStatesCompanion({
    this.exerciseId = const Value.absent(),
    this.workingLoadKg = const Value.absent(),
    this.lastIncrementKg = const Value.absent(),
    this.consecutiveFailures = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExerciseStatesCompanion.insert({
    required String exerciseId,
    this.workingLoadKg = const Value.absent(),
    this.lastIncrementKg = const Value.absent(),
    this.consecutiveFailures = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : exerciseId = Value(exerciseId),
       updatedAt = Value(updatedAt);
  static Insertable<ExerciseState> custom({
    Expression<String>? exerciseId,
    Expression<double>? workingLoadKg,
    Expression<double>? lastIncrementKg,
    Expression<int>? consecutiveFailures,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (workingLoadKg != null) 'working_load_kg': workingLoadKg,
      if (lastIncrementKg != null) 'last_increment_kg': lastIncrementKg,
      if (consecutiveFailures != null)
        'consecutive_failures': consecutiveFailures,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExerciseStatesCompanion copyWith({
    Value<String>? exerciseId,
    Value<double>? workingLoadKg,
    Value<double?>? lastIncrementKg,
    Value<int>? consecutiveFailures,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ExerciseStatesCompanion(
      exerciseId: exerciseId ?? this.exerciseId,
      workingLoadKg: workingLoadKg ?? this.workingLoadKg,
      lastIncrementKg: lastIncrementKg ?? this.lastIncrementKg,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (exerciseId.present) {
      map['exercise_id'] = Variable<String>(exerciseId.value);
    }
    if (workingLoadKg.present) {
      map['working_load_kg'] = Variable<double>(workingLoadKg.value);
    }
    if (lastIncrementKg.present) {
      map['last_increment_kg'] = Variable<double>(lastIncrementKg.value);
    }
    if (consecutiveFailures.present) {
      map['consecutive_failures'] = Variable<int>(consecutiveFailures.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExerciseStatesCompanion(')
          ..write('exerciseId: $exerciseId, ')
          ..write('workingLoadKg: $workingLoadKg, ')
          ..write('lastIncrementKg: $lastIncrementKg, ')
          ..write('consecutiveFailures: $consecutiveFailures, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkoutSessionsTable extends WorkoutSessions
    with TableInfo<$WorkoutSessionsTable, WorkoutSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rotationIndexMeta = const VerificationMeta(
    'rotationIndex',
  );
  @override
  late final GeneratedColumn<int> rotationIndex = GeneratedColumn<int>(
    'rotation_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pairRestSecondsMeta = const VerificationMeta(
    'pairRestSeconds',
  );
  @override
  late final GeneratedColumn<int> pairRestSeconds = GeneratedColumn<int>(
    'pair_rest_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tripletRestSecondsMeta =
      const VerificationMeta('tripletRestSeconds');
  @override
  late final GeneratedColumn<int> tripletRestSeconds = GeneratedColumn<int>(
    'triplet_rest_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cursorJsonMeta = const VerificationMeta(
    'cursorJson',
  );
  @override
  late final GeneratedColumn<String> cursorJson = GeneratedColumn<String>(
    'cursor_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    startedAt,
    endedAt,
    status,
    rotationIndex,
    pairRestSeconds,
    tripletRestSeconds,
    cursorJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workout_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkoutSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('rotation_index')) {
      context.handle(
        _rotationIndexMeta,
        rotationIndex.isAcceptableOrUnknown(
          data['rotation_index']!,
          _rotationIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_rotationIndexMeta);
    }
    if (data.containsKey('pair_rest_seconds')) {
      context.handle(
        _pairRestSecondsMeta,
        pairRestSeconds.isAcceptableOrUnknown(
          data['pair_rest_seconds']!,
          _pairRestSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_pairRestSecondsMeta);
    }
    if (data.containsKey('triplet_rest_seconds')) {
      context.handle(
        _tripletRestSecondsMeta,
        tripletRestSeconds.isAcceptableOrUnknown(
          data['triplet_rest_seconds']!,
          _tripletRestSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_tripletRestSecondsMeta);
    }
    if (data.containsKey('cursor_json')) {
      context.handle(
        _cursorJsonMeta,
        cursorJson.isAcceptableOrUnknown(data['cursor_json']!, _cursorJsonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkoutSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkoutSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      rotationIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rotation_index'],
      )!,
      pairRestSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pair_rest_seconds'],
      )!,
      tripletRestSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}triplet_rest_seconds'],
      )!,
      cursorJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cursor_json'],
      ),
    );
  }

  @override
  $WorkoutSessionsTable createAlias(String alias) {
    return $WorkoutSessionsTable(attachedDatabase, alias);
  }
}

class WorkoutSession extends DataClass implements Insertable<WorkoutSession> {
  final String id;
  final DateTime startedAt;

  /// Null while in progress.
  final DateTime? endedAt;

  /// 'in_progress' | 'completed' | 'abandoned'. Only completed sessions
  /// advance the rotation counter.
  final String status;

  /// Which pair order this session used. Stored rather than recomputed so
  /// history stays truthful if the completed-session count later changes.
  final int rotationIndex;
  final int pairRestSeconds;
  final int tripletRestSeconds;

  /// Resume point for an interrupted workout. Cleared once finished.
  final String? cursorJson;
  const WorkoutSession({
    required this.id,
    required this.startedAt,
    this.endedAt,
    required this.status,
    required this.rotationIndex,
    required this.pairRestSeconds,
    required this.tripletRestSeconds,
    this.cursorJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    map['status'] = Variable<String>(status);
    map['rotation_index'] = Variable<int>(rotationIndex);
    map['pair_rest_seconds'] = Variable<int>(pairRestSeconds);
    map['triplet_rest_seconds'] = Variable<int>(tripletRestSeconds);
    if (!nullToAbsent || cursorJson != null) {
      map['cursor_json'] = Variable<String>(cursorJson);
    }
    return map;
  }

  WorkoutSessionsCompanion toCompanion(bool nullToAbsent) {
    return WorkoutSessionsCompanion(
      id: Value(id),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      status: Value(status),
      rotationIndex: Value(rotationIndex),
      pairRestSeconds: Value(pairRestSeconds),
      tripletRestSeconds: Value(tripletRestSeconds),
      cursorJson: cursorJson == null && nullToAbsent
          ? const Value.absent()
          : Value(cursorJson),
    );
  }

  factory WorkoutSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkoutSession(
      id: serializer.fromJson<String>(json['id']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      status: serializer.fromJson<String>(json['status']),
      rotationIndex: serializer.fromJson<int>(json['rotationIndex']),
      pairRestSeconds: serializer.fromJson<int>(json['pairRestSeconds']),
      tripletRestSeconds: serializer.fromJson<int>(json['tripletRestSeconds']),
      cursorJson: serializer.fromJson<String?>(json['cursorJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'status': serializer.toJson<String>(status),
      'rotationIndex': serializer.toJson<int>(rotationIndex),
      'pairRestSeconds': serializer.toJson<int>(pairRestSeconds),
      'tripletRestSeconds': serializer.toJson<int>(tripletRestSeconds),
      'cursorJson': serializer.toJson<String?>(cursorJson),
    };
  }

  WorkoutSession copyWith({
    String? id,
    DateTime? startedAt,
    Value<DateTime?> endedAt = const Value.absent(),
    String? status,
    int? rotationIndex,
    int? pairRestSeconds,
    int? tripletRestSeconds,
    Value<String?> cursorJson = const Value.absent(),
  }) => WorkoutSession(
    id: id ?? this.id,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    status: status ?? this.status,
    rotationIndex: rotationIndex ?? this.rotationIndex,
    pairRestSeconds: pairRestSeconds ?? this.pairRestSeconds,
    tripletRestSeconds: tripletRestSeconds ?? this.tripletRestSeconds,
    cursorJson: cursorJson.present ? cursorJson.value : this.cursorJson,
  );
  WorkoutSession copyWithCompanion(WorkoutSessionsCompanion data) {
    return WorkoutSession(
      id: data.id.present ? data.id.value : this.id,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      status: data.status.present ? data.status.value : this.status,
      rotationIndex: data.rotationIndex.present
          ? data.rotationIndex.value
          : this.rotationIndex,
      pairRestSeconds: data.pairRestSeconds.present
          ? data.pairRestSeconds.value
          : this.pairRestSeconds,
      tripletRestSeconds: data.tripletRestSeconds.present
          ? data.tripletRestSeconds.value
          : this.tripletRestSeconds,
      cursorJson: data.cursorJson.present
          ? data.cursorJson.value
          : this.cursorJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutSession(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('status: $status, ')
          ..write('rotationIndex: $rotationIndex, ')
          ..write('pairRestSeconds: $pairRestSeconds, ')
          ..write('tripletRestSeconds: $tripletRestSeconds, ')
          ..write('cursorJson: $cursorJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    startedAt,
    endedAt,
    status,
    rotationIndex,
    pairRestSeconds,
    tripletRestSeconds,
    cursorJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutSession &&
          other.id == this.id &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.status == this.status &&
          other.rotationIndex == this.rotationIndex &&
          other.pairRestSeconds == this.pairRestSeconds &&
          other.tripletRestSeconds == this.tripletRestSeconds &&
          other.cursorJson == this.cursorJson);
}

class WorkoutSessionsCompanion extends UpdateCompanion<WorkoutSession> {
  final Value<String> id;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<String> status;
  final Value<int> rotationIndex;
  final Value<int> pairRestSeconds;
  final Value<int> tripletRestSeconds;
  final Value<String?> cursorJson;
  final Value<int> rowid;
  const WorkoutSessionsCompanion({
    this.id = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.rotationIndex = const Value.absent(),
    this.pairRestSeconds = const Value.absent(),
    this.tripletRestSeconds = const Value.absent(),
    this.cursorJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkoutSessionsCompanion.insert({
    required String id,
    required DateTime startedAt,
    this.endedAt = const Value.absent(),
    required String status,
    required int rotationIndex,
    required int pairRestSeconds,
    required int tripletRestSeconds,
    this.cursorJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       startedAt = Value(startedAt),
       status = Value(status),
       rotationIndex = Value(rotationIndex),
       pairRestSeconds = Value(pairRestSeconds),
       tripletRestSeconds = Value(tripletRestSeconds);
  static Insertable<WorkoutSession> custom({
    Expression<String>? id,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<String>? status,
    Expression<int>? rotationIndex,
    Expression<int>? pairRestSeconds,
    Expression<int>? tripletRestSeconds,
    Expression<String>? cursorJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (status != null) 'status': status,
      if (rotationIndex != null) 'rotation_index': rotationIndex,
      if (pairRestSeconds != null) 'pair_rest_seconds': pairRestSeconds,
      if (tripletRestSeconds != null)
        'triplet_rest_seconds': tripletRestSeconds,
      if (cursorJson != null) 'cursor_json': cursorJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkoutSessionsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? startedAt,
    Value<DateTime?>? endedAt,
    Value<String>? status,
    Value<int>? rotationIndex,
    Value<int>? pairRestSeconds,
    Value<int>? tripletRestSeconds,
    Value<String?>? cursorJson,
    Value<int>? rowid,
  }) {
    return WorkoutSessionsCompanion(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      status: status ?? this.status,
      rotationIndex: rotationIndex ?? this.rotationIndex,
      pairRestSeconds: pairRestSeconds ?? this.pairRestSeconds,
      tripletRestSeconds: tripletRestSeconds ?? this.tripletRestSeconds,
      cursorJson: cursorJson ?? this.cursorJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rotationIndex.present) {
      map['rotation_index'] = Variable<int>(rotationIndex.value);
    }
    if (pairRestSeconds.present) {
      map['pair_rest_seconds'] = Variable<int>(pairRestSeconds.value);
    }
    if (tripletRestSeconds.present) {
      map['triplet_rest_seconds'] = Variable<int>(tripletRestSeconds.value);
    }
    if (cursorJson.present) {
      map['cursor_json'] = Variable<String>(cursorJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutSessionsCompanion(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('status: $status, ')
          ..write('rotationIndex: $rotationIndex, ')
          ..write('pairRestSeconds: $pairRestSeconds, ')
          ..write('tripletRestSeconds: $tripletRestSeconds, ')
          ..write('cursorJson: $cursorJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SetRecordsTable extends SetRecords
    with TableInfo<$SetRecordsTable, SetRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SetRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES workout_sessions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _pathIdMeta = const VerificationMeta('pathId');
  @override
  late final GeneratedColumn<String> pathId = GeneratedColumn<String>(
    'path_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exerciseIdMeta = const VerificationMeta(
    'exerciseId',
  );
  @override
  late final GeneratedColumn<String> exerciseId = GeneratedColumn<String>(
    'exercise_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _setIndexMeta = const VerificationMeta(
    'setIndex',
  );
  @override
  late final GeneratedColumn<int> setIndex = GeneratedColumn<int>(
    'set_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repsCompletedMeta = const VerificationMeta(
    'repsCompleted',
  );
  @override
  late final GeneratedColumn<int> repsCompleted = GeneratedColumn<int>(
    'reps_completed',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _holdSecondsMeta = const VerificationMeta(
    'holdSeconds',
  );
  @override
  late final GeneratedColumn<int> holdSeconds = GeneratedColumn<int>(
    'hold_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _weightKgMeta = const VerificationMeta(
    'weightKg',
  );
  @override
  late final GeneratedColumn<double> weightKg = GeneratedColumn<double>(
    'weight_kg',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _recordedAtMeta = const VerificationMeta(
    'recordedAt',
  );
  @override
  late final GeneratedColumn<DateTime> recordedAt = GeneratedColumn<DateTime>(
    'recorded_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    pathId,
    exerciseId,
    setIndex,
    repsCompleted,
    holdSeconds,
    weightKg,
    recordedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'set_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<SetRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('path_id')) {
      context.handle(
        _pathIdMeta,
        pathId.isAcceptableOrUnknown(data['path_id']!, _pathIdMeta),
      );
    } else if (isInserting) {
      context.missing(_pathIdMeta);
    }
    if (data.containsKey('exercise_id')) {
      context.handle(
        _exerciseIdMeta,
        exerciseId.isAcceptableOrUnknown(data['exercise_id']!, _exerciseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_exerciseIdMeta);
    }
    if (data.containsKey('set_index')) {
      context.handle(
        _setIndexMeta,
        setIndex.isAcceptableOrUnknown(data['set_index']!, _setIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_setIndexMeta);
    }
    if (data.containsKey('reps_completed')) {
      context.handle(
        _repsCompletedMeta,
        repsCompleted.isAcceptableOrUnknown(
          data['reps_completed']!,
          _repsCompletedMeta,
        ),
      );
    }
    if (data.containsKey('hold_seconds')) {
      context.handle(
        _holdSecondsMeta,
        holdSeconds.isAcceptableOrUnknown(
          data['hold_seconds']!,
          _holdSecondsMeta,
        ),
      );
    }
    if (data.containsKey('weight_kg')) {
      context.handle(
        _weightKgMeta,
        weightKg.isAcceptableOrUnknown(data['weight_kg']!, _weightKgMeta),
      );
    }
    if (data.containsKey('recorded_at')) {
      context.handle(
        _recordedAtMeta,
        recordedAt.isAcceptableOrUnknown(data['recorded_at']!, _recordedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_recordedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SetRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SetRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      pathId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path_id'],
      )!,
      exerciseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exercise_id'],
      )!,
      setIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}set_index'],
      )!,
      repsCompleted: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reps_completed'],
      ),
      holdSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hold_seconds'],
      ),
      weightKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight_kg'],
      )!,
      recordedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}recorded_at'],
      )!,
    );
  }

  @override
  $SetRecordsTable createAlias(String alias) {
    return $SetRecordsTable(attachedDatabase, alias);
  }
}

class SetRecord extends DataClass implements Insertable<SetRecord> {
  final String id;
  final String sessionId;
  final String pathId;
  final String exerciseId;
  final int setIndex;
  final int? repsCompleted;
  final int? holdSeconds;

  /// The load actually used for this set, independent of the exercise's
  /// current working load.
  final double weightKg;
  final DateTime recordedAt;
  const SetRecord({
    required this.id,
    required this.sessionId,
    required this.pathId,
    required this.exerciseId,
    required this.setIndex,
    this.repsCompleted,
    this.holdSeconds,
    required this.weightKg,
    required this.recordedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['path_id'] = Variable<String>(pathId);
    map['exercise_id'] = Variable<String>(exerciseId);
    map['set_index'] = Variable<int>(setIndex);
    if (!nullToAbsent || repsCompleted != null) {
      map['reps_completed'] = Variable<int>(repsCompleted);
    }
    if (!nullToAbsent || holdSeconds != null) {
      map['hold_seconds'] = Variable<int>(holdSeconds);
    }
    map['weight_kg'] = Variable<double>(weightKg);
    map['recorded_at'] = Variable<DateTime>(recordedAt);
    return map;
  }

  SetRecordsCompanion toCompanion(bool nullToAbsent) {
    return SetRecordsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      pathId: Value(pathId),
      exerciseId: Value(exerciseId),
      setIndex: Value(setIndex),
      repsCompleted: repsCompleted == null && nullToAbsent
          ? const Value.absent()
          : Value(repsCompleted),
      holdSeconds: holdSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(holdSeconds),
      weightKg: Value(weightKg),
      recordedAt: Value(recordedAt),
    );
  }

  factory SetRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SetRecord(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      pathId: serializer.fromJson<String>(json['pathId']),
      exerciseId: serializer.fromJson<String>(json['exerciseId']),
      setIndex: serializer.fromJson<int>(json['setIndex']),
      repsCompleted: serializer.fromJson<int?>(json['repsCompleted']),
      holdSeconds: serializer.fromJson<int?>(json['holdSeconds']),
      weightKg: serializer.fromJson<double>(json['weightKg']),
      recordedAt: serializer.fromJson<DateTime>(json['recordedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'pathId': serializer.toJson<String>(pathId),
      'exerciseId': serializer.toJson<String>(exerciseId),
      'setIndex': serializer.toJson<int>(setIndex),
      'repsCompleted': serializer.toJson<int?>(repsCompleted),
      'holdSeconds': serializer.toJson<int?>(holdSeconds),
      'weightKg': serializer.toJson<double>(weightKg),
      'recordedAt': serializer.toJson<DateTime>(recordedAt),
    };
  }

  SetRecord copyWith({
    String? id,
    String? sessionId,
    String? pathId,
    String? exerciseId,
    int? setIndex,
    Value<int?> repsCompleted = const Value.absent(),
    Value<int?> holdSeconds = const Value.absent(),
    double? weightKg,
    DateTime? recordedAt,
  }) => SetRecord(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    pathId: pathId ?? this.pathId,
    exerciseId: exerciseId ?? this.exerciseId,
    setIndex: setIndex ?? this.setIndex,
    repsCompleted: repsCompleted.present
        ? repsCompleted.value
        : this.repsCompleted,
    holdSeconds: holdSeconds.present ? holdSeconds.value : this.holdSeconds,
    weightKg: weightKg ?? this.weightKg,
    recordedAt: recordedAt ?? this.recordedAt,
  );
  SetRecord copyWithCompanion(SetRecordsCompanion data) {
    return SetRecord(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      pathId: data.pathId.present ? data.pathId.value : this.pathId,
      exerciseId: data.exerciseId.present
          ? data.exerciseId.value
          : this.exerciseId,
      setIndex: data.setIndex.present ? data.setIndex.value : this.setIndex,
      repsCompleted: data.repsCompleted.present
          ? data.repsCompleted.value
          : this.repsCompleted,
      holdSeconds: data.holdSeconds.present
          ? data.holdSeconds.value
          : this.holdSeconds,
      weightKg: data.weightKg.present ? data.weightKg.value : this.weightKg,
      recordedAt: data.recordedAt.present
          ? data.recordedAt.value
          : this.recordedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SetRecord(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('pathId: $pathId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('setIndex: $setIndex, ')
          ..write('repsCompleted: $repsCompleted, ')
          ..write('holdSeconds: $holdSeconds, ')
          ..write('weightKg: $weightKg, ')
          ..write('recordedAt: $recordedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    pathId,
    exerciseId,
    setIndex,
    repsCompleted,
    holdSeconds,
    weightKg,
    recordedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SetRecord &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.pathId == this.pathId &&
          other.exerciseId == this.exerciseId &&
          other.setIndex == this.setIndex &&
          other.repsCompleted == this.repsCompleted &&
          other.holdSeconds == this.holdSeconds &&
          other.weightKg == this.weightKg &&
          other.recordedAt == this.recordedAt);
}

class SetRecordsCompanion extends UpdateCompanion<SetRecord> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String> pathId;
  final Value<String> exerciseId;
  final Value<int> setIndex;
  final Value<int?> repsCompleted;
  final Value<int?> holdSeconds;
  final Value<double> weightKg;
  final Value<DateTime> recordedAt;
  final Value<int> rowid;
  const SetRecordsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.pathId = const Value.absent(),
    this.exerciseId = const Value.absent(),
    this.setIndex = const Value.absent(),
    this.repsCompleted = const Value.absent(),
    this.holdSeconds = const Value.absent(),
    this.weightKg = const Value.absent(),
    this.recordedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SetRecordsCompanion.insert({
    required String id,
    required String sessionId,
    required String pathId,
    required String exerciseId,
    required int setIndex,
    this.repsCompleted = const Value.absent(),
    this.holdSeconds = const Value.absent(),
    this.weightKg = const Value.absent(),
    required DateTime recordedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       pathId = Value(pathId),
       exerciseId = Value(exerciseId),
       setIndex = Value(setIndex),
       recordedAt = Value(recordedAt);
  static Insertable<SetRecord> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? pathId,
    Expression<String>? exerciseId,
    Expression<int>? setIndex,
    Expression<int>? repsCompleted,
    Expression<int>? holdSeconds,
    Expression<double>? weightKg,
    Expression<DateTime>? recordedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (pathId != null) 'path_id': pathId,
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (setIndex != null) 'set_index': setIndex,
      if (repsCompleted != null) 'reps_completed': repsCompleted,
      if (holdSeconds != null) 'hold_seconds': holdSeconds,
      if (weightKg != null) 'weight_kg': weightKg,
      if (recordedAt != null) 'recorded_at': recordedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SetRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<String>? pathId,
    Value<String>? exerciseId,
    Value<int>? setIndex,
    Value<int?>? repsCompleted,
    Value<int?>? holdSeconds,
    Value<double>? weightKg,
    Value<DateTime>? recordedAt,
    Value<int>? rowid,
  }) {
    return SetRecordsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      pathId: pathId ?? this.pathId,
      exerciseId: exerciseId ?? this.exerciseId,
      setIndex: setIndex ?? this.setIndex,
      repsCompleted: repsCompleted ?? this.repsCompleted,
      holdSeconds: holdSeconds ?? this.holdSeconds,
      weightKg: weightKg ?? this.weightKg,
      recordedAt: recordedAt ?? this.recordedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (pathId.present) {
      map['path_id'] = Variable<String>(pathId.value);
    }
    if (exerciseId.present) {
      map['exercise_id'] = Variable<String>(exerciseId.value);
    }
    if (setIndex.present) {
      map['set_index'] = Variable<int>(setIndex.value);
    }
    if (repsCompleted.present) {
      map['reps_completed'] = Variable<int>(repsCompleted.value);
    }
    if (holdSeconds.present) {
      map['hold_seconds'] = Variable<int>(holdSeconds.value);
    }
    if (weightKg.present) {
      map['weight_kg'] = Variable<double>(weightKg.value);
    }
    if (recordedAt.present) {
      map['recorded_at'] = Variable<DateTime>(recordedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SetRecordsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('pathId: $pathId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('setIndex: $setIndex, ')
          ..write('repsCompleted: $repsCompleted, ')
          ..write('holdSeconds: $holdSeconds, ')
          ..write('weightKg: $weightKg, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $UserProfilesTable userProfiles = $UserProfilesTable(this);
  late final $BodyWeightEntriesTable bodyWeightEntries =
      $BodyWeightEntriesTable(this);
  late final $ProgressionConfigsTable progressionConfigs =
      $ProgressionConfigsTable(this);
  late final $ExerciseStatesTable exerciseStates = $ExerciseStatesTable(this);
  late final $WorkoutSessionsTable workoutSessions = $WorkoutSessionsTable(
    this,
  );
  late final $SetRecordsTable setRecords = $SetRecordsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    userProfiles,
    bodyWeightEntries,
    progressionConfigs,
    exerciseStates,
    workoutSessions,
    setRecords,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'workout_sessions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('set_records', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$UserProfilesTableCreateCompanionBuilder =
    UserProfilesCompanion Function({
      Value<int> id,
      Value<double?> heightCm,
      Value<String> unitSystem,
      Value<int> defaultPairRestSeconds,
      Value<int> defaultTripletRestSeconds,
      Value<bool> rotatePairOrder,
    });
typedef $$UserProfilesTableUpdateCompanionBuilder =
    UserProfilesCompanion Function({
      Value<int> id,
      Value<double?> heightCm,
      Value<String> unitSystem,
      Value<int> defaultPairRestSeconds,
      Value<int> defaultTripletRestSeconds,
      Value<bool> rotatePairOrder,
    });

class $$UserProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $UserProfilesTable> {
  $$UserProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get heightCm => $composableBuilder(
    column: $table.heightCm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unitSystem => $composableBuilder(
    column: $table.unitSystem,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get defaultPairRestSeconds => $composableBuilder(
    column: $table.defaultPairRestSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get defaultTripletRestSeconds => $composableBuilder(
    column: $table.defaultTripletRestSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get rotatePairOrder => $composableBuilder(
    column: $table.rotatePairOrder,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $UserProfilesTable> {
  $$UserProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get heightCm => $composableBuilder(
    column: $table.heightCm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unitSystem => $composableBuilder(
    column: $table.unitSystem,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get defaultPairRestSeconds => $composableBuilder(
    column: $table.defaultPairRestSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get defaultTripletRestSeconds => $composableBuilder(
    column: $table.defaultTripletRestSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get rotatePairOrder => $composableBuilder(
    column: $table.rotatePairOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserProfilesTable> {
  $$UserProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get heightCm =>
      $composableBuilder(column: $table.heightCm, builder: (column) => column);

  GeneratedColumn<String> get unitSystem => $composableBuilder(
    column: $table.unitSystem,
    builder: (column) => column,
  );

  GeneratedColumn<int> get defaultPairRestSeconds => $composableBuilder(
    column: $table.defaultPairRestSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get defaultTripletRestSeconds => $composableBuilder(
    column: $table.defaultTripletRestSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get rotatePairOrder => $composableBuilder(
    column: $table.rotatePairOrder,
    builder: (column) => column,
  );
}

class $$UserProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserProfilesTable,
          UserProfile,
          $$UserProfilesTableFilterComposer,
          $$UserProfilesTableOrderingComposer,
          $$UserProfilesTableAnnotationComposer,
          $$UserProfilesTableCreateCompanionBuilder,
          $$UserProfilesTableUpdateCompanionBuilder,
          (
            UserProfile,
            BaseReferences<_$AppDatabase, $UserProfilesTable, UserProfile>,
          ),
          UserProfile,
          PrefetchHooks Function()
        > {
  $$UserProfilesTableTableManager(_$AppDatabase db, $UserProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<double?> heightCm = const Value.absent(),
                Value<String> unitSystem = const Value.absent(),
                Value<int> defaultPairRestSeconds = const Value.absent(),
                Value<int> defaultTripletRestSeconds = const Value.absent(),
                Value<bool> rotatePairOrder = const Value.absent(),
              }) => UserProfilesCompanion(
                id: id,
                heightCm: heightCm,
                unitSystem: unitSystem,
                defaultPairRestSeconds: defaultPairRestSeconds,
                defaultTripletRestSeconds: defaultTripletRestSeconds,
                rotatePairOrder: rotatePairOrder,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<double?> heightCm = const Value.absent(),
                Value<String> unitSystem = const Value.absent(),
                Value<int> defaultPairRestSeconds = const Value.absent(),
                Value<int> defaultTripletRestSeconds = const Value.absent(),
                Value<bool> rotatePairOrder = const Value.absent(),
              }) => UserProfilesCompanion.insert(
                id: id,
                heightCm: heightCm,
                unitSystem: unitSystem,
                defaultPairRestSeconds: defaultPairRestSeconds,
                defaultTripletRestSeconds: defaultTripletRestSeconds,
                rotatePairOrder: rotatePairOrder,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserProfilesTable,
      UserProfile,
      $$UserProfilesTableFilterComposer,
      $$UserProfilesTableOrderingComposer,
      $$UserProfilesTableAnnotationComposer,
      $$UserProfilesTableCreateCompanionBuilder,
      $$UserProfilesTableUpdateCompanionBuilder,
      (
        UserProfile,
        BaseReferences<_$AppDatabase, $UserProfilesTable, UserProfile>,
      ),
      UserProfile,
      PrefetchHooks Function()
    >;
typedef $$BodyWeightEntriesTableCreateCompanionBuilder =
    BodyWeightEntriesCompanion Function({
      required String id,
      required DateTime recordedAt,
      required double weightKg,
      Value<int> rowid,
    });
typedef $$BodyWeightEntriesTableUpdateCompanionBuilder =
    BodyWeightEntriesCompanion Function({
      Value<String> id,
      Value<DateTime> recordedAt,
      Value<double> weightKg,
      Value<int> rowid,
    });

class $$BodyWeightEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $BodyWeightEntriesTable> {
  $$BodyWeightEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weightKg => $composableBuilder(
    column: $table.weightKg,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BodyWeightEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $BodyWeightEntriesTable> {
  $$BodyWeightEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weightKg => $composableBuilder(
    column: $table.weightKg,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BodyWeightEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BodyWeightEntriesTable> {
  $$BodyWeightEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => column,
  );

  GeneratedColumn<double> get weightKg =>
      $composableBuilder(column: $table.weightKg, builder: (column) => column);
}

class $$BodyWeightEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BodyWeightEntriesTable,
          BodyWeightEntry,
          $$BodyWeightEntriesTableFilterComposer,
          $$BodyWeightEntriesTableOrderingComposer,
          $$BodyWeightEntriesTableAnnotationComposer,
          $$BodyWeightEntriesTableCreateCompanionBuilder,
          $$BodyWeightEntriesTableUpdateCompanionBuilder,
          (
            BodyWeightEntry,
            BaseReferences<
              _$AppDatabase,
              $BodyWeightEntriesTable,
              BodyWeightEntry
            >,
          ),
          BodyWeightEntry,
          PrefetchHooks Function()
        > {
  $$BodyWeightEntriesTableTableManager(
    _$AppDatabase db,
    $BodyWeightEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BodyWeightEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BodyWeightEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BodyWeightEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> recordedAt = const Value.absent(),
                Value<double> weightKg = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BodyWeightEntriesCompanion(
                id: id,
                recordedAt: recordedAt,
                weightKg: weightKg,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime recordedAt,
                required double weightKg,
                Value<int> rowid = const Value.absent(),
              }) => BodyWeightEntriesCompanion.insert(
                id: id,
                recordedAt: recordedAt,
                weightKg: weightKg,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BodyWeightEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BodyWeightEntriesTable,
      BodyWeightEntry,
      $$BodyWeightEntriesTableFilterComposer,
      $$BodyWeightEntriesTableOrderingComposer,
      $$BodyWeightEntriesTableAnnotationComposer,
      $$BodyWeightEntriesTableCreateCompanionBuilder,
      $$BodyWeightEntriesTableUpdateCompanionBuilder,
      (
        BodyWeightEntry,
        BaseReferences<_$AppDatabase, $BodyWeightEntriesTable, BodyWeightEntry>,
      ),
      BodyWeightEntry,
      PrefetchHooks Function()
    >;
typedef $$ProgressionConfigsTableCreateCompanionBuilder =
    ProgressionConfigsCompanion Function({
      required String pathId,
      required String selectedBranchId,
      Value<String?> selectedExerciseId,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ProgressionConfigsTableUpdateCompanionBuilder =
    ProgressionConfigsCompanion Function({
      Value<String> pathId,
      Value<String> selectedBranchId,
      Value<String?> selectedExerciseId,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ProgressionConfigsTableFilterComposer
    extends Composer<_$AppDatabase, $ProgressionConfigsTable> {
  $$ProgressionConfigsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get pathId => $composableBuilder(
    column: $table.pathId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get selectedBranchId => $composableBuilder(
    column: $table.selectedBranchId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get selectedExerciseId => $composableBuilder(
    column: $table.selectedExerciseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProgressionConfigsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProgressionConfigsTable> {
  $$ProgressionConfigsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get pathId => $composableBuilder(
    column: $table.pathId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get selectedBranchId => $composableBuilder(
    column: $table.selectedBranchId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get selectedExerciseId => $composableBuilder(
    column: $table.selectedExerciseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProgressionConfigsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProgressionConfigsTable> {
  $$ProgressionConfigsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get pathId =>
      $composableBuilder(column: $table.pathId, builder: (column) => column);

  GeneratedColumn<String> get selectedBranchId => $composableBuilder(
    column: $table.selectedBranchId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get selectedExerciseId => $composableBuilder(
    column: $table.selectedExerciseId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ProgressionConfigsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProgressionConfigsTable,
          ProgressionConfig,
          $$ProgressionConfigsTableFilterComposer,
          $$ProgressionConfigsTableOrderingComposer,
          $$ProgressionConfigsTableAnnotationComposer,
          $$ProgressionConfigsTableCreateCompanionBuilder,
          $$ProgressionConfigsTableUpdateCompanionBuilder,
          (
            ProgressionConfig,
            BaseReferences<
              _$AppDatabase,
              $ProgressionConfigsTable,
              ProgressionConfig
            >,
          ),
          ProgressionConfig,
          PrefetchHooks Function()
        > {
  $$ProgressionConfigsTableTableManager(
    _$AppDatabase db,
    $ProgressionConfigsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProgressionConfigsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProgressionConfigsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProgressionConfigsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> pathId = const Value.absent(),
                Value<String> selectedBranchId = const Value.absent(),
                Value<String?> selectedExerciseId = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProgressionConfigsCompanion(
                pathId: pathId,
                selectedBranchId: selectedBranchId,
                selectedExerciseId: selectedExerciseId,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String pathId,
                required String selectedBranchId,
                Value<String?> selectedExerciseId = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ProgressionConfigsCompanion.insert(
                pathId: pathId,
                selectedBranchId: selectedBranchId,
                selectedExerciseId: selectedExerciseId,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProgressionConfigsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProgressionConfigsTable,
      ProgressionConfig,
      $$ProgressionConfigsTableFilterComposer,
      $$ProgressionConfigsTableOrderingComposer,
      $$ProgressionConfigsTableAnnotationComposer,
      $$ProgressionConfigsTableCreateCompanionBuilder,
      $$ProgressionConfigsTableUpdateCompanionBuilder,
      (
        ProgressionConfig,
        BaseReferences<
          _$AppDatabase,
          $ProgressionConfigsTable,
          ProgressionConfig
        >,
      ),
      ProgressionConfig,
      PrefetchHooks Function()
    >;
typedef $$ExerciseStatesTableCreateCompanionBuilder =
    ExerciseStatesCompanion Function({
      required String exerciseId,
      Value<double> workingLoadKg,
      Value<double?> lastIncrementKg,
      Value<int> consecutiveFailures,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ExerciseStatesTableUpdateCompanionBuilder =
    ExerciseStatesCompanion Function({
      Value<String> exerciseId,
      Value<double> workingLoadKg,
      Value<double?> lastIncrementKg,
      Value<int> consecutiveFailures,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ExerciseStatesTableFilterComposer
    extends Composer<_$AppDatabase, $ExerciseStatesTable> {
  $$ExerciseStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get workingLoadKg => $composableBuilder(
    column: $table.workingLoadKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lastIncrementKg => $composableBuilder(
    column: $table.lastIncrementKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get consecutiveFailures => $composableBuilder(
    column: $table.consecutiveFailures,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ExerciseStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $ExerciseStatesTable> {
  $$ExerciseStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get workingLoadKg => $composableBuilder(
    column: $table.workingLoadKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lastIncrementKg => $composableBuilder(
    column: $table.lastIncrementKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get consecutiveFailures => $composableBuilder(
    column: $table.consecutiveFailures,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExerciseStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExerciseStatesTable> {
  $$ExerciseStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => column,
  );

  GeneratedColumn<double> get workingLoadKg => $composableBuilder(
    column: $table.workingLoadKg,
    builder: (column) => column,
  );

  GeneratedColumn<double> get lastIncrementKg => $composableBuilder(
    column: $table.lastIncrementKg,
    builder: (column) => column,
  );

  GeneratedColumn<int> get consecutiveFailures => $composableBuilder(
    column: $table.consecutiveFailures,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ExerciseStatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExerciseStatesTable,
          ExerciseState,
          $$ExerciseStatesTableFilterComposer,
          $$ExerciseStatesTableOrderingComposer,
          $$ExerciseStatesTableAnnotationComposer,
          $$ExerciseStatesTableCreateCompanionBuilder,
          $$ExerciseStatesTableUpdateCompanionBuilder,
          (
            ExerciseState,
            BaseReferences<_$AppDatabase, $ExerciseStatesTable, ExerciseState>,
          ),
          ExerciseState,
          PrefetchHooks Function()
        > {
  $$ExerciseStatesTableTableManager(
    _$AppDatabase db,
    $ExerciseStatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExerciseStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExerciseStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExerciseStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> exerciseId = const Value.absent(),
                Value<double> workingLoadKg = const Value.absent(),
                Value<double?> lastIncrementKg = const Value.absent(),
                Value<int> consecutiveFailures = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExerciseStatesCompanion(
                exerciseId: exerciseId,
                workingLoadKg: workingLoadKg,
                lastIncrementKg: lastIncrementKg,
                consecutiveFailures: consecutiveFailures,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String exerciseId,
                Value<double> workingLoadKg = const Value.absent(),
                Value<double?> lastIncrementKg = const Value.absent(),
                Value<int> consecutiveFailures = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ExerciseStatesCompanion.insert(
                exerciseId: exerciseId,
                workingLoadKg: workingLoadKg,
                lastIncrementKg: lastIncrementKg,
                consecutiveFailures: consecutiveFailures,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ExerciseStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExerciseStatesTable,
      ExerciseState,
      $$ExerciseStatesTableFilterComposer,
      $$ExerciseStatesTableOrderingComposer,
      $$ExerciseStatesTableAnnotationComposer,
      $$ExerciseStatesTableCreateCompanionBuilder,
      $$ExerciseStatesTableUpdateCompanionBuilder,
      (
        ExerciseState,
        BaseReferences<_$AppDatabase, $ExerciseStatesTable, ExerciseState>,
      ),
      ExerciseState,
      PrefetchHooks Function()
    >;
typedef $$WorkoutSessionsTableCreateCompanionBuilder =
    WorkoutSessionsCompanion Function({
      required String id,
      required DateTime startedAt,
      Value<DateTime?> endedAt,
      required String status,
      required int rotationIndex,
      required int pairRestSeconds,
      required int tripletRestSeconds,
      Value<String?> cursorJson,
      Value<int> rowid,
    });
typedef $$WorkoutSessionsTableUpdateCompanionBuilder =
    WorkoutSessionsCompanion Function({
      Value<String> id,
      Value<DateTime> startedAt,
      Value<DateTime?> endedAt,
      Value<String> status,
      Value<int> rotationIndex,
      Value<int> pairRestSeconds,
      Value<int> tripletRestSeconds,
      Value<String?> cursorJson,
      Value<int> rowid,
    });

final class $$WorkoutSessionsTableReferences
    extends
        BaseReferences<_$AppDatabase, $WorkoutSessionsTable, WorkoutSession> {
  $$WorkoutSessionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$SetRecordsTable, List<SetRecord>>
  _setRecordsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.setRecords,
    aliasName: 'workout_sessions__id__set_records__session_id',
  );

  $$SetRecordsTableProcessedTableManager get setRecordsRefs {
    final manager = $$SetRecordsTableTableManager(
      $_db,
      $_db.setRecords,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_setRecordsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WorkoutSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $WorkoutSessionsTable> {
  $$WorkoutSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rotationIndex => $composableBuilder(
    column: $table.rotationIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pairRestSeconds => $composableBuilder(
    column: $table.pairRestSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tripletRestSeconds => $composableBuilder(
    column: $table.tripletRestSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cursorJson => $composableBuilder(
    column: $table.cursorJson,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> setRecordsRefs(
    Expression<bool> Function($$SetRecordsTableFilterComposer f) f,
  ) {
    final $$SetRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.setRecords,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SetRecordsTableFilterComposer(
            $db: $db,
            $table: $db.setRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorkoutSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkoutSessionsTable> {
  $$WorkoutSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rotationIndex => $composableBuilder(
    column: $table.rotationIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pairRestSeconds => $composableBuilder(
    column: $table.pairRestSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tripletRestSeconds => $composableBuilder(
    column: $table.tripletRestSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cursorJson => $composableBuilder(
    column: $table.cursorJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorkoutSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkoutSessionsTable> {
  $$WorkoutSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get rotationIndex => $composableBuilder(
    column: $table.rotationIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pairRestSeconds => $composableBuilder(
    column: $table.pairRestSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get tripletRestSeconds => $composableBuilder(
    column: $table.tripletRestSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cursorJson => $composableBuilder(
    column: $table.cursorJson,
    builder: (column) => column,
  );

  Expression<T> setRecordsRefs<T extends Object>(
    Expression<T> Function($$SetRecordsTableAnnotationComposer a) f,
  ) {
    final $$SetRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.setRecords,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SetRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.setRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorkoutSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkoutSessionsTable,
          WorkoutSession,
          $$WorkoutSessionsTableFilterComposer,
          $$WorkoutSessionsTableOrderingComposer,
          $$WorkoutSessionsTableAnnotationComposer,
          $$WorkoutSessionsTableCreateCompanionBuilder,
          $$WorkoutSessionsTableUpdateCompanionBuilder,
          (WorkoutSession, $$WorkoutSessionsTableReferences),
          WorkoutSession,
          PrefetchHooks Function({bool setRecordsRefs})
        > {
  $$WorkoutSessionsTableTableManager(
    _$AppDatabase db,
    $WorkoutSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkoutSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkoutSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkoutSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> rotationIndex = const Value.absent(),
                Value<int> pairRestSeconds = const Value.absent(),
                Value<int> tripletRestSeconds = const Value.absent(),
                Value<String?> cursorJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkoutSessionsCompanion(
                id: id,
                startedAt: startedAt,
                endedAt: endedAt,
                status: status,
                rotationIndex: rotationIndex,
                pairRestSeconds: pairRestSeconds,
                tripletRestSeconds: tripletRestSeconds,
                cursorJson: cursorJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime startedAt,
                Value<DateTime?> endedAt = const Value.absent(),
                required String status,
                required int rotationIndex,
                required int pairRestSeconds,
                required int tripletRestSeconds,
                Value<String?> cursorJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkoutSessionsCompanion.insert(
                id: id,
                startedAt: startedAt,
                endedAt: endedAt,
                status: status,
                rotationIndex: rotationIndex,
                pairRestSeconds: pairRestSeconds,
                tripletRestSeconds: tripletRestSeconds,
                cursorJson: cursorJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WorkoutSessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({setRecordsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (setRecordsRefs) db.setRecords],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (setRecordsRefs)
                    await $_getPrefetchedData<
                      WorkoutSession,
                      $WorkoutSessionsTable,
                      SetRecord
                    >(
                      currentTable: table,
                      referencedTable: $$WorkoutSessionsTableReferences
                          ._setRecordsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$WorkoutSessionsTableReferences(
                            db,
                            table,
                            p0,
                          ).setRecordsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.sessionId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$WorkoutSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkoutSessionsTable,
      WorkoutSession,
      $$WorkoutSessionsTableFilterComposer,
      $$WorkoutSessionsTableOrderingComposer,
      $$WorkoutSessionsTableAnnotationComposer,
      $$WorkoutSessionsTableCreateCompanionBuilder,
      $$WorkoutSessionsTableUpdateCompanionBuilder,
      (WorkoutSession, $$WorkoutSessionsTableReferences),
      WorkoutSession,
      PrefetchHooks Function({bool setRecordsRefs})
    >;
typedef $$SetRecordsTableCreateCompanionBuilder =
    SetRecordsCompanion Function({
      required String id,
      required String sessionId,
      required String pathId,
      required String exerciseId,
      required int setIndex,
      Value<int?> repsCompleted,
      Value<int?> holdSeconds,
      Value<double> weightKg,
      required DateTime recordedAt,
      Value<int> rowid,
    });
typedef $$SetRecordsTableUpdateCompanionBuilder =
    SetRecordsCompanion Function({
      Value<String> id,
      Value<String> sessionId,
      Value<String> pathId,
      Value<String> exerciseId,
      Value<int> setIndex,
      Value<int?> repsCompleted,
      Value<int?> holdSeconds,
      Value<double> weightKg,
      Value<DateTime> recordedAt,
      Value<int> rowid,
    });

final class $$SetRecordsTableReferences
    extends BaseReferences<_$AppDatabase, $SetRecordsTable, SetRecord> {
  $$SetRecordsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $WorkoutSessionsTable _sessionIdTable(_$AppDatabase db) => db
      .workoutSessions
      .createAlias('set_records__session_id__workout_sessions__id');

  $$WorkoutSessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$WorkoutSessionsTableTableManager(
      $_db,
      $_db.workoutSessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SetRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $SetRecordsTable> {
  $$SetRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pathId => $composableBuilder(
    column: $table.pathId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get setIndex => $composableBuilder(
    column: $table.setIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get repsCompleted => $composableBuilder(
    column: $table.repsCompleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get holdSeconds => $composableBuilder(
    column: $table.holdSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weightKg => $composableBuilder(
    column: $table.weightKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$WorkoutSessionsTableFilterComposer get sessionId {
    final $$WorkoutSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.workoutSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutSessionsTableFilterComposer(
            $db: $db,
            $table: $db.workoutSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SetRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $SetRecordsTable> {
  $$SetRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pathId => $composableBuilder(
    column: $table.pathId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get setIndex => $composableBuilder(
    column: $table.setIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get repsCompleted => $composableBuilder(
    column: $table.repsCompleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get holdSeconds => $composableBuilder(
    column: $table.holdSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weightKg => $composableBuilder(
    column: $table.weightKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$WorkoutSessionsTableOrderingComposer get sessionId {
    final $$WorkoutSessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.workoutSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutSessionsTableOrderingComposer(
            $db: $db,
            $table: $db.workoutSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SetRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SetRecordsTable> {
  $$SetRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get pathId =>
      $composableBuilder(column: $table.pathId, builder: (column) => column);

  GeneratedColumn<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get setIndex =>
      $composableBuilder(column: $table.setIndex, builder: (column) => column);

  GeneratedColumn<int> get repsCompleted => $composableBuilder(
    column: $table.repsCompleted,
    builder: (column) => column,
  );

  GeneratedColumn<int> get holdSeconds => $composableBuilder(
    column: $table.holdSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<double> get weightKg =>
      $composableBuilder(column: $table.weightKg, builder: (column) => column);

  GeneratedColumn<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => column,
  );

  $$WorkoutSessionsTableAnnotationComposer get sessionId {
    final $$WorkoutSessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.workoutSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutSessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.workoutSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SetRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SetRecordsTable,
          SetRecord,
          $$SetRecordsTableFilterComposer,
          $$SetRecordsTableOrderingComposer,
          $$SetRecordsTableAnnotationComposer,
          $$SetRecordsTableCreateCompanionBuilder,
          $$SetRecordsTableUpdateCompanionBuilder,
          (SetRecord, $$SetRecordsTableReferences),
          SetRecord,
          PrefetchHooks Function({bool sessionId})
        > {
  $$SetRecordsTableTableManager(_$AppDatabase db, $SetRecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SetRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SetRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SetRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String> pathId = const Value.absent(),
                Value<String> exerciseId = const Value.absent(),
                Value<int> setIndex = const Value.absent(),
                Value<int?> repsCompleted = const Value.absent(),
                Value<int?> holdSeconds = const Value.absent(),
                Value<double> weightKg = const Value.absent(),
                Value<DateTime> recordedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SetRecordsCompanion(
                id: id,
                sessionId: sessionId,
                pathId: pathId,
                exerciseId: exerciseId,
                setIndex: setIndex,
                repsCompleted: repsCompleted,
                holdSeconds: holdSeconds,
                weightKg: weightKg,
                recordedAt: recordedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required String pathId,
                required String exerciseId,
                required int setIndex,
                Value<int?> repsCompleted = const Value.absent(),
                Value<int?> holdSeconds = const Value.absent(),
                Value<double> weightKg = const Value.absent(),
                required DateTime recordedAt,
                Value<int> rowid = const Value.absent(),
              }) => SetRecordsCompanion.insert(
                id: id,
                sessionId: sessionId,
                pathId: pathId,
                exerciseId: exerciseId,
                setIndex: setIndex,
                repsCompleted: repsCompleted,
                holdSeconds: holdSeconds,
                weightKg: weightKg,
                recordedAt: recordedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SetRecordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sessionId,
                                referencedTable: $$SetRecordsTableReferences
                                    ._sessionIdTable(db),
                                referencedColumn: $$SetRecordsTableReferences
                                    ._sessionIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SetRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SetRecordsTable,
      SetRecord,
      $$SetRecordsTableFilterComposer,
      $$SetRecordsTableOrderingComposer,
      $$SetRecordsTableAnnotationComposer,
      $$SetRecordsTableCreateCompanionBuilder,
      $$SetRecordsTableUpdateCompanionBuilder,
      (SetRecord, $$SetRecordsTableReferences),
      SetRecord,
      PrefetchHooks Function({bool sessionId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$UserProfilesTableTableManager get userProfiles =>
      $$UserProfilesTableTableManager(_db, _db.userProfiles);
  $$BodyWeightEntriesTableTableManager get bodyWeightEntries =>
      $$BodyWeightEntriesTableTableManager(_db, _db.bodyWeightEntries);
  $$ProgressionConfigsTableTableManager get progressionConfigs =>
      $$ProgressionConfigsTableTableManager(_db, _db.progressionConfigs);
  $$ExerciseStatesTableTableManager get exerciseStates =>
      $$ExerciseStatesTableTableManager(_db, _db.exerciseStates);
  $$WorkoutSessionsTableTableManager get workoutSessions =>
      $$WorkoutSessionsTableTableManager(_db, _db.workoutSessions);
  $$SetRecordsTableTableManager get setRecords =>
      $$SetRecordsTableTableManager(_db, _db.setRecords);
}
