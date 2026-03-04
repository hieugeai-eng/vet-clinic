import 'package:get/get.dart';
import '../controllers/petshop_controller.dart';

class PetshopBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PetshopController>(() => PetshopController());
  }
}
