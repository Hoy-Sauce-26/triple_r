import 'package:flutter_test/flutter_test.dart';
import 'package:triple_r/domain/units.dart';

void main() {
  group('conversion', () {
    test('round-trips losslessly in both directions', () {
      for (final lb in [0.0, 1.25, 2.5, 45.0, 135.0, 317.5]) {
        expect(kgToPounds(poundsToKg(lb)), closeTo(lb, 1e-12));
      }
    });

    test('uses the exact avoirdupois pound', () {
      expect(poundsToKg(1), closeTo(0.45359237, 1e-12));
      expect(kgToPounds(100), closeTo(220.462262, 1e-6));
    });

    test('metric display is a no-op', () {
      expect(toDisplayWeight(42.5, UnitSystem.metric), 42.5);
      expect(fromDisplayWeight(42.5, UnitSystem.metric), 42.5);
    });
  });

  group('increments', () {
    test('twenty 2.5 lb jumps land exactly on 50 lb', () {
      // The case that motivated doing arithmetic in display units: converting
      // 2.5 lb to 1.1339... kg and accumulating there lets error compound
      // into weights like 49.7 lb.
      var kg = 0.0;
      final increment = poundsToKg(2.5);
      for (var i = 0; i < 20; i++) {
        kg = applyIncrement(kg, increment, UnitSystem.imperial);
      }
      expect(kgToPounds(kg), closeTo(50, 1e-9));
      expect(formatWeight(kg, UnitSystem.imperial), '50 lb');
    });

    test('preserves 1.25 lb micro-loading across many sessions', () {
      // Rounding to a half-pound grid mid-arithmetic would snap 1.25 to 1.5
      // and silently break micro-plates.
      var kg = poundsToKg(100);
      final increment = poundsToKg(1.25);
      for (var i = 0; i < 8; i++) {
        kg = applyIncrement(kg, increment, UnitSystem.imperial);
      }
      expect(kgToPounds(kg), closeTo(110, 1e-9));
    });

    test('metric increments accumulate cleanly too', () {
      var kg = 60.0;
      for (var i = 0; i < 10; i++) {
        kg = applyIncrement(kg, 1.25, UnitSystem.metric);
      }
      expect(kg, closeTo(72.5, 1e-9));
    });

    test('removing mirrors adding', () {
      final increment = poundsToKg(5);
      final up = applyIncrement(poundsToKg(100), increment, UnitSystem.imperial);
      final backDown = removeIncrement(up, increment, UnitSystem.imperial);
      expect(kgToPounds(backDown), closeTo(100, 1e-9));
    });

    test('load never goes negative', () {
      // Regression at an empty bar should stop at zero, not invert.
      expect(removeIncrement(1.0, poundsToKg(10), UnitSystem.imperial), 0);
      expect(removeIncrement(0, 5, UnitSystem.metric), 0);
    });
  });

  group('seed increment', () {
    test('is 2.5 lb for imperial and 1 kg for metric', () {
      expect(
        kgToPounds(seedIncrementKg(UnitSystem.imperial)),
        closeTo(2.5, 1e-9),
      );
      expect(seedIncrementKg(UnitSystem.metric), 1.0);
    });
  });

  group('formatting', () {
    test('renders whole numbers without a decimal tail', () {
      expect(formatWeight(poundsToKg(135), UnitSystem.imperial), '135 lb');
      expect(formatWeight(60, UnitSystem.metric), '60 kg');
    });

    test('rounds away the floating-point tail of a conversion', () {
      // 137.5 lb is not representable exactly in kg; it must not render as
      // "137.49999 lb".
      expect(formatWeight(poundsToKg(137.5), UnitSystem.imperial), '137.5 lb');
    });

    test('snaps to the display grid', () {
      expect(formatWeight(poundsToKg(100.24), UnitSystem.imperial), '100 lb');
      expect(formatWeight(20.13, UnitSystem.metric), '20.25 kg');
    });

    test('can omit the suffix', () {
      expect(
        formatWeight(poundsToKg(45), UnitSystem.imperial, withSuffix: false),
        '45',
      );
    });
  });

  group('unit system parsing', () {
    test('round-trips through the stored string', () {
      for (final u in UnitSystem.values) {
        expect(UnitSystem.parse(u.name), u);
      }
    });

    test('falls back to imperial for anything unrecognised', () {
      // The column is free text; a corrupt import must not crash the app.
      expect(UnitSystem.parse('furlongs'), UnitSystem.imperial);
    });
  });
}
