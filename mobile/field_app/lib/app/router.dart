import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/blocked_screen.dart';
import '../features/auth/citizen_registration_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/official_login_screen.dart';
import '../features/auth/otp_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/citizen/screens/ai_detection_result_screen.dart';
import '../features/citizen/screens/citizen_home_screen.dart';
import '../features/citizen/screens/complaint_tracker_screen.dart';
import '../features/citizen/screens/my_complaints_screen.dart';
import '../features/citizen/screens/profile_screen.dart';
import '../features/citizen/screens/report_damage_screen.dart';
import '../features/citizen/screens/submission_confirmation_screen.dart';
import '../features/contractor/contractor_home_screen.dart';
import '../features/contractor/contractor_job_screen.dart';
import '../features/handoff/web_handoff_screen.dart';
import '../features/je/je_assign_screen.dart';
import '../features/je/je_checkin_screen.dart';
import '../features/je/je_home_screen.dart';
import '../features/je/je_measure_screen.dart';
import '../features/je/je_ticket_detail_screen.dart';
import '../features/mukadam/mukadam_home_screen.dart';
import '../features/mukadam/mukadam_job_screen.dart';
import '../features/shared/execution_proof_screen.dart';
import 'router_refresh.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = GoRouterRefresh(
    Supabase.instance.client.auth.onAuthStateChange,
  );
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final path = state.uri.path;
      if (session == null) {
        if (path == '/login' ||
            path == '/official-login' ||
            path == '/otp' ||
            path == '/splash') {
          return null;
        }
        return '/login';
      }
      if (path == '/login' || path == '/official-login') {
        return '/splash';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/official-login',
        builder: (_, __) => const OfficialLoginScreen(),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) {
          final phone = state.extra as String?;
          if (phone == null || phone.isEmpty) {
            return const Scaffold(
              body: Center(child: Text('Missing phone — go back to login.')),
            );
          }
          return OtpScreen(phoneE164: phone);
        },
      ),
      GoRoute(
        path: '/register/details',
        builder: (context, state) {
          final fromExtra = state.extra as String?;
          final fromQuery = state.uri.queryParameters['phone'];
          final phone = (fromExtra != null && fromExtra.isNotEmpty)
              ? fromExtra
              : (fromQuery ?? '');
          if (phone.isEmpty) {
            return const Scaffold(
              body: Center(child: Text('Missing phone — start from login.')),
            );
          }
          return CitizenRegistrationScreen(phoneE164: phone);
        },
      ),
      GoRoute(
        path: '/blocked',
        builder: (context, state) =>
            BlockedScreen(message: state.extra as String?),
      ),
      GoRoute(
        path: '/handoff',
        builder: (_, __) => const WebHandoffScreen(),
      ),
      GoRoute(
        path: '/citizen',
        redirect: (_, __) => '/citizen/home',
      ),
      GoRoute(
        path: '/citizen/home',
        builder: (_, __) => const CitizenHomeScreen(),
      ),
      GoRoute(
        path: '/citizen/report',
        builder: (_, __) => const ReportDamageScreen(),
      ),
      GoRoute(
        path: '/citizen/ai-result',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          if (extra == null) {
            return const Scaffold(body: Center(child: Text('Missing capture data.')));
          }
          return AIDetectionResultScreen(
            imageFile: extra['imageFile'] as File,
            gpsPosition: extra['gpsPosition'] as Position,
          );
        },
      ),
      GoRoute(
        path: '/citizen/confirmation',
        builder: (context, state) {
          final ticket = state.extra as Map<String, dynamic>?;
          if (ticket == null) {
            return const Scaffold(body: Center(child: Text('Missing ticket.')));
          }
          return SubmissionConfirmationScreen(ticket: ticket);
        },
      ),
      GoRoute(
        path: '/citizen/my-complaints',
        builder: (_, __) => const MyComplaintsScreen(),
      ),
      GoRoute(
        path: '/citizen/tracker',
        builder: (context, state) {
          final ticketId = state.uri.queryParameters['ticketId'];
          if (ticketId == null || ticketId.isEmpty) {
            return const Scaffold(body: Center(child: Text('Missing ticket id.')));
          }
          return ComplaintTrackerScreen(ticketId: ticketId);
        },
      ),
      GoRoute(
        path: '/citizen/profile',
        builder: (_, __) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/je',
        builder: (_, __) => const JeHomeScreen(),
        routes: [
          GoRoute(
            path: 'tickets/:ticketId',
            builder: (_, state) => JeTicketDetailScreen(
              ticketId: state.pathParameters['ticketId']!,
            ),
            routes: [
              GoRoute(
                path: 'checkin',
                builder: (_, state) => JeCheckInScreen(
                  ticketId: state.pathParameters['ticketId']!,
                ),
              ),
              GoRoute(
                path: 'measure',
                builder: (_, state) => JeMeasureScreen(
                  ticketId: state.pathParameters['ticketId']!,
                ),
              ),
              GoRoute(
                path: 'assign',
                builder: (_, state) => JeAssignScreen(
                  ticketId: state.pathParameters['ticketId']!,
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/mukadam',
        builder: (_, __) => const MukadamHomeScreen(),
        routes: [
          GoRoute(
            path: 'jobs/:ticketId',
            builder: (_, state) => MukadamJobScreen(
              ticketId: state.pathParameters['ticketId']!,
            ),
            routes: [
              GoRoute(
                path: 'proof',
                builder: (_, state) => ExecutionProofScreen(
                  args: ExecutionProofArgs(
                    ticketId: state.pathParameters['ticketId']!,
                    roleLabel: 'Mukadam',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/contractor',
        builder: (_, __) => const ContractorHomeScreen(),
        routes: [
          GoRoute(
            path: 'jobs/:ticketId',
            builder: (_, state) => ContractorJobScreen(
              ticketId: state.pathParameters['ticketId']!,
            ),
            routes: [
              GoRoute(
                path: 'proof',
                builder: (_, state) => ExecutionProofScreen(
                  args: ExecutionProofArgs(
                    ticketId: state.pathParameters['ticketId']!,
                    roleLabel: 'Contractor',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
