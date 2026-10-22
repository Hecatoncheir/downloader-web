import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:downloader_lab/probe_cubit.dart';

void main() {
  test('Настоящее видео X получается целиком', () async {
    final cubit = ProbeCubit();
    final subscription = cubit.stream.listen((state) {
      if (state.bytes > 0) debugPrint('${state.message}: ${state.bytes}');
    });
    await cubit.inspectAuto(
      'https://x.com/Pusikattpusen/status/2113136961292497205?s=20',
    );
    expect(cubit.state.links, isNotEmpty, reason: cubit.state.log);
    await cubit.download(cubit.state.links.first, forSharing: true);
    expect(cubit.state.shareFile, isNotNull, reason: cubit.state.log);
    final bytes = cubit.state.shareFile!;
    expect(bytes.length, 1919669);
    expect(String.fromCharCodes(bytes.sublist(4, 8)), 'ftyp');
    debugPrint('Получен полный MP4: ${bytes.length} байт');
    await subscription.cancel();
    await cubit.close();
  }, skip: !const bool.fromEnvironment('RUN_LIVE_VIDEO_TEST'));
}
