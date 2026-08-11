import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// One article as authored in the repo, before it becomes a Firestore post.
class ArticleSeed {
  /// Doubles as the Firestore document id, which is what makes publishing
  /// idempotent — running it twice updates the same seventy documents instead
  /// of creating a hundred and forty.
  final String slug;
  final String category;
  final String title;
  final String titleHinglish;
  final String content;
  final String contentHinglish;

  const ArticleSeed({
    required this.slug,
    required this.category,
    required this.title,
    required this.titleHinglish,
    required this.content,
    required this.contentHinglish,
  });

  factory ArticleSeed.fromJson(Map<String, dynamic> json) => ArticleSeed(
        slug: json['slug'] as String,
        category: json['category'] as String,
        title: json['title'] as String,
        titleHinglish: json['titleHinglish'] as String? ?? '',
        content: json['content'] as String,
        contentHinglish: json['contentHinglish'] as String? ?? '',
      );
}

/// The written article library that ships with the app.
///
/// Kept as JSON assets rather than Dart source: it is content, not code, it
/// stays readable in a diff, and it is only parsed when an admin publishes —
/// so ordinary readers never pay to load it. Firestore is still the thing the
/// app reads from; this is only the source the library is published from.
class ArticleLibrary {
  /// Explicit list rather than an AssetManifest scan: a file that is present
  /// but not listed is a visible omission in a diff, where a silent scan would
  /// just quietly publish whatever happened to be in the folder.
  static const files = <String>[
    'assets/content/articles/01-dark-psychology.json',
    'assets/content/articles/02-manipulation.json',
    'assets/content/articles/03-toxic-relationships.json',
    'assets/content/articles/04-love-attachment.json',
    'assets/content/articles/05-breakups-healing.json',
    'assets/content/articles/06-family.json',
    'assets/content/articles/07-friendship.json',
    'assets/content/articles/08-self-worth.json',
    'assets/content/articles/09-boundaries.json',
    'assets/content/articles/10-emotions.json',
    'assets/content/articles/11-anxiety.json',
    'assets/content/articles/12-anger-ego.json',
    'assets/content/articles/13-habits.json',
    'assets/content/articles/14-focus.json',
    'assets/content/articles/15-career-studies.json',
    'assets/content/articles/16-money.json',
    'assets/content/articles/17-social-media.json',
    'assets/content/articles/18-soul-consciousness.json',
    'assets/content/articles/19-meditation.json',
    'assets/content/articles/20-karma.json',
    'assets/content/articles/21-gita.json',
    'assets/content/articles/22-impermanence.json',
    'assets/content/articles/23-forgiveness.json',
    'assets/content/articles/24-gratitude.json',
    'assets/content/articles/25-purpose.json',
    'assets/content/articles/26-daily-practice.json',
  ];

  /// Dates the library backwards from a fixed point so republishing does not
  /// reshuffle the archive. A fixed epoch, not `now()`: identical input has to
  /// produce identical documents or "publish again" becomes destructive.
  static final DateTime epoch = DateTime.utc(2026, 6, 1, 7);
  static const Duration spacing = Duration(hours: 8);

  static List<ArticleSeed>? _cache;

  static Future<List<ArticleSeed>> load() async {
    if (_cache != null) return _cache!;
    final seeds = <ArticleSeed>[];
    for (final path in files) {
      final raw = await rootBundle.loadString(path);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      for (final item in (decoded['articles'] as List)) {
        seeds.add(ArticleSeed.fromJson(item as Map<String, dynamic>));
      }
    }
    return _cache = seeds;
  }

  static DateTime dateFor(int index) => epoch.add(spacing * index);
}
