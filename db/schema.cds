// db/schema.cds
// ─────────────────────────────────────────────────────────────────────────────
// Business Partner domain model
// All entities use UUID keys (cuid) — required for draft and Fiori Elements
// ─────────────────────────────────────────────────────────────────────────────
namespace com.bp.manager;

using { cuid, managed, Country, sap.common.CodeList } from '@sap/cds/common';

// ── Code list: BP Category ────────────────────────────────────────────────────
entity BPCategories : CodeList {
  key code : String(1);  // 1=Person, 2=Organisation, 3=Group
}

// ── Code list: BP Status ──────────────────────────────────────────────────────
entity BPStatuses : CodeList {
  key code : String(10);  // ACTIVE, BLOCKED
}

// ── Core entity: Business Partner ────────────────────────────────────────────
entity BusinessPartners : cuid, managed {
  // Identity
  bpNumber          : String(10);               // assigned by number range
  category          : Association to BPCategories;
  status            : Association to BPStatuses default 'ACTIVE';
  isBlocked         : Boolean default false;

  // Name fields — used by both persons and organisations
  organizationName  : String(40);               // category = 2 or 3
  firstName         : String(40);               // category = 1
  lastName          : String(40);               // category = 1
  fullName          : String(81);               // computed/stored on write

  searchTerm        : String(20);
  correspondenceLang: String(2) default 'EN';

  // Compositions
  addresses         : Composition of many BPAddresses         on addresses.bp = $self;
  roles             : Composition of many BPRoles             on roles.bp = $self;
  taxNumbers        : Composition of many BPTaxNumbers        on taxNumbers.bp = $self;

  // Virtual — for Fiori criticality colouring (0=none,1=error,2=warning,3=ok)
  virtual statusCriticality : Integer;
}

// ── Address ───────────────────────────────────────────────────────────────────
entity BPAddresses : cuid {
  bp          : Association to BusinessPartners;
  isDefault   : Boolean default false;
  country     : Country;
  region      : String(3);
  city        : String(40);
  postalCode  : String(10);
  streetName  : String(60);
  houseNumber : String(10);
  language    : String(2) default 'EN';
  addressUsage: String(20) default 'XXDEFAULT';
}

// ── Roles ─────────────────────────────────────────────────────────────────────
entity BPRoles : cuid {
  bp              : Association to BusinessPartners;
  businessPartnerRole : String(6);  // e.g. FLCU01, FLVN01
  validFrom       : Date;
  validTo         : Date;
}

// ── Tax Numbers ───────────────────────────────────────────────────────────────
entity BPTaxNumbers : cuid {
  bp          : Association to BusinessPartners;
  taxType     : String(4);   // e.g. DE0 (German VAT)
  taxNumber   : String(20);
}
