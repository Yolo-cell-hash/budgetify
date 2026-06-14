import 'package:flutter/material.dart';

import '../models/transaction_model.dart';
import '../services/custom_tag_service.dart';

/// Vector icons for the predefined categories — used instead of emoji in
/// transaction lists for a cleaner, fintech-grade look. Emoji still appear
/// for custom tags and user emoji overrides.
class CategoryVisuals {
  static const Map<String, IconData> _icons = {
    'Food & Dining': Icons.restaurant_rounded,
    'Groceries': Icons.shopping_basket_rounded,
    'Shopping': Icons.shopping_bag_rounded,
    'Transportation': Icons.directions_car_filled_rounded,
    'Bills & Utilities': Icons.receipt_long_rounded,
    'Entertainment': Icons.movie_rounded,
    'Health & Medical': Icons.monitor_heart_rounded,
    'Travel': Icons.flight_takeoff_rounded,
    'Education': Icons.school_rounded,
    'Salary': Icons.payments_rounded,
    'Transfer': Icons.swap_horiz_rounded,
    'Self Transfer': Icons.sync_alt_rounded,
    'Investments': Icons.trending_up_rounded,
    'Refund': Icons.replay_rounded,
    'Cash': Icons.account_balance_wallet_rounded,
    'Cash Conversion': Icons.currency_exchange_rounded,
  };

  static IconData iconFor(String category) =>
      _icons[category] ?? Icons.sell_rounded;
}

/// Leading tile for a transaction row: category icon (or custom emoji) in
/// a soft tinted squircle. Untagged transactions get a merchant monogram —
/// direction is carried by the signed, colored amount, not by arrows.
class TransactionLeadingIcon extends StatelessWidget {
  final TransactionModel transaction;
  final double size;

  const TransactionLeadingIcon({
    super.key,
    required this.transaction,
    this.size = 46,
  });

  @override
  Widget build(BuildContext context) {
    final category = transaction.category;

    Color color;
    Widget glyph;

    if (category != null) {
      color = ExpenseCategories.getColor(category);
      // User emoji overrides and custom tags keep their emoji; predefined
      // categories get the crisper vector icon.
      final emoji = CustomTagService().getTagEmoji(category);
      glyph = emoji != null
          ? Text(emoji, style: TextStyle(fontSize: size * 0.42))
          : Icon(
              CategoryVisuals.iconFor(category),
              color: color,
              size: size * 0.46,
            );
    } else {
      // Monogram fallback for untagged transactions
      color = const Color(0xFFC8A75E);
      final source = transaction.merchantName ?? transaction.sender;
      final letter = source.trim().isEmpty
          ? '?'
          : source.trim()[0].toUpperCase();
      glyph = Text(
        letter,
        style: TextStyle(
          fontSize: size * 0.40,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Center(child: glyph),
    );
  }
}
