import 'package:PiliPlus/pages/login/view.dart';
import 'package:PiliPlus/pages/pure/home.dart';
import 'package:PiliPlus/pages/pure/settings.dart';
import 'package:PiliPlus/pages/video/view.dart';
import 'package:get/get.dart';

class Routes {
  static final List<GetPage<dynamic>> getPages = [
    GetPage(name: '/', page: () => const PureHomePage()),
    GetPage(name: '/videoV', page: () => const VideoDetailPageV()),
    GetPage(name: '/setting', page: () => const PureSettingsPage()),
    GetPage(name: '/loginPage', page: () => const LoginPage()),
  ];
}
