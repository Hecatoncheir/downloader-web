import 'package:flutter_bloc/flutter_bloc.dart';

import 'api.dart';

class LinkInputCubit extends Cubit<String> {
  LinkInputCubit() : super('');
  void changed(String value) => emit(value.trim());
  VideoService? get service {
    try {
      return detectService(state);
    } catch (_) {
      return null;
    }
  }
}
