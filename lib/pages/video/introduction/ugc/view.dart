import 'package:PiliPlus/pages/video/controller.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/controller.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/widgets/page.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/widgets/season.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class UgcIntroPanel extends StatefulWidget {
  const UgcIntroPanel({
    super.key,
    required this.heroTag,
    required this.showAiBottomSheet,
    required this.showEpisodes,
    required this.onShowMemberPage,
    required this.isPortrait,
    required this.isHorizontal,
  });
  final String heroTag;
  final Function showAiBottomSheet;
  final Function showEpisodes;
  final ValueChanged<int?> onShowMemberPage;
  final bool isPortrait;
  final bool isHorizontal;

  @override
  State<UgcIntroPanel> createState() => _UgcIntroPanelState();
}

class _UgcIntroPanelState extends State<UgcIntroPanel> {
  late ColorScheme colorScheme;
  late final UgcIntroController introController;
  late final VideoDetailController videoDetailCtr =
      Get.find<VideoDetailController>(tag: widget.heroTag);

  @override
  void initState() {
    super.initState();
    introController = Get.putOrFind(
      UgcIntroController.new,
      tag: widget.heroTag,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    colorScheme = ColorScheme.of(context);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final detail = introController.videoDetail.value;
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                detail.title ?? '',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (detail.ugcSeason != null)
                SeasonPanel(
                  key: ValueKey(detail),
                  heroTag: widget.heroTag,
                  showEpisodes: widget.showEpisodes,
                  ugcIntroController: introController,
                ),
              if ((detail.pages?.length ?? 0) > 1)
                PagesPanel(
                  key: ValueKey(detail.bvid),
                  heroTag: widget.heroTag,
                  ugcIntroController: introController,
                  bvid: introController.bvid,
                  showEpisodes: widget.showEpisodes,
                ),
              if (!introController.status.value)
                TextButton(
                  onPressed: introController.queryVideoIntro,
                  child: const Text('重新加载视频信息'),
                ),
            ],
          ),
        ),
      );
    });
  }
}
