import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kitchenowl/enums/expenselist_sorting.dart';
import 'package:kitchenowl/models/expense.dart';
import 'package:kitchenowl/models/expense_category.dart';
import 'package:kitchenowl/models/household.dart';
import 'package:kitchenowl/services/storage/storage.dart';
import 'package:kitchenowl/services/transaction_handler.dart';
import 'package:kitchenowl/services/transactions/expense.dart';

class ExpenseListCubit extends Cubit<ExpenseListCubitState> {
  final Household household;
  Future<void>? _refreshThread;

  ExpenseListCubit(this.household)
      : super(const LoadingExpenseListCubitState()) {
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

  void setFilter(ExpenseCategory? category, bool selected) {
    final filter = List.of(state.filter);
    if (selected) {
      filter.add(category);
    } else {
      filter.removeWhere((e) => e?.id == category?.id);
    }
    emit(state.copyWith(filter: filter));
    refresh();
  }

  Future<void> loadMore() async {
    if (state.allLoaded) return;

    final moreExpenses = TransactionHandler.getInstance()
        .runTransaction(TransactionExpenseGetMore(
      household: household,
      sorting: state.sorting,
      lastExpense: state.expenses.last,
      filter: state.filter,
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
    final filter = state.filter;
    final categories = TransactionHandler.getInstance()
        .runTransaction(TransactionExpenseCategoriesGet(household: household));
    final expenses = TransactionHandler.getInstance()
        .runTransaction(TransactionExpenseGetAll(
      household: household,
      sorting: sorting,
      filter: filter,
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
      expenses: await expenses,
      sorting: sorting,
      categories: await categories,
      allLoaded: (await expenses).length < 30,
      categoryOverview: (await categoryOverview) ?? state.categoryOverview,
      filter: filter,
    ));
    _refreshThread = null;
  }
}

class ExpenseListCubitState extends Equatable {
  final List<Expense> expenses;
  final ExpenselistSorting sorting;
  final List<ExpenseCategory> categories;
  final Map<int, double> categoryOverview;
  final bool allLoaded;
  final List<ExpenseCategory?> filter;

  const ExpenseListCubitState({
    this.expenses = const [],
    this.sorting = ExpenselistSorting.all,
    this.allLoaded = false,
    this.categories = const [],
    this.categoryOverview = const {},
    this.filter = const [],
  });

  ExpenseListCubitState copyWith({
    List<Expense>? expenses,
    ExpenselistSorting? sorting,
    bool? allLoaded,
    List<ExpenseCategory>? categories,
    Map<int, double>? categoryOverview,
    List<ExpenseCategory?>? filter,
  }) =>
      ExpenseListCubitState(
        expenses: expenses ?? this.expenses,
        sorting: sorting ?? this.sorting,
        allLoaded: allLoaded ?? this.allLoaded,
        categories: categories ?? this.categories,
        categoryOverview: categoryOverview ?? this.categoryOverview,
        filter: filter ?? this.filter,
      );

  @override
  List<Object?> get props =>
      <Object>[sorting, categoryOverview, filter] + categories + expenses;
}

class LoadingExpenseListCubitState extends ExpenseListCubitState {
  const LoadingExpenseListCubitState({super.sorting, super.filter});

  @override
  // ignore: long-parameter-list
  ExpenseListCubitState copyWith({
    List<Expense>? expenses,
    ExpenselistSorting? sorting,
    bool? allLoaded,
    List<ExpenseCategory>? categories,
    Map<int, double>? categoryOverview,
    List<ExpenseCategory?>? filter,
  }) =>
      LoadingExpenseListCubitState(
        sorting: sorting ?? this.sorting,
        filter: filter ?? this.filter,
      );
}
