import 'package:letmeserve/src/letmevalidate.dart';
import 'package:test/test.dart';

void main() {
  group('json validator', () {
    group('int validations', () {
      test('validates int', () {
        final errors = (JsonValidator()..isInt('cities')).validate({'cities': 5});

        expect(errors.length, 0);
      });

      test('succeeds on null int', () {
        final errors = (JsonValidator()..isInt('cities', nullable: true)).validate({'cities': null});

        expect(errors.length, 0);
      });

      test('fails on null int', () {
        final errors = (JsonValidator()..isInt('cities')).validate({'cities': null});

        expect(errors.length, 1);
        expect(errors[0]['cities'], 'Not null allowed');
      });

      test('succeeds on range', () {
        final validator = (JsonValidator()..isInt('cities', min: 25, max: 30));

        var errors = validator.validate({'cities': 25});
        expect(errors.length, 0);

        errors = validator.validate({'cities': 30});
        expect(errors.length, 0);

        errors = validator.validate({'cities': 28});
        expect(errors.length, 0);
      });

      test('fails on range', () {
        final validator = (JsonValidator()..isInt('cities', min: 25, max: 30));

        var errors = validator.validate({'cities': 24});
        expect(errors.length, 1);

        errors = validator.validate({'cities': 31});
        expect(errors.length, 1);
      });
    });

    group('double validations', () {
      test('validates double', () {
        final errors = (JsonValidator()..isDouble('amount')).validate({'amount': 35.0});

        expect(errors.length, 0);
      });

      test('succeeds on null double', () {
        final errors = (JsonValidator()..isDouble('amount', nullable: true)).validate({'amount': null});

        expect(errors.length, 0);
      });

      test('fails on null double', () {
        final errors = (JsonValidator()..isDouble('amount')).validate({'amount': null});

        expect(errors.length, 1);
        expect(errors[0]['amount'], 'Not null allowed');
      });

      test('succeeds on range', () {
        final validator = JsonValidator()
          ..isDouble(
            'amount',
            min: 25.0,
            max: 30.0,
            allowInt: true,
          );

        var errors = validator.validate({'amount': 25});
        expect(errors.length, 0);

        errors = validator.validate({'amount': 30.0});
        expect(errors.length, 0);

        errors = validator.validate({'amount': 28.0});
        expect(errors.length, 0);
      });

      test('fails on range', () {
        final validator = (JsonValidator()..isDouble('amount', min: 25, max: 30));

        var errors = validator.validate({'amount': 24.0});
        expect(errors.length, 1);

        errors = validator.validate({'amount': 31.0});
        expect(errors.length, 1);
      });
    });

    group('string validations', () {
      test('validates string', () {
        final errors = (JsonValidator()..isString('name')).validate({'name': 'pantelis'});

        expect(errors.length, 0);
      });

      test('succeeds on null string', () {
        final errors = (JsonValidator()..isDouble('name', nullable: true)).validate({'name': null});

        expect(errors.length, 0);
      });

      test('fails on null string', () {
        final errors = (JsonValidator()..isDouble('name')).validate({'name': null});

        expect(errors.length, 1);
        expect(errors[0]['name'], 'Not null allowed');
      });

      test('succees on mix and max length', () {
        final validator = JsonValidator()..isString('name', minLength: 5, maxLength: 12);

        var errors = validator.validate({'name': 'pantelis'});
        expect(errors.length, 0);
      });

      test('fails on min length', () {
        final validator = JsonValidator()..isString('name', minLength: 5);

        var errors = validator.validate({'name': 'pan'});
        expect(errors.length, 1);
        expect(errors.first['name'], 'String length less than min length [length: 3, minLength: 5]');
      });

      test('fails on max length', () {
        final validator = JsonValidator()..isString('name', maxLength: 6);

        var errors = validator.validate({'name': 'pantelis'});
        expect(errors.length, 1);
        expect(errors.first['name'], 'String length greater than max length [length: 8, maxLength: 6]');
      });
    });

    group('combined validations', () {
      test('succeeds validation on int (profile.age) and string (profile.name) and double (profile.completionPercent)',
          () {
        final json = {
          'profile': {
            'name': 'pantelis',
            'age': 26,
            'completionPercent': 94.2,
          },
        };

        final validator = JsonValidator()
          ..isInt('profile.age')
          ..isString('profile.name')
          ..isDouble('profile.completionPercent');

        final errors = validator.validate(json);

        expect(errors.length, 0);
      });

      test('fails with "field is not json map"', () {
        final json = {
          'profile': 5,
        };

        final validator = JsonValidator()..isInt('profile.age');

        final errors = validator.validate(json);

        expect(errors.length, 1);
        expect(errors.first['profile.age'], 'field is not json map');
      });
    });

    test('fails on empty json', () {
      final validator = JsonValidator()..isString('name');

      final errors = validator.validate({});

      expect(errors.length, 1);
    });
  });
}
