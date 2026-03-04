import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/auth_service.dart';
import '../../routes/app_routes.dart';

class AuthMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    // Check if user is logged in
    final isLoggedIn = AuthService.to.isLoggedIn.value;

    // If not logged in and trying to access a protected route
    if (!isLoggedIn) {
      print('AuthMiddleware: User not logged in, redirecting to login');
      return const RouteSettings(name: Routes.login);
    }

    return null;
  }
}
