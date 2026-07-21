import 'package:flutter_test/flutter_test.dart';
import 'package:voca_crm/core/utils/date_parser.dart';

void main() {
  group('DateParser.fromServer', () {
    test('초 단위 ISO 문자열을 UTC로 간주해 로컬 시간으로 변환한다', () {
      const input = '2024-01-15T10:30:00';
      final result = DateParser.fromServer(input);
      final expected = DateTime.parse('${input}Z').toLocal();

      expect(result, expected);
      expect(result.isUtc, isFalse);
    });

    test('밀리초 포함 ISO 문자열을 UTC로 간주해 로컬 시간으로 변환한다', () {
      const input = '2024-01-15T10:30:00.123';
      final result = DateParser.fromServer(input);
      final expected = DateTime.parse('${input}Z').toLocal();

      expect(result, expected);
    });

    test('이미 Z가 붙은 문자열은 중복으로 Z를 붙이지 않는다', () {
      const input = '2024-01-15T10:30:00Z';
      final result = DateParser.fromServer(input);
      final expected = DateTime.parse(input).toLocal();

      expect(result, expected);
    });

    test('날짜만 있는 값(T 미포함)은 UTC 보정 없이 그대로 파싱한다', () {
      const input = '2024-01-15';
      final result = DateParser.fromServer(input);
      final expected = DateTime.parse(input);

      expect(result, expected);
      expect(result.year, 2024);
      expect(result.month, 1);
      expect(result.day, 15);
    });

    test('빈 문자열은 FormatException을 던진다', () {
      expect(() => DateParser.fromServer(''), throwsFormatException);
    });

    test('잘못된 포맷 문자열은 FormatException을 던진다', () {
      expect(
        () => DateParser.fromServer('not-a-valid-date'),
        throwsFormatException,
      );
    });
  });

  group('DateParser.fromServerNullable', () {
    test('null 입력 시 null을 반환한다', () {
      expect(DateParser.fromServerNullable(null), isNull);
    });

    test('유효한 문자열 입력 시 fromServer와 동일한 결과를 반환한다', () {
      const input = '2024-01-15T10:30:00';
      final result = DateParser.fromServerNullable(input);
      final expected = DateParser.fromServer(input);

      expect(result, expected);
    });

    test('빈 문자열 입력 시 FormatException을 던진다', () {
      expect(() => DateParser.fromServerNullable(''), throwsFormatException);
    });
  });
}
