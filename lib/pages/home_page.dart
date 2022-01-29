import 'package:animations/animations.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kitchenowl/app.dart';
import 'package:kitchenowl/cubits/auth_cubit.dart';
import 'package:kitchenowl/cubits/expense_list_cubit.dart';
import 'package:kitchenowl/cubits/planner_cubit.dart';
import 'package:kitchenowl/cubits/recipe_list_cubit.dart';
import 'package:kitchenowl/cubits/settings_cubit.dart';
import 'package:kitchenowl/cubits/shoppinglist_cubit.dart';
import 'package:kitchenowl/enums/update_enum.dart';
import 'package:kitchenowl/pages/expense_add_update_page.dart';
import 'package:kitchenowl/pages/recipe_add_update_page.dart';
import 'package:kitchenowl/pages/home_page/home_page.dart';
import 'package:kitchenowl/kitchenowl.dart';
import 'package:kitchenowl/widgets/action_widget.dart';
import 'package:kitchenowl/widgets/expandable_fab.dart';
import 'package:kitchenowl/widgets/text_dialog.dart';
import 'package:responsive_builder/responsive_builder.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ShoppinglistCubit shoppingListCubit = ShoppinglistCubit();
  final RecipeListCubit recipeListCubit = RecipeListCubit();
  final PlannerCubit plannerCubit = PlannerCubit();
  final ExpenseListCubit expenseCubit = ExpenseListCubit();

  late List<Widget> pages;
  int _selectedIndex = 0;
  List<_HomePageMenu> _homePageMenuItems = [];

  @override
  void initState() {
    super.initState();
    pages = [
      BlocProvider.value(
        value: shoppingListCubit,
        child: const ShoppinglistPage(),
      ),
      BlocProvider.value(value: recipeListCubit, child: const RecipeListPage()),
      BlocProvider.value(value: plannerCubit, child: const PlannerPage()),
      BlocProvider.value(value: expenseCubit, child: const ExpenseListPage()),
      const ProfilePage(),
    ];
  }

  @override
  void dispose() {
    shoppingListCubit.close();
    recipeListCubit.close();
    plannerCubit.close();
    expenseCubit.close();
    super.dispose();
  }

  void _onItemTapped(int i, List<_HomePageMenu> homePageMenuItems) {
    if (homePageMenuItems[i].onTap != null) {
      homePageMenuItems[i].onTap!(_selectedIndex == i);
    }
    setState(() {
      _selectedIndex = i;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        return BlocConsumer<SettingsCubit, SettingsState>(
          listenWhen: (prev, curr) =>
              prev.serverSettings != curr.serverSettings,
          listener: (context, state) {
            final offset =
                (state.serverSettings.featurePlanner ?? false ? 0 : 1) +
                    (state.serverSettings.featureExpenses ?? false ? 0 : 1);
            _selectedIndex = (_selectedIndex *
                    (pages.length - offset) /
                    _homePageMenuItems.length)
                .clamp(0, pages.length - offset)
                .round();
          },
          builder: (context, state) {
            final bool isOffline = App.isOffline;

            _homePageMenuItems = [
              _HomePageMenu(
                page: pages[0],
                icon: Icons.shopping_bag_outlined,
                label: AppLocalizations.of(context)!.shoppingList,
                onTap: (equals) {
                  if (equals) {
                    shoppingListCubit.refresh("");
                  } else {
                    shoppingListCubit.refresh();
                  }
                },
              ),
              _HomePageMenu(
                page: pages[1],
                icon: Icons.receipt,
                label: AppLocalizations.of(context)!.recipes,
                onTap: (equals) {
                  if (equals) {
                    recipeListCubit.refresh("");
                  } else {
                    recipeListCubit.refresh();
                  }
                },
                floatingActionButton: !isOffline
                    ? ExpandableFab(
                        distance: 70,
                        openIcon: const Icon(Icons.add),
                        children: [
                          ActionButton(
                            onPressed: () async {
                              final res = await Navigator.of(context)
                                  .push<UpdateEnum>(MaterialPageRoute(
                                      builder: (context) =>
                                          const AddUpdateRecipePage()));
                              if (res == UpdateEnum.updated) {
                                recipeListCubit.refresh();
                              }
                            },
                            icon: const Icon(Icons.add),
                          ),
                          ActionButton(
                              onPressed: () async {
                                final url = await showDialog<String>(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return TextDialog(
                                        title: AppLocalizations.of(context)!
                                            .addTag,
                                        doneText:
                                            AppLocalizations.of(context)!.add,
                                        hintText:
                                            AppLocalizations.of(context)!.name,
                                      );
                                    });
                                if (url == null || url.isEmpty) return;

                                final res = await Navigator.of(context)
                                    .push<UpdateEnum>(MaterialPageRoute(
                                        builder: (context) =>
                                            const AddUpdateRecipePage()));
                                if (res == UpdateEnum.updated) {
                                  recipeListCubit.refresh();
                                }
                              },
                              icon: const Icon(Icons.link_rounded)),
                        ],
                      )
                    : null,
              ),
              if (state.serverSettings.featurePlanner ?? false)
                _HomePageMenu(
                  page: pages[2],
                  icon: Icons.calendar_today_rounded,
                  label: AppLocalizations.of(context)!.planner,
                  onTap: (equals) {
                    plannerCubit.refresh();
                  },
                ),
              if (state.serverSettings.featureExpenses ?? false)
                _HomePageMenu(
                  page: pages[3],
                  icon: Icons.account_balance_rounded,
                  label: AppLocalizations.of(context)!.balances,
                  onTap: (equals) {
                    expenseCubit.refresh();
                  },
                  floatingActionButton: !isOffline
                      ? OpenContainer(
                          transitionType: ContainerTransitionType.fade,
                          openBuilder: (BuildContext context, VoidCallback _) {
                            return AddUpdateExpensePage(
                              users: expenseCubit.state.users,
                            );
                          },
                          openColor: Theme.of(context).scaffoldBackgroundColor,
                          onClosed: (data) {
                            if (data == UpdateEnum.updated) {
                              expenseCubit.refresh();
                            }
                          },
                          closedElevation: 6.0,
                          closedShape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(
                              Radius.circular(56 / 2),
                            ),
                          ),
                          closedColor: Theme.of(context).colorScheme.secondary,
                          closedBuilder: (
                            BuildContext context,
                            VoidCallback openContainer,
                          ) {
                            return SizedBox(
                              height: 56,
                              width: 56,
                              child: Center(
                                child: Icon(
                                  Icons.add,
                                  color:
                                      Theme.of(context).colorScheme.onSecondary,
                                ),
                              ),
                            );
                          },
                        )
                      : null,
                ),
              _HomePageMenu(
                page: pages[4],
                icon: isOffline ? Icons.cloud_off_rounded : Icons.person,
                label: AppLocalizations.of(context)!.profile,
              ),
            ];

            Widget body = PageTransitionSwitcher(
              transitionBuilder: (
                Widget child,
                Animation<double> animation,
                Animation<double> secondaryAnimation,
              ) {
                return FadeThroughTransition(
                  animation: animation,
                  secondaryAnimation: secondaryAnimation,
                  child: child,
                );
              },
              child: Align(
                key: ValueKey<int>(_selectedIndex),
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints.expand(width: 1600),
                  child: _homePageMenuItems[_selectedIndex].page,
                ),
              ),
            );

            final bool useBottomNavigationBar = getValueForScreenType<bool>(
              context: context,
              mobile: true,
              tablet: false,
              desktop: false,
            );

            if (!useBottomNavigationBar) {
              body = Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 200,
                    child: ListView(children: [
                      // Image.asset('assets/images/header.png'),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          AppLocalizations.of(context)!.appTitle,
                          style: Theme.of(context).textTheme.headline5,
                        ),
                      ),
                      const Divider(),
                      ..._homePageMenuItems
                          .asMap()
                          .entries
                          .map(
                            (e) => ListTile(
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.horizontal(
                                  right: Radius.circular(5),
                                ),
                              ),
                              tileColor: _selectedIndex == e.key
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                              title: Text(
                                e.value.label,
                                style: TextStyle(
                                  color: _selectedIndex == e.key
                                      ? Colors.white
                                      : null,
                                ),
                              ),
                              leading: Icon(
                                e.value.icon,
                                color: _selectedIndex == e.key
                                    ? Colors.white
                                    : null,
                              ),
                              onTap: () =>
                                  _onItemTapped(e.key, _homePageMenuItems),
                            ),
                          )
                          .toList(),
                    ]),
                  ),
                  const VerticalDivider(),
                  Expanded(child: body),
                ],
              );
            }

            return Scaffold(
              body: body,
              floatingActionButton:
                  _homePageMenuItems[_selectedIndex].floatingActionButton,
              bottomNavigationBar: useBottomNavigationBar
                  ? BottomNavigationBar(
                      showUnselectedLabels: false,
                      showSelectedLabels: true,
                      type: BottomNavigationBarType.fixed,
                      items: _homePageMenuItems
                          .map((e) => BottomNavigationBarItem(
                                icon: Icon(e.icon),
                                label: e.label,
                              ))
                          .toList(),
                      currentIndex: _selectedIndex,
                      onTap: (i) => _onItemTapped(i, _homePageMenuItems),
                    )
                  : null,
            );
          },
        );
      },
    );
  }
}

class _HomePageMenu extends Equatable {
  final Widget page;
  final IconData icon;
  final String label;
  final Widget? floatingActionButton;
  final Function(bool)? onTap;

  const _HomePageMenu({
    required this.page,
    required this.icon,
    required this.label,
    this.floatingActionButton,
    this.onTap,
  });

  @override
  List<Object?> get props => [];
}
