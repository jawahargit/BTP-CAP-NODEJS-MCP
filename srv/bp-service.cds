// srv/bp-service.cds
// ─────────────────────────────────────────────────────────────────────────────
// Business Partner Service
// OData V4 — consumed by Fiori Elements List Report + Object Page
// ─────────────────────────────────────────────────────────────────────────────
using { com.bp.manager as db } from '../db/schema';

@path: '/api/v1/bp'
service BPService @(requires: 'authenticated-user') {

  // ── Main entity — draft enabled for Fiori create/edit flow ───────────────
  @odata.draft.enabled
  @(restrict: [
    { grant: 'READ',                    to: 'BP_VIEWER'    },
    { grant: ['READ','WRITE','CREATE'], to: 'BP_PROCESSOR' },
    { grant: '*',                        to: 'BP_ADMIN'     }
  ])
  entity BusinessPartners as projection on db.BusinessPartners {
    *,
    // Expose association keys for Fiori value helps
    category.code  as categoryCode,
    category.name  as categoryName,
    status.code    as statusCode,
    status.name    as statusName
  }
  excluding { createdBy, modifiedBy };

  // ── Addresses (child — no separate draft, navigated from parent) ─────────
  @(restrict: [
    { grant: 'READ',   to: ['BP_VIEWER','BP_PROCESSOR','BP_ADMIN'] },
    { grant: 'WRITE',  to: ['BP_PROCESSOR','BP_ADMIN'] }
  ])
  entity BPAddresses as projection on db.BPAddresses;

  // ── Roles ─────────────────────────────────────────────────────────────────
  @(restrict: [
    { grant: 'READ',   to: ['BP_VIEWER','BP_PROCESSOR','BP_ADMIN'] },
    { grant: 'WRITE',  to: ['BP_PROCESSOR','BP_ADMIN'] }
  ])
  entity BPRoles as projection on db.BPRoles;

  // ── Tax Numbers ───────────────────────────────────────────────────────────
  @(restrict: [
    { grant: 'READ',   to: ['BP_VIEWER','BP_PROCESSOR','BP_ADMIN'] },
    { grant: 'WRITE',  to: ['BP_PROCESSOR','BP_ADMIN'] }
  ])
  entity BPTaxNumbers as projection on db.BPTaxNumbers;

  // ── Code lists (read-only — feed F4 value helps) ─────────────────────────
  @readonly entity BPCategories as projection on db.BPCategories;
  @readonly entity BPStatuses   as projection on db.BPStatuses;

  // ── Bound action: block a Business Partner ───────────────────────────────
  @(restrict: [{ grant: 'WRITE', to: ['BP_PROCESSOR','BP_ADMIN'] }])
  action blockBP()   returns String;

  // ── Bound action: unblock a Business Partner ────────────────────────────
  @(restrict: [{ grant: 'WRITE', to: ['BP_ADMIN'] }])
  action unblockBP() returns String;

  // ── Unbound function: summary counts ─────────────────────────────────────
  @readonly
  function getBPSummary() returns {
    totalBPs    : Integer;
    activeBPs   : Integer;
    blockedBPs  : Integer;
    persons     : Integer;
    orgs        : Integer;
  };
}
