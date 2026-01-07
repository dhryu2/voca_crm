import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:voca_crm/core/notification/business_place_change_notifier.dart';
import 'package:voca_crm/core/theme/theme_color.dart';
import 'package:voca_crm/core/utils/message_handler.dart';
import 'package:voca_crm/core/utils/haptic_helper.dart';
import 'package:voca_crm/data/datasource/business_place_service.dart';
import 'package:voca_crm/data/datasource/member_service.dart';
import 'package:voca_crm/data/datasource/reservation_service.dart';
import 'package:voca_crm/data/datasource/user_service.dart';
import 'package:voca_crm/data/repository/member_repository_impl.dart';
import 'package:voca_crm/data/repository/reservation_repository_impl.dart';
import 'package:voca_crm/domain/entity/business_place_with_role.dart';
import 'package:voca_crm/domain/entity/member.dart';
import 'package:voca_crm/domain/entity/reservation.dart';
import 'package:voca_crm/domain/entity/user.dart';
import 'package:voca_crm/presentation/viewmodels/user_view_model.dart';
import 'package:voca_crm/presentation/widgets/character_count_text_field.dart';
import 'package:voca_crm/presentation/widgets/member_search_dialog.dart';
import 'package:table_calendar/table_calendar.dart';

class ReservationsScreen extends StatefulWidget {
  final User user;

  const ReservationsScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> {
  final _reservationRepository = ReservationRepositoryImpl(ReservationService());
  final _memberRepository = MemberRepositoryImpl(MemberService());
  final _businessPlaceService = BusinessPlaceService();
  final _userService = UserService();

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Reservation> _reservations = [];
  List<Reservation> _selectedDayReservations = [];
  bool _isLoading = true;
  String? _error;

  // 사업장 상태
  List<BusinessPlaceWithRole> _businessPlaces = [];
  String? _selectedBusinessPlaceId;
  StreamSubscription<BusinessPlaceChangeEvent>? _businessPlaceChangeSubscription;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _selectedBusinessPlaceId = widget.user.defaultBusinessPlaceId;
    _initializeData();

    // 사업장 변경 이벤트 구독
    _businessPlaceChangeSubscription = BusinessPlaceChangeNotifier().stream
        .listen((event) {
      _loadBusinessPlaces();
    });
  }

  Future<void> _initializeData() async {
    await _loadBusinessPlaces();
    // defaultBusinessPlaceId가 없으면 첫 번째 사업장 사용
    if (_selectedBusinessPlaceId == null && _businessPlaces.isNotEmpty) {
      setState(() {
        _selectedBusinessPlaceId = _businessPlaces.first.businessPlace.id;
      });
    }
    _loadReservations();
  }

