import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/citizen_providers.dart';
import '../../providers/providers.dart';
import '../../providers/ticket_providers.dart';

/// Invalidates ticket-related providers when `tickets` changes (Supabase Realtime).
class TicketsRealtimeScope extends ConsumerStatefulWidget {
  const TicketsRealtimeScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<TicketsRealtimeScope> createState() =>
      _TicketsRealtimeScopeState();
}

class _TicketsRealtimeScopeState extends ConsumerState<TicketsRealtimeScope> {
  RealtimeChannel? _channel;
  StreamSubscription<AuthState>? _authSub;

  void _attachIfNeeded() {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      _channel?.unsubscribe();
      _channel = null;
      return;
    }
    if (_channel != null) return;
    _channel = Supabase.instance.client.channel('public_tickets_${uid.substring(0, 8)}');
    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tickets',
          callback: (_) {
            ref.invalidate(citizenTicketsProvider);
            ref.invalidate(citizenMapPinsProvider);
            ref.invalidate(citizenNearbyTicketsProvider);
            ref.invalidate(jeInboxProvider);
            ref.invalidate(mukadamInboxProvider);
            ref.invalidate(contractorInboxProvider);
            ref.invalidate(profileProvider);
          },
        )
        .subscribe();
  }

  @override
  void initState() {
    super.initState();
    _authSub =
        Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      _channel?.unsubscribe();
      _channel = null;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _attachIfNeeded());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _attachIfNeeded());
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
