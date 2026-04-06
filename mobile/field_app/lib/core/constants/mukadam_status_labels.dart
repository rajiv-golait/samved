// ignore: constant_identifier_names — product spec
const Map<String, String> MUKADAM_STATUS_LABELS = {
  'open': 'Received',
  'verified': 'Verified',
  'assigned': 'Assigned',
  'in_progress': 'In Progress',
  'audit_pending': 'Pending Verification',
  'resolved': 'Completed',
  'rejected': 'Rejected',
};

String mukadamStatusLabel(String status) =>
    MUKADAM_STATUS_LABELS[status] ?? status.replaceAll('_', ' ');
