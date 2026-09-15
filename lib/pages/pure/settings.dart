import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/login.dart';
import 'package:PiliPlus/http/user.dart';
import 'package:PiliPlus/models/user/info.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/accounts/account.dart';
import 'package:PiliPlus/utils/login_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class PureSettingsPage extends StatefulWidget {
  const PureSettingsPage({super.key});
  @override
  State<PureSettingsPage> createState() => _PureSettingsPageState();
}

class _PureSettingsPageState extends State<PureSettingsPage> {
  UserInfoData? _info = Pref.userInfoCache;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (Accounts.main.isLogin) _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await UserHttp.userInfo();
      if (result case Success(:final response) when response.isLogin == true) {
        await GStorage.userInfo.put('userInfoCache', response);
        if (mounted) setState(() => _info = response);
      } else if (mounted) {
        setState(() => _error = '无法确认账号状态，请重新登录或稍后刷新');
      }
    } catch (_) {
      if (mounted) setState(() => _error = '网络连接失败，请稍后刷新');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _login() async {
    await Get.toNamed('/loginPage');
    if (mounted && Accounts.main.isLogin) await _refresh();
  }

  Future<void> _logout() async {
    setState(() => _busy = true);
    try {
      if (Accounts.main case final LoginAccount account) {
        await LoginHttp.logout(account);
      }
    } catch (_) {
      // 本地退出不依赖网络，避免离线时留下账号凭证。
    }
    await Accounts.clear();
    await LoginUtils.onLogoutMain();
    if (mounted) {
      setState(() {
        _info = null;
        _busy = false;
        _error = null;
      });
    }
  }

  void _save(String key, Object value) {
    GStorage.setting.put(key, value);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('设置')),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: Text(
              Accounts.main.isLogin ? _info?.uname ?? '已登录' : '登录 B 站',
            ),
            subtitle: Text(
              Accounts.main.isLogin
                  ? (_info == null
                        ? '会员状态待刷新'
                        : _info?.vipStatus == 1
                        ? '大会员 · 按账号权限播放'
                        : '普通会员 · 按账号权限播放')
                  : '登录后使用账号已有的观看权限',
            ),
            trailing: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    tooltip: '刷新账号状态',
                    onPressed: Accounts.main.isLogin ? _refresh : _login,
                    icon: const Icon(Icons.refresh),
                  ),
            onTap: _busy ? null : _login,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_error!),
            ),
          if (Accounts.main.isLogin)
            ListTile(
              title: const Text('退出登录'),
              leading: const Icon(Icons.logout),
              onTap: _busy ? null : _logout,
            ),
          const Divider(),
          SwitchListTile(
            title: const Text('显示弹幕'),
            value: Pref.enableShowDanmaku,
            onChanged: (value) => _save(SettingBoxKey.enableShowDanmaku, value),
          ),
          _slider(
            '弹幕透明度',
            Pref.danmakuOpacity,
            0.1,
            1,
            (value) => _save(SettingBoxKey.danmakuOpacity, value),
          ),
          _slider(
            '弹幕大小',
            Pref.danmakuFontScale,
            0.6,
            1.8,
            (value) => _save(SettingBoxKey.danmakuFontScale, value),
          ),
          _slider(
            '全屏弹幕大小',
            Pref.danmakuFontScaleFS,
            0.6,
            2,
            (value) => _save(SettingBoxKey.danmakuFontScaleFS, value),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('清晰度、倍速和字幕可在播放时调整。'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('简看 0.1.0'),
            subtitle: const Text('基于 PiliPlus 2.1.4 · GPL-3.0'),
            onTap: () => showLicensePage(
              context: context,
              applicationName: '简看',
              applicationVersion: '0.1.0',
              applicationLegalese:
                  '基于 PiliPlus、PiliPalaX 和 PiliPala。修改后的源码随安装包提供。',
            ),
          ),
        ],
      ),
    ),
  );

  Widget _slider(
    String title,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    ),
  );
}
