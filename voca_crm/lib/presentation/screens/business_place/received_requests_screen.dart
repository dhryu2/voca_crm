import 'package:flutter/material.dart';
import 'package:voca_crm/core/theme/theme_color.dart';
import 'package:voca_crm/core/utils/message_handler.dart';
import 'package:voca_crm/data/datasource/business_place_service.dart';
import 'package:voca_crm/domain/entity/business_place_access_request.dart';
import 'package:voca_crm/domain/entity/user.dart';
import 'package:voca_crm/domain/entity/user_business_place.dart';
import 'package:voca_crm/presentation/widgets/custom_button.dart';

class ReceivedRequestsScreen extends StatefulWidget {
  final User user;

  const ReceivedRequestsScreen({Key? key, required this.user})
    : super(key: key);

  @override
  State<ReceivedRequestsScreen> createState() => _ReceivedRequestsScreenState();
}

class _ReceivedRequestsScreenState extends State<ReceivedRequestsScreen> {
  final BusinessPlaceService _service = BusinessPlaceService();

  List<BusinessPlaceAccessRequest> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      // API가 요청자 정보와 사업장 정보를 함께 반환
      final requests = await _service.getReceivedRequests(widget.user.id);

      setState(() {
        _requests = requests;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        AppMessageHandler.handleApiError(context, e);
      }
    }
  }

  Future<void> _approveRequest(BusinessPlaceAccessRequest request) async {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(screenWidth * 0.05),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        insetPadding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.06),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: screenWidth * 0.18,
                height: screenWidth * 0.18,
                decoration: BoxDecoration(
                  color: ThemeColor.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_add_rounded,
                  size: screenWidth * 0.09,
                  color: ThemeColor.success,
                ),
              ),
              SizedBox(height: screenHeight * 0.025),

              // Title
              Text(
                '접근 요청 승인',
                style: TextStyle(
                  fontSize: screenWidth * 0.05,
                  fontWeight: FontWeight.bold,
                  color: ThemeColor.textPrimary,
                ),
              ),
              SizedBox(height: screenHeight * 0.02),

              // Request Info Card - 요청자 상세 정보
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(screenWidth * 0.04),
                decoration: BoxDecoration(
                  color: ThemeColor.neutral50,
                  borderRadius: BorderRadius.circular(screenWidth * 0.03),
                  border: Border.all(color: ThemeColor.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 섹션 헤더: 요청자 정보
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: screenWidth * 0.04,
                          color: ThemeColor.textSecondary,
                        ),
                        SizedBox(width: screenWidth * 0.02),
                        Text(
                          '요청자 정보',
                          style: TextStyle(
                            fontSize: screenWidth * 0.035,
                            fontWeight: FontWeight.w600,
                            color: ThemeColor.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: screenHeight * 0.012),
                    _buildInfoRow(
                      icon: Icons.badge_outlined,
                      label: '이름',
                      value: request.requesterName ?? '알 수 없음',
                      screenWidth: screenWidth,
                    ),
                    SizedBox(height: screenHeight * 0.008),
                    _buildInfoRow(
                      icon: Icons.phone_outlined,
                      label: '전화번호',
                      value: request.requesterPhone ?? '-',
                      screenWidth: screenWidth,
                    ),
                    SizedBox(height: screenHeight * 0.008),
                    _buildInfoRow(
                      icon: Icons.email_outlined,
                      label: '이메일',
                      value: request.requesterEmail ?? '-',
                      screenWidth: screenWidth,
                    ),
                    SizedBox(height: screenHeight * 0.015),
                    Divider(color: ThemeColor.border, height: 1),
                    SizedBox(height: screenHeight * 0.015),
                    _buildInfoRow(
                      icon: Icons.shield_outlined,
                      label: '요청 권한',
                      value: _getRoleText(request.role),
                      valueColor: _getRoleColor(request.role),
                      screenWidth: screenWidth,
                    ),
                    SizedBox(height: screenHeight * 0.015),
                    Divider(color: ThemeColor.border, height: 1),
                    SizedBox(height: screenHeight * 0.015),
                    // 섹션: 사업장 정보
                    Row(
                      children: [
                        Icon(
                          Icons.business_outlined,
                          size: screenWidth * 0.04,
                          color: ThemeColor.textSecondary,
                        ),
                        SizedBox(width: screenWidth * 0.02),
                        Text(
                          '사업장 정보',
                          style: TextStyle(
                            fontSize: screenWidth * 0.035,
                            fontWeight: FontWeight.w600,
                            color: ThemeColor.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: screenHeight * 0.012),
                    _buildInfoRow(
                      icon: Icons.store_outlined,
                      label: '사업장 이름',
                      value: request.businessPlaceName ?? '알 수 없음',
                      screenWidth: screenWidth,
                    ),
                    SizedBox(height: screenHeight * 0.008),
                    _buildInfoRow(
                      icon: Icons.tag,
                      label: '사업장 ID',
                      value: request.businessPlaceId.length > 12
                          ? '${request.businessPlaceId.substring(0, 12)}...'
                          : request.businessPlaceId,
                      screenWidth: screenWidth,
                    ),
                  ],
                ),
              ),
              SizedBox(height: screenHeight * 0.015),

              // Warning message
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.03,
                  vertical: screenHeight * 0.01,
                ),
                decoration: BoxDecoration(
                  color: ThemeColor.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(screenWidth * 0.02),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: screenWidth * 0.045,
                      color: ThemeColor.warning,
                    ),
                    SizedBox(width: screenWidth * 0.02),
                    Expanded(
                      child: Text(
                        '승인 시 해당 사용자가 사업장에 접근할 수 있습니다',
                        style: TextStyle(
                          fontSize: screenWidth * 0.032,
                          color: ThemeColor.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: screenHeight * 0.03),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: screenHeight * 0.018,
                        ),
                        side: BorderSide(color: ThemeColor.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            screenWidth * 0.025,
                          ),
                        ),
                      ),
                      child: Text(
                        '취소',
                        style: TextStyle(
                          fontSize: screenWidth * 0.038,
                          color: ThemeColor.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.03),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeColor.success,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: screenHeight * 0.018,
                        ),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            screenWidth * 0.025,
                          ),
                        ),
                      ),
                      child: Text(
                        '승인하기',
                        style: TextStyle(
                          fontSize: screenWidth * 0.038,
                          fontWeight: FontWeight.w600,
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
    );

    if (confirm == true) {
      try {
        await _service.approveRequest(
          requestId: request.id,
          ownerId: widget.user.id,
        );
        _loadRequests();
        if (mounted) {
          AppMessageHandler.showSuccessSnackBar(context, '요청을 승인했습니다');
        }
      } catch (e) {
        if (mounted) {
          AppMessageHandler.handleApiError(context, e);
        }
      }
    }
  }

  Future<void> _rejectRequest(BusinessPlaceAccessRequest request) async {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(screenWidth * 0.05),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        insetPadding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.06),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: screenWidth * 0.18,
                height: screenWidth * 0.18,
                decoration: BoxDecoration(
                  color: ThemeColor.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_remove_rounded,
                  size: screenWidth * 0.09,
                  color: ThemeColor.error,
                ),
              ),
              SizedBox(height: screenHeight * 0.025),

              // Title
              Text(
                '접근 요청 거부',
                style: TextStyle(
                  fontSize: screenWidth * 0.05,
                  fontWeight: FontWeight.bold,
                  color: ThemeColor.textPrimary,
                ),
              ),
              SizedBox(height: screenHeight * 0.02),

              // Request Info Card - 요청자 상세 정보
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(screenWidth * 0.04),
                decoration: BoxDecoration(
                  color: ThemeColor.neutral50,
                  borderRadius: BorderRadius.circular(screenWidth * 0.03),
                  border: Border.all(color: ThemeColor.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 섹션 헤더: 요청자 정보
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: screenWidth * 0.04,
                          color: ThemeColor.textSecondary,
                        ),
                        SizedBox(width: screenWidth * 0.02),
                        Text(
                          '요청자 정보',
                          style: TextStyle(
                            fontSize: screenWidth * 0.035,
                            fontWeight: FontWeight.w600,
                            color: ThemeColor.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: screenHeight * 0.012),
                    _buildInfoRow(
                      icon: Icons.badge_outlined,
                      label: '이름',
                      value: request.requesterName ?? '알 수 없음',
                      screenWidth: screenWidth,
                    ),
                    SizedBox(height: screenHeight * 0.008),
                    _buildInfoRow(
                      icon: Icons.phone_outlined,
                      label: '전화번호',
                      value: request.requesterPhone ?? '-',
                      screenWidth: screenWidth,
                    ),
                    SizedBox(height: screenHeight * 0.008),
                    _buildInfoRow(
                      icon: Icons.email_outlined,
                      label: '이메일',
                      value: request.requesterEmail ?? '-',
                      screenWidth: screenWidth,
                    ),
                    SizedBox(height: screenHeight * 0.015),
                    Divider(color: ThemeColor.border, height: 1),
                    SizedBox(height: screenHeight * 0.015),
                    _buildInfoRow(
                      icon: Icons.shield_outlined,
                      label: '요청 권한',
                      value: _getRoleText(request.role),
                      valueColor: _getRoleColor(request.role),
                      screenWidth: screenWidth,
                    ),
                    SizedBox(height: screenHeight * 0.015),
                    Divider(color: ThemeColor.border, height: 1),
                    SizedBox(height: screenHeight * 0.015),
                    // 섹션: 사업장 정보
                    Row(
                      children: [
                        Icon(
                          Icons.business_outlined,
                          size: screenWidth * 0.04,
                          color: ThemeColor.textSecondary,
                        ),
                        SizedBox(width: screenWidth * 0.02),
                        Text(
                          '사업장 정보',
                          style: TextStyle(
                            fontSize: screenWidth * 0.035,
                            fontWeight: FontWeight.w600,
                            color: ThemeColor.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: screenHeight * 0.012),
                    _buildInfoRow(
                      icon: Icons.store_outlined,
                      label: '사업장 이름',
                      value: request.businessPlaceName ?? '알 수 없음',
                      screenWidth: screenWidth,
                    ),
                    SizedBox(height: screenHeight * 0.008),
                    _buildInfoRow(
                      icon: Icons.tag,
                      label: '사업장 ID',
                      value: request.businessPlaceId.length > 12
                          ? '${request.businessPlaceId.substring(0, 12)}...'
                          : request.businessPlaceId,
                      screenWidth: screenWidth,
                    ),
                  ],
                ),
              ),
              SizedBox(height: screenHeight * 0.015),

              // Warning message
              Text(
                '이 요청을 거부하시겠습니까?',
                style: TextStyle(
                  fontSize: screenWidth * 0.038,
                  color: ThemeColor.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: screenHeight * 0.03),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: screenHeight * 0.018,
                        ),
                        side: BorderSide(color: ThemeColor.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            screenWidth * 0.025,
                          ),
                        ),
                      ),
                      child: Text(
                        '취소',
                        style: TextStyle(
                          fontSize: screenWidth * 0.038,
                          color: ThemeColor.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.03),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeColor.error,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: screenHeight * 0.018,
                        ),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            screenWidth * 0.025,
                          ),
                        ),
                      ),
                      child: Text(
                        '거부하기',
                        style: TextStyle(
                          fontSize: screenWidth * 0.038,
                          fontWeight: FontWeight.w600,
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
    );

    if (confirm == true) {
      try {
        await _service.rejectRequest(
          requestId: request.id,
          ownerId: widget.user.id,
        );
        _loadRequests();
        if (mounted) {
          AppMessageHandler.showSuccessSnackBar(context, '요청을 거부했습니다');
        }
      } catch (e) {
        if (mounted) {
          AppMessageHandler.handleApiError(context, e);
        }
      }
    }
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required double screenWidth,
    Color? valueColor,
  }) {
    return Row(
      children: [
        SizedBox(
          width: screenWidth * 0.28,
          child: Row(
            children: [
              Icon(
                icon,
                size: screenWidth * 0.045,
                color: ThemeColor.textTertiary,
              ),
              SizedBox(width: screenWidth * 0.02),
              SizedBox(
                width: screenWidth * 0.2,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: screenWidth * 0.033,
                    color: ThemeColor.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: screenWidth * 0.035,
              fontWeight: FontWeight.w600,
              color: valueColor ?? ThemeColor.textPrimary,
            ),
            textAlign: TextAlign.start,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Color _getRoleColor(Role role) {
    switch (role) {
      case Role.OWNER:
        return ThemeColor.warning;
      case Role.MANAGER:
        return ThemeColor.info;
      case Role.STAFF:
        return ThemeColor.success;
    }
  }

  String _getRoleText(Role role) {
    switch (role) {
      case Role.OWNER:
        return '주인';
      case Role.MANAGER:
        return '매니저';
      case Role.STAFF:
        return '스태프';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/images/app_logo2.png',
          height: screenHeight * 0.04,
          fit: BoxFit.contain,
        ),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadRequests),
        ],
      ),
      body: _isLoading
          ? Center(
              child: SizedBox(
                width: screenWidth * 0.1,
                height: screenWidth * 0.1,
                child: CircularProgressIndicator(
                  strokeWidth: screenWidth * 0.008,
                ),
              ),
            )
          : _requests.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox,
                    size: screenWidth * 0.2,
                    color: ThemeColor.textTertiary,
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  Text(
                    '받은 요청이 없습니다',
                    style: TextStyle(
                      fontSize: screenWidth * 0.04,
                      color: ThemeColor.textTertiary,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(screenWidth * 0.04),
              itemCount: _requests.length,
              itemBuilder: (context, index) {
                final request = _requests[index];
                final requesterName = request.requesterName ?? '알 수 없음';
                final businessPlaceName = request.businessPlaceName ?? '알 수 없음';

                return Card(
                  margin: EdgeInsets.only(bottom: screenHeight * 0.015),
                  child: Padding(
                    padding: EdgeInsets.all(screenWidth * 0.04),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: screenWidth * 0.05,
                              backgroundColor: ThemeColor.primary.withValues(
                                alpha: 0.1,
                              ),
                              child: Icon(
                                Icons.person,
                                size: screenWidth * 0.05,
                                color: ThemeColor.primary,
                              ),
                            ),
                            SizedBox(width: screenWidth * 0.03),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    requesterName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: screenWidth * 0.04,
                                    ),
                                  ),
                                  SizedBox(height: screenHeight * 0.004),
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: screenWidth * 0.02,
                                          vertical: screenHeight * 0.003,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getRoleColor(
                                            request.role,
                                          ).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            screenWidth * 0.01,
                                          ),
                                        ),
                                        child: Text(
                                          _getRoleText(request.role),
                                          style: TextStyle(
                                            color: _getRoleColor(request.role),
                                            fontSize: screenWidth * 0.032,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: screenHeight * 0.004),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.store_outlined,
                                        size: screenWidth * 0.035,
                                        color: ThemeColor.textTertiary,
                                      ),
                                      SizedBox(width: screenWidth * 0.01),
                                      Expanded(
                                        child: Text(
                                          businessPlaceName,
                                          style: TextStyle(
                                            fontSize: screenWidth * 0.032,
                                            color: ThemeColor.textSecondary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: screenHeight * 0.015),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: () => _rejectRequest(request),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: ThemeColor.error,
                              ),
                              child: const Text('거부'),
                            ),
                            SizedBox(width: screenWidth * 0.02),
                            CustomButton(
                              onPressed: () => _approveRequest(request),
                              child: const Text('수락'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
