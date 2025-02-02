import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kitchenowl/config.dart';
import 'package:kitchenowl/models/user.dart';
import 'package:kitchenowl/services/api/api_service.dart';
import 'package:kitchenowl/services/storage/mem_storage.dart';
import 'package:kitchenowl/services/storage/storage.dart';
import 'package:kitchenowl/services/transaction_handler.dart';
import 'package:kitchenowl/platform/dart_html/dart_html.dart' as html;

class AuthCubit extends Cubit<AuthState> {
  bool _forcedOfflineMode = false;

  AuthCubit() : super(const Loading()) {
    ApiService.getInstance().addListener(updateState);
    ApiService.setTokenRotationHandler((token) =>
        SecureStorage.getInstance().write(key: 'TOKEN', value: token));
    if (kIsWeb) {
      ApiService.setTokenBeforeReauthHandler((token) {
        if (token == null) return Future.value(token);

        return SecureStorage.getInstance()
            .read(key: 'TOKEN')
            .then((value) => value ?? token);
      });
    }
    _loadForcedOfflineMode();
    setup();
  }

  void setup() async {
    String? url;
    url = kIsWeb
        ? kDebugMode
            ? "http://localhost:5000"
            : html.getBaseUri()
        : await PreferenceStorage.getInstance().read(key: 'URL') ??
            Config.defaultServer;
    final token = await SecureStorage.getInstance().read(key: 'TOKEN');
    _newConnection(url, token: token, storeData: false);
  }

  Future<void> updateState() async {
    switch (ApiService.getInstance().connectionStatus) {
      case Connection.authenticated:
        if (!_forcedOfflineMode) {
          final user = (await ApiService.getInstance().getUser())!;
          MemStorage.getInstance().writeUser(user);
          TransactionHandler.getInstance().runOpenTransactions();
          emit(Authenticated(user));
        } else {
          await _caseDisconnected();
        }
        break;
      case Connection.disconnected:
        await _caseDisconnected();
        break;
      case Connection.connected:
        if (state is AuthenticatedOffline) {
          // Try to authenticate, only stay offline if it fails
          try {
            if (await ApiService.getInstance().refreshAuth()) {
              final user = (await ApiService.getInstance().getUser())!;
              emit(Authenticated(user));
            }
          } catch (_) {
            // Stay offline if auth fails
          }
          return;
        }
        if (await ApiService.getInstance().isOnboarding()) {
          emit(const Onboarding());
        } else {
          emit(const Unauthenticated());
        }
        break;
      case Connection.unsupportedBackend:
        await _caseUnsupported(true);
        break;
      case Connection.unsupportedFrontend:
        await _caseUnsupported(false);
        break;
      case Connection.undefined:
        emit(const Loading());
        break;
    }
    _forcedOfflineMode = state.forcedOfflineMode;
  }

  Future<void> _caseDisconnected() async {
    if (kIsWeb || ApiService.getInstance().baseUrl.isNotEmpty) {
      final user = await MemStorage.getInstance().readUser();
      if (user != null) {
        emit(AuthenticatedOffline(user, _forcedOfflineMode));
      } else {
        emit(const Unreachable());
      }
    } else {
      emit(const Setup());
    }
  }

  Future<void> _caseUnsupported(bool unsupportedBackend) async {
    final user = await MemStorage.getInstance().readUser();
    if (_forcedOfflineMode &&
        (kIsWeb || ApiService.getInstance().baseUrl.isNotEmpty)) {
      if (user != null) {
        emit(AuthenticatedOffline(user, true));
      } else {
        emit(Unsupported(unsupportedBackend));
      }
    } else {
      emit(Unsupported(unsupportedBackend, user != null));
    }
  }

  void setupServer(String url) async {
    if (kIsWeb) return;
    emit(const Loading());
    if (!url.contains("http")) url = "https://" + url;

    _newConnection(url);
  }

  void setupDefaultServer() async {
    if (kIsWeb) return;
    emit(const Loading());
    _newConnection(Config.defaultServer, storeData: false);
  }

  User? getUser() {
    if (state is Authenticated) {
      return (state as Authenticated).user;
    }

    return null;
  }

  Future<void> refresh() {
    // Don't refresh if we're in forced offline mode
    if (_forcedOfflineMode) {
      return Future.value();
    }
    return ApiService.getInstance().refresh();
  }

  Future<void> refreshUser() async {
    if (state is Authenticated) {
      if (state is AuthenticatedOffline) {
        final user = await MemStorage.getInstance().readUser();
        if (user != null) {
          emit(AuthenticatedOffline(user, state.forcedOfflineMode));
        } else {
          emit(const Unreachable());
        }
      } else {
        emit(Authenticated((await ApiService.getInstance().getUser())!));
      }
    }
  }

  Future<void> onboard({
    required String username,
    required String name,
    required String password,
    Function()? wrongCredentialsCallback,
    Function()? correctCredentialsCallback,
  }) async {
    emit(const Loading());
    if (await ApiService.getInstance().isOnboarding()) {
      final token =
          await ApiService.getInstance().onboarding(username, name, password);
      if (token != null && ApiService.getInstance().isAuthenticated()) {
        await SecureStorage.getInstance().write(key: 'TOKEN', value: token);
        await this.stream.any((s) => s is Authenticated);
        if (correctCredentialsCallback != null) {
          correctCredentialsCallback();
        }
      } else {
        await updateState();
        if (wrongCredentialsCallback != null) {
          wrongCredentialsCallback();
        }
      }
    }
  }

