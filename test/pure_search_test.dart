import 'dart:async';

import 'package:PiliPlus/models/search/result.dart';
import 'package:PiliPlus/pages/pure/search_state.dart';
import 'package:flutter_test/flutter_test.dart';

PureSearchItem item(String title) =>
    PureSearchItem(title: title, cover: null, subtitle: '');
PureSearchPageData page(List<String> titles, {bool more = false}) =>
    PureSearchPageData(titles.map(item).toList(), hasMore: more);

void main() {
  test(
    'slow earlier query cannot overwrite a newer keyword or category',
    () async {
      final first = Completer<PureSearchPageData>();
      final state = PureSearchState(
        (query, pageNumber) => query.keyword == 'old'
            ? first.future
            : Future.value(page(['new result'])),
      );
      final old = state.search(const PureSearchQuery('old'));
      await state.search(
        const PureSearchQuery('new', category: PureSearchCategory.bangumi),
      );
      first.complete(page(['old result']));
      await old;
      expect(state.items.map((item) => item.title), ['new result']);
      expect(state.query!.category, PureSearchCategory.bangumi);
      expect(state.loading, false);
      state.dispose();
    },
  );

  test(
    'pagination keeps server order and retries the failed page once',
    () async {
      var fail = true;
      final requests = <int>[];
      final state = PureSearchState((query, pageNumber) async {
        requests.add(pageNumber);
        expect(query.order, 'pubdate');
        expect(query.duration, 2);
        if (pageNumber == 1) return page(['third', 'first'], more: true);
        if (fail) {
          fail = false;
          throw Exception('network unavailable');
        }
        return page(['second']);
      });
      await state.search(
        const PureSearchQuery('test', order: 'pubdate', duration: 2),
      );
      await state.loadMore();
      expect(state.items.map((item) => item.title), ['third', 'first']);
      expect(state.error, 'network unavailable');
      await state.loadMore();
      await state.loadMore();
      expect(requests, [1, 2, 2]);
      expect(state.items.map((item) => item.title), [
        'third',
        'first',
        'second',
      ]);
      expect(state.hasMore, false);
      expect(state.error, null);
      state.dispose();
    },
  );

  test('clearing search ignores an in-flight response', () async {
    final pending = Completer<PureSearchPageData>();
    final state = PureSearchState((_, _) => pending.future);
    final request = state.search(const PureSearchQuery('test'));
    state.clear();
    pending.complete(page(['late response']));
    await request;
    expect(state.query, null);
    expect(state.items, isEmpty);
    expect(state.loading, false);
    state.dispose();
  });

  test('disposal during a request does not notify a dead page', () async {
    final pending = Completer<PureSearchPageData>();
    final state = PureSearchState((_, _) => pending.future);
    final request = state.search(const PureSearchQuery('test'));
    state.dispose();
    pending.complete(page(['late response']));
    await request;
  });

  test(
    'video parsing removes marked ads and live cards without reordering videos',
    () {
      Map<String, dynamic> row(
        String title, {
        Object ad = false,
        String type = 'video',
      }) => {
        'title': title,
        'aid': 1,
        'bvid': 'BVfixture',
        'type': type,
        'duration': '3:21',
        'author': 'fixture',
        'is_ad': ad,
      };
      final data = SearchVideoData.fromJson({
        'numResults': 1000,
        'numPages': 50,
        'result': [
          row('third'),
          row('ad', ad: 1),
          row('live', type: 'live_room'),
          row('广告设计教程'),
          row('first'),
        ],
      });
      expect(data.list!.map((item) => item.title), [
        'third',
        '广告设计教程',
        'first',
      ]);
      expect(data.numPages, 50);
      expect(data.numResults, 1000);
    },
  );

  test('PGC parsing keeps official season order and page count', () {
    final data = SearchPgcData.fromJson({
      'numResults': 3,
      'numPages': 1,
      'result': [
        {'title': 'second', 'season_id': 2},
        {'title': 'ad', 'season_id': 99, 'is_ad': true},
        {'title': 'first', 'season_id': 1},
      ],
    });
    expect(data.list!.map((item) => item.seasonId), [2, 1]);
    expect(data.numPages, 1);
  });
}
