import 'faq_category.dart';

class FaqItem {
  const FaqItem({
    required this.category,
    required this.question,
    required this.answer,
  });

  final FaqCategory category;
  final String question;
  final String answer;
}
