import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:PiliPlus/http/api.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/http/login.dart';
import 'package:PiliPlus/utils/accounts/account_manager/account_mgr.dart';
import 'package:PiliPlus/models/common/account_type.dart';
import 'package:PiliPlus/pages/login/controller.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/accounts/account.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late Future<Map<String, dynamic>> Function(RequestOptions) respond;
  final pending = <Completer<Map<String, dynamic>>>[];
  Completer<Map<String, dynamic>> hold() {
    final c = Completer<Map<String, dynamic>>();
    pending.add(c);
    return c;
  }

  Future<void> drain() =>
      Future<void>.delayed(const Duration(milliseconds: 30));
  LoginAccount account(String id) => LoginAccount(
    BiliCookieJar.fromJson({'DedeUserID': id, 'bili_jct': 'test-only'}),
    null,
    null,
  );
  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('jiankan-auth-');
    Hive.init(temp.path);
    GStorage.regAdapter();
    GStorage.setting = await Hive.openBox('setting');
    GStorage.video = await Hive.openBox('video');
    GStorage.localCache = await Hive.openBox('localCache');
    GStorage.userInfo = await Hive.openBox('userInfo');
    await Accounts.init();
    Request();
    Request.dio.interceptors.clear();
    Request.dio.interceptors.add(AccountManager());
    Request.dio.httpClientAdapter = _Adapter(
      (o) async => ResponseBody.fromString(
        jsonEncode(await respond(o)),
        200,
        headers: {
          'content-type': ['application/json'],
          if (o.path == Api.logout)
            'set-cookie': ['test_marker=ok; Domain=.bilibili.com; Path=/'],
        },
      ),
    );
  });
  setUp(() async {
    respond = (_) async => {'code': 1, 'message': 'offline'};
    await Accounts.clear();
    await GStorage.userInfo.clear();
    await drain();
  });
  tearDown(() async {
    for (final c in pending) {
      if (!c.isCompleted) c.complete({'code': 1, 'message': 'offline'});
    }
    pending.clear();
    await drain();
  });
  tearDownAll(() async {
    await Hive.close();
    await temp.delete(recursive: true);
  });

  test('disposed login discards delayed SMS response', () async {
    final key = hold();
    var calls = 0;
    respond = (_) {
      calls++;
      return key.future;
    };
    final c = LoginPageController()..onInit();
    c.telTextController.text = '10000000000';
    c.smsCodeTextController.text = '000000';
    c.captchaKey = 'test';
    c.smsSendTimestamp = DateTime.now().millisecondsSinceEpoch;
    final login = c.loginBySmsCode();
    await drain();
    c.onDelete();
    key.complete({
      'code': 0,
      'data': {'key': 'test'},
    });
    await login;
    expect(calls, 1);
    expect(Accounts.account.isEmpty, true);
    expect(Accounts.accountMode.every((a) => !a.isLogin), true);
  });

  test('latest QR owns the timer; disposal cancels it', () async {
    final older = hold(), newer = hold();
    var calls = 0;
    respond = (_) => (++calls == 1 ? older : newer).future;
    final c = LoginPageController()..onInit();
    final first = c.refreshQRCode();
    await drain();
    final second = c.refreshQRCode();
    await drain();
    newer.complete({
      'code': 0,
      'data': {'auth_code': 'new', 'url': 'new'},
    });
    await second;
    final timer = c.qrCodeTimer;
    older.complete({
      'code': 0,
      'data': {'auth_code': 'old', 'url': 'old'},
    });
    await first;
    expect(c.codeInfo.value.dataOrNull?.authCode, 'new');
    expect(c.qrCodeTimer, same(timer));
    c.onDelete();
    expect(timer!.isActive, false);
  });

  test('restore completes before remote activation', () async {
    final activation = hold();
    respond = (_) => activation.future;
    final saved = account('1')..type.addAll(AccountType.values);
    await saved.onChange();
    await Accounts.refresh().timeout(const Duration(milliseconds: 100));
    expect(Accounts.accountMode.every((a) => identical(a, saved)), true);
    expect(activation.isCompleted, false);
  });

  test('logout discards old credentials and profile', () async {
    final profile = hold();
    final started = Completer<void>();
    respond = (o) async {
      if (o.path == Api.userInfo) {
        started.complete();
        return profile.future;
      }
      return {'code': 0};
    };
    final login = Accounts.useSingle(account('2'));
    await started.future;
    await Accounts.clear();
    profile.complete({
      'code': 0,
      'data': {'isLogin': true, 'mid': 2, 'face': ''},
    });
    await login;
    expect(Accounts.account.isEmpty, true);
    expect(Accounts.accountMode.every((a) => !a.isLogin), true);
    expect(Pref.userInfoCache, null);
  });
  test('same-user replacement rejects old account writes', () async {
    final old = account('4');
    await old.onChange();
    final replacement = account('4');
    final login = Accounts.useSingle(replacement);
    await old.onChange();
    expect(Accounts.account.get('4'), same(replacement));
    await Accounts.clear();
    await login;
  });

  test(
    'logout Cookie response cannot restore credentials after restart',
    () async {
      final old = account('3')..type.addAll(AccountType.values);
      await old.onChange();
      await Accounts.refresh();
      final response = hold();
      respond = (_) => response.future;
      await Accounts.clear();
      final logout = LoginHttp.logout(old);
      response.complete({'code': 0});
      await logout;
      expect(old.cookieJar.toJson()['test_marker'], 'ok');
      expect(old.csrf, 'test-only');
      expect(Accounts.account.isEmpty, true);
      await Accounts.refresh();
      expect(Accounts.accountMode.every((a) => !a.isLogin), true);
    },
  );
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? cancelFuture,
  ) => respond(o);
  @override
  void close({bool force = false}) {}
}
