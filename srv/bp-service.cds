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
  excluding { createdBy, modifiedBy }
  actions {
    // ── Bound action: block a Business Partner ─────────────────────────────
    // SideEffects tells the Fiori client to refetch the whole BP (incl. the
    // computed statusCriticality) after a successful call, so the List
    // Report / Object Page reflect the new status without a manual reload.
    @(restrict: [{ grant: 'WRITE', to: ['BP_PROCESSOR','BP_ADMIN'] }])
    @Common.SideEffects: { TargetEntities: ['_it'] }
    action blockBP()   returns String;

    // ── Bound action: unblock a Business Partner ───────────────────────────
    @(restrict: [{ grant: 'WRITE', to: ['BP_ADMIN'] }])
    @Common.SideEffects: { TargetEntities: ['_it'] }
    action unblockBP() returns String;
  };

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
