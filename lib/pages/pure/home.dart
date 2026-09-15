import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/http/search.dart';
import 'package:PiliPlus/models/common/search/video_search_type.dart';
import 'package:PiliPlus/pages/pure/search_api.dart';
import 'package:PiliPlus/pages/pure/history.dart';
import 'package:PiliPlus/pages/pure/search_state.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class PureHomePage extends StatefulWidget {
  const PureHomePage({super.key});

  @override
  State<PureHomePage> createState() => _PureHomePageState();
}

class _PureHomePageState extends State<PureHomePage> {
  final _text = TextEditingController();
  final _state = PureSearchState(PureSearchApi().load);
  PureSearchCategory _category = PureSearchCategory.video;
  String _order = '';
  int _duration = 0;
  bool _openingVideo = false;

  @override
  void dispose() {
    _text.dispose();
    _state.dispose();
    super.dispose();
  }

  void _search() {
    FocusScope.of(context).unfocus();
    _state.search(
      PureSearchQuery(
        _text.text.trim(),
        category: _category,
        order: _order,
        duration: _duration,
      ),
    );
  }

  Future<void> _login() async {
    await Get.toNamed('/loginPage');
    if (mounted) {
      setState(() {});
      if (_state.query != null) _search();
    }
  }

  Future<void> _settings() async {
    await Get.toNamed('/setting');
    if (mounted) setState(() {});
  }

  Future<void> _open(PureSearchItem item) async {
    if (_openingVideo) return;
    _openingVideo = true;
    try {
      if (item.seasonId != null) {
        await PageUtils.viewPgc(seasonId: item.seasonId);
      } else {
        SmartDialog.showLoading(msg: '正在打开视频');
        final part = await SearchHttp.ab2cWithDimension(
          aid: item.aid,
          bvid: item.bvid,
        );
        SmartDialog.dismiss();
        if (!mounted) return;
        if (part?.cid == null) {
          SmartDialog.showToast('视频暂时无法打开，请稍后重试');
          return;
        }
        await PageUtils.toVideoPage(
          aid: item.aid,
          bvid: item.bvid,
          cid: part!.cid,
          title: item.title,
          cover: item.cover,
          dimension: part.dimension,
        );
      }
    } catch (_) {
      SmartDialog.dismiss();
      SmartDialog.showToast('视频加载失败，请检查网络后重试');
    } finally {
      _openingVideo = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('简看'),
        actions: [
          IconButton(
            tooltip: '观看历史',
            onPressed: () => Get.to(() => const PureHistoryPage()),
            icon: const Icon(Icons.history),
          ),
          TextButton.icon(
            onPressed: Accounts.main.isLogin ? _settings : _login,
            icon: Icon(
              Accounts.main.isLogin
                  ? Icons.account_circle_outlined
                  : Icons.login,
            ),
            label: Text(Accounts.main.isLogin ? '账号' : '登录'),
          ),
          IconButton(
            tooltip: '设置',
            onPressed: _settings,
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _text,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      hintText: '搜索视频、番剧、影视',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: colors.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: '清空',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _text.clear();
                              _state.clear();
                            },
                          ),
                          IconButton(
                            tooltip: '搜索',
                            icon: const Icon(Icons.arrow_forward),
                            onPressed: _search,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      for (final entry in const {
                        PureSearchCategory.video: '视频',
                        PureSearchCategory.bangumi: '番剧',
                        PureSearchCategory.cinema: '影视',
                      }.entries)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(entry.value),
                            selected: _category == entry.key,
                            onSelected: (_) {
                              setState(() => _category = entry.key);
                              if (_state.query != null) _search();
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                if (_category == PureSearchCategory.video)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 16,
                      children: [
                        DropdownButton<String>(
                          value: _order,
                          underline: const SizedBox.shrink(),
                          items: [
                            for (final type in ArchiveFilterType.values)
                              DropdownMenuItem(
                                value: type == ArchiveFilterType.totalrank
                                    ? ''
                                    : type.name,
                                child: Text(type.desc),
                              ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _order = value);
                            if (_state.query != null) _search();
                          },
                        ),
                        DropdownButton<int>(
                          value: _duration,
                          underline: const SizedBox.shrink(),
                          items: [
                            for (final type in VideoDurationType.values)
                              DropdownMenuItem(
                                value: type.index,
                                child: Text(type.label),
                              ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _duration = value);
                            if (_state.query != null) _search();
                          },
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: ListenableBuilder(
                    listenable: _state,
                    builder: (context, _) {
                      if (_state.query == null) {
                        return Center(
                          child: Text(
                            '想看什么，搜一下',
                            style: TextStyle(color: colors.outline),
                          ),
                        );
                      }
                      return ListView.builder(
                        key: ValueKey(_state.query),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: _state.items.length + 1,
                        itemBuilder: (context, index) {
                          if (index == _state.items.length) return _footer();
                          final item = _state.items[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _open(item),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: NetworkImgLayer(
                                      src: item.cover,
                                      width: item.seasonId == null ? 136 : 80,
                                      height: item.seasonId == null ? 82 : 108,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          item.subtitle,
                                          maxLines: 2,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: colors.outline,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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
        ),
      ),
    );
  }

  Widget _footer() {
    if (_state.loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_state.error != null) {
      return Column(
        children: [
          Text(_state.error!, textAlign: TextAlign.center),
          TextButton(onPressed: _state.loadMore, child: const Text('重试')),
          TextButton(onPressed: _login, child: const Text('重新登录')),
        ],
      );
    }
    if (_state.hasMore) {
      return Center(
        child: TextButton(
          onPressed: _state.loadMore,
          child: const Text('加载更多'),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(_state.items.isEmpty ? '没有找到结果，试试其他关键词' : '已显示全部结果'),
      ),
    );
  }
}
