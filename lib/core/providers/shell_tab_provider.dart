import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'shell_tab_provider.g.dart';

@riverpod
class ShellTab extends _$ShellTab {
  @override
  int build() => 0;
  void setTab(int index) => state = index;
}
