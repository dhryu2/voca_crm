import 'package:flutter/material.dart';
import 'package:voca_crm/core/theme/theme_color.dart';
import 'package:voca_crm/core/utils/message_handler.dart';
import 'package:voca_crm/data/datasource/business_place_service.dart';
import 'package:voca_crm/domain/entity/user.dart';
import 'package:voca_crm/domain/entity/user_business_place.dart';
import 'package:voca_crm/presentation/widgets/custom_button.dart';

class RequestAccessScreen extends StatefulWidget {
  final User user;

  const RequestAccessScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<RequestAccessScreen> createState() => _RequestAccessScreenState();
}

class _RequestAccessScreenState extends State<RequestAccessScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessPlaceIdController = TextEditingController();
  Role _selectedRole = Role.STAFF;
  bool _isLoading = false;

  final BusinessPlaceService _service = BusinessPlaceService();

  Future<void> _requestAccess() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _service.requestAccess(
        userId: widget.user.id,
        businessPlaceId: _businessPlaceIdController.text,
        role: _selectedRole,
      );

      if (mounted) {
        Navigator.pop(context);
        // Navigator.pop 후에 SnackBar 표시 (이전 화면의 context 사용)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            AppMessageHandler.showSuccessSnackBar(context, '접근 요청을 보냈습니다');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        AppMessageHandler.handleApiError(context, e);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(screenWidth * 0.06),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.business_center,
                size: screenWidth * 0.2,
                color: ThemeColor.primary,
              ),
              SizedBox(height: screenHeight * 0.03),
              Text(
                '기존 사업장에 접근 요청',
                style: TextStyle(
                  fontSize: screenWidth * 0.05,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: screenHeight * 0.04),
              TextFormField(
                controller: _businessPlaceIdController,
                decoration: InputDecoration(
                  labelText: '사업장 ID',
                  hintText: '접근하려는 사업장의 ID를 입력하세요',
                  prefixIcon: const Icon(Icons.business),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(screenWidth * 0.03),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '사업장 ID를 입력해주세요';
                  }
                  return null;
                },
              ),
              SizedBox(height: screenHeight * 0.02),
              DropdownButtonFormField<Role>(
                value: _selectedRole,
                decoration: InputDecoration(
                  labelText: '요청할 권한',
                  prefixIcon: const Icon(Icons.admin_panel_settings),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(screenWidth * 0.03),
                  ),
                ),
                items: [Role.MANAGER, Role.STAFF].map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Text(role == Role.MANAGER ? '매니저' : '스태프'),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedRole = value);
                  }
                },
              ),
              SizedBox(height: screenHeight * 0.03),
              Container(
                padding: EdgeInsets.all(screenWidth * 0.04),
                decoration: BoxDecoration(
                  color: ThemeColor.primarySurface,
                  borderRadius: BorderRadius.circular(screenWidth * 0.03),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '안내사항',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: screenHeight * 0.01),
                    const Text('• 사업장 주인만 OWNER 권한을 가질 수 있습니다'),
                    const Text('• 요청 후 사업장 주인의 승인이 필요합니다'),
                    const Text('• 승인되면 해당 사업장에 접근할 수 있습니다'),
                  ],
                ),
              ),
              SizedBox(height: screenHeight * 0.04),
              SizedBox(
                height: screenHeight * 0.06,
                child: CustomButton(
                  onPressed: _isLoading ? null : _requestAccess,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(screenWidth * 0.03),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          '접근 요청 보내기',
                          style: TextStyle(fontSize: screenWidth * 0.04),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _businessPlaceIdController.dispose();
    super.dispose();
  }
}
