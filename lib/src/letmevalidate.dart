import 'package:letmeserve/src/typedefs.dart';

class JsonValidator {
  final _validators = <_BaseValidator>[];

  JsonValidator();

  dynamic _extractValue(JsonMap json, String path) {
    if (json.isEmpty) return const _EmptyJson();

    final fields = path.split('.');
    dynamic currentJson = json;
    dynamic value;

    for (final field in fields) {
      if (currentJson is! JsonMap) {
        return const _FieldNotJsonMap();
      }

      if (!currentJson.containsKey(field)) {
        return null;
      }

      if (currentJson[field] == null) {
        return null;
      }

      value = currentJson[field];
      currentJson = currentJson[field];
    }

    return value;
  }

  void isInt(
    String path, {
    int? min,
    int? max,
    bool nullable = false,
  }) {
    _validators.add(
      _IntValidator(
        path,
        min: min,
        max: max,
        nullable: nullable,
      ),
    );
  }

  void isDouble(
    String path, {
    double? min,
    double? max,
    bool nullable = false,
    bool allowInt = true,
  }) {
    _validators.add(
      _DoubleValidator(
        path,
        min: min,
        max: max,
        nullable: nullable,
        allowInt: allowInt,
      ),
    );
  }

  void isString(
    String path, {
    int? minLength,
    int? maxLength,
    bool nullable = false,
  }) {
    _validators.add(
      _StringValidator(
        path,
        minLength: minLength,
        maxLength: maxLength,
        nullable: nullable,
      ),
    );
  }

  void isBoolean(
    String path, {
    bool nullable = false,
  }) {
    _validators.add(
      _BooleanValidator(
        path,
        nullable: nullable,
      ),
    );
  }

  JsonArray validate(
    JsonMap json, {
    bool earlyExit = true,
  }) {
    final errors = <JsonMap>[];

    JsonArray onEarlyExit(String path, String reason) {
      return [
        {path: reason}
      ];
    }

    void addError(String path, String reason) {
      errors.add({path: reason});
    }

    for (final validator in _validators) {
      final value = _extractValue(json, validator.path);

      if (value is _JsonError) {
        if (value is _EmptyJson) {
          if (earlyExit) {
            return onEarlyExit('body', value.reason);
          }

          addError(validator.path, value.reason);
          continue;
        }

        if (earlyExit) {
          return onEarlyExit(validator.path, value.reason);
        }

        addError(validator.path, value.reason);
        continue;
      }

      final reason = validator.validate(value);

      if (reason != null) {
        if (earlyExit) {
          return onEarlyExit(validator.path, reason);
        }

        addError(validator.path, value.reason);
      }
    }

    return errors;
  }
}

abstract class _JsonError {
  String get reason;
}

class _EmptyJson implements _JsonError {
  @override
  final String reason;

  const _EmptyJson([this.reason = 'json is empty']);
}

class _FieldNotJsonMap implements _JsonError {
  @override
  final String reason;

  const _FieldNotJsonMap([this.reason = 'field is not json map']);
}

abstract class _BaseValidator {
  String get path;
  String? validate(dynamic value);
}

class _IntValidator implements _BaseValidator {
  @override
  final String path;
  final int? min;
  final int? max;
  final bool nullable;

  _IntValidator(
    this.path, {
    this.min,
    this.max,
    this.nullable = false,
  });

  @override
  String? validate(dynamic value) {
    if (value == null && !nullable) return 'Not null allowed';

    if (value == null) return null;

    if (value is! int) return 'Value is not type of int';

    if (min != null && value < min!) return 'Value is less than min [value: $value, min: $min]';

    if (max != null && value > max!) return 'Value is greater than max [value: $value, min: $max]';

    return null;
  }
}

class _DoubleValidator implements _BaseValidator {
  @override
  final String path;
  final double? min;
  final double? max;
  final bool nullable;
  final bool allowInt;

  _DoubleValidator(
    this.path, {
    this.min,
    this.max,
    this.nullable = false,
    this.allowInt = true,
  });

  @override
  String? validate(dynamic value) {
    if (value == null && !nullable) return 'Not null allowed';

    if (value == null) return null;

    if (value is int) {
      if (!allowInt) {
        return 'Value is not type of double';
      }
    } else if (value is! double) {
      return 'Value is not type of double';
    }

    if (min != null && value < min!) return 'Value is less than min [value: $value, min: $min]';

    if (max != null && value > max!) return 'Value is greater than max [value: $value, min: $max]';

    return null;
  }
}

class _StringValidator implements _BaseValidator {
  @override
  final String path;
  final int? minLength;
  final int? maxLength;
  final bool nullable;

  _StringValidator(
    this.path, {
    this.minLength,
    this.maxLength,
    this.nullable = false,
  });

  @override
  String? validate(dynamic value) {
    if (value == null && !nullable) return 'Not null allowed';

    if (value == null) return null;

    if (value is! String) return 'Value is not type of string';

    if (minLength != null && value.length < minLength!) {
      return 'String length less than min length [length: ${value.length}, minLength: $minLength]';
    }

    if (maxLength != null && value.length > maxLength!) {
      return 'String length greater than max length [length: ${value.length}, maxLength: $maxLength]';
    }

    return null;
  }
}

class _BooleanValidator implements _BaseValidator {
  @override
  final String path;
  final bool nullable;

  _BooleanValidator(
    this.path, {
    this.nullable = false,
  });

  @override
  String? validate(value) {
    if (value == null && !nullable) return 'Not null allowed';

    if (value == null) return null;

    if (value is! bool) return 'Value is not type of bool';

    return null;
  }
}
