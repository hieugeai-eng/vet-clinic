import 'package:get/get.dart';
import 'vi_vn.dart';
import 'en_us.dart';

class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {'vi_VN': viVN, 'en_US': enUS};
}
