import 'dart:async' show Timer;
import 'dart:convert' show utf8;
import 'dart:io' show Platform;
import 'dart:typed_data' show Uint8List;

import 'package:PiliPlus/common/constants.dart';
import 'package:PiliPlus/common/widgets/button/icon_button.dart';
import 'package:PiliPlus/common/widgets/custom_icon.dart';
import 'package:PiliPlus/common/widgets/dialog/report.dart';
import 'package:PiliPlus/common/widgets/dialog/simple_dialog_option.dart';
import 'package:PiliPlus/common/widgets/marquee.dart';
import 'package:PiliPlus/http/danmaku.dart';
import 'package:PiliPlus/http/danmaku_block.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/http/live.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models/common/video/audio_quality.dart';
import 'package:PiliPlus/models/common/video/video_decode_type.dart';
import 'package:PiliPlus/models/common/video/video_quality.dart';
import 'package:PiliPlus/models/video/play/url.dart';
import 'package:PiliPlus/pages/common/common_intro_controller.dart';
import 'package:PiliPlus/pages/danmaku/danmaku_model.dart';
import 'package:PiliPlus/pages/video/controller.dart';
import 'package:PiliPlus/pages/video/introduction/local/controller.dart';
import 'package:PiliPlus/pages/video/introduction/pgc/controller.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/controller.dart';
import 'package:PiliPlus/pages/video/widgets/header_mixin.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/accounts/account.dart';
import 'package:PiliPlus/utils/connectivity_utils.dart';
import 'package:PiliPlus/utils/extension/num_ext.dart';
import 'package:PiliPlus/utils/extension/string_ext.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/storage_utils.dart';
import 'package:PiliPlus/utils/subtitle_utils.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:dio/dio.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart' hide showBottomSheet;
import 'package:media_kit/media_kit.dart' show NativePlayer;

