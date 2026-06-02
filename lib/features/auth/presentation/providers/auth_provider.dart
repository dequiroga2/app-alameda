import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'auth_provider.g.dart';

@riverpod
Stream<AuthState> authState(Ref ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
}

@riverpod
SupabaseClient supabase(Ref ref) {
  return Supabase.instance.client;
}

@riverpod
User? currentUser(Ref ref) {
  return Supabase.instance.client.auth.currentUser;
}
