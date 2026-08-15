import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0F172A),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF3B82F6),
            surface: Color(0xFF1E293B),
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
