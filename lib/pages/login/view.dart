import 'package:PiliPlus/common/constants.dart';
import 'package:PiliPlus/common/dial_prefix.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/loading_widget/loading_widget.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/common/widgets/scroll_physics.dart' show tabBarView;
import 'package:PiliPlus/common/widgets/view_insets_safe_area.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/pages/login/controller.dart';
import 'package:PiliPlus/utils/extension/widget_ext.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final LoginPageController _loginPageCtr = Get.put(LoginPageController());
  // 二维码生成时间

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loginPageCtr.didChangeDependencies(context);
  }

  Widget loginByQRCode(ThemeData theme) => Column(
    children: [
      const SizedBox(height: 24),
      const Text('使用 bilibili 官方 App 扫码登录'),
      const SizedBox(height: 20),
      Obx(
        () => switch (_loginPageCtr.codeInfo.value) {
          Loading() => const SizedBox(
            height: 200,
            width: 200,
            child: m3eLoading,
          ),
          Success(:final response) => Container(
            width: 220,
            height: 220,
            color: Colors.white,
            padding: const EdgeInsets.all(10),
            child: PrettyQrView.data(
              data: response.url,
              decoration: const PrettyQrDecoration(
                shape: PrettyQrSquaresSymbol(color: Colors.black87),
              ),
            ),
          ),
          Error(:final errMsg) => HttpError(
            isSliver: false,
            errMsg: errMsg,
            onReload: _loginPageCtr.refreshQRCode,
          ),
        },
      ),
      const SizedBox(height: 16),
      Obx(() => Text(_loginPageCtr.statusQRCode.value)),
      Obx(() => Text('剩余 ${_loginPageCtr.qrCodeLeftTime.value} 秒')),
      TextButton.icon(
        onPressed: _loginPageCtr.refreshQRCode,
        icon: const Icon(Icons.refresh),
        label: const Text('刷新二维码'),
      ),
      Obx(() {
        final data = _loginPageCtr.codeInfo.value.dataOrNull;
        return TextButton.icon(
          onPressed: data == null
              ? null
              : () => PageUtils.launchURL(
                  'bilibili://browser?url=${Uri.encodeComponent(data.url)}',
                  mode: LaunchMode.externalNonBrowserApplication,
                ),
          icon: const Icon(Icons.open_in_new),
          label: const Text('在本机 B 站确认登录'),
        );
      }),
    ],
  );

  Widget loginBySmS(ThemeData theme) {
    return Column(
      children: [
        const SizedBox(height: 20),
        const Text('使用手机短信验证码登录'),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: DecoratedBox(
            decoration: UnderlineTabIndicator(
              borderSide: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Builder(
                  builder: (context) {
                    return PopupMenuButton(
                      padding: EdgeInsets.zero,
                      tooltip:
                          '选择国际冠码，'
                          '当前为${_loginPageCtr.selectedCountryCodeId.cname}，'
                          '+${_loginPageCtr.selectedCountryCodeId.countryId}',
                      onSelected: (item) {
                        _loginPageCtr.selectedCountryCodeId = item;
                        (context as Element).markNeedsBuild();
                      },
                      initialValue: _loginPageCtr.selectedCountryCodeId,
                      itemBuilder: (_) => Login.dialPrefix.map((item) {
                        return PopupMenuItem(
                          value: item,
                          child: Row(
                            children: [
                              Text(item.cname),
                              const Spacer(),
                              Text("+${item.countryId}"),
                            ],
                          ),
                        );
                      }).toList(),
                      child: Row(
                        children: [
                          Icon(
                            Icons.phone,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "+${_loginPageCtr.selectedCountryCodeId.countryId}",
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 6),
                SizedBox(
                  height: 24,
                  child: VerticalDivider(
                    color: theme.colorScheme.outline.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _loginPageCtr.telTextController,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      labelText: '手机号',
                      suffixIcon: IconButton(
                        onPressed: _loginPageCtr.telTextController.clear,
                        icon: const Icon(Icons.clear),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: DecoratedBox(
            decoration: UnderlineTabIndicator(
              borderSide: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _loginPageCtr.smsCodeTextController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.sms_outlined),
                      border: InputBorder.none,
                      labelText: '验证码',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),
                ),
                Obx(
                  () => TextButton.icon(
                    onPressed: _loginPageCtr.smsSendCooldown > 0
                        ? null
                        : _loginPageCtr.sendSmsCode,
                    icon: const Icon(Icons.send),
                    label: Text(
                      _loginPageCtr.smsSendCooldown > 0
                          ? '等待${_loginPageCtr.smsSendCooldown}秒'
                          : '获取验证码',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: _loginPageCtr.loginBySmsCode,
          icon: const Icon(Icons.login),
          label: const Text('登录'),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            '手机号仅用于 bilibili 官方发送验证码与登录接口，不予保存；\n'
            '本地仅存储登录凭证。\n'
            '请务必在 ${Constants.appName} 开源仓库等可信渠道下载安装。',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall!.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ),
      ],
    );
  }

  late EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    padding =
        MediaQuery.viewPaddingOf(context).copyWith(top: 0) +
        const EdgeInsets.only(bottom: 25);
    return SimpleScaffold(
      appBar: AppBar(title: const Text('登录 B 站')),
      body: Column(
        children: [
          TabBar(
            controller: _loginPageCtr.tabController,
            tabs: const [
              Tab(icon: Icon(Icons.sms_outlined), text: '短信登录'),
              Tab(icon: Icon(Icons.qr_code), text: '扫码登录'),
            ],
          ),
          Expanded(
            child: ViewInsetsSafeArea(
              child: tabBarView(
                controller: _loginPageCtr.tabController,
                children: [
                  tabViewOuter(loginBySmS(theme)),
                  tabViewOuter(loginByQRCode(theme)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget tabViewOuter(Widget child) {
    return SingleChildScrollView(
      padding: padding,
      child: child.constraintWidth(),
    );
  }
}
