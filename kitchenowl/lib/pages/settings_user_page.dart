import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kitchenowl/app.dart';
import 'package:kitchenowl/cubits/auth_cubit.dart';
import 'package:kitchenowl/cubits/server_info_cubit.dart';
import 'package:kitchenowl/cubits/settings_user_cubit.dart';
import 'package:kitchenowl/enums/update_enum.dart';
import 'package:kitchenowl/kitchenowl.dart';
import 'package:kitchenowl/models/user.dart';
import 'package:kitchenowl/pages/settings_user_email_page.dart';
import 'package:kitchenowl/pages/settings_user_linked_accounts_page.dart';
import 'package:kitchenowl/pages/settings_user_password_page.dart';
import 'package:kitchenowl/pages/settings_user_sessions_page.dart';
import 'package:kitchenowl/widgets/user_image_selector.dart';

class SettingsUserPage extends StatefulWidget {
  final User? user;
  const SettingsUserPage({super.key, this.user});

  @override
  _SettingsUserPageState createState() => _SettingsUserPageState();
}

enum _UserAction {
  delete;
}

class _SettingsUserPageState extends State<SettingsUserPage> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  late SettingsUserCubit cubit;

  @override
  void initState() {
    super.initState();
    cubit = SettingsUserCubit(
      widget.user?.id,
      widget.user ?? context.read<AuthCubit>().getUser(),
    );
    final user = widget.user ?? BlocProvider.of<AuthCubit>(context).getUser();
    if (user != null) {
      usernameController.text = "@${user.username}";
      emailController.text = user.email ?? "";
      nameController.text = user.name;
    }
  }

  @override
  void dispose() {
    cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.of(context).pop(cubit.state.updateState);
      },
      child: BlocListener<SettingsUserCubit, SettingsUserState>(
        bloc: cubit,
        listenWhen: (previous, current) => previous.user != current.user,
        listener: (context, state) {
          if (state.user != null) {
            usernameController.text = "@${state.user?.username ?? ''}";
            emailController.text = state.user?.email ?? '';
            nameController.text = state.user?.name ?? '';
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(cubit.userId == null
                ? AppLocalizations.of(context)!.profile
                : AppLocalizations.of(context)!.user),
            leading: BackButton(
              onPressed: () =>
                  Navigator.of(context).pop(cubit.state.updateState),
            ),
            actions: [
              PopupMenuButton(
                itemBuilder: (BuildContext context) =>
                    <PopupMenuEntry<_UserAction>>[
                  PopupMenuItem<_UserAction>(
                    value: _UserAction.delete,
                    child: Text(cubit.userId == null
                        ? AppLocalizations.of(context)!.accountDelete
                        : AppLocalizations.of(context)!.userDelete),
                  ),
                ],
                onSelected: (value) async {
                  switch (value) {
                    case _UserAction.delete:
                      final confirm = await askForConfirmation(
                        context: context,
                        title: Text(
                          cubit.userId == null
                              ? AppLocalizations.of(context)!.accountDelete
                              : AppLocalizations.of(context)!.userDelete,
                        ),
                        content: Text(cubit.userId == null
                            ? AppLocalizations.of(context)!
                                .accountDeleteConfirmation
                            : AppLocalizations.of(context)!
                                .userDeleteConfirmation(
                                nameController.text,
                              )),
                      );
                      if (confirm) {
                        if (await cubit.deleteUser() && mounted) {
                          if (cubit.userId == null) {
                            BlocProvider.of<AuthCubit>(context).logout();
                          }
                          Navigator.of(context).pop(UpdateEnum.deleted);
                        }
                      }
                      break;
                  }
                },
              ),
            ],
          ),
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints.expand(width: 600),
              child: AutofillGroup(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    BlocBuilder<SettingsUserCubit, SettingsUserState>(
                      bloc: cubit,
                      builder: (context, state) => Center(
                        child: UserImageSelector(
                          name: nameController.text,
                          originalImage: state.user?.image,
                          image: state.image,
                          tooltip: AppLocalizations.of(context)!.imageSelect,
                          setImage: cubit.setImage,
                        ),
                      ),
                    ),
                    TextField(
                      controller: usernameController,
                      enabled: false,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.username,
                      ),
                    ),
                    BlocBuilder<SettingsUserCubit, SettingsUserState>(
                      bloc: cubit,
                      buildWhen: (previous, current) =>
                          previous.user?.emailVerified !=
                          current.user?.emailVerified,
                      builder: (context, state) => TextField(
                        controller: emailController,
                        enabled: false,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!.email,
                          suffix: (state.user?.email?.isEmpty ?? true) ||
                                  (state.user?.emailVerified ?? false)
                              ? null
                              : Text(
                                  AppLocalizations.of(context)!
                                      .emailNotVerified,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color:
                                            Theme.of(context).colorScheme.error,
                                      ),
                                ),
                        ),
                      ),
                    ),
                    TextField(
                      controller: nameController,
                      textInputAction: TextInputAction.done,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.name,
                      ),
                    ),
                    if (cubit.userId == null && App.isDefaultServer) ...[
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(context)!.accountCreateHint,
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.color
                                      ?.withAlpha(204),
                                ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    if (cubit.userId != null)
                      BlocBuilder<SettingsUserCubit, SettingsUserState>(
                        bloc: cubit,
                        builder: (context, state) {
                          return ListTile(
                            title: Text(AppLocalizations.of(context)!.admin),
                            leading:
                                const Icon(Icons.admin_panel_settings_rounded),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 0),
                            trailing: KitchenOwlSwitch(
                              value: state.setAdmin,
                              onChanged: cubit.setAdmin,
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: LoadingElevatedButton(
                        onPressed: () => cubit.updateUser(
                          context: context,
                          name: nameController.text,
                        ),
                        child: Text(AppLocalizations.of(context)!.save),
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      title: Text(AppLocalizations.of(context)!.passwordSave),
                      leading: const Icon(Icons.lock_rounded),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded),
                      contentPadding: EdgeInsets.zero,
                      onTap: () async {
                        final res = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => SettingsUserPasswordPage(),
                          ),
                        );
                        if (res != null) {
                          cubit.updateUser(
                            context: context,
                            password: res,
                          );
                        }
                      },
                    ),
                    ListTile(
                      title: Text(AppLocalizations.of(context)!.emailUpdate),
                      leading: const Icon(Icons.email_rounded),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded),
                      contentPadding: EdgeInsets.zero,
                      onTap: () async {
                        final res = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => SettingsUserEmailPage(),
                          ),
                        );
                        if (res != null) {
                          cubit.updateUser(
                            context: context,
                            email: res,
                          );
                        }
                      },
                    ),
                    if (!App.isOffline)
                      BlocBuilder<SettingsUserCubit, SettingsUserState>(
                          bloc: cubit,
                          buildWhen: (previous, current) =>
                              previous.user?.emailVerified !=
                              current.user?.emailVerified,
                          builder: (context, state) {
                            if ((state.user?.email?.isEmpty ?? true) ||
                                (state.user?.emailVerified ?? false)) {
                              return const SizedBox();
                            }
                            return LoadingListTile(
                              title: Text(AppLocalizations.of(context)!
                                  .emailResendVerification),
                              leading:
                                  const Icon(Icons.mark_email_read_rounded),
                              trailing:
                                  const Icon(Icons.arrow_forward_ios_rounded),
                              contentPadding: EdgeInsets.zero,
                              onTap: () async {
                                String message =
                                    await cubit.resendVerificationMail()
                                        ? AppLocalizations.of(context)!.done
                                        : AppLocalizations.of(context)!.error;

                                showSnackbar(
                                  context: context,
                                  content: Text(message),
                                );
                              },
                            );
                          }),
                    if (cubit.userId == null &&
                        App.serverInfo is ConnectedServerInfoState &&
                        (App.serverInfo as ConnectedServerInfoState)
                            .oidcProvider
                            .isNotEmpty)
                      ListTile(
                        title:
                            Text(AppLocalizations.of(context)!.accountsLinked),
                        leading: const Icon(Icons.link_rounded),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded),
                        contentPadding: EdgeInsets.zero,
                        onTap: () async {
                          final res = await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => SettingsLinkedAccountsPage(
                                cubit: cubit,
                                oidcProvider:
                                    (App.serverInfo as ConnectedServerInfoState)
                                        .oidcProvider,
                              ),
                            ),
                          );
                          if (res != null) {
                            cubit.updateUser(
                              context: context,
                              password: res,
                            );
                          }
                        },
                      ),
                    if (cubit.userId == null)
                      ListTile(
                        title: Text(AppLocalizations.of(context)!.sessions),
                        leading: const Icon(Icons.devices_rounded),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded),
                        contentPadding: EdgeInsets.zero,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => SettingsUserSessionsPage(
                              cubit: cubit,
                            ),
                          ),
                        ),
                      ),
                    SizedBox(height: MediaQuery.paddingOf(context).bottom),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
