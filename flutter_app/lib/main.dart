import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_colors.dart';
import 'ui/layout/main_layout.dart';
import 'ui/pages/login_page.dart';
import 'services/api_service.dart';
import 'services/auth_session.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authSession = AuthSession();
  await authSession.init();
  ApiService.onUnauthorized = () {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  };
  runApp(DocuSyncApp(authSession: authSession));
}

class DocuSyncApp extends StatelessWidget {
  final AuthSession authSession;

  const DocuSyncApp({super.key, required this.authSession});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthSession>.value(
      value: authSession,
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'DocuSync',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: AppColors.background,
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            secondary: AppColors.primaryLight,
            surface: AppColors.surface,
            onSurface: AppColors.textPrimary,
          ),
          useMaterial3: true,
        ),
        home: Consumer<AuthSession>(
          builder: (context, session, _) {
            return session.token != null ? const MainLayout() : const LoginPage();
          },
        ),
      ),
    );
  }
}
