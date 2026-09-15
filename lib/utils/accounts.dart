import 'dart:async';

import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/models/common/account_type.dart';
import 'package:PiliPlus/pages/mine/controller.dart';
import 'package:PiliPlus/utils/accounts/account.dart';
import 'package:PiliPlus/utils/login_utils.dart';
import 'package:hive_ce/hive.dart';

abstract final class Accounts {
  static late final Box<LoginAccount> account;
  static int revision = 0;
  static final List<Account> accountMode = List.filled(
    AccountType.values.length,
    AnonymousAccount(),
  );
  static bool get mainEqVideo => main == video;
  static Account get main => accountMode[AccountType.main.index];
  static Account get video => accountMode[AccountType.video.index];
  static Account get heartbeat => accountMode[AccountType.heartbeat.index];
  static Account get history {
    final heartbeat = Accounts.heartbeat;
    if (heartbeat is AnonymousAccount) {
      return Accounts.main;
    }
    return heartbeat;
  }
  // static set main(Account account) => set(AccountType.main, account);

  static Future<void> init() async {
    account = await Hive.openBox(
      'account',
      compactionStrategy: (int entries, int deletedEntries) {
        return deletedEntries > 2;
      },
    );
  }

  static Future<void> refresh() {
    for (final a in account.values) {
      for (final t in a.type) {
        accountMode[t.index] = a;
      }
    }
    for (final a in accountMode.toSet()) {
      unawaited(Request.buvidActive(a));
    }
    return Future.value();
  }

  static Future<void> clear() async {
    revision++;
    final cleared = account.clear();
    for (int i = 0; i < AccountType.values.length; i++) {
      accountMode[i] = AnonymousAccount();
    }
    await Future.wait([cleared, AnonymousAccount().delete()]);
    Request.buvidActive(AnonymousAccount());
  }

  static Future<void> useSingle(LoginAccount next) async {
    final current = ++revision;
    final previous = account.values.where((a) => a.mid != next.mid).toList();
    next.type.addAll(AccountType.values);
    accountMode.fillRange(0, accountMode.length, next);
    final writes = [?next.onChange(), for (final a in previous) a.delete()];
    MineController.anonymity.value = false;
    await Future.wait(writes);
    if (revision != current) return;
    unawaited(Request.buvidActive(next));
    await LoginUtils.onLoginMain();
  }

  static Future<void> deleteAll(Set<Account> accounts) async {
    final isLoginMain = Accounts.main.isLogin;
    for (int i = 0; i < AccountType.values.length; i++) {
      if (accounts.contains(accountMode[i])) {
        accountMode[i] = AnonymousAccount();
      }
    }
    await Future.wait(accounts.map((i) => i.delete()));
    if (isLoginMain && !Accounts.main.isLogin) {
      await LoginUtils.onLogoutMain();
    }
  }

  static Future<void> set(AccountType key, Account account) async {
    final oldAccount = accountMode[key.index]..type.remove(key);
    accountMode[key.index] = account..type.add(key);
    await Future.wait([?account.onChange(), ?oldAccount.onChange()]);
    if (!account.activated) await Request.buvidActive(account);
    switch (key) {
      case AccountType.main:
        await (account.isLogin
            ? LoginUtils.onLoginMain()
            : LoginUtils.onLogoutMain());
        break;
      case AccountType.heartbeat:
        MineController.anonymity.value = !account.isLogin;
        break;
      default:
        break;
    }
  }

  @pragma("vm:prefer-inline")
  static Account get(AccountType key) {
    return accountMode[key.index];
  }
}
