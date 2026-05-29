import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../routes/app_routes.dart';

class AuthGuard extends ChangeNotifier {
  final Ref _ref;

  AuthGuard(this._ref) {
    _ref.listen(authStateProvider, (_, __) => notifyListeners());
  }

  String? redirect(_, GoRouterState state) {
    final authState = _ref.read(authStateProvider);
    final isLoggedIn = authState.valueOrNull != null;
    final isLoginPage = state.matchedLocation == AppRoutes.login;

    if (!isLoggedIn && !isLoginPage) return AppRoutes.login;
    if (isLoggedIn && isLoginPage) return AppRoutes.dashboard;
    return null;
  }
}
