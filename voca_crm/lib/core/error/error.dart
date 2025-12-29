/// 종합 에러 처리 시스템
///
/// VocaCRM 앱의 에러 처리를 위한 통합 export 파일입니다.
///
/// 사용 예:
/// ```dart
/// import 'package:voca_crm/core/error/error.dart';
///
/// // Result 패턴 사용
/// final result = await apiClient.getSafe<Member>(
///   '/api/members/123',
///   parser: Member.fromJson,
/// );
///
/// result.when(
///   success: (member) => print(member.name),
///   failure: (error) => AppMessageHandler.handleAppException(context, error),
/// );
/// ```

// 예외 클래스
export 'app_exception.dart';

// Result 패턴
export 'result.dart';

// 예외 파서
export 'exception_parser.dart';

// 글로벌 에러 바운더리
export 'error_boundary.dart';
