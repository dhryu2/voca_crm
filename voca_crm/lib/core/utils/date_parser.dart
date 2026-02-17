/// 서버 응답 DateTime 파싱 유틸리티
///
/// 서버(Spring Boot)가 타임존 표시 없이 UTC 시간을 반환하므로
/// 'Z' 접미사를 추가하여 UTC로 파싱한 뒤 로컬 시간으로 변환한다.
class DateParser {
  DateParser._();

  /// 서버 응답 날짜 문자열을 로컬 DateTime으로 변환
  static DateTime fromServer(String dateStr) {
    if (!dateStr.endsWith('Z')) dateStr = '${dateStr}Z';
    return DateTime.parse(dateStr).toLocal();
  }

  /// nullable 버전
  static DateTime? fromServerNullable(String? dateStr) {
    if (dateStr == null) return null;
    return fromServer(dateStr);
  }
}
