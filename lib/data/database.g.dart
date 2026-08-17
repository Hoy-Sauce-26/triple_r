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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $UserProfilesTable userProfiles = $UserProfilesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [userProfiles];
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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$UserProfilesTableTableManager get userProfiles =>
      $$UserProfilesTableTableManager(_db, _db.userProfiles);
}