  @override
  void dispose() {
    _businessPlaceChangeSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadBusinessPlaces() async {
    try {
      final businessPlaces = await _businessPlaceService.getMyBusinessPlaces(
        widget.user.id,
      );
      if (!mounted) return;
      setState(() {
        _businessPlaces = businessPlaces;
      });
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> _loadReservations() async {
    if (_selectedBusinessPlaceId == null || _selectedBusinessPlaceId!.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = '사업장을 선택해주세요';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final startDate = DateTime(_focusedDay.year, _focusedDay.month, 1);
      final endDate = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);

      final reservations = await _reservationRepository.getReservationsByDateRange(
        _selectedBusinessPlaceId!,
        startDate,
        endDate,
      );

      if (!mounted) return;
      setState(() {
        _reservations = reservations;
        _isLoading = false;
        _updateSelectedDayReservations();
      });
    } catch (e, stackTrace) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = AppMessageHandler.parseErrorMessage(e);
      });
      if (mounted) {
        await AppMessageHandler.handleErrorWithLogging(
          context,
          e,
          stackTrace,
          screenName: 'ReservationsScreen',
          action: '예약 목록 조회',
          userId: widget.user.id,
          businessPlaceId: _selectedBusinessPlaceId,
        );
      }
    }
  }

  void _updateSelectedDayReservations() {
    if (_selectedDay == null) return;
    _selectedDayReservations = _reservations.where((reservation) {
      return isSameDay(reservation.reservationDate, _selectedDay);
    }).toList();
  }

  List<Reservation> _getReservationsForDay(DateTime day) {
    return _reservations.where((reservation) {
      return isSameDay(reservation.reservationDate, day);
    }).toList();
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      HapticHelper.light();
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
        _updateSelectedDayReservations();
      });
    }
  }

  Future<void> _showAddReservationDialog() async {
    HapticHelper.medium();

    if (_selectedBusinessPlaceId == null || _selectedBusinessPlaceId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사업장을 선택해주세요')),
      );
      return;
    }

    if (!mounted) return;

    DateTime selectedDate = _selectedDay ?? DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();
    Member? selectedMember;
    final serviceTypeController = TextEditingController();
    int durationMinutes = 60;
    final notesController = TextEditingController();
    final remarkController = TextEditingController();

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> openMemberSearchDialog() async {
              final result = await MemberSearchDialog.show(
                context: context,
                user: widget.user,
                initialBusinessPlaceId: _selectedBusinessPlaceId,
              );

              if (result != null) {
                setDialogState(() {
                  selectedMember = result.member;
                });
              }
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(screenWidth * 0.06),
              ),
              elevation: 0,
              backgroundColor: Colors.white,
              insetPadding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: screenWidth * 0.9,
                  maxHeight: screenHeight * 0.85,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Close button
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close, color: ThemeColor.textSecondary),
                        padding: EdgeInsets.all(screenWidth * 0.04),
                      ),
                    ),
                    // Content
                    Flexible(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          screenWidth * 0.06,
                          0,
                          screenWidth * 0.06,
                          screenWidth * 0.06,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Icon
                            Container(
                              width: screenWidth * 0.16,
                              height: screenWidth * 0.16,
                              decoration: BoxDecoration(
                                color: ThemeColor.primarySurface,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.calendar_month,
                                size: screenWidth * 0.08,
                                color: ThemeColor.primary,
                              ),
                            ),
                            SizedBox(height: screenHeight * 0.02),
                            // Title
                            Text(
                              '예약 추가',
                              style: TextStyle(
                                fontSize: screenWidth * 0.055,
                                fontWeight: FontWeight.w700,
                                color: ThemeColor.textPrimary,
                              ),
                            ),
                            SizedBox(height: screenHeight * 0.03),

                            // Member selection (회원 검색 팝업 사용)
                            _buildFieldLabel('회원 선택', screenWidth),
                            SizedBox(height: screenHeight * 0.01),
                            InkWell(
                              onTap: openMemberSearchDialog,
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(
                                  horizontal: screenWidth * 0.04,
                                  vertical: screenHeight * 0.018,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: selectedMember != null
                                        ? ThemeColor.primary
                                        : ThemeColor.border,
                                    width: selectedMember != null ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(screenWidth * 0.03),
                                ),
                                child: Row(
                                  children: [
                                    if (selectedMember != null) ...[
                                      Container(
                                        width: screenWidth * 0.08,
                                        height: screenWidth * 0.08,
                                        decoration: BoxDecoration(
                                          color: ThemeColor.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(screenWidth * 0.02),
                                        ),
                                        child: Center(
                                          child: Text(
                                            selectedMember!.name.isNotEmpty
                                                ? selectedMember!.name.substring(0, 1)
                                                : '?',
                                            style: TextStyle(
                                              fontSize: screenWidth * 0.035,
                                              fontWeight: FontWeight.bold,
                                              color: ThemeColor.primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: screenWidth * 0.03),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              selectedMember!.name,
                                              style: TextStyle(
                                                fontSize: screenWidth * 0.04,
                                                fontWeight: FontWeight.w600,
                                                color: ThemeColor.textPrimary,
                                              ),
                                            ),
                                            Text(
                                              selectedMember!.memberNumber,
                                              style: TextStyle(
                                                fontSize: screenWidth * 0.032,
                                                color: ThemeColor.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ] else ...[
                                      Icon(
                                        Icons.person_search_rounded,
                                        size: screenWidth * 0.05,
                                        color: ThemeColor.textTertiary,
                                      ),
                                      SizedBox(width: screenWidth * 0.03),
                                      Text(
                                        '회원을 검색하세요',
                                        style: TextStyle(
                                          fontSize: screenWidth * 0.038,
                                          color: ThemeColor.textTertiary,
                                        ),
                                      ),
                                    ],
                                    const Spacer(),
                                    Icon(
                                      Icons.chevron_right,
                                      size: screenWidth * 0.05,
                                      color: ThemeColor.textTertiary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: screenHeight * 0.02),

                            // Date and Time Row
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildFieldLabel('예약 날짜', screenWidth),
                                      SizedBox(height: screenHeight * 0.01),
                                      InkWell(
                                        onTap: () async {
                                          final date = await showDatePicker(
                                            context: context,
                                            initialDate: selectedDate,
                                            firstDate: DateTime.now(),
                                            lastDate: DateTime.now().add(const Duration(days: 365)),
                                          );
                                          if (date != null) {
                                            setDialogState(() {
                                              selectedDate = date;
                                            });
                                          }
                                        },
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: screenWidth * 0.04,
                                            vertical: screenHeight * 0.015,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: ThemeColor.border),
                                            borderRadius: BorderRadius.circular(screenWidth * 0.03),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.calendar_today, size: screenWidth * 0.045, color: ThemeColor.primary),
                                              SizedBox(width: screenWidth * 0.02),
                                              Text(
                                                '${selectedDate.month}/${selectedDate.day}',
                                                style: TextStyle(fontSize: screenWidth * 0.038),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: screenWidth * 0.03),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildFieldLabel('예약 시간', screenWidth),
                                      SizedBox(height: screenHeight * 0.01),
                                      InkWell(
                                        onTap: () async {
                                          final time = await showTimePicker(
                                            context: context,
                                            initialTime: selectedTime,
                                          );
                                          if (time != null) {
                                            setDialogState(() {
                                              selectedTime = time;
                                            });
                                          }
                                        },
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: screenWidth * 0.04,
                                            vertical: screenHeight * 0.015,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: ThemeColor.border),
                                            borderRadius: BorderRadius.circular(screenWidth * 0.03),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.access_time, size: screenWidth * 0.045, color: ThemeColor.primary),
                                              SizedBox(width: screenWidth * 0.02),
                                              Text(
                                                '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                                                style: TextStyle(fontSize: screenWidth * 0.038),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: screenHeight * 0.02),

                            // Service type
                            CharacterCountTextField(
                              controller: serviceTypeController,
                              labelText: '서비스 유형',
                              hintText: '예: 상담, 시술, 진료 등',
                              maxLength: InputLimits.serviceType,
                            ),
                            SizedBox(height: screenHeight * 0.02),

                            // Duration
                            _buildFieldLabel('소요 시간 (분)', screenWidth),
                            SizedBox(height: screenHeight * 0.01),
                            TextFormField(
                              initialValue: durationMinutes.toString(),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: '예: 10, 30, 60, 90',
                                suffixText: '분',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(screenWidth * 0.03),
                                  borderSide: BorderSide(color: ThemeColor.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(screenWidth * 0.03),
                                  borderSide: BorderSide(color: ThemeColor.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(screenWidth * 0.03),
                                  borderSide: BorderSide(color: ThemeColor.primary, width: 2),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: screenWidth * 0.04,
                                  vertical: screenHeight * 0.015,
                                ),
                              ),
                              onChanged: (value) {
                                final parsed = int.tryParse(value);
                                if (parsed != null && parsed > 0 && parsed <= 480) {
                                  setDialogState(() {
                                    durationMinutes = parsed;
                                  });
                                }
                              },
                            ),
                            SizedBox(height: screenHeight * 0.02),

                            // Notes
                            CharacterCountTextField(
                              controller: notesController,
                              labelText: '메모',
                              hintText: '추가 메모 사항',
                              maxLength: InputLimits.reservationNotes,
                              maxLines: 3,
                            ),
                            SizedBox(height: screenHeight * 0.02),

                            // Remark
                            CharacterCountTextField(
                              controller: remarkController,
                              labelText: '특이사항',
                              hintText: '예: 30분 늦을 수도 있음',
                              maxLength: 200,
                              maxLines: 2,
                            ),
                            SizedBox(height: screenHeight * 0.03),

                            // Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: screenHeight * 0.06,
                                    child: OutlinedButton(
                                      onPressed: () => Navigator.pop(context),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(color: ThemeColor.border),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(screenWidth * 0.03),
                                        ),
                                      ),
                                      child: Text(
                                        '취소',
                                        style: TextStyle(
                                          fontSize: screenWidth * 0.04,
                                          color: ThemeColor.textSecondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: screenWidth * 0.03),
                                Expanded(
                                  child: SizedBox(
                                    height: screenHeight * 0.06,
                                    child: ElevatedButton(
                                      onPressed: selectedMember == null
                                          ? null
                                          : () async {
                                              final serviceType = serviceTypeController.text.trim();
                                              final notes = notesController.text.trim();
                                              final remark = remarkController.text.trim();
                                              final reservation = Reservation(
                                                id: '',
                                                memberId: selectedMember!.id,
                                                businessPlaceId: _selectedBusinessPlaceId!,
                                                reservationDate: selectedDate,
                                                reservationTime: DateTime(
                                                  1970,
                                                  1,
                                                  1,
                                                  selectedTime.hour,
                                                  selectedTime.minute,
                                                ),
                                                status: ReservationStatus.PENDING,
                                                serviceType: serviceType.isEmpty ? null : serviceType,
                                                durationMinutes: durationMinutes,
                                                notes: notes.isEmpty ? null : notes,
                                                remark: remark.isEmpty ? null : remark,
                                                createdBy: widget.user.providerId,
                                                createdAt: DateTime.now(),
                                                updatedAt: DateTime.now(),
                                              );

                                              try {
                                                await _reservationRepository.createReservation(reservation);
                                                if (!mounted) return;
                                                Navigator.pop(context);
                                                await _loadReservations();
                                                AppMessageHandler.showSuccessSnackBar(context, '예약이 생성되었습니다');
                                              } catch (e, stackTrace) {
                                                if (!mounted) return;
                                                await AppMessageHandler.handleErrorWithLogging(
                                                  context,
                                                  e,
                                                  stackTrace,
                                                  screenName: 'ReservationsScreen',
                                                  action: '예약 추가',
                                                  userId: widget.user.id,
                                                  businessPlaceId: _selectedBusinessPlaceId,
                                                );
                                              }
                                            },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: ThemeColor.primary,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(screenWidth * 0.03),
                                        ),
                                      ),
                                      child: Text(
                                        '추가',
                                        style: TextStyle(
                                          fontSize: screenWidth * 0.04,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: ThemeColor.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Image.asset(
          'assets/images/app_logo2.png',
          height: MediaQuery.of(context).size.height * 0.04,
          fit: BoxFit.contain,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : Column(
                  children: [
                    // Business Place Selector
                    _buildBusinessPlaceSelector(screenWidth, MediaQuery.of(context).size.height),

                    // Data Retention Notice
                    _buildRetentionNotice(screenWidth),

                    // Calendar
                    Container(
                      color: Colors.white,
                      child: TableCalendar(
                        firstDay: DateTime.utc(2020, 1, 1),
                        lastDay: DateTime.utc(2030, 12, 31),
                        focusedDay: _focusedDay,
                        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                        onDaySelected: _onDaySelected,
                        onPageChanged: (focusedDay) {
                          _focusedDay = focusedDay;
                          _loadReservations();
                        },
                        calendarStyle: CalendarStyle(
                          todayDecoration: BoxDecoration(
                            color: ThemeColor.primary.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          selectedDecoration: BoxDecoration(
                            color: ThemeColor.primary,
                            shape: BoxShape.circle,
                          ),
                          markerDecoration: BoxDecoration(
                            color: ThemeColor.primary.withValues(alpha: 0.7),
                            shape: BoxShape.circle,
                          ),
                        ),
                        eventLoader: _getReservationsForDay,
                        headerStyle: const HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                        ),
                      ),
                    ),
                    SizedBox(height: screenWidth * 0.04),

                    // Selected day reservations
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedDay == null
                                ? '예약 목록'
                                : '${_selectedDay!.month}월 ${_selectedDay!.day}일 예약',
                            style: TextStyle(
                              fontSize: screenWidth * 0.045,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_selectedDayReservations.length}건',
                            style: TextStyle(
                              fontSize: screenWidth * 0.04,
                              color: ThemeColor.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: screenWidth * 0.03),

                    // Reservations list with Pull-to-Refresh
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadReservations,
                        color: ThemeColor.primary,
                        child: _selectedDayReservations.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(height: MediaQuery.of(context).size.height * 0.08),
                                  Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.event_busy,
                                          size: screenWidth * 0.16,
                                          color: ThemeColor.textTertiary,
                                        ),
                                        SizedBox(height: screenWidth * 0.04),
                                        Text(
                                          '예약이 없습니다',
                                          style: TextStyle(
                                            fontSize: screenWidth * 0.04,
                                            color: ThemeColor.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                                itemCount: _selectedDayReservations.length,
                                separatorBuilder: (context, index) =>
                                    SizedBox(height: screenWidth * 0.02),
                                itemBuilder: (context, index) {
                                  final reservation = _selectedDayReservations[index];
                                  return _buildReservationCard(reservation);
                                },
                              ),
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'reservations_fab',
        onPressed: _showAddReservationDialog,
        backgroundColor: ThemeColor.primary,
        child: const Icon(Icons.add),
      ),
    );
  }

  /// 예약 데이터 보관 기간 안내 배너
  Widget _buildRetentionNotice(double screenWidth) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.04,
        vertical: screenWidth * 0.02,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.03,
        vertical: screenWidth * 0.02,
      ),
      decoration: BoxDecoration(
        color: ThemeColor.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: ThemeColor.info.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: screenWidth * 0.04,
            color: ThemeColor.info,
          ),
          SizedBox(width: screenWidth * 0.02),
          Expanded(
            child: Text(
              '예약 기록은 900일(약 2년 6개월)까지 보관됩니다',
              style: TextStyle(
                fontSize: screenWidth * 0.03,
                color: ThemeColor.info,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(screenWidth * 0.08),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: screenWidth * 0.16,
              color: ThemeColor.error,
            ),
            SizedBox(height: screenHeight * 0.02),
            Text(
              _error ?? '오류가 발생했습니다',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: screenWidth * 0.04),
            ),
            SizedBox(height: screenHeight * 0.03),
            ElevatedButton(
              onPressed: _loadReservations,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReservationCard(Reservation reservation) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return FutureBuilder<Member?>(
      future: _memberRepository.getMemberById(reservation.memberId),
      builder: (context, snapshot) {
        final memberName = snapshot.data?.name ?? '로딩중...';

        return Card(
          child: ListTile(
            leading: Container(
              width: screenWidth * 0.12,
              height: screenWidth * 0.12,
              decoration: BoxDecoration(
                color: _getStatusColor(reservation.status).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(screenWidth * 0.02),
              ),
              child: Center(
                child: Text(
                  memberName.isNotEmpty ? memberName[0] : '?',
                  style: TextStyle(
                    fontSize: screenWidth * 0.05,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(reservation.status),
                  ),
                ),
              ),
            ),
            title: Text(
              memberName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: screenHeight * 0.005),
                Row(
                  children: [
                    Icon(Icons.access_time, size: screenWidth * 0.035, color: ThemeColor.textSecondary),
                    SizedBox(width: screenWidth * 0.01),
                    Text(
                      '${reservation.reservationTime.hour.toString().padLeft(2, '0')}:'
                      '${reservation.reservationTime.minute.toString().padLeft(2, '0')} '
                      '(${reservation.durationMinutes}분)',
                      style: TextStyle(fontSize: screenWidth * 0.03, color: ThemeColor.textSecondary),
                    ),
                  ],
                ),
                if (reservation.serviceType != null) ...[
                  SizedBox(height: screenHeight * 0.003),
                  Text(
                    reservation.serviceType!,
                    style: TextStyle(fontSize: screenWidth * 0.03, color: ThemeColor.textSecondary),
                  ),
                ],
              ],
            ),
            trailing: _buildStatusChip(reservation.status),
            onTap: () => _showReservationDetail(reservation),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(ReservationStatus status) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.03, vertical: screenHeight * 0.008),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(screenWidth * 0.03),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          fontSize: screenWidth * 0.03,
          fontWeight: FontWeight.w600,
          color: _getStatusColor(status),
        ),
      ),
    );
  }

  Color _getStatusColor(ReservationStatus status) {
    switch (status) {
      case ReservationStatus.PENDING:
        return ThemeColor.warning;
      case ReservationStatus.CONFIRMED:
        return ThemeColor.success;
      case ReservationStatus.CANCELLED:
        return ThemeColor.error;
      case ReservationStatus.COMPLETED:
        return ThemeColor.info;
      case ReservationStatus.NO_SHOW:
        return ThemeColor.textTertiary;
    }
  }

  Widget _buildFieldLabel(String label, double screenWidth) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: TextStyle(
          fontSize: screenWidth * 0.035,
          fontWeight: FontWeight.w600,
          color: ThemeColor.textPrimary,
        ),
      ),
    );
  }

  Future<void> _showReservationDetail(Reservation reservation) async {
    final member = await _memberRepository.getMemberById(reservation.memberId);

    // 수정자 또는 생성자 정보 조회
    String? modifierName;
    final modifierId = reservation.updatedBy ?? reservation.createdBy;
    if (modifierId != null && modifierId.isNotEmpty) {
      try {
        final modifier = await _userService.getUser(modifierId);
        modifierName = modifier.username;
      } catch (e) {
        // 사용자 조회 실패 시 무시
      }
    }

    if (!mounted) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(screenWidth * 0.06),
          ),
          elevation: 0,
          backgroundColor: Colors.white,
          insetPadding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
          child: Container(
            constraints: BoxConstraints(maxWidth: screenWidth * 0.9),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Close button
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: ThemeColor.textSecondary),
                    padding: EdgeInsets.all(screenWidth * 0.04),
                  ),
                ),
                // Content
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    screenWidth * 0.06,
                    0,
                    screenWidth * 0.06,
                    screenWidth * 0.06,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon
                      Container(
                        width: screenWidth * 0.16,
                        height: screenWidth * 0.16,
                        decoration: BoxDecoration(
                          color: _getStatusColor(reservation.status).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            (member?.name ?? '?')[0],
                            style: TextStyle(
                              fontSize: screenWidth * 0.06,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(reservation.status),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.02),
                      // Title
                      Text(
                        member?.name ?? '알 수 없음',
                        style: TextStyle(
                          fontSize: screenWidth * 0.055,
                          fontWeight: FontWeight.w700,
                          color: ThemeColor.textPrimary,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.005),
                      // Status chip
                      _buildStatusChip(reservation.status),
                      SizedBox(height: screenHeight * 0.025),

                      // Details container
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(screenWidth * 0.04),
                        decoration: BoxDecoration(
                          color: ThemeColor.neutral50,
                          borderRadius: BorderRadius.circular(screenWidth * 0.03),
                          border: Border.all(color: ThemeColor.border),
                        ),
                        child: Column(
                          children: [
                            _buildDetailRow('날짜',
                                '${reservation.reservationDate.year}-${reservation.reservationDate.month.toString().padLeft(2, '0')}-${reservation.reservationDate.day.toString().padLeft(2, '0')}'),
                            _buildDetailRow('시간',
                                '${reservation.reservationTime.hour.toString().padLeft(2, '0')}:${reservation.reservationTime.minute.toString().padLeft(2, '0')}'),
                            _buildDetailRow('소요 시간', '${reservation.durationMinutes}분'),
                            if (reservation.serviceType != null)
                              _buildDetailRow('서비스', reservation.serviceType!),
                            if (reservation.notes != null)
                              _buildDetailRow('메모', reservation.notes!),
                            if (reservation.remark != null)
                              _buildDetailRow('특이사항', reservation.remark!),
                            if (modifierName != null)
                              _buildDetailRow(
                                reservation.updatedBy != null ? '수정자' : '생성자',
                                modifierName,
                              ),
                          ],
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.025),

                      // Edit button (always available)
                      SizedBox(
                        width: double.infinity,
                        height: screenHeight * 0.055,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _showEditReservationDialog(reservation);
                            });
                          },
                          icon: Icon(Icons.edit, size: screenWidth * 0.045),
                          label: Text(
                            '예약 수정',
                            style: TextStyle(
                              fontSize: screenWidth * 0.038,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ThemeColor.primary,
                            side: BorderSide(color: ThemeColor.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(screenWidth * 0.03),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.015),

                      // Action buttons
                      if (reservation.status == ReservationStatus.PENDING)
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: screenHeight * 0.055,
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: ThemeColor.border),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(screenWidth * 0.03),
                                    ),
                                  ),
                                  child: Text(
                                    '닫기',
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.038,
                                      color: ThemeColor.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: screenWidth * 0.03),
                            Expanded(
                              child: SizedBox(
                                height: screenHeight * 0.055,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    try {
                                      await _reservationRepository.updateReservationStatus(
                                        reservation.id,
                                        ReservationStatus.CONFIRMED,
                                        updatedBy: widget.user.providerId,
                                      );
                                      if (!mounted) return;
                                      Navigator.pop(context);
                                      await _loadReservations();
                                      AppMessageHandler.showSuccessSnackBar(context, '예약이 확정되었습니다');
                                    } catch (e, stackTrace) {
                                      if (!mounted) return;
                                      await AppMessageHandler.handleErrorWithLogging(
                                        context,
                                        e,
                                        stackTrace,
                                        screenName: 'ReservationsScreen',
                                        action: '예약 상태 변경',
                                        userId: widget.user.id,
                                        businessPlaceId: _selectedBusinessPlaceId,
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: ThemeColor.success,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(screenWidth * 0.03),
                                    ),
                                  ),
                                  child: Text(
                                    '확정',
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.038,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          height: screenHeight * 0.055,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: ThemeColor.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(screenWidth * 0.03),
                              ),
                            ),
                            child: Text(
                              '닫기',
                              style: TextStyle(
                                fontSize: screenWidth * 0.038,
                                color: ThemeColor.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 예약 수정 다이얼로그
  Future<void> _showEditReservationDialog(Reservation reservation) async {
    HapticHelper.medium();

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    DateTime selectedDate = reservation.reservationDate;
    TimeOfDay selectedTime = TimeOfDay(
      hour: reservation.reservationTime.hour,
      minute: reservation.reservationTime.minute,
    );
    ReservationStatus selectedStatus = reservation.status;
    final serviceTypeController = TextEditingController(text: reservation.serviceType ?? '');
    int durationMinutes = reservation.durationMinutes;
    final notesController = TextEditingController(text: reservation.notes ?? '');
    final remarkController = TextEditingController(text: reservation.remark ?? '');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(screenWidth * 0.06),
              ),
              elevation: 0,
              backgroundColor: Colors.white,
              insetPadding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: screenWidth * 0.9,
                  maxHeight: screenHeight * 0.85,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Close button
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close, color: ThemeColor.textSecondary),
                        padding: EdgeInsets.all(screenWidth * 0.04),
                      ),
                    ),
                    // Content
                    Flexible(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          screenWidth * 0.06,
                          0,
                          screenWidth * 0.06,
                          screenWidth * 0.06,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Icon
                            Container(
                              width: screenWidth * 0.16,
                              height: screenWidth * 0.16,
                              decoration: BoxDecoration(
                                color: ThemeColor.primarySurface,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.edit_calendar,
                                size: screenWidth * 0.08,
                                color: ThemeColor.primary,
                              ),
                            ),
                            SizedBox(height: screenHeight * 0.02),
                            // Title
                            Text(
                              '예약 수정',
                              style: TextStyle(
                                fontSize: screenWidth * 0.055,
                                fontWeight: FontWeight.w700,
                                color: ThemeColor.textPrimary,
                              ),
                            ),
                            SizedBox(height: screenHeight * 0.03),

                            // Status selection
                            _buildFieldLabel('예약 상태', screenWidth),
                            SizedBox(height: screenHeight * 0.01),
                            DropdownButtonFormField<ReservationStatus>(
                              value: selectedStatus,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(screenWidth * 0.03),
                                  borderSide: BorderSide(color: ThemeColor.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(screenWidth * 0.03),
                                  borderSide: BorderSide(color: ThemeColor.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(screenWidth * 0.03),
                                  borderSide: BorderSide(color: ThemeColor.primary, width: 2),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: screenWidth * 0.04,
                                  vertical: screenHeight * 0.015,
                                ),
                              ),
                              items: ReservationStatus.values.map((status) {
                                return DropdownMenuItem(
                                  value: status,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: screenWidth * 0.025,
                                        height: screenWidth * 0.025,
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(status),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      SizedBox(width: screenWidth * 0.02),
                                      Text(status.displayName),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (status) {
                                if (status != null) {
                                  setDialogState(() {
                                    selectedStatus = status;
                                  });
                                }
                              },
                            ),
                            SizedBox(height: screenHeight * 0.02),

                            // Date and Time Row
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildFieldLabel('예약 날짜', screenWidth),
                                      SizedBox(height: screenHeight * 0.01),
                                      InkWell(
                                        onTap: () async {
                                          final date = await showDatePicker(
                                            context: context,
                                            initialDate: selectedDate,
                                            firstDate: DateTime(2020),
                                            lastDate: DateTime.now().add(const Duration(days: 365)),
                                          );
                                          if (date != null) {
                                            setDialogState(() {
                                              selectedDate = date;
                                            });
                                          }
                                        },
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: screenWidth * 0.04,
                                            vertical: screenHeight * 0.015,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: ThemeColor.border),
                                            borderRadius: BorderRadius.circular(screenWidth * 0.03),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.calendar_today, size: screenWidth * 0.045, color: ThemeColor.primary),
                                              SizedBox(width: screenWidth * 0.02),
                                              Text(
                                                '${selectedDate.month}/${selectedDate.day}',
                                                style: TextStyle(fontSize: screenWidth * 0.038),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: screenWidth * 0.03),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildFieldLabel('예약 시간', screenWidth),
                                      SizedBox(height: screenHeight * 0.01),
                                      InkWell(
                                        onTap: () async {
                                          final time = await showTimePicker(
                                            context: context,
                                            initialTime: selectedTime,
                                          );
                                          if (time != null) {
                                            setDialogState(() {
                                              selectedTime = time;
                                            });
                                          }
                                        },
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: screenWidth * 0.04,
                                            vertical: screenHeight * 0.015,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: ThemeColor.border),
                                            borderRadius: BorderRadius.circular(screenWidth * 0.03),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.access_time, size: screenWidth * 0.045, color: ThemeColor.primary),
                                              SizedBox(width: screenWidth * 0.02),
                                              Text(
                                                '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                                                style: TextStyle(fontSize: screenWidth * 0.038),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: screenHeight * 0.02),

                            // Service type
                            CharacterCountTextField(
                              controller: serviceTypeController,
                              labelText: '서비스 유형',
                              hintText: '예: 상담, 시술, 진료 등',
                              maxLength: InputLimits.serviceType,
                            ),
                            SizedBox(height: screenHeight * 0.02),

                            // Duration
                            _buildFieldLabel('소요 시간 (분)', screenWidth),
                            SizedBox(height: screenHeight * 0.01),
                            TextFormField(
                              initialValue: durationMinutes.toString(),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: '예: 10, 30, 60, 90',
                                suffixText: '분',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(screenWidth * 0.03),
                                  borderSide: BorderSide(color: ThemeColor.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(screenWidth * 0.03),
                                  borderSide: BorderSide(color: ThemeColor.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(screenWidth * 0.03),
                                  borderSide: BorderSide(color: ThemeColor.primary, width: 2),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: screenWidth * 0.04,
                                  vertical: screenHeight * 0.015,
                                ),
                              ),
                              onChanged: (value) {
                                final parsed = int.tryParse(value);
                                if (parsed != null && parsed > 0 && parsed <= 480) {
                                  setDialogState(() {
                                    durationMinutes = parsed;
                                  });
                                }
                              },
                            ),
                            SizedBox(height: screenHeight * 0.02),

                            // Notes
                            CharacterCountTextField(
                              controller: notesController,
                              labelText: '메모',
                              hintText: '추가 메모 사항',
                              maxLength: InputLimits.reservationNotes,
                              maxLines: 3,
                            ),
                            SizedBox(height: screenHeight * 0.02),

                            // Remark
                            CharacterCountTextField(
                              controller: remarkController,
                              labelText: '특이사항',
                              hintText: '예: 30분 늦을 수도 있음',
                              maxLength: 200,
                              maxLines: 2,
                            ),
                            SizedBox(height: screenHeight * 0.03),

                            // Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: screenHeight * 0.06,
                                    child: OutlinedButton(
                                      onPressed: () => Navigator.pop(context),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(color: ThemeColor.border),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(screenWidth * 0.03),
                                        ),
                                      ),
                                      child: Text(
                                        '취소',
                                        style: TextStyle(
                                          fontSize: screenWidth * 0.04,
                                          color: ThemeColor.textSecondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: screenWidth * 0.03),
                                Expanded(
                                  child: SizedBox(
                                    height: screenHeight * 0.06,
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        final serviceType = serviceTypeController.text.trim();
                                        final notes = notesController.text.trim();
                                        final remark = remarkController.text.trim();

                                        final updatedReservation = reservation.copyWith(
                                          reservationDate: selectedDate,
                                          reservationTime: DateTime(
                                            1970,
                                            1,
                                            1,
                                            selectedTime.hour,
                                            selectedTime.minute,
                                          ),
                                          status: selectedStatus,
                                          serviceType: serviceType.isEmpty ? null : serviceType,
                                          durationMinutes: durationMinutes,
                                          notes: notes.isEmpty ? null : notes,
                                          remark: remark.isEmpty ? null : remark,
                                          updatedBy: widget.user.providerId,
                                        );

                                        try {
                                          await _reservationRepository.updateReservation(
                                            reservation.id,
                                            updatedReservation,
                                          );
                                          if (!mounted) return;
                                          Navigator.pop(context);
                                          await _loadReservations();
                                          AppMessageHandler.showSuccessSnackBar(context, '예약이 수정되었습니다');
                                        } catch (e, stackTrace) {
                                          if (!mounted) return;
                                          await AppMessageHandler.handleErrorWithLogging(
                                            context,
                                            e,
                                            stackTrace,
                                            screenName: 'ReservationsScreen',
                                            action: '예약 수정',
                                            userId: widget.user.id,
                                            businessPlaceId: _selectedBusinessPlaceId,
                                          );
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: ThemeColor.primary,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(screenWidth * 0.03),
                                        ),
                                      ),
                                      child: Text(
                                        '저장',
                                        style: TextStyle(
                                          fontSize: screenWidth * 0.04,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: screenHeight * 0.005),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: screenWidth * 0.2,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: ThemeColor.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: ThemeColor.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  /// Business Place Selector Widget
  Widget _buildBusinessPlaceSelector(double screenWidth, double screenHeight) {
    if (_businessPlaces.isEmpty) {
      return const SizedBox.shrink();
    }

    final selectedPlace = _businessPlaces.firstWhere(
      (bp) => bp.businessPlace.id == _selectedBusinessPlaceId,
      orElse: () => _businessPlaces.first,
    );

    return Container(
      margin: EdgeInsets.fromLTRB(
        screenWidth * 0.04,
        screenHeight * 0.015,
        screenWidth * 0.04,
        screenHeight * 0.01,
      ),
      decoration: BoxDecoration(
        color: ThemeColor.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ThemeColor.primary.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: ThemeColor.primary.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showBusinessPlaceSelectorDialog(screenWidth, screenHeight),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.04,
              vertical: screenHeight * 0.014,
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(screenWidth * 0.02),
                  decoration: BoxDecoration(
                    color: ThemeColor.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.store_rounded,
                    color: ThemeColor.primary,
                    size: screenWidth * 0.05,
                  ),
                ),
                SizedBox(width: screenWidth * 0.03),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '사업장',
                        style: TextStyle(
                          fontSize: screenWidth * 0.028,
                          color: ThemeColor.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.002),
                      Text(
                        selectedPlace.businessPlace.name,
                        style: TextStyle(
                          fontSize: screenWidth * 0.04,
                          fontWeight: FontWeight.w700,
                          color: ThemeColor.textPrimary,
                          letterSpacing: screenWidth * -0.0008,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  color: ThemeColor.primary,
                  size: screenWidth * 0.07,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showBusinessPlaceSelectorDialog(
    double screenWidth,
    double screenHeight,
  ) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(screenWidth * 0.05),
        ),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: screenWidth * 0.9,
            maxHeight: screenHeight * 0.6,
          ),
          padding: EdgeInsets.all(screenWidth * 0.04),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.store_rounded,
                    color: ThemeColor.primary,
                    size: screenWidth * 0.06,
                  ),
                  SizedBox(width: screenWidth * 0.02),
                  Text(
                    '사업장 선택',
                    style: TextStyle(
                      fontSize: screenWidth * 0.045,
                      fontWeight: FontWeight.w700,
                      color: ThemeColor.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: Icon(Icons.close, color: ThemeColor.textSecondary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              SizedBox(height: screenHeight * 0.02),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _businessPlaces.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final bp = _businessPlaces[index];
                    final isSelected =
                        bp.businessPlace.id == _selectedBusinessPlaceId;

                    return ListTile(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.02,
                        vertical: screenHeight * 0.005,
                      ),
                      leading: Container(
                        width: screenWidth * 0.1,
                        height: screenWidth * 0.1,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? ThemeColor.primary
                              : ThemeColor.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.store,
                          color: isSelected ? Colors.white : ThemeColor.primary,
                          size: screenWidth * 0.05,
                        ),
                      ),
                      title: Text(
                        bp.businessPlace.name,
                        style: TextStyle(
                          fontSize: screenWidth * 0.038,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected
                              ? ThemeColor.primary
                              : ThemeColor.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        bp.userRole.name,
                        style: TextStyle(
                          fontSize: screenWidth * 0.03,
                          color: ThemeColor.textTertiary,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_circle, color: ThemeColor.primary)
                          : null,
                      onTap: () {
                        if (_selectedBusinessPlaceId != bp.businessPlace.id) {
                          setState(() {
                            _selectedBusinessPlaceId = bp.businessPlace.id;
                          });
                          Navigator.pop(dialogContext);
                          _loadReservations();
                        } else {
                          Navigator.pop(dialogContext);
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
