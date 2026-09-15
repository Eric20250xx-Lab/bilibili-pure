import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart' as grpc;
import 'package:PiliPlus/models_new/history/history.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/history/list.dart';
import 'package:PiliPlus/pages/pure/comments.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('history resumes in milliseconds and completed videos restart', () {
    final item = HistoryItemModel(history: History(), progress: 125);
    expect(item.playbackProgress, 125000);
    item.progress = -1;
    expect(item.playbackProgress, 0);
    item.progress = null;
    expect(item.playbackProgress, isNull);
  });

  testWidgets('failed sort refresh retries page one even after end of list', (
    tester,
  ) async {
    var calls = 0;
    final cursors = <Int64?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PureComments(
            oid: 1,
            type: 1,
            load: (mode, next, offset) async {
              cursors.add(next);
              calls++;
              if (calls == 2) return const Error('offline');
              return Success(
                grpc.MainListReply(
                  cursor: grpc.CursorReply(isEnd: true, next: Int64(99)),
                  replies: [
                    grpc.ReplyInfo(
                      id: Int64(calls),
                      member: grpc.Member(name: '作者'),
                      content: grpc.Content(
                        message: calls == 1 ? '热门评论' : '最新评论',
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('按热度'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('评论加载失败，请重试'));
    await tester.pumpAndSettle();
    expect(calls, 3);
    expect(cursors, [null, null, null]);
    expect(find.text('最新评论'), findsOneWidget);
    expect(find.text('热门评论'), findsNothing);
  });

  testWidgets('comment previews open thread without publishing controls', (
    tester,
  ) async {
    var opened = false;
    final reply = grpc.ReplyInfo(
      id: Int64(12),
      count: Int64(3),
      member: grpc.Member(name: '主评论作者'),
      content: grpc.Content(message: '完整评论内容'),
      replies: [
        grpc.ReplyInfo(
          member: grpc.Member(name: '回复作者'),
          content: grpc.Content(message: '楼中楼内容'),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PureCommentCard(reply: reply, onThread: () => opened = true),
        ),
      ),
    );
    expect(find.text('完整评论内容'), findsOneWidget);
    expect(find.text('回复作者：楼中楼内容'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('发表评论'), findsNothing);
    expect(find.text('点赞'), findsNothing);
    await tester.tap(find.text('查看全部 3 条回复'));
    expect(opened, isTrue);
    expect(tester.takeException(), isNull);
  });
}
