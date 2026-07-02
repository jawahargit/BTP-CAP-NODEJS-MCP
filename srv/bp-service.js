// srv/bp-service.js
// ─────────────────────────────────────────────────────────────────────────────
// BPService handler — Node.js CAP ApplicationService
// Covers:
//   • BEFORE CREATE/UPDATE: compute fullName, validate required fields
//   • AFTER READ: set statusCriticality virtual field
//   • ON blockBP / unblockBP: bound actions
//   • ON getBPSummary: unbound function
// ─────────────────────────────────────────────────────────────────────────────
const cds = require('@sap/cds');
const LOG = cds.log('bp-service');

module.exports = class BPService extends cds.ApplicationService {

  async init() {
    const { BusinessPartners, BPAddresses, BPRoles, BPTaxNumbers, BPStatuses } = this.entities;

    // ════════════════════════════════════════════════════════════════════════
    // BEFORE CREATE — validation + fullName computation
    // ════════════════════════════════════════════════════════════════════════
    this.before('CREATE', BusinessPartners, (req) => {
      const d = req.data;

      // Category is mandatory
      if (!d.category_code && !d.categoryCode) {
        req.error(400, 'Category is mandatory.', 'categoryCode');
      }

      // Name validation per category
      const cat = d.category_code ?? d.categoryCode;
      if (cat === '2' || cat === '3') {
        if (!d.organizationName?.trim()) {
          req.error(400, 'Organisation Name is required for category Organisation/Group.', 'organizationName');
        }
        // Compute fullName for organisations
        if (d.organizationName) d.fullName = d.organizationName.trim();
      } else if (cat === '1') {
        if (!d.lastName?.trim()) {
          req.error(400, 'Last Name is required for category Person.', 'lastName');
        }
        // Compute fullName for persons
        const parts = [d.firstName?.trim(), d.lastName?.trim()].filter(Boolean);
        d.fullName = parts.join(' ');
      }

      // Default status
      if (!d.status_code && !d.statusCode) {
        d.status_code = 'ACTIVE';
      }

      // Default correspondence language
      if (!d.correspondenceLang) {
        d.correspondenceLang = 'EN';
      }

      LOG.info(`Creating BP: category=${cat}, fullName=${d.fullName}`);
    });

    // ════════════════════════════════════════════════════════════════════════
    // BEFORE UPDATE — recompute fullName if name fields change
    // ════════════════════════════════════════════════════════════════════════
    this.before('UPDATE', BusinessPartners, async (req) => {
      const d = req.data;

      // Only recompute if name-relevant fields are in the patch
      const hasNameChange = d.organizationName !== undefined
        || d.firstName !== undefined
        || d.lastName !== undefined;

      if (!hasNameChange) return;

      // Fetch current state to merge missing fields
      const current = await SELECT.one
        .from(BusinessPartners, req.params[0])
        .columns('category_code', 'organizationName', 'firstName', 'lastName');

      if (!current) return req.error(404, 'Business Partner not found.');

      const cat = current.category_code;

      if (cat === '2' || cat === '3') {
        const name = d.organizationName ?? current.organizationName;
        if (name) d.fullName = name.trim();
      } else if (cat === '1') {
        const first = (d.firstName ?? current.firstName ?? '').trim();
        const last  = (d.lastName  ?? current.lastName  ?? '').trim();
        d.fullName = [first, last].filter(Boolean).join(' ');
      }
    });

    // ════════════════════════════════════════════════════════════════════════
    // AFTER READ — set virtual statusCriticality for Fiori traffic lights
    // Criticality values: 0=none, 1=error(red), 2=warning(orange), 3=ok(green)
    // ════════════════════════════════════════════════════════════════════════
    this.after('READ', BusinessPartners, (results) => {
      const bps = Array.isArray(results) ? results : [results];
      bps.forEach(bp => {
        if (bp.isBlocked) {
          bp.statusCriticality = 1;        // red — blocked
        } else if (bp.status_code === 'ACTIVE') {
          bp.statusCriticality = 3;        // green — active
        } else {
          bp.statusCriticality = 0;        // neutral
        }
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // ON blockBP / unblockBP — bound actions: flip isBlocked + status.
    // Registered for both the active entity AND the drafts shadow entity, so
    // the buttons work whether invoked while viewing or while editing a BP.
    // We always update the persisted ACTIVE row, and mirror the result into
    // any open draft too — otherwise a later Save would overwrite the active
    // row with the draft's stale fields and silently undo the change.
    //
    // The drafts table materializes categoryCode/categoryName/statusCode/
    // statusName as flat columns (unlike the active entity, where they're a
    // live SQL view via the category/status associations) — so on the draft
    // we must patch those denormalized columns explicitly, or the edit-mode
    // form would keep showing the old status text after the action runs.
    // ════════════════════════════════════════════════════════════════════════
    const blockHandler = (toBlocked) => async (req) => {
      const id = req.params[0]?.ID ?? req.params[0];

      const bp = await SELECT.one
        .from(BusinessPartners, id)
        .columns('isBlocked', 'fullName', 'bpNumber');

      if (!bp) return req.error(404, `Business Partner not found.`);
      if (bp.isBlocked === toBlocked) {
        return `Business Partner ${bp.bpNumber} is already ${toBlocked ? 'blocked' : 'active'}.`;
      }

      const status_code = toBlocked ? 'BLOCKED' : 'ACTIVE';
      const status = await SELECT.one.from(BPStatuses, status_code).columns('name');

      const activePatch = { isBlocked: toBlocked, status_code };
      const draftPatch   = { ...activePatch, statusCode: status_code, statusName: status?.name };

      await UPDATE(BusinessPartners, id).with(activePatch);
      await UPDATE(BusinessPartners.drafts, id).with(draftPatch);

      LOG.info(`BP ${bp.bpNumber} ${toBlocked ? 'blocked' : 'unblocked'} by ${req.user.id}`);
      return `Business Partner ${bp.bpNumber} (${bp.fullName}) has been ${toBlocked ? 'blocked' : 'unblocked'}.`;
    };

    this.on('blockBP',   [BusinessPartners, BusinessPartners.drafts], blockHandler(true));
    this.on('unblockBP', [BusinessPartners, BusinessPartners.drafts], blockHandler(false));

    // ════════════════════════════════════════════════════════════════════════
    // ON getBPSummary — unbound function: aggregate counts
    // ════════════════════════════════════════════════════════════════════════
    this.on('getBPSummary', async (req) => {
      const [totalRow] = await SELECT
        .from(BusinessPartners)
        .columns(
          'COUNT(*) as total',
          `SUM(CASE WHEN isBlocked = false THEN 1 ELSE 0 END) as active`,
          `SUM(CASE WHEN isBlocked = true  THEN 1 ELSE 0 END) as blocked`,
          `SUM(CASE WHEN category_code = '1' THEN 1 ELSE 0 END) as persons`,
          `SUM(CASE WHEN category_code = '2' THEN 1 ELSE 0 END) as orgs`
        );

      return {
        totalBPs:   totalRow.total   ?? 0,
        activeBPs:  totalRow.active  ?? 0,
        blockedBPs: totalRow.blocked ?? 0,
        persons:    totalRow.persons ?? 0,
        orgs:       totalRow.orgs    ?? 0
      };
    });

    // ════════════════════════════════════════════════════════════════════════
    // Pagination guard — cap list responses to 500 rows
    // ════════════════════════════════════════════════════════════════════════
    this.before('READ', BusinessPartners, (req) => {
      const MAX = 500;
      const sel = req.query.SELECT;
      if (!sel?.limit) {
        if (sel) sel.limit = { rows: { val: MAX } };
      } else if (sel.limit.rows?.val > MAX) {
        sel.limit.rows.val = MAX;
      }
    });

    await super.init();
  }
};
