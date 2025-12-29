enum VoiceCommandType { search, memo, checkIn, unknown }

class VoiceCommandResult {
  final VoiceCommandType type;
  final String? target; // Name or Number
  final String? content; // Memo content

  VoiceCommandResult({required this.type, this.target, this.content});
}

class VoiceCommandParser {
  // Regex patterns
  static final RegExp _memoPattern1 = RegExp(
    r'(.+)에게\s+(.+)(?:라고|이라고)\s+메모',
  ); // "홍길동에게 예약 확인이라고 메모"

  static final RegExp _memoPattern2 = RegExp(
    r'(.+)\s+(?:회원|고객)에게\s+(.+)(?:라고|이라고)?\s+(?:메모|기록)',
  ); // "홍길동 회원에게 다음주 예약 확인 필요라고 메모"

  static final RegExp _checkInPattern1 = RegExp(
    r'(.+)\s+(?:회원|고객)?\s+(?:방문|왔어|체크인|체크)',
  ); // "홍길동 방문", "홍길동 회원 방문 체크"

  static final RegExp _checkInPattern2 = RegExp(
    r'(.+)\s+(?:회원|고객)?\s+방문\s+(?:체크|확인)',
  ); // "홍길동 회원 방문 체크해줘"

  static final RegExp _searchByNumberPattern = RegExp(
    r'(\d+)\s*(?:번|번호)?\s*(?:회원|고객)?',
  ); // "1234번 회원 찾아줘", "1234 회원"

  static final RegExp _searchByNamePattern = RegExp(
    r'([가-힣a-zA-Z]+)\s*(?:회원|고객)',
  ); // "홍길동 회원 찾아줘", "홍길동 정보"

  static VoiceCommandResult parse(String text) {
    String cleanText = text.trim();

    // 1. Check Memo (두 가지 패턴)
    final memoMatch1 = _memoPattern1.firstMatch(cleanText);
    if (memoMatch1 != null) {
      return VoiceCommandResult(
        type: VoiceCommandType.memo,
        target: memoMatch1.group(1)?.trim(),
        content: memoMatch1.group(2)?.trim(),
      );
    }

    final memoMatch2 = _memoPattern2.firstMatch(cleanText);
    if (memoMatch2 != null) {
      return VoiceCommandResult(
        type: VoiceCommandType.memo,
        target: memoMatch2.group(1)?.trim(),
        content: memoMatch2.group(2)?.trim(),
      );
    }

    // 2. Check Check-in (두 가지 패턴)
    final checkInMatch1 = _checkInPattern1.firstMatch(cleanText);
    if (checkInMatch1 != null) {
      return VoiceCommandResult(
        type: VoiceCommandType.checkIn,
        target: checkInMatch1.group(1)?.trim(),
      );
    }

    final checkInMatch2 = _checkInPattern2.firstMatch(cleanText);
    if (checkInMatch2 != null) {
      return VoiceCommandResult(
        type: VoiceCommandType.checkIn,
        target: checkInMatch2.group(1)?.trim(),
      );
    }

    // 3. Search by number
    final searchNumberMatch = _searchByNumberPattern.firstMatch(cleanText);
    if (searchNumberMatch != null) {
      return VoiceCommandResult(
        type: VoiceCommandType.search,
        target: searchNumberMatch.group(1)?.trim(),
      );
    }

    // 4. Search by name
    final searchNameMatch = _searchByNamePattern.firstMatch(cleanText);
    if (searchNameMatch != null) {
      return VoiceCommandResult(
        type: VoiceCommandType.search,
        target: searchNameMatch.group(1)?.trim(),
      );
    }

    // 5. Default to Search with entire text
    if (cleanText.isNotEmpty) {
      return VoiceCommandResult(
        type: VoiceCommandType.search,
        target: cleanText,
      );
    }

    return VoiceCommandResult(type: VoiceCommandType.unknown);
  }
}
