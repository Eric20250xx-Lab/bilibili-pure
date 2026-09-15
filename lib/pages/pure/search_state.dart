import 'package:flutter/foundation.dart';

enum PureSearchCategory { video, bangumi, cinema }

class PureSearchQuery {
  const PureSearchQuery(
    this.keyword, {
    this.category = PureSearchCategory.video,
    this.order = '',
    this.duration = 0,
  });

  final String keyword;
  final PureSearchCategory category;
  final String order;
  final int duration;
}

class PureSearchItem {
  const PureSearchItem({
    required this.title,
    required this.cover,
    required this.subtitle,
    this.bvid,
    this.aid,
    this.seasonId,
  });

  final String title;
  final String? cover;
  final String subtitle;
  final String? bvid;
  final int? aid;
  final int? seasonId;
}

class PureSearchPageData {
  const PureSearchPageData(this.items, {required this.hasMore});
  final List<PureSearchItem> items;
  final bool hasMore;
}

typedef PureSearchLoader = Future<PureSearchPageData> Function(
  PureSearchQuery query,
  int page,
);

class PureSearchState extends ChangeNotifier {
  PureSearchState(this.loader);

  final PureSearchLoader loader;
  PureSearchQuery? query;
  List<PureSearchItem> items = [];
  bool loading = false;
  bool hasMore = false;
  String? error;
  int _page = 0;
  int _generation = 0;
  bool _disposed = false;

  Future<void> search(PureSearchQuery next) async {
    if (next.keyword.trim().isEmpty) {
      clear();
      return;
    }
    query = next;
    _generation++;
    _page = 0;
    items = [];
    hasMore = true;
    loading = false;
    await loadMore();
  }

  void clear() {
    _generation++;
    query = null;
    items = [];
    error = null;
    loading = false;
    hasMore = false;
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (_disposed || loading || !hasMore || query == null) return;
    final generation = _generation;
    final page = _page + 1;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await loader(query!, page);
      if (_disposed || generation != _generation) return;
      items = [...items, ...result.items];
      _page = page;
      hasMore = result.hasMore;
    } catch (e) {
      if (_disposed || generation != _generation) return;
      error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
