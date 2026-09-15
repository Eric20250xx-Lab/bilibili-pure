import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart'
    show ReplyInfo, MainListReply, DetailListReply, Mode;
import 'package:PiliPlus/grpc/reply.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:fixnum/fixnum.dart';
import 'package:material_ui/material_ui.dart';

class PureComments extends StatefulWidget {
  const PureComments({
    super.key,
    required this.oid,
    required this.type,
    this.root,
    this.load,
  });
  final int oid;
  final int type;
  final ReplyInfo? root;
  final Future<LoadingState<dynamic>> Function(Mode, Int64?, String?)? load;

  @override
  State<PureComments> createState() => _PureCommentsState();
}

class _PureCommentsState extends State<PureComments> {
  final _items = <ReplyInfo>[];
  bool _busy = false;
  bool _end = false;
  bool _retryRefresh = false;
  bool _hot = true;
  String? _error;
  String? _offset;
  Int64? _next;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (_busy || (_end && !refresh)) return;
    _retryRefresh = refresh;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final mode = _hot ? Mode.MAIN_LIST_HOT : Mode.MAIN_LIST_TIME;
      final result = widget.load != null
          ? await widget.load!(
              mode,
              refresh ? null : _next,
              refresh ? null : _offset,
            )
          : widget.root == null
          ? await ReplyGrpc.mainList(
              oid: widget.oid,
              type: widget.type,
              mode: mode,
              offset: refresh ? null : _offset,
              cursorNext: refresh ? null : _next,
            )
          : await ReplyGrpc.detailList(
              oid: widget.oid,
              type: widget.type,
              root: widget.root!.id.toInt(),
              rpid: 0,
              mode: mode,
              offset: refresh ? null : _offset,
            );
      if (!mounted) return;
      final List<ReplyInfo> items;
      switch (result) {
        case Success(response: MainListReply data):
          items = [
            if ((refresh || _items.isEmpty) && data.hasUpTop()) data.upTop,
            ...data.replies,
          ];
          _next = data.cursor.next;
          _offset = data.paginationReply.nextOffset;
          _end = data.cursor.isEnd || items.isEmpty;
        case Success(response: DetailListReply data):
          items = data.root.replies;
          _offset = data.paginationReply.nextOffset;
          _end = data.cursor.isEnd || items.isEmpty || _offset!.isEmpty;
        case Error(:final errMsg):
          throw Exception(errMsg ?? '评论暂时无法加载');
        default:
          throw Exception('评论暂时无法加载');
      }
      if (refresh) _items.clear();
      final seen = _items.map((e) => e.id).toSet();
      _items.addAll(items.where((e) => seen.add(e.id)));
    } catch (_) {
      if (mounted) _error = '评论加载失败，请重试';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _thread(ReplyInfo root) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .78,
        child: Column(
          children: [
            ListTile(
              title: Text('评论详情 · ${root.count} 条回复'),
              trailing: IconButton(
                tooltip: '关闭',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: PureComments(
                oid: widget.oid,
                type: widget.type,
                root: root,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(widget.root == null ? '评论' : '楼中楼'),
            TextButton.icon(
              onPressed: _busy
                  ? null
                  : () {
                      setState(() => _hot = !_hot);
                      _load(refresh: true);
                    },
              icon: const Icon(Icons.sort),
              label: Text(_hot ? '按热度' : '按时间'),
            ),
          ],
        ),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: () => _load(refresh: true),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: _items.length + 1 + (widget.root == null ? 0 : 1),
            itemBuilder: (context, index) {
              if (widget.root != null) {
                if (index == 0) return PureCommentCard(reply: widget.root!);
                index--;
              }
              if (index < _items.length) {
                final item = _items[index];
                return PureCommentCard(
                  reply: item,
                  onThread:
                      widget.root == null &&
                          (item.count > Int64.ZERO || item.replies.isNotEmpty)
                      ? () => _thread(item)
                      : null,
                );
              }
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
                      ? Text(_items.isEmpty ? '暂无评论' : '没有更多了')
                      : TextButton(onPressed: _load, child: const Text('加载更多')),
                ),
              );
            },
          ),
        ),
      ),
    ],
  );
}

class PureCommentCard extends StatelessWidget {
  const PureCommentCard({super.key, required this.reply, this.onThread});
  final ReplyInfo reply;
  final VoidCallback? onThread;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reply.member.name,
            style: TextStyle(
              color: colors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(reply.content.message),
          for (final picture in reply.content.pictures)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Image.network(
                picture.imgSrc,
                height: 180,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Text('图片暂时无法加载'),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            '${reply.like} 人赞同',
            style: TextStyle(color: colors.outline, fontSize: 12),
          ),
          if (onThread != null) ...[
            for (final child in reply.replies.take(2))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${child.member.name}：${child.content.message}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            TextButton(
              onPressed: onThread,
              child: Text('查看全部 ${reply.count} 条回复'),
            ),
          ],
        ],
      ),
    );
  }
}
