import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/search.dart';
import 'package:PiliPlus/http/user.dart';
import 'package:PiliPlus/models_new/history/list.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class PureHistoryPage extends StatefulWidget {
  const PureHistoryPage({super.key});
  @override
  State<PureHistoryPage> createState() => _PureHistoryPageState();
}

class _PureHistoryPageState extends State<PureHistoryPage> {
  final _items = <HistoryItemModel>[];
  bool _busy = false;
  bool _opening = false;
  bool _end = false;
  bool _retryRefresh = false;
  String? _error;
  int? _max;
  int? _viewAt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (_busy || !Accounts.main.isLogin || (_end && !refresh)) return;
    final account = Accounts.main;
    _retryRefresh = refresh;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await UserHttp.historyList(
        type: 'all',
        account: account,
        max: refresh ? null : _max,
        viewAt: refresh ? null : _viewAt,
      );
      if (!mounted || !identical(account, Accounts.main)) return;
      if (result case Success(:final response)) {
        final items = response.list ?? [];
        _end = items.isEmpty;
        if (items.isNotEmpty) {
          final last = items.last;
          if (!refresh && _max == last.history.oid && _viewAt == last.viewAt)
            _end = true;
          _max = last.history.oid;
          _viewAt = last.viewAt;
        }
        if (refresh) _items.clear();
        final seen = _items
            .map(
              (e) => '${e.history.business}:${e.history.oid}:${e.history.epid}',
            )
            .toSet();
        _items.addAll(
          items.where(
            (e) =>
                (e.history.business == 'archive' ||
                    e.history.business == 'pgc') &&
                seen.add(
                  '${e.history.business}:${e.history.oid}:${e.history.epid}',
                ),
          ),
        );
      } else {
        throw Exception('history');
      }
    } catch (_) {
      if (mounted) _error = '历史记录加载失败，请重试';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(HistoryItemModel item) async {
    if (_opening) return;
    _opening = true;
    try {
      final h = item.history;
      if (h.business == 'pgc' && h.epid != null) {
        await PageUtils.viewPgc(epId: h.epid, progress: item.playbackProgress);
      } else {
        final cid =
            h.cid ??
            await SearchHttp.ab2c(aid: h.oid, bvid: h.bvid, part: h.page);
        if (!mounted) return;
        if (cid == null) throw Exception('Unavailable');
        await PageUtils.toVideoPage(
          aid: h.oid,
          bvid: h.bvid,
          cid: cid,
          title: item.title,
          cover: item.cover,
          progress: item.playbackProgress,
        );
      }
      if (mounted) await _load(refresh: true);
    } catch (_) {
      SmartDialog.showToast('视频暂时无法打开，请稍后重试');
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('观看历史')),
    body: !Accounts.main.isLogin
        ? Center(
            child: TextButton(
              onPressed: () async {
                await Get.toNamed('/loginPage');
                if (mounted) {
                  setState(() {});
                  _load(refresh: true);
                }
              },
              child: const Text('登录后查看观看历史'),
            ),
          )
        : RefreshIndicator(
            onRefresh: () => _load(refresh: true),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _items.length + 1,
              itemBuilder: (context, index) {
                if (index == _items.length)
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: _busy
                          ? const CircularProgressIndicator()
                          : _error != null
                          ? TextButton(
                              onPressed: () => _load(refresh: _retryRefresh),
                              child: Text(_error!),
                            )
                          : _end
                          ? Text(_items.isEmpty ? '暂无观看历史' : '没有更多了')
                          : TextButton(
                              onPressed: _load,
                              child: const Text('加载更多'),
                            ),
                    ),
                  );
                final item = _items[index];
                final seconds = item.progress ?? 0;
                final progress = seconds < 0
                    ? '已看完'
                    : '看到 ${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
                return ListTile(
                  leading: item.cover == null
                      ? const Icon(Icons.play_circle_outline)
                      : SizedBox(
                          width: 96,
                          child: Image.network(
                            item.cover!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.play_circle_outline),
                          ),
                        ),
                  title: Text(
                    item.title ?? '视频',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${item.showTitle ?? item.authorName ?? ''} · $progress',
                  ),
                  onTap: () => _open(item),
                );
              },
            ),
          ),
  );
}