mixin TimeBatteryMixin<T extends StatefulWidget> on State<T> {
  PlPlayerController get plPlayerController;
  late final titleKey = GlobalKey();
  ContextSingleTicker? provider;
  ContextSingleTicker get effectiveProvider => provider ??= ContextSingleTicker(
    context,
    autoStart: () =>
        plPlayerController.showControls.value &&
        !plPlayerController.controlsLock.value,
  );

  bool get isPortrait;
  bool get isFullScreen;
  bool get horizontalScreen;

  Timer? _clock;
  RxString now = ''.obs;

  static final _format = DateFormat('HH:mm');

  @override
  void dispose() {
    stopClock();
    super.dispose();
  }

  void startClock() {
    if (!_showCurrTime) return;
    if (_clock == null) {
      now.value = _format.format(DateTime.now());
      _clock ??= Timer.periodic(const Duration(seconds: 1), (Timer t) {
        if (!mounted) {
          stopClock();
          return;
        }
        now.value = _format.format(DateTime.now());
      });
    }
  }

  void stopClock() {
    _clock?.cancel();
    _clock = null;
  }

  bool _showCurrTime = false;
  void showCurrTimeIfNeeded(bool isFullScreen) {
    _showCurrTime = !isPortrait && (isFullScreen || !horizontalScreen);
    if (!_showCurrTime) {
      stopClock();
    }
  }

  late final _battery = Battery();
  late final RxnInt _batteryLevel = RxnInt();
  late final _showBatteryLevel = Pref.showBatteryLevel;
  void getBatteryLevelIfNeeded() {
    if (!_showCurrTime || !_showBatteryLevel) return;
    EasyThrottle.throttle(
      'getBatteryLevel$hashCode',
      const Duration(seconds: 30),
      () async {
        try {
          _batteryLevel.value = await _battery.batteryLevel;
        } catch (_) {}
      },
    );
  }

  List<Widget>? get timeBatteryWidgets {
    if (_showCurrTime) {
      return [
        if (_showBatteryLevel) ...[
          Obx(() {
            final batteryLevel = _batteryLevel.value;
            if (batteryLevel == null) {
              return const SizedBox.shrink();
            }
            return Text(
              '$batteryLevel%',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            );
          }),
          const SizedBox(width: 10),
        ],
        Obx(
          () => Text(
            now.value,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
      ];
    }
    return null;
  }
}

class HeaderControl extends StatefulWidget {
  const HeaderControl({
    required this.isPortrait,
    required this.controller,
    required this.videoDetailCtr,
    required this.heroTag,
    super.key,
  });

  final bool isPortrait;
  final PlPlayerController controller;
  final VideoDetailController videoDetailCtr;
  final String heroTag;

  @override
  State<HeaderControl> createState() => HeaderControlState();

  static Future<bool> likeDanmaku(VideoDanmaku extra, int cid) async {
    if (!Accounts.main.isLogin) {
      SmartDialog.showToast('请先登录');
      return false;
    }
    final isLike = !extra.isLike;
    final res = await DanmakuHttp.danmakuLike(
      isLike: isLike,
      cid: cid,
      id: extra.id,
    );
    if (res.isSuccess) {
      extra.isLike = isLike;
      if (isLike) {
        extra.like++;
      } else {
        extra.like--;
      }
      SmartDialog.showToast('${isLike ? '' : '取消'}点赞成功');
      return true;
    } else {
      res.toast();
      if (res case Error(:final code)) {
        if (code == 65006) {
          extra.isLike = true;
          return true;
        }
        if (code == 65004) {
          extra.isLike = false;
          return true;
        }
      }
      return false;
    }
  }

  static Future<bool> deleteDanmaku(int id, int cid) async {
    final res = await DanmakuHttp.danmakuRecall(cid: cid, id: id);
    if (res.isSuccess) {
      SmartDialog.showToast('删除成功');
      return true;
    } else {
      res.toast();
      return false;
    }
  }

  static Future<void> reportDanmaku(
    BuildContext context, {
    required VideoDanmaku extra,
    required PlPlayerController ctr,
  }) {
    if (Accounts.main.isLogin) {
      return autoWrapReportDialog(
        context,
        ReportOptions.danmakuReport,
        withContent: ReportOptions.danmakuReportCheck,
        contentRequired: ReportOptions.danmakuReportCheck,
        (reasonType, reasonDesc, banUid) {
          if (banUid) {
            final filter = ctr.filters;
            if (filter.dmUid.add(extra.mid)) {
              filter.count++;
              GStorage.localCache.put(LocalCacheKey.danmakuFilterRules, filter);
            }
            DanmakuFilterHttp.danmakuFilterAdd(filter: extra.mid, type: 2);
          }
          return DanmakuHttp.danmakuReport(
            reason: reasonType,
            cid: ctr.cid!,
            id: extra.id,
            content: reasonDesc,
          );
        },
      );
    } else {
      return SmartDialog.showToast('请先登录');
    }
  }

  static Future<void> reportLiveDanmaku(
    BuildContext context, {
    required int roomId,
    required String msg,
    required LiveDanmaku extra,
  }) {
    if (Accounts.main.isLogin) {
      return autoWrapReportDialog(
        context,
        ban: false,
        ReportOptions.liveDanmakuReport,
        withContent: ReportOptions.liveDanmakuReportCheck,
        contentRequired: ReportOptions.liveDanmakuReportCheck,
        (reasonType, reasonDesc, banUid) {
          // if (banUid) {
          //   final filter = ctr.filters;
          //   if (filter.dmUid.add(extra.mid)) {
          //     filter.count++;
          //     GStorage.localCache.put(
          //       LocalCacheKey.danmakuFilterRules,
          //       filter,
          //     );
          //   }
          //   DanmakuFilterHttp.danmakuFilterAdd(
          //     filter: extra.mid,
          //     type: 2,
          //   );
          // }
          return LiveHttp.liveDmReport(
            roomId: roomId,
            mid: extra.mid,
            msg: msg,
            reason: ReportOptions.liveDanmakuReport['']![reasonType]!,
            reasonId: reasonType,
            dmType: extra.dmType,
            idStr: extra.id,
            ts: extra.ts,
            sign: extra.ct,
          );
        },
      );
    } else {
      return SmartDialog.showToast('请先登录');
    }
  }
}

class HeaderControlState extends State<HeaderControl>
    with HeaderMixin, TimeBatteryMixin {
  @override
  late final PlPlayerController plPlayerController = widget.controller;
  late final VideoDetailController videoDetailCtr = widget.videoDetailCtr;
  late final PlayUrlModel videoInfo = videoDetailCtr.data;
  static const TextStyle subTitleStyle = TextStyle(fontSize: 12);
  static const TextStyle titleStyle = TextStyle(fontSize: 14);

  String get heroTag => widget.heroTag;
  late final UgcIntroController ugcIntroController;
  late final PgcIntroController pgcIntroController;
  late final LocalIntroController localIntroController;
  late CommonIntroController introController = isFileSource
      ? localIntroController
      : videoDetailCtr.isUgc
      ? ugcIntroController
      : pgcIntroController;

  @override
  bool get isPortrait => widget.isPortrait;
  @override
  late final horizontalScreen = videoDetailCtr.horizontalScreen;

  Box setting = GStorage.setting;

  @override
  void initState() {
    super.initState();
    if (isFileSource) {
      introController = Get.find<LocalIntroController>(tag: heroTag);
    } else if (videoDetailCtr.isUgc) {
      introController = Get.find<UgcIntroController>(tag: heroTag);
    } else {
      introController = Get.find<PgcIntroController>(tag: heroTag);
    }
  }

  /// 设置面板
  void showSettingSheet() {
    showBottomSheet(
      (context, setState) => Material(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: const Text('选择画质'),
              onTap: () {
                Get.back();
                showSetVideoQa();
              },
            ),
            ListTile(
              title: const Text('字幕设置'),
              onTap: () {
                Get.back();
                showSetSubtitle();
              },
            ),
            ListTile(
              title: const Text('弹幕设置'),
              onTap: () {
                Get.back();
                showSetDanmaku();
              },
            ),
            ListTile(
              title: const Text('重新加载视频'),
              onTap: () {
                Get.back();
                videoDetailCtr.queryVideoUrl();
              },
            ),
          ],
        ),
      ),
    );
  }

  static void showPlayerInfo(
    BuildContext context, {
    required NativePlayer player,
  }) {
    final hwdec = player.getProperty('hwdec-current');
    final volume = player.getProperty('volume');
    showDialog(
      context: context,
      builder: (context) {
        final state = player.state;
        final colorScheme = ColorScheme.of(context);
        return AlertDialog(
          title: const Text('播放信息'),
          contentPadding: const EdgeInsets.only(top: 16),
          content: Material(
            type: MaterialType.transparency,
            child: ListTileTheme(
              contentPadding: const .symmetric(horizontal: 24),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    ListTile(
                      dense: true,
                      title: const Text("Resolution"),
                      subtitle: Text('${state.width}x${state.height}'),
                      onTap: () => Utils.copyText(
                        'Resolution\n${state.width}x${state.height}',
                      ),
                    ),
                    ListTile(
                      dense: true,
                      title: const Text("VideoParams"),
                      subtitle: Text(state.videoParams.toString()),
                      onTap: () =>
                          Utils.copyText('VideoParams\n${state.videoParams}'),
                    ),
                    ListTile(
                      dense: true,
                      title: const Text("AudioParams"),
                      subtitle: Text(state.audioParams.toString()),
                      onTap: () =>
                          Utils.copyText('AudioParams\n${state.audioParams}'),
                    ),
                    ListTile(
                      dense: true,
                      title: const Text("Media"),
                      subtitle: Text(state.playlist.toString()),
                      onTap: () => Utils.copyText('Media\n${state.playlist}'),
                    ),
                    ListTile(
                      dense: true,
                      title: const Text("AudioTrack"),
                      subtitle: Text(state.track.audio.toString()),
                      onTap: () =>
                          Utils.copyText('AudioTrack\n${state.track.audio}'),
                    ),
                    ListTile(
                      dense: true,
                      title: const Text("VideoTrack"),
                      subtitle: Text(state.track.video.toString()),
                      onTap: () =>
                          Utils.copyText('VideoTrack\n${state.track.video}'),
                    ),
                    ListTile(
                      dense: true,
                      title: const Text("rate"),
                      subtitle: Text(state.rate.toString()),
                      onTap: () => Utils.copyText('rate\n${state.rate}'),
                    ),
                    ListTile(
                      dense: true,
                      title: const Text("Volume"),
                      subtitle: Text(volume),
                      onTap: () => Utils.copyText('Volume\n$volume'),
                    ),
                    ListTile(
                      dense: true,
                      title: const Text('hwdec'),
                      subtitle: Text(hwdec),
                      onTap: () => Utils.copyText('hwdec\n$hwdec'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: Get.back,
              child: Text('确定', style: TextStyle(color: colorScheme.outline)),
            ),
          ],
        );
      },
    );
  }

  /// 选择画质
  void showSetVideoQa() {
    if (videoInfo.dash == null) {
      SmartDialog.showToast('当前视频不支持选择画质');
      return;
    }
    final VideoQuality? currentVideoQa = videoDetailCtr.currentVideoQa.value;
    if (currentVideoQa == null) return;

    final List<FormatItem> videoFormat = videoInfo.supportFormats!;
    final availableQa = videoInfo.dash!.video!.availableVideoQualities;

    showBottomSheet((context, setState) {
      final theme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Material(
          clipBehavior: Clip.hardEdge,
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 45,
                  child: GestureDetector(
                    onTap: () => SmartDialog.showToast(
                      '灰色表示本次未获取到对应画质，可能与登录状态、观看权限或片源有关。已是大会员可先在设置中刷新账号，再重新加载视频。',
                    ),
                    child: Row(
                      spacing: 8,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('选择画质', style: titleStyle),
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: theme.colorScheme.outline,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverList.builder(
                itemCount: videoFormat.length,
                itemBuilder: (context, index) {
                  final item = videoFormat[index];
                  final isCurr = currentVideoQa.code == item.quality;
                  return ListTile(
                    dense: true,
                    onTap: () async {
                      if (isCurr) {
                        return;
                      }
                      Get.back();
                      final int quality = item.quality!;
                      final newQa = VideoQuality.fromCode(quality);
                      videoDetailCtr
                        ..plPlayerController.cacheVideoQa = newQa.code
                        ..currentVideoQa.value = newQa
                        ..updatePlayer();

                      SmartDialog.showToast("画质已变为：${newQa.desc}");

                      // update
                      if (!plPlayerController.tempPlayerConf) {
                        setting.put(
                          await ConnectivityUtils.isWiFi
                              ? SettingBoxKey.defaultVideoQa
                              : SettingBoxKey.defaultVideoQaCellular,
                          quality,
                        );
                      }
                    },
                    // 可能包含会员解锁画质
                    enabled: availableQa.contains(item.quality),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    title: Text(item.newDesc!),
                    trailing: isCurr
                        ? Icon(Icons.done, color: theme.colorScheme.primary)
                        : availableQa.contains(item.quality)
                        ? null
                        : const Text('暂不可用', style: subTitleStyle),
                  );
                },
              ),
            ],
          ),
        ),
      );
    });
  }

  /// 选择音质
  void showSetAudioQa() {
    final AudioQuality currentAudioQa = videoDetailCtr.currentAudioQa!;
    final List<AudioItem> audio = videoInfo.dash!.audio!;
    showBottomSheet((context, setState) {
      final theme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Material(
          clipBehavior: Clip.hardEdge,
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(
                child: SizedBox(
                  height: 45,
                  child: Center(child: Text('选择音质', style: titleStyle)),
                ),
              ),
              SliverList.builder(
                itemCount: audio.length,
                itemBuilder: (context, index) {
                  final item = audio[index];
                  final isCurr = currentAudioQa.code == item.id;
                  return ListTile(
                    dense: true,
                    onTap: () async {
                      if (isCurr) {
                        return;
                      }
                      Get.back();
                      final int quality = item.id;
                      final newQa = AudioQuality.fromCode(quality);
                      videoDetailCtr
                        ..plPlayerController.cacheAudioQa = newQa.code
                        ..currentAudioQa = newQa
                        ..updatePlayer();

                      SmartDialog.showToast("音质已变为：${newQa.desc}");

                      // update
                      if (!plPlayerController.tempPlayerConf) {
                        setting.put(
                          await ConnectivityUtils.isWiFi
                              ? SettingBoxKey.defaultAudioQa
                              : SettingBoxKey.defaultAudioQaCellular,
                          quality,
                        );
                      }
                    },
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    title: Text(item.quality),
                    subtitle: Text(item.codecs!, style: subTitleStyle),
                    trailing: isCurr
                        ? Icon(Icons.done, color: theme.colorScheme.primary)
                        : null,
                  );
                },
              ),
            ],
          ),
        ),
      );
    });
  }

  // 选择解码格式
  void showSetDecodeFormats() {
    final firstCode = videoDetailCtr.firstVideo.quality.code;
    // 当前视频可用的解码格式
    final videoFormat = videoInfo.supportFormats!;

    final list = videoFormat.firstWhere((e) => e.quality == firstCode).codecs;
    if (list == null) {
      SmartDialog.showToast('当前视频不支持选择解码格式');
      return;
    }

    // 当前选中的解码格式
    final curCodecs = videoDetailCtr.currentDecodeFormats.codes;
    showBottomSheet((context, setState) {
      final colorScheme = ColorScheme.of(context);
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Material(
          clipBehavior: Clip.hardEdge,
          color: colorScheme.surface,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          child: Column(
            children: [
              const SizedBox(
                height: 45,
                child: Center(child: Text('选择解码格式', style: titleStyle)),
              ),
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverList.builder(
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final item = list[index];
                        final format = VideoDecodeFormatType.fromString(item);
                        final isCurr = curCodecs.any(item.startsWith);
                        return ListTile(
                          dense: true,
                          onTap: () {
                            if (isCurr) return;
                            Get.back();
                            videoDetailCtr
                              ..currentDecodeFormats = format
                              ..updatePlayer();
                            SmartDialog.showToast("解码已变为：${format.name}");
                          },
                          contentPadding: const .symmetric(horizontal: 20),
                          title: Text(format.description),
                          subtitle: Text(item, style: subTitleStyle),
                          trailing: isCurr
                              ? Icon(Icons.done, color: colorScheme.primary)
                              : null,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  void onExportSubtitle() {
    showDialog(
      context: context,
      builder: (context) {
        SubtitleFormat format = .vtt;
        final subtitles = videoDetailCtr.subtitles;
        final secondary = ColorScheme.of(context).secondary;
        return SimpleDialog(
          clipBehavior: .hardEdge,
          contentPadding: const .only(bottom: 12),
          titlePadding: const .fromLTRB(20, 20, 20, 12),
          title: Row(
            children: [
              const Expanded(child: Text('保存字幕')),
              const Text('格式: ', style: TextStyle(fontSize: 14)),
              Builder(
                builder: (context) => PopupMenuButton<SubtitleFormat>(
                  tooltip: '',
                  initialValue: format,
                  onSelected: (value) {
                    format = value;
                    (context as Element).markNeedsBuild();
                  },
                  itemBuilder: (_) => SubtitleFormat.values
                      .map(
                        (e) => PopupMenuItem(
                          value: e,
                          height: 35,
                          child: Text(e.label),
                        ),
                      )
                      .toList(),
                  child: Padding(
                    padding: const .symmetric(horizontal: 2, vertical: 5),
                    child: Text.rich(
                      style: .new(fontSize: 14, color: secondary),
                      TextSpan(
                        children: [
                          TextSpan(text: format.label),
                          WidgetSpan(
                            alignment: .middle,
                            child: Icon(
                              size: 14,
                              MdiIcons.unfoldMoreHorizontal,
                              color: secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          children: List.generate(subtitles.length, (i) {
            final item = subtitles[i];
            return DialogOption(
              onPressed: () async {
                Get.back();
                final url = item.subtitleUrl;
                if (url == null || url.isEmpty) return;
                try {
                  final Uint8List bytes;
                  switch (format) {
                    case .vtt || .srt:
                      var subtitle = format == .vtt
                          ? videoDetailCtr.vttSubtitles[i]?.id
                          : null;
                      if (subtitle == null) {
                        final res = await VideoHttp.getSubtitles(
                          item.subtitleUrl!,
                          format: format,
                        );
                        if (res == null) return;
                        subtitle = res;
                        if (format == .vtt) {
                          videoDetailCtr.vttSubtitles[i] = (
                            isData: true,
                            id: res,
                          );
                        }
                      }
                      bytes = utf8.encode(subtitle);
                    case .json:
                      final res = await Request.dio.get<Uint8List>(
                        url.http2https,
                        options: Options(
                          responseType: .bytes,
                          headers: Constants.baseHeaders,
                          extra: {'account': const NoAccount()},
                        ),
                      );
                      if (res.statusCode != 200) return;
                      bytes = Uint8List.fromList(
                        Request.responseBytesDecoder(
                          res.data!,
                          res.headers.map,
                        ),
                      );
                  }
                  final videoDetail = introController.videoDetail.value;
                  final name =
                      '${videoDetail.title}-${videoDetail.owner?.name}(${videoDetail.owner?.mid})-${videoDetailCtr.bvid}-${videoDetailCtr.cid.value}-${item.lanDoc}.${format.name}'
                          .replaceAll(
                            Platform.isWindows ? RegExp(r'[<>:/\\|?*"]') : '/',
                            '_',
                          );
                  // Reserved characters may not be used in file names. See: https://docs.microsoft.com/en-us/windows/win32/fileio/naming-a-file#naming-conventions
                  StorageUtils.saveBytes2File(
                    name: name,
                    bytes: bytes,
                    allowedExtensions: [format.name],
                  );
                } catch (e, s) {
                  Utils.reportError(e, s);
                  SmartDialog.showToast(e.toString());
                }
              },
              child: Text(item.lanDoc ?? item.lan),
            );
          }),
        );
      },
    );
  }

  double get subtitleFontScale => plPlayerController.subtitleFontScale;
  double get subtitleFontScaleFS => plPlayerController.subtitleFontScaleFS;
  int get subtitlePaddingH => plPlayerController.subtitlePaddingH;
  int get subtitlePaddingB => plPlayerController.subtitlePaddingB;
  double get subtitleBgOpacity => plPlayerController.subtitleBgOpacity;
  double get subtitleStrokeWidth => plPlayerController.subtitleStrokeWidth;
  int get subtitleFontWeight => plPlayerController.subtitleFontWeight;

  /// 字幕设置
  void showSetSubtitle() {
    showBottomSheet(padding: () => isFullScreen ? const .only(bottom: 70) : .zero, (
      context,
      setState,
    ) {
      final theme = Theme.of(context);

      const EdgeInsets sliderPadding = .symmetric(vertical: 16);

      final sliderTheme = SliderThemeData(
        trackHeight: 10,
        padding: const .symmetric(horizontal: 6),
        trackShape: const MSliderTrackShape(),
        thumbColor: theme.colorScheme.primary,
        activeTrackColor: theme.colorScheme.primary,
        inactiveTrackColor: theme.colorScheme.onInverseSurface,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
      );

      void updateStrokeWidth(double val) {
        plPlayerController
          ..subtitleStrokeWidth = val
          ..updateSubtitleStyle();
        setState(() {});
      }

      void updateOpacity(double val) {
        plPlayerController
          ..subtitleBgOpacity = val.toPrecision(2)
          ..updateSubtitleStyle();
        setState(() {});
      }

      void updateBottomPadding(double val) {
        plPlayerController
          ..subtitlePaddingB = val.round()
          ..updateSubtitleStyle();
        setState(() {});
      }

      void updateHorizontalPadding(double val) {
        plPlayerController
          ..subtitlePaddingH = val.round()
          ..updateSubtitleStyle();
        setState(() {});
      }

      void updateFontScaleFS(double val) {
        plPlayerController
          ..subtitleFontScaleFS = val.toPrecision(2)
          ..updateSubtitleStyle();
        setState(() {});
      }

      void updateFontScale(double val) {
        plPlayerController
          ..subtitleFontScale = val.toPrecision(2)
          ..updateSubtitleStyle();
        setState(() {});
      }

      void updateFontWeight(double val) {
        plPlayerController
          ..subtitleFontWeight = val.toInt()
          ..updateSubtitleStyle();
        setState(() {});
      }

      return Padding(
        padding: const EdgeInsets.all(12),
        child: Material(
          clipBehavior: Clip.hardEdge,
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: SliderTheme(
              data: sliderTheme,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const SizedBox(
                    height: 45,
                    child: Center(child: Text('字幕设置', style: titleStyle)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '字体大小 ${(subtitleFontScale * 100).toStringAsFixed(1)}%',
                      ),
                      resetBtn(theme, '100.0%', () => updateFontScale(1.0)),
                    ],
                  ),
                  Padding(
                    padding: sliderPadding,
                    child: Slider(
                      min: 0.5,
                      max: 2.5,
                      value: subtitleFontScale,
                      divisions: 200,
                      label: '${(subtitleFontScale * 100).toStringAsFixed(1)}%',
                      onChanged: updateFontScale,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '全屏字体大小 ${(subtitleFontScaleFS * 100).toStringAsFixed(1)}%',
                      ),
                      resetBtn(theme, '150.0%', () => updateFontScaleFS(1.5)),
                    ],
                  ),
                  Padding(
                    padding: sliderPadding,
                    child: Slider(
                      min: 0.5,
                      max: 2.5,
                      value: subtitleFontScaleFS,
                      divisions: 200,
                      label:
                          '${(subtitleFontScaleFS * 100).toStringAsFixed(1)}%',
                      onChanged: updateFontScaleFS,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('字体粗细 ${subtitleFontWeight + 1}（可能无法精确调节）'),
                      resetBtn(theme, 6, () => updateFontWeight(5)),
                    ],
                  ),
                  Padding(
                    padding: sliderPadding,
                    child: Slider(
                      min: 0,
                      max: 8,
                      value: subtitleFontWeight.toDouble(),
                      divisions: 8,
                      label: '${subtitleFontWeight + 1}',
                      onChanged: updateFontWeight,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('描边粗细 $subtitleStrokeWidth'),
                      resetBtn(theme, 2.0, () => updateStrokeWidth(2.0)),
                    ],
                  ),
                  Padding(
                    padding: sliderPadding,
                    child: Slider(
                      min: 0,
                      max: 5,
                      value: subtitleStrokeWidth,
                      divisions: 10,
                      label: '$subtitleStrokeWidth',
                      onChanged: updateStrokeWidth,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('左右边距 $subtitlePaddingH'),
                      resetBtn(theme, 24, () => updateHorizontalPadding(24)),
                    ],
                  ),
                  Padding(
                    padding: sliderPadding,
                    child: Slider(
                      min: 0,
                      max: 100,
                      value: subtitlePaddingH.toDouble(),
                      divisions: 100,
                      label: '$subtitlePaddingH',
                      onChanged: updateHorizontalPadding,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('底部边距 $subtitlePaddingB'),
                      resetBtn(theme, 24, () => updateBottomPadding(24)),
                    ],
                  ),
                  Padding(
                    padding: sliderPadding,
                    child: Slider(
                      min: 0,
                      max: 200,
                      value: subtitlePaddingB.toDouble(),
                      divisions: 200,
                      label: '$subtitlePaddingB',
                      onChanged: updateBottomPadding,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '背景不透明度 ${(subtitleBgOpacity * 100).toStringAsFixed(1)}%',
                      ),
                      resetBtn(theme, '67%', () => updateOpacity(0.67)),
                    ],
                  ),
                  Padding(
                    padding: sliderPadding,
                    child: Slider(
                      min: 0,
                      max: 1,
                      divisions: 100,
                      value: subtitleBgOpacity,
                      onChanged: updateOpacity,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    })?.whenComplete(plPlayerController.putSubtitleSettings);
  }

  void showDanmakuPool() {
    final ctr = plPlayerController.danmakuController;
    if (ctr == null) return;
    showBottomSheet((context, setState) {
      final theme = Theme.of(context);
      return Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
        ),
        child: Column(
          children: [
            Container(
              height: 45,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('弹幕列表'),
                  iconButton(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Material(
                type: .transparency,
                clipBehavior: .hardEdge,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
                child: CustomScrollView(
                  slivers: [
                    ?_buildDanmakuList(ctr.staticDanmaku.nonNulls.toList()),
                    ?_buildDanmakuList(
                      ctr.scrollDanmaku.expand((e) => e).toList(),
                    ),
                    ?_buildDanmakuList(ctr.specialDanmaku.toList()),
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget? _buildDanmakuList(List<DanmakuItem<DanmakuExtra>> list) {
    if (list.isEmpty) return null;

    return SliverList.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        final extra = item.content.extra! as VideoDanmaku;
        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          onLongPress: () => Utils.copyText(item.content.text),
          title: Text(item.content.text, style: const TextStyle(fontSize: 14)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Builder(
                builder: (context) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    iconButton(
                      onPressed: () async {
                        if (await HeaderControl.likeDanmaku(
                              extra,
                              plPlayerController.cid!,
                            ) &&
                            context.mounted) {
                          (context as Element).markNeedsBuild();
                        }
                      },
                      icon: extra.isLike
                          ? const Icon(CustomIcons.player_dm_tip_like_solid)
                          : const Icon(CustomIcons.player_dm_tip_like),
                    ),
                    if (extra.like > 0)
                      Positioned(
                        left: 24.5,
                        top: 1.5,
                        child: Text(
                          extra.like.toString(),
                          style: const TextStyle(
                            fontSize: 10.5,
                            letterSpacing: 0,
                            // fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (item.content.selfSend)
                iconButton(
                  onPressed: () => HeaderControl.deleteDanmaku(
                    extra.id,
                    plPlayerController.cid!,
                  ).then((_) => item.expired = true),
                  icon: const Icon(CustomIcons.player_dm_tip_recall),
                )
              else
                iconButton(
                  onPressed: () => HeaderControl.reportDanmaku(
                    context,
                    extra: extra,
                    ctr: plPlayerController,
                  ),
                  icon: const Icon(CustomIcons.player_dm_tip_back),
                ),
            ],
          ),
        );
      },
    );
  }

  late final isFileSource = videoDetailCtr.isFileSource;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: '返回',
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () =>
                plPlayerController.onPopInvokedWithResult(false, null),
          ),
          Expanded(
            child: Obx(
              () => Text(
                introController.videoDetail.value.title ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
          Obx(
            () => IconButton(
              tooltip: '开关弹幕',
              icon: Icon(
                plPlayerController.enableShowDanmaku.value
                    ? CustomIcons.dm_on
                    : CustomIcons.dm_off,
                color: Colors.white,
              ),
              onPressed: () {
                final value = !plPlayerController.enableShowDanmaku.value;
                plPlayerController.enableShowDanmaku.value = value;
                setting.put(SettingBoxKey.enableShowDanmaku, value);
              },
            ),
          ),
          IconButton(
            tooltip: '播放设置',
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            onPressed: showSettingSheet,
          ),
        ],
      ),
    );
  }
}
