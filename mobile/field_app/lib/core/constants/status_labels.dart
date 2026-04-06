/// Human-readable ticket status labels (JE / shared). Do not change strings.
// ignore: constant_identifier_names — spec requires STATUS_LABELS
const Map<String, String> STATUS_LABELS = {
  'open': 'Received',
  'verified': 'Verified',
  'assigned': 'Repair Assigned',
  'in_progress': 'Fixing',
  'audit_pending': 'Quality Check',
  'resolved': 'Resolved',
  'rejected': 'Rejected',
  'escalated': 'Escalated',
};

String statusLabel(String status) =>
    STATUS_LABELS[status] ?? status.replaceAll('_', ' ');
