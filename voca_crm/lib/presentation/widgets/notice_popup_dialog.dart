import 'package:flutter/material.dart';
import 'package:voca_crm/core/theme/theme_color.dart';
import 'package:voca_crm/domain/entity/notice.dart';
import 'package:intl/intl.dart';

/// 공지사항 팝업 다이얼로그
///
/// 로그인 후 또는 홈 화면 진입 시 공지사항을 표시하는 위젯
/// "다시 보지 않기" 체크박스 기능 포함
class NoticePopupDialog extends StatefulWidget {
  final Notice notice;
  final Function(bool doNotShowAgain) onClose;

  const NoticePopupDialog({
    super.key,
    required this.notice,
    required this.onClose,
  });

  @override
  State<NoticePopupDialog> createState() => NoticePopupDialogState();
}

class NoticePopupDialogState extends State<NoticePopupDialog> {
  bool _doNotShowAgain = false;

  String _formatDate(DateTime date) {
    return DateFormat('yyyy년 MM월 dd일').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(screenWidth * 0.04),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.75,
          maxWidth: screenWidth * 0.9,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(screenWidth * 0.04),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with close button
            Container(
              padding: EdgeInsets.fromLTRB(
                screenWidth * 0.05,
                screenHeight * 0.02,
                screenWidth * 0.02,
                screenHeight * 0.01,
              ),
              decoration: BoxDecoration(
                color: ThemeColor.primaryPurple.withOpacity(0.1),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(screenWidth * 0.04),
                  topRight: Radius.circular(screenWidth * 0.04),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.campaign_outlined,
                    color: ThemeColor.primaryPurple,
                    size: screenWidth * 0.06,
                  ),
                  SizedBox(width: screenWidth * 0.02),
                  Expanded(
                    child: Text(
                      '공지사항',
                      style: TextStyle(
                        fontSize: screenWidth * 0.045,
                        fontWeight: FontWeight.bold,
                        color: ThemeColor.primaryPurple,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: Colors.grey[600],
                    ),
                    onPressed: () => widget.onClose(_doNotShowAgain),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(screenWidth * 0.05),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      widget.notice.title,
                      style: TextStyle(
                        fontSize: screenWidth * 0.05,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),

                    SizedBox(height: screenHeight * 0.015),

                    // Date
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: screenWidth * 0.035,
                          color: Colors.grey[600],
                        ),
                        SizedBox(width: screenWidth * 0.015),
                        Text(
                          _formatDate(widget.notice.createdAt),
                          style: TextStyle(
                            fontSize: screenWidth * 0.032,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: screenHeight * 0.02),

                    Divider(height: 1, color: Colors.grey[300]),

                    SizedBox(height: screenHeight * 0.02),

                    // Content
                    Text(
                      widget.notice.content,
                      style: TextStyle(
                        fontSize: screenWidth * 0.038,
                        color: Colors.black87,
                        height: 1.6,
                      ),
                    ),

                    SizedBox(height: screenHeight * 0.02),
                  ],
                ),
              ),
            ),

            // Bottom section with checkbox and button
            Container(
              padding: EdgeInsets.all(screenWidth * 0.05),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(screenWidth * 0.04),
                  bottomRight: Radius.circular(screenWidth * 0.04),
                ),
              ),
              child: Column(
                children: [
                  // Do not show again checkbox
                  InkWell(
                    onTap: () {
                      setState(() {
                        _doNotShowAgain = !_doNotShowAgain;
                      });
                    },
                    borderRadius: BorderRadius.circular(screenWidth * 0.02),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: screenHeight * 0.008,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: screenWidth * 0.05,
                            height: screenWidth * 0.05,
                            child: Checkbox(
                              value: _doNotShowAgain,
                              onChanged: (value) {
                                setState(() {
                                  _doNotShowAgain = value ?? false;
                                });
                              },
                              activeColor: ThemeColor.primaryPurple,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  screenWidth * 0.01,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: screenWidth * 0.03),
                          Text(
                            '다시 보지 않기',
                            style: TextStyle(
                              fontSize: screenWidth * 0.035,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: screenHeight * 0.015),

                  // Confirm button
                  SizedBox(
                    width: double.infinity,
                    height: screenHeight * 0.06,
                    child: ElevatedButton(
                      onPressed: () => widget.onClose(_doNotShowAgain),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeColor.primaryPurple,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            screenWidth * 0.03,
                          ),
                        ),
                      ),
                      child: Text(
                        '확인',
                        style: TextStyle(
                          fontSize: screenWidth * 0.04,
                          fontWeight: FontWeight.bold,
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
  }

  bool get doNotShowAgain => _doNotShowAgain;
}
