import 'dart:convert';

import 'package:kitchenowl/models/user.dart';
import 'package:kitchenowl/services/api/api_service.dart';

extension UserApi on ApiService {
  static const baseRoute = '/user';

  Future<User?> getUser() async {
    if (!isAuthenticated()) return null;
    final res = await get(baseRoute);
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);

      return User.fromJson(body);
    }

    return null;
  }

  Future<User?> getUserById(int userId) async {
    if (!isAuthenticated()) return null;
    final res = await get('$baseRoute/$userId');
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);

      return User.fromJson(body);
    }

    return null;
  }

  Future<List<User>?> getAllUsers() async {
    if (!isAuthenticated()) return null;
    final res = await get('$baseRoute/all');
    if (res.statusCode == 200) {
      final body = List.from(jsonDecode(res.body));

      return body.map((e) => User.fromJson(e)).toList();
    }

    return null;
  }

  Future<bool> updateUser({
    String? image,
    String? name,
    String? password,
    String? email,
  }) async {
    if (!isAuthenticated()) return false;

    final body = {
      if (name != null) 'name': name,
      if (password != null) 'password': password,
      if (email != null) 'email': email,
      if (image != null) 'photo': image,
    };

    final res = await post(baseRoute, jsonEncode(body));

    return res.statusCode == 200;
  }

  Future<bool> updateUserById(
    int userId, {
    String? image,
    String? name,
    String? password,
    String? email,
    bool? admin,
  }) async {
    if (!isAuthenticated()) return false;

    final body = {
      if (name != null) 'name': name,
      if (password != null) 'password': password,
      if (email != null) 'email': email,
      if (admin != null) 'admin': admin,
      if (image != null) 'photo': image,
    };

    final res = await post('$baseRoute/$userId', jsonEncode(body));

    return res.statusCode == 200;
  }

  Future<bool> createUser(String username, String name, String password) async {
    final res = await post(
      '$baseRoute/new',
      jsonEncode({
        'username': username,
        'name': name,
        'password': password,
      }),
    );

    return res.statusCode == 200;
  }

  Future<bool> deleteUser([User? user]) async {
    final res = user != null
        ? await delete('$baseRoute/${user.id}')
        : await delete(baseRoute);

    return res.statusCode == 200;
  }

  Future<List<User>?> searchUser(String query) async {
    final res = await get('$baseRoute/search?query=$query');
    if (res.statusCode != 200) return null;

    final body = List.from(jsonDecode(res.body));

    return body.map((e) => User.fromJson(e)).toList();
  }

  Future<bool> resendVerificationMail() async {
    final res = await post('$baseRoute/resend-verification-mail', null);
    return res.statusCode == 200;
  }

  Future<bool> confirmMail(String token) async {
    final res =
        await post('$baseRoute/confirm-mail', jsonEncode({"token": token}));
    return res.statusCode == 200;
  }

  Future<bool> resetPassword(String token, String password) async {
    final res = await post(
        '$baseRoute/reset-password',
        jsonEncode({
          "token": token,
          "password": password,
        }));
    return res.statusCode == 200;
  }

  Future<bool> forgotPassword(String email) async {
    final res =
        await post('$baseRoute/forgot-password', jsonEncode({"email": email}));
    return res.statusCode == 200;
  }
}
