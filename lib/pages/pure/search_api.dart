import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/search.dart';
import 'package:PiliPlus/models/common/search/search_type.dart';
import 'package:PiliPlus/models/search/result.dart';
import 'package:PiliPlus/pages/pure/search_state.dart';
import 'package:dio/dio.dart';

class PureSearchApi {
  String? _gaiaVtoken;

  Future<PureSearchPageData> load(PureSearchQuery query, int page) async {
    try {
      return await _load(query, page);
    } on DioException {
      throw Exception('网络连接失败，请稍后重试');
    }
  }

  Future<PureSearchPageData> _load(PureSearchQuery query, int page) async {
    if (query.category == PureSearchCategory.video) {
      final result = await SearchHttp.searchByType<SearchVideoData>(
        searchType: SearchType.video,
        keyword: query.keyword,
        page: page,
        order: query.order,
        duration: query.duration,
        gaiaVtoken: _gaiaVtoken,
        onSuccess: (token) => _gaiaVtoken = token,
      );
      if (result case Success(:final response)) {
        final list = response.list ?? [];
        return PureSearchPageData(
          [
            for (final item in list)
              PureSearchItem(
                title: item.title,
                cover: item.cover,
                subtitle:
                    '${item.owner.name ?? ''} · ${_duration(item.duration)}',
                bvid: item.bvid,
                aid: item.aid,
              ),
          ],
          hasMore: _hasMore(
            response.numPages,
            response.numResults,
            page,
            list.length,
          ),
        );
      }
      throw Exception(_message(result));
    }
    final result = await SearchHttp.searchByType<SearchPgcData>(
      searchType: query.category == PureSearchCategory.bangumi
          ? SearchType.media_bangumi
          : SearchType.media_ft,
      keyword: query.keyword,
      page: page,
      gaiaVtoken: _gaiaVtoken,
      onSuccess: (token) => _gaiaVtoken = token,
    );
    if (result case Success(:final response)) {
      final list = response.list ?? [];
      return PureSearchPageData(
        [
          for (final item in list)
            PureSearchItem(
              title: item.title.map((part) => part.text).join(),
              cover: item.cover,
              subtitle: [
                item.seasonTypeName,
                item.indexShow,
              ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
              seasonId: item.seasonId,
            ),
        ],
        hasMore: _hasMore(
          response.numPages,
          response.numResults,
          page,
          list.length,
        ),
      );
    }
    throw Exception(_message(result));
  }

  static bool _hasMore(int? pages, int? total, int page, int count) =>
      pages != null
      ? page < pages
      : total == null
      ? count == 20
      : page * 20 < total;

  static String _message(LoadingState<Object?> result) {
    if (result case Error(code: -101)) return '登录已过期，请重新登录后重试';
    if (result case Error(code: -412)) return '搜索暂时受限，请稍后重试';
    final message = result.toString();
    if (message.contains('#0') || message.contains('StackTrace')) {
      return '搜索结果暂时无法读取，请稍后重试';
    }
    if (message.contains('风控')) return '请完成验证，然后点击重试';
    return message.isEmpty ? '搜索失败，请重试' : message;
  }

  static String _duration(int seconds) => seconds < 0
      ? ''
      : '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}
