// srv/mcp.cds
// ─────────────────────────────────────────────────────────────────────────────
// MCP (Model Context Protocol) annotations — @gavdi/cap-mcp
// Exposes BPService to MCP-compatible AI agents as resources, tools and hints.
// Kept isolated from bp-service.cds and annotations.cds, mirroring how Fiori
// UI annotations are kept separate from the domain/service definitions.
// ─────────────────────────────────────────────────────────────────────────────
using BPService from './bp-service';

// ── BusinessPartners — MCP resource with field-level hints ───────────────────
annotate BPService.BusinessPartners with @(
  mcp: {
    name       : 'business-partners',
    description: 'Business Partner master data: persons, organisations, and groups, with blocked/active status. Supports OData v4 query options for filtering, sorting, paging and field selection.',
    resource   : ['filter', 'orderby', 'select', 'top', 'skip', 'expand']
  }
) {
  ID           @mcp.hint: 'Internal UUID primary key. Prefer bpNumber for human-facing lookups and conversation.';
  bpNumber     @mcp.hint: 'Human-readable Business Partner number (e.g. "1000000005"). The primary identifier to use when discussing a specific partner.';
  categoryCode @mcp.hint: 'Category code: "1"=Person, "2"=Organisation, "3"=Group. Resolve display names via the bp-categories resource.';
  statusCode   @mcp.hint: 'Status code: "ACTIVE" or "BLOCKED". Resolve display names via the bp-statuses resource.';
  isBlocked    @mcp.hint: 'True if the Business Partner is blocked from transactions. Always kept in sync with statusCode — do not set directly; use the block/unblock tools.';
  fullName     @mcp.hint: 'Display name: organizationName for orgs/groups, "firstName lastName" for persons. Computed by the server on every create/update.';
  searchTerm   @mcp.hint: 'Short uppercase search key used for fuzzy lookups (e.g. "SAPSE" for SAP SE).';
};

// Also expose read-only wrapper tools (query/get) alongside the resource —
// gives agents a discrete, named tool in addition to raw OData querying.
// Deliberately NOT wrapping create/update: BusinessPartners is draft-enabled
// with a multi-step Fiori edit flow (draft/activate, composed child entities);
// creates/updates should go through the UI, not a raw MCP tool call.
annotate BPService.BusinessPartners with @mcp.wrap: {
  tools: true,
  modes: ['query', 'get'],
  hint : 'Use for read-only lookups of Business Partners. To change blocked status, use the block-business-partner / unblock-business-partner tools rather than updating fields directly.'
};

// ── Code lists — small static resources for resolving category/status names ──
annotate BPService.BPCategories with @mcp: {
  name       : 'bp-categories',
  description: 'Code list of Business Partner categories: Person, Organisation, Group.',
  resource   : []
};

annotate BPService.BPStatuses with @mcp: {
  name       : 'bp-statuses',
  description: 'Code list of Business Partner statuses: Active, Blocked.',
  resource   : []
};

// ── Business actions as MCP tools ─────────────────────────────────────────────
annotate BPService.BusinessPartners with actions {
  blockBP @mcp: {
    name       : 'block-business-partner',
    description: 'Blocks a Business Partner from transactions, setting status to BLOCKED. Requires BP_PROCESSOR or BP_ADMIN role.',
    tool       : true,
    elicit     : ['confirm']
  };

  unblockBP @mcp: {
    name       : 'unblock-business-partner',
    description: 'Unblocks a previously blocked Business Partner, restoring ACTIVE status. Requires BP_ADMIN role.',
    tool       : true,
    elicit     : ['confirm']
  };
};

annotate BPService.getBPSummary with @mcp: {
  name       : 'get-bp-summary',
  description: 'Returns aggregate Business Partner counts: total, active, blocked, persons, and organisations.',
  tool       : true
};
