import 'package:flutter_test/flutter_test.dart';

import 'package:bodilog/core/error/failures.dart';
import 'package:bodilog/core/error/result.dart';

void main() {
  group('Result<T>', () {
    test('Success holds data and isSuccess returns true', () {
      const result = Success<int>(42);

      expect(result.data, equals(42));
      expect(result.isSuccess, isTrue);
      expect(result.isError, isFalse);
    });

    test('AppError holds a Failure and isError returns true', () {
      const failure = GeneralFailure('Something went wrong');
      const result = AppError<int>(failure);

      expect(result.failure, equals(failure));
      expect(result.isError, isTrue);
      expect(result.isSuccess, isFalse);
    });

    test('Success<String> holds a string value', () {
      const result = Success<String>('hello');

      expect(result.data, equals('hello'));
      expect(result.isSuccess, isTrue);
    });

    test('AppError<String> holds a CameraFailure', () {
      const failure = CameraFailure('Camera not available');
      const result = AppError<String>(failure);

      expect(result.failure, isA<CameraFailure>());
      expect(result.failure.message, equals('Camera not available'));
    });
  });
}
