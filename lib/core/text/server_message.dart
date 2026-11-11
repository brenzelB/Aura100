import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

/// The sentence a player may read after a refused action.
///
/// The game rules on the server answer in plain English and raise with
/// SQLSTATE `P0001`; those sentences are written for players and are
/// shown as they are. Everything else a database can say - an expired
/// session, a constraint name, a policy violation - is written for
/// engineers, so the player gets [fallback] instead.
String serverMessage(Object? error, String fallback) {
  if (error is PostgrestException &&
      error.code == 'P0001' &&
      error.message.trim().isNotEmpty) {
    return error.message;
  }
  return fallback;
}
