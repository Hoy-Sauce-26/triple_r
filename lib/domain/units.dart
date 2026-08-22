/// Weight conversion and load arithmetic.
///
/// Loads are stored canonically in kilograms, but every calculation the user
/// can see happens in *their* unit and is converted once. See
/// `docs/PLAN.md` §2.2.1.
library;

enum UnitSystem {
  imperial,
  metric;

  static UnitSystem parse(String raw) =>
      raw == 'metric' ? UnitSystem.metric : UnitSystem.imperial;

  String get name => this == UnitSystem.metric ? 'metric' : 'imperial';

  /// Short label for weights.
  String get weightSuffix => this == UnitSystem.metric ? 'kg' : 'lb';
}

/// The international avoirdupois pound. Exact by definition, so conversions
/// are lossless in both directions at double precision.
const kgPerPound = 0.45359237;

double poundsToKg(double lb) => lb * kgPerPound;
double kgToPounds(double kg) => kg / kgPerPound;

/// Converts a stored kilogram value into the user's unit.
double toDisplayWeight(double kg, UnitSystem units) =>
    units == UnitSystem.metric ? kg : kgToPounds(kg);

/// Converts a value the user typed back into storage units.
double fromDisplayWeight(double value, UnitSystem units) =>
    units == UnitSystem.metric ? value : poundsToKg(value);

/// What the "add weight?" prompt offers when neither the exercise nor the
/// user has said otherwise — 2.5 lb, or 1 kg for metric users.
///
/// The smallest step most people can actually make: a pair of 1.25 lb plates,
/// or a single kilo.
double seedIncrementKg(UnitSystem units) =>
    units == UnitSystem.metric ? 1.0 : poundsToKg(2.5);

/// The step the "add weight?" prompt offers for an exercise with no remembered
/// increment of its own.
///
/// Three tiers, narrowest first: what this exercise last moved by, the step
/// the user configured in Settings, and finally [seedIncrementKg]. The
/// per-exercise memory stays on top because a weighted pull-up and a barbell
/// deadlift do not climb at the same rate, and the setting exists for the
/// users whose whole plate set makes the default step wrong everywhere.
double incrementKgFor({
  required UnitSystem units,
  double? lastIncrementKg,
  double? configuredIncrementKg,
}) =>
    lastIncrementKg ?? configuredIncrementKg ?? seedIncrementKg(units);

/// The steps offered in Settings, in the user's own unit.
///
/// Fixed choices rather than a free field: these are the plate pairs that
/// exist, and a 3.7 lb step is not a thing anyone can load.
List<double> incrementChoices(UnitSystem units) =>
    units == UnitSystem.metric
        ? const [0.5, 1.0, 1.25, 2.0, 2.5, 5.0]
        : const [1.0, 2.5, 5.0, 10.0];

/// Applies [incrementKg] to [currentKg], doing the addition in the user's
/// display unit.
///
/// The order matters. Converting the increment to kilograms and accumulating
/// there lets representation error compound across many sessions, and it
/// surfaces as a working weight of 194.7 lb where the user has only ever
/// added round numbers. Adding in display units keeps the number the user
/// sees exact, and the single conversion back to kilograms is lossless.
///
/// Nothing is rounded here. Rounding mid-arithmetic is what would actually
/// produce drift, and it would also destroy micro-loading — a 1.25 lb plate
/// snapped to the nearest half pound becomes 1.5. Rounding belongs in
/// [formatWeight], at the point of rendering.
double applyIncrement(
  double currentKg,
  double incrementKg,
  UnitSystem units,
) {
  final current = toDisplayWeight(currentKg, units);
  final increment = toDisplayWeight(incrementKg, units);
  return fromDisplayWeight(current + increment, units);
}

/// The inverse of [applyIncrement], for load-mode regression. Never returns a
/// negative load — an empty bar is the floor.
double removeIncrement(
  double currentKg,
  double incrementKg,
  UnitSystem units,
) {
  final current = toDisplayWeight(currentKg, units);
  final increment = toDisplayWeight(incrementKg, units);
  final next = current - increment;
  return next <= 0 ? 0 : fromDisplayWeight(next, units);
}

/// Exact by definition, like [kgPerPound].
const cmPerInch = 2.54;

/// Renders a stored kilogram value for display, trimming a trailing `.0`.
///
/// Rounds to 0.5 lb / 0.25 kg — fine enough for plate math, coarse enough to
/// hide the floating-point tail of a unit conversion.
String formatWeight(double kg, UnitSystem units, {bool withSuffix = true}) {
  final value = toDisplayWeight(kg, units);
  final grid = units == UnitSystem.metric ? 4.0 : 2.0;
  final rounded = (value * grid).round() / grid;
  final text = rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');
  return withSuffix ? '$text ${units.weightSuffix}' : text;
}
