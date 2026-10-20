import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/finance_transaction.dart';
import '../providers/finance_provider.dart';
import '../utils/constants.dart';
import '../utils/date_utils.dart';
import '../widgets/empty_state.dart';
import '../widgets/transaction_tile.dart';
import 'add_expense_screen.dart';
import 'add_income_screen.dart';
import 'transaction_details_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // Filter States
  String _selectedType = 'All'; // All, Income, Expense
  String _selectedDateRange =
      'All Time'; // All Time, Today, This Week, This Month
  String _selectedCategory = 'All'; // All, or specific category name
  String _selectedSort = 'Newest'; // Newest, Oldest, Highest, Lowest

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<FinanceTransaction> _getFilteredTransactions(
    List<FinanceTransaction> allTransactions,
  ) {
    List<FinanceTransaction> list = List.from(allTransactions);

    // 1. Search Query
    if (_searchQuery.isNotEmpty) {
      list = list
          .where(
            (t) =>
                t.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                t.note.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                t.merchant.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }

    // 2. Type Filter
    if (_selectedType != 'All') {
      final targetType = _selectedType == 'Income'
          ? TransactionType.income
          : TransactionType.expense;
      list = list.where((t) => t.type == targetType).toList();
    }

    // 3. Category Filter
    if (_selectedCategory != 'All') {
      list = list.where((t) => t.category == _selectedCategory).toList();
    }

    // 4. Date Range Filter
    if (_selectedDateRange != 'All Time') {
      final now = DateTime.now();
      if (_selectedDateRange == 'Today') {
        list = list.where((t) => AppDateUtils.isSameDay(t.date, now)).toList();
      } else if (_selectedDateRange == 'This Week') {
        list = list
            .where((t) => AppDateUtils.isWithinThisWeek(t.date))
            .toList();
      } else if (_selectedDateRange == 'This Month') {
        list = list
            .where((t) => AppDateUtils.isWithinThisMonth(t.date))
            .toList();
      }
    }

    // 5. Sorting
    if (_selectedSort == 'Newest') {
      list.sort((a, b) => b.date.compareTo(a.date));
    } else if (_selectedSort == 'Oldest') {
      list.sort((a, b) => a.date.compareTo(b.date));
    } else if (_selectedSort == 'Highest Amount') {
      list.sort((a, b) => b.amount.compareTo(a.amount));
    } else if (_selectedSort == 'Lowest Amount') {
      list.sort((a, b) => a.amount.compareTo(b.amount));
    }

    return list;
  }

  void _editTransaction(FinanceTransaction transaction) {
    Widget editScreen = transaction.type == TransactionType.income
        ? AddIncomeScreen(editTransaction: transaction)
        : AddExpenseScreen(editTransaction: transaction);

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => editScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final financeProvider = context.watch<FinanceProvider>();
    final allTx = financeProvider.transactions;
    final filteredTx = _getFilteredTransactions(allTx);

    // Dynamic list of unique categories available based on current selection
    final categoriesList = {
      'All',
      ...AppConstants.expenseCategories,
      ...AppConstants.incomeCategories,
    }.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() {
                _searchController.clear();
                _selectedType = 'All';
                _selectedDateRange = 'All Time';
                _selectedCategory = 'All';
                _selectedSort = 'Newest';
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: TextFormField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search merchant, note, or title...',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.textMuted,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear_rounded,
                            color: AppColors.textMuted,
                          ),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                ),
              ),
            ),

            // Horizontal filters row (Type, Date Range, Category, Sort)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  // Type dropdown
                  _buildFilterDropdown(
                    label: 'Type: $_selectedType',
                    items: ['All', 'Income', 'Expense'],
                    onChanged: (val) {
                      setState(() {
                        _selectedType = val;
                      });
                    },
                  ),
                  const SizedBox(width: 8),

                  // Date range dropdown
                  _buildFilterDropdown(
                    label: 'Time: $_selectedDateRange',
                    items: ['All Time', 'Today', 'This Week', 'This Month'],
                    onChanged: (val) {
                      setState(() {
                        _selectedDateRange = val;
                      });
                    },
                  ),
                  const SizedBox(width: 8),

                  // Category dropdown
                  _buildFilterDropdown(
                    label: 'Category: $_selectedCategory',
                    items: categoriesList,
                    onChanged: (val) {
                      setState(() {
                        _selectedCategory = val;
                      });
                    },
                  ),
                  const SizedBox(width: 8),

                  // Sort dropdown
                  _buildFilterDropdown(
                    label: 'Sort: $_selectedSort',
                    items: [
                      'Newest',
                      'Oldest',
                      'Highest Amount',
                      'Lowest Amount',
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedSort = val;
                      });
                    },
                  ),
                ],
              ),
            ),

            // Transactions list
            Expanded(
              child: filteredTx.isEmpty
                  ? EmptyState(
                      icon: Icons.receipt_long_rounded,
                      title: 'No Transactions Found',
                      description: allTx.isEmpty
                          ? 'Start tracking your cash flow by logging your first transaction.'
                          : 'Try modifying your search query or filter tags.',
                      buttonText: allTx.isEmpty ? 'Log Expense' : null,
                      onButtonTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AddExpenseScreen(),
                          ),
                        );
                      },
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      itemCount: filteredTx.length,
                      itemBuilder: (context, index) {
                        final tx = filteredTx[index];
                        return TransactionTile(
                          transaction: tx,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    TransactionDetailsScreen(transaction: tx),
                              ),
                            );
                          },
                          onLongPress: () => _editTransaction(tx),
                          onDismissed: (direction) async {
                            final id = tx.id;
                            await financeProvider.deleteTransaction(id);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Transaction deleted'),
                                action: SnackBarAction(
                                  label: 'Undo',
                                  textColor: AppColors.cyan,
                                  onPressed: () async {
                                    await financeProvider.addTransaction(tx);
                                  },
                                ),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required List<String> items,
    required Function(String) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 16,
            color: AppColors.cyan,
          ),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          dropdownColor: AppColors.cardBackground,
          hint: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          items: items.map((item) {
            return DropdownMenuItem<String>(value: item, child: Text(item));
          }).toList(),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ),
    );
  }
}
