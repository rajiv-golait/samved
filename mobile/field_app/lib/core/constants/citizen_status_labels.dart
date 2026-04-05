/// Citizen-facing status labels — do not change strings.
const Map<String, String> kCitizenStatusLabels = {
  'open': 'Received',
  'verified': 'Verified',
  'assigned': 'Repair Assigned',
  'in_progress': 'Fixing',
  'audit_pending': 'Quality Check',
  'resolved': 'Resolved',
  'rejected': 'Rejected',
  'escalated': 'Escalated',
  'cross_assigned': 'Cross Assigned',
};

String citizenStatusLabel(String status) =>
    kCitizenStatusLabels[status] ?? status.replaceAll('_', ' ');