  Future<void> signup({
    required String username,
    required String name,
    required String password,
    required String email,
    Function(String?)? wrongCredentialsCallback,
    Function()? correctCredentialsCallback,
  }) async {
    emit(const Loading());
    final (token, msg) = await ApiService.getInstance().signup(
      username: username,
      name: name,
      email: email,
      password: password,
    );
    if (token != null && ApiService.getInstance().isAuthenticated()) {
      await SecureStorage.getInstance().write(key: 'TOKEN', value: token);
      await this.stream.any((s) => s is Authenticated);
      if (correctCredentialsCallback != null) {
        correctCredentialsCallback();
      }
    } else {
      await updateState();
      if (ApiService.getInstance().connectionStatus == Connection.connected &&
          wrongCredentialsCallback != null) {
        wrongCredentialsCallback(msg);
      }
    }
  }

  Future<void> login(
    String username,
    String password, [
    Function? wrongCredentialsCallback,
  ]) async {
    emit(const Loading());
    final token = await ApiService.getInstance().login(username, password);
    if (token != null && ApiService.getInstance().isAuthenticated()) {
      await SecureStorage.getInstance().write(key: 'TOKEN', value: token);
    } else {
      await updateState();
      if (ApiService.getInstance().connectionStatus == Connection.connected &&
          wrongCredentialsCallback != null) {
        wrongCredentialsCallback();
      }
    }
  }

  Future<void> loginOIDC(
    String state,
    String code, [
    Function(String?)? feedbackCallback,
  ]) async {
    emit(const Loading());
    (String?, String?) res =
        await ApiService.getInstance().loginOIDC(state, code);
    final token = res.$1;
    if (token != null && ApiService.getInstance().isAuthenticated()) {
      await SecureStorage.getInstance().write(key: 'TOKEN', value: token);
    } else if (ApiService.getInstance().isAuthenticated()) {
      if (feedbackCallback != null) feedbackCallback(res.$2);
    } else {
      await updateState();
      if (ApiService.getInstance().connectionStatus == Connection.connected &&
          feedbackCallback != null) {
        feedbackCallback(res.$2);
      }
    }
  }

  Future<void> logout() async {
    emit(const Loading());
    await SecureStorage.getInstance().delete(key: 'TOKEN');
    await MemStorage.getInstance().clearAll();
    await PreferenceStorage.getInstance().delete(key: "lastHouseholdId");
    await ApiService.getInstance().logout();
    if (ApiService.getInstance().connectionStatus == Connection.disconnected) {
      emit(const Unreachable());
    }
    refresh();
  }

  void removeServer() async {
    if (kIsWeb) return logout(); //Cannot remove server on WEB

    emit(const Loading());
    await PreferenceStorage.getInstance().delete(key: 'URL');
    await SecureStorage.getInstance().delete(key: 'TOKEN');
    await MemStorage.getInstance().clearAll();
    ApiService.getInstance().dispose();
    refresh();
  }

  Future<void> _newConnection(
    String? url, {
    String? token,
    bool storeData = true,
  }) async {
    if (url == null || url.isEmpty) return;
    await ApiService.connectTo(url, refreshToken: token);
    if (storeData && ApiService.getInstance().isConnected()) {
      if (!kIsWeb) {
        await PreferenceStorage.getInstance().write(key: 'URL', value: url);
      }
      if (token != null && token.isNotEmpty) {
        await SecureStorage.getInstance().write(key: 'TOKEN', value: token);
      }
    }
  }

  Future<void> _loadForcedOfflineMode() async {
    _forcedOfflineMode = await PreferenceStorage.getInstance().readBool(key: 'forcedOfflineMode') ?? false;
  }

  void setForcedOfflineMode(bool forcedOfflineMode) async {
    _forcedOfflineMode = forcedOfflineMode;
    await PreferenceStorage.getInstance().writeBool(key: 'forcedOfflineMode', value: forcedOfflineMode);
    // Always update state to reflect the change immediately
    updateState();
    if (!forcedOfflineMode) {
      // When disabling offline mode, also do a full refresh to reconnect
      refresh();
    }
  }
}

abstract class AuthState extends Equatable {
  const AuthState();

  bool get forcedOfflineMode => false;
}

class Authenticated extends AuthState {
  final User user;

  const Authenticated(this.user);

  @override
  List<Object?> get props => [user];
}

class AuthenticatedOffline extends Authenticated {
  final bool _forcedOfflineMode;

  const AuthenticatedOffline(super.user, this._forcedOfflineMode);

  @override
  List<Object?> get props => [user, _forcedOfflineMode];

  @override
  bool get forcedOfflineMode => _forcedOfflineMode;
}

class Onboarding extends AuthState {
  const Onboarding();

  @override
  List<Object?> get props => ["Onboarding"];
}

class Unauthenticated extends AuthState {
  const Unauthenticated();

  @override
  List<Object?> get props => ["Setup"];
}

class Setup extends AuthState {
  const Setup();

  @override
  List<Object?> get props => ["Unauthenticated"];
}

class Loading extends AuthState {
  const Loading();

  @override
  List<Object?> get props => ["Initial"];
}

class Unreachable extends AuthState {
  const Unreachable();

  @override
  List<Object?> get props => ["Unreachable"];
}

class Unsupported extends AuthState {
  final bool unsupportedBackend;
  final bool canForceOfflineMode;

  const Unsupported(
    this.unsupportedBackend, [
    this.canForceOfflineMode = false,
  ]);

  @override
  List<Object?> get props =>
      ["Unsupported", unsupportedBackend, canForceOfflineMode];
}
