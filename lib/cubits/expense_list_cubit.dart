import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kitchenowl/enums/expenselist_sorting.dart';
import 'package:kitchenowl/models/expense.dart';
import 'package:kitchenowl/models/expense_category.dart';
import 'package:kitchenowl/models/household.dart';
import 'package:kitchenowl/services/storage/storage.dart';
import 'package:kitchenowl/services/transaction_handler.dart';
import 'package:kitchenowl/services/transactions/expense.dart';
import 'package:kitchenowl/services/transactions/household.dart';

class ExpenseListCubit extends Cubit<ExpenseListCubitState> {
  final Household household;
  Future<void>? _refreshThread;

  ExpenseListCubit(this.household)
      : super(LoadingExpenseListCubitState(household: household)) {
    PreferenceStorage.getInstance().readInt(key: 'expenseSorting').then((i) {
      if (i != null && state.sorting.index != i) {
        setSorting(
          ExpenselistSorting.values[i % ExpenselistSorting.values.length],
          false,
        );
      }
      refresh();
    });
  }

  Future<void> remove(Expense expense) async {
    await TransactionHandler.getInstance()
        .runTransaction(TransactionExpenseRemove(expense: expense));
    await refresh();
  }

  Future<void> add(Expense expense) async {
    await TransactionHandler.getInstance().runTransaction(TransactionExpenseAdd(
      household: household,
      expense: expense,
    ));
    await refresh();
  }

  Future<void> update(Expense expense) async {
    await TransactionHandler.getInstance()
        .runTransaction(TransactionExpenseUpdate(expense: expense));
    await refresh();
  }

  void incrementSorting() {
    setSorting(ExpenselistSorting
        .values[(state.sorting.index + 1) % ExpenselistSorting.values.length]);
  }

  void setSorting(ExpenselistSorting sorting, [bool savePreference = true]) {
    if (savePreference) {
      PreferenceStorage.getInstance()
          .writeInt(key: 'expenseSorting', value: sorting.index);
    }
    emit(state.copyWith(sorting: sorting));
    refresh();
  }

  Future<void> loadMore() async {
    if (state.allLoaded) return;

    final moreExpenses = TransactionHandler.getInstance()
        .runTransaction(TransactionExpenseGetMore(
      household: household,
      sorting: state.sorting,
      lastExpense: state.expenses.last,
    ));
    emit(state.copyWith(
      expenses: List.from(state.expenses + await moreExpenses),
      allLoaded: (await moreExpenses).length < 30,
    ));
  }

  Future<void> refresh() {
    _refreshThread ??= _refresh();

    return _refreshThread!;
  }

  Future<void> _refresh() async {
    final sorting = state.sorting;
    final fHousehold = TransactionHandler.getInstance()
        .runTransaction(TransactionHouseholdGet(household: household));
    final categories = TransactionHandler.getInstance()
        .runTransaction(TransactionExpenseCategoriesGet(household: household));
    final expenses = TransactionHandler.getInstance()
        .runTransaction(TransactionExpenseGetAll(
      household: household,
      sorting: sorting,
    ));

    Future<Map<int, double>>? categoryOverview;
    if (state.sorting == ExpenselistSorting.personal) {
      categoryOverview = TransactionHandler.getInstance()
          .runTransaction(TransactionExpenseGetOverview(
            household: household,
            sorting: state.sorting,
            months: 1,
          ))
          .then<Map<int, double>>((v) => v[0] ?? const {});
    }

    emit(ExpenseListCubitState(
      household: await fHousehold,
      expenses: await expenses,
      sorting: sorting,
      categories: await categories,
      categoryOverview: (await categoryOverview) ?? state.categoryOverview,
    ));
    _refreshThread = null;
  }
}

class ExpenseListCubitState extends Equatable {
  final Household household;
  final List<Expense> expenses;
  final ExpenselistSorting sorting;
  final List<ExpenseCategory> categories;
  final Map<int, double> categoryOverview;
  final bool allLoaded;

  const ExpenseListCubitState({
    required this.household,
    this.expenses = const [],
    this.sorting = ExpenselistSorting.all,
    this.allLoaded = false,
    this.categories = const [],
    this.categoryOverview = const {},
  });

  ExpenseListCubitState copyWith({
    Household? household,
    List<Expense>? expenses,
    ExpenselistSorting? sorting,
    bool? allLoaded,
    List<ExpenseCategory>? categories,
    Map<int, double>? categoryOverview,
  }) =>
      ExpenseListCubitState(
        household: household ?? this.household,
        expenses: expenses ?? this.expenses,
        sorting: sorting ?? this.sorting,
        allLoaded: allLoaded ?? this.allLoaded,
        categories: categories ?? this.categories,
        categoryOverview: categoryOverview ?? this.categoryOverview,
      );

  @override
  List<Object?> get props =>
      <Object>[sorting, categoryOverview, household] + categories + expenses;
}

class LoadingExpenseListCubitState extends ExpenseListCubitState {
  const LoadingExpenseListCubitState({required super.household, super.sorting});

  @override
  // ignore: long-parameter-list
  ExpenseListCubitState copyWith({
    Household? household,
    List<Expense>? expenses,
    ExpenselistSorting? sorting,
    bool? allLoaded,
    List<ExpenseCategory>? categories,
    Map<int, double>? categoryOverview,
  }) =>
      LoadingExpenseListCubitState(
        household: household ?? this.household,
        sorting: sorting ?? this.sorting,
      );
}
