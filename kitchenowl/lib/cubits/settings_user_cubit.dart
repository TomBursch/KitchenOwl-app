// ignore_for_file: use_build_context_synchronously

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kitchenowl/cubits/auth_cubit.dart';
import 'package:kitchenowl/enums/update_enum.dart';
import 'package:kitchenowl/helpers/named_bytearray.dart';
import 'package:kitchenowl/models/token.dart';
import 'package:kitchenowl/models/user.dart';
import 'package:kitchenowl/services/api/api_service.dart';

class SettingsUserCubit extends Cubit<SettingsUserState> {
  final int? userId;
  SettingsUserCubit(this.userId, [User? initialUserData])
      : super(SettingsUserState(user: initialUserData)) {
    refresh();
  }

  Future<void> refresh() async {
    User? user;
    user = userId != null
        ? await ApiService.getInstance().getUserById(userId!)
        : await ApiService.getInstance().getUser();
    emit(state.copyWith(user: user, setAdmin: user?.serverAdmin));
  }

  Future<void> updateUser({
    required BuildContext context,
    String? name,
    String? username,
    String? password,
    String? email,
  }) async {
    if (state.user == null) return;
    String? image;
    if (state.image != null) {
      image = state.image!.isEmpty
          ? ''
          : await ApiService.getInstance().uploadBytes(state.image!);
    }
    bool res = false;
    res = userId != null
        ? await ApiService.getInstance().updateUserById(
            userId!,
            name: name,
            password: password,
            email: email,
            image: image,
            admin: (state.setAdmin != state.user!.serverAdmin)
                ? state.setAdmin
                : null,
          )
        : await ApiService.getInstance().updateUser(
            name: name,
            password: password,
            email: email,
            image: image,
          );
    if (res) {
      emit(state.copyWith(updateState: UpdateEnum.updated));
      if (userId == null) {
        BlocProvider.of<AuthCubit>(context).refreshUser();
      }
      await refresh();
    }
  }

  void setAdmin(bool newAdmin) {
    emit(state.copyWith(setAdmin: newAdmin));
  }

  void setImage(NamedByteArray image) {
    emit(state.copyWith(image: image));
  }

  Future<String?> addLongLivedToken(String name) async {
    final token = await ApiService.getInstance().createLongLivedToken(name);
    if (token != null) refresh();

    return token;
  }

  Future<void> logout(Token token) async {
    final success = await ApiService.getInstance().logout(token.id);
    if (success) refresh();
  }

  Future<void> deleteLongLivedToken(Token token) async {
    final success = await ApiService.getInstance().deleteLongLivedToken(token);
    if (success) refresh();
  }

  Future<bool> deleteUser() async {
    if (state.user != null) {
      return ApiService.getInstance()
          .deleteUser(userId != null ? state.user! : null);
    }

    return false;
  }

  Future<bool> resendVerificationMail() {
    return ApiService.getInstance().resendVerificationMail();
  }
}

class SettingsUserState extends Equatable {
  final User? user;

  final NamedByteArray? image;
  final bool setAdmin;
  final UpdateEnum updateState;

  const SettingsUserState({
    this.user,
    this.setAdmin = false,
    this.updateState = UpdateEnum.unchanged,
    this.image,
  });

  @override
  List<Object?> get props => [user, setAdmin, updateState, image];

  SettingsUserState copyWith({
    User? user,
    bool? setAdmin,
    UpdateEnum? updateState,
    NamedByteArray? image,
  }) =>
      SettingsUserState(
        user: user ?? this.user,
        setAdmin: setAdmin ?? this.setAdmin,
        updateState: updateState ?? this.updateState,
        image: image ?? this.image,
      );
}
