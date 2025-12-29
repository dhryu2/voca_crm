import 'package:get_it/get_it.dart';
import 'package:voca_crm/core/session/session_manager.dart';
import 'package:voca_crm/data/datasource/member_service.dart';
import 'package:voca_crm/data/datasource/memo_service.dart';
import 'package:voca_crm/data/datasource/notification_service.dart';
import 'package:voca_crm/data/repository/member_repository_impl.dart';
import 'package:voca_crm/data/repository/memo_repository_impl.dart';
import 'package:voca_crm/domain/repository/member_repository.dart';
import 'package:voca_crm/domain/repository/memo_repository.dart';
import 'package:voca_crm/domain/repository/visit_repository.dart';
import 'package:voca_crm/data/repository/visit_repository_impl.dart';
import 'package:voca_crm/domain/usecase/member/create_member_usecase.dart';
import 'package:voca_crm/domain/usecase/member/get_members_by_number_usecase.dart';
import 'package:voca_crm/domain/usecase/member/search_members_usecase.dart';
import 'package:voca_crm/domain/usecase/memo/create_memo_usecase.dart';
import 'package:voca_crm/domain/usecase/memo/get_memos_by_member_usecase.dart';
import 'package:voca_crm/domain/usecase/voice_search/search_members_with_latest_memo_usecase.dart';
import 'package:voca_crm/presentation/viewmodels/notification_view_model.dart';
import 'package:voca_crm/services/fcm_service.dart';

final sl = GetIt.instance;

Future<void> initializeDependencies() async {
  // Session Manager 초기화
  await SessionManager.instance.initialize();
  // Services
  sl.registerLazySingleton<MemberService>(
    () => MemberService(),
  );
  sl.registerLazySingleton<MemoService>(
    () => MemoService(),
  );
  sl.registerLazySingleton<NotificationService>(
    () => NotificationService(),
  );
  sl.registerLazySingleton<FCMService>(
    () => FCMService(),
  );

  // Repositories
  sl.registerLazySingleton<MemberRepository>(
    () => MemberRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<MemoRepository>(
    () => MemoRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<VisitRepository>(
    () => VisitRepositoryImpl(),
  );

  // Use cases - Member
  sl.registerLazySingleton(() => CreateMemberUseCase(sl()));
  sl.registerLazySingleton(() => GetMembersByNumberUseCase(sl()));
  sl.registerLazySingleton(() => SearchMembersUseCase(sl()));

  // Use cases - Memo
  sl.registerLazySingleton(() => CreateMemoUseCase(sl()));
  sl.registerLazySingleton(() => GetMemosByMemberUseCase(sl()));

  // Use cases - Voice Search
  sl.registerLazySingleton(
    () => SearchMembersWithLatestMemoUseCase(
      memberRepository: sl(),
      memoRepository: sl(),
    ),
  );

  // ViewModels
  sl.registerFactory<NotificationViewModel>(
    () => NotificationViewModel(notificationService: sl()),
  );
}
