import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user.dart';

final profileControllerProvider =
    StateNotifierProvider<ProfileController, AppUser?>((ref) {
  return ProfileController();
});

class ProfileController extends StateNotifier<AppUser?> {
  ProfileController() : super(null);

  void setProfile(AppUser user) {
    state = user;
  }
}
