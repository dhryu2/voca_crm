import 'package:flutter/material.dart';
import 'package:voca_crm/core/theme/theme_color.dart';
import 'package:voca_crm/core/utils/message_handler.dart';
import 'package:voca_crm/data/datasource/business_place_service.dart';
import 'package:voca_crm/domain/entity/business_place_access_request.dart';
import 'package:voca_crm/domain/entity/user.dart';
import 'package:voca_crm/domain/entity/user_business_place.dart';

class SentRequestsScreen extends StatefulWidget {
  final User user;

  const SentRequestsScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<SentRequestsScreen> createState() => _SentRequestsScreenState();
}

class _SentRequestsScreenState extends State<SentRequestsScreen> {
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
      final requests = await _service.getSentRequests(widget.user.id);
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

  Future<void> _deleteRequest(String requestId) async {
    try {
      await _service.deleteRequest(
        requestId: requestId,
        userId: widget.user.id,
      );
      _loadRequests();
      if (mounted) {
        AppMessageHandler.showSuccessSnackBar(context, '요청을 삭제했습니다');
      }
    } catch (e) {
      if (mounted) {
        AppMessageHandler.handleApiError(context, e);
      }
    }
  }

  Future<void> _markAsRead(String requestId) async {
    try {
      await _service.markRequestAsRead(
        requestId: requestId,
        userId: widget.user.id,
      );
      _loadRequests();
      if (mounted) {
        AppMessageHandler.showSuccessSnackBar(context, '요청 결과를 확인했습니다');
      }
    } catch (e) {
      if (mounted) {
        AppMessageHandler.handleApiError(context, e);
      }
    }
  }

  String _getStatusText(AccessStatus status) {
    switch (status) {
      case AccessStatus.PENDING:
        return '대기중';
      case AccessStatus.APPROVED:
        return '허용됨';
      case AccessStatus.REJECTED:
        return '거부됨';
    }
  }

  Color _getStatusColor(AccessStatus status) {
    switch (status) {
      case AccessStatus.PENDING:
        return ThemeColor.warning;
      case AccessStatus.APPROVED:
        return ThemeColor.success;
      case AccessStatus.REJECTED:
        return ThemeColor.error;
    }
  }

  String _getRoleText(Role role) {
    switch (role) {
      case Role.OWNER:
        return '소유자';
      case Role.MANAGER:
        return '매니저';
      case Role.STAFF:
        return '스태프';
    }
  }

  Future<void> _showCancelConfirmDialog(BusinessPlaceAccessRequest request) async {
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
                  color: ThemeColor.warning.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cancel_outlined,
                  size: screenWidth * 0.09,
                  color: ThemeColor.warning,
                ),
              ),
              SizedBox(height: screenHeight * 0.025),

              // Title
              Text(
                '요청 취소',
                style: TextStyle(
                  fontSize: screenWidth * 0.05,
                  fontWeight: FontWeight.bold,
                  color: ThemeColor.textPrimary,
                ),
              ),
              SizedBox(height: screenHeight * 0.02),

              // Request Info Card
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
                    _buildInfoRow(
                      icon: Icons.business_outlined,
                      label: '사업장 ID',
                      value: request.businessPlaceId,
                      screenWidth: screenWidth,
                    ),
                    SizedBox(height: screenHeight * 0.01),
                    _buildInfoRow(
                      icon: Icons.shield_outlined,
                      label: '요청 권한',
                      value: _getRoleText(request.role),
                      screenWidth: screenWidth,
                    ),
                  ],
                ),
              ),
              SizedBox(height: screenHeight * 0.02),

              // Message
              Text(
                '이 요청을 취소하시겠습니까?',
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
                          borderRadius: BorderRadius.circular(screenWidth * 0.025),
                        ),
                      ),
                      child: Text(
                        '아니오',
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
                        backgroundColor: ThemeColor.warning,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: screenHeight * 0.018,
                        ),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(screenWidth * 0.025),
                        ),
                      ),
                      child: Text(
                        '취소하기',
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
      _deleteRequest(request.id);
    }
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required double screenWidth,
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
              Text(
                label,
                style: TextStyle(
                  fontSize: screenWidth * 0.033,
                  color: ThemeColor.textTertiary,
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
              color: ThemeColor.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
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
                    '보낸 요청이 없습니다',
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
                return Card(
                  margin: EdgeInsets.only(bottom: screenHeight * 0.015),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: screenWidth * 0.05,
                      backgroundColor: _getStatusColor(request.status),
                      child: Icon(
                        Icons.business,
                        color: Colors.white,
                        size: screenWidth * 0.05,
                      ),
                    ),
                    title: Text(
                      '사업장 ID: ${request.businessPlaceId}',
                      style: TextStyle(fontSize: screenWidth * 0.038),
                    ),
                    subtitle: Text(
                      '권한: ${request.role.name} | 상태: ${_getStatusText(request.status)}',
                      style: TextStyle(fontSize: screenWidth * 0.032),
                    ),
                    trailing: request.status == AccessStatus.PENDING
                        ? TextButton(
                            onPressed: () => _showCancelConfirmDialog(request),
                            child: const Text('취소'),
                          )
                        : !request.isReadByRequester
                        ? TextButton(
                            onPressed: () => _markAsRead(request.id),
                            style: TextButton.styleFrom(
                              backgroundColor: ThemeColor.primarySurface,
                            ),
                            child: Text(
                              '확인',
                              style: TextStyle(
                                color: ThemeColor.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : TextButton(
                            onPressed: () => _deleteRequest(request.id),
                            child: const Text('삭제'),
                          ),
                  ),
                );
              },
            ),
    );
  }
}
