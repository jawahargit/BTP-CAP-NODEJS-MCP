// srv/annotations.cds
// ─────────────────────────────────────────────────────────────────────────────
// Fiori Elements OData V4 annotations
// Drives: List Report Page + Object Page (with facets for Address, Roles, Tax)
// ─────────────────────────────────────────────────────────────────────────────
using BPService from './bp-service';

// ════════════════════════════════════════════════════════════════════════════
// BusinessPartners — List Report
// ════════════════════════════════════════════════════════════════════════════
annotate BPService.BusinessPartners with @(

  // ── List Report: table columns ──────────────────────────────────────────
  UI.LineItem: [
    { Value: bpNumber,         Label: 'BP Number' },
    { Value: fullName,         Label: 'Name' },
    { Value: categoryCode,     Label: 'Category' },
    {
      Value:                      statusCode,
      Label:                     'Status',
      Criticality:                statusCriticality,
      CriticalityRepresentation: #WithIcon
    },
    { Value: searchTerm,       Label: 'Search Term' },
    { Value: isBlocked,        Label: 'Blocked' },
    { Value: createdAt,        Label: 'Created On' }
  ],

  // ── List Report: filter bar fields ──────────────────────────────────────
  UI.SelectionFields: [
    bpNumber,
    fullName,
    categoryCode,
    statusCode,
    isBlocked,
    searchTerm
  ],

  // ── List Report / Object Page header ────────────────────────────────────
  UI.HeaderInfo: {
    TypeName:       'Business Partner',
    TypeNamePlural: 'Business Partners',
    Title:          { Value: fullName },
    Description:    { Value: bpNumber }
  },

  // ════════════════════════════════════════════════════════════════════════
  // Object Page: facet structure
  // ════════════════════════════════════════════════════════════════════════
  UI.Facets: [
    {
      $Type:  'UI.ReferenceFacet',
      ID:     'GeneralFacet',
      Label:  'General Information',
      Target: '@UI.FieldGroup#General'
    },
    {
      $Type:  'UI.ReferenceFacet',
      ID:     'NameFacet',
      Label:  'Name Details',
      Target: '@UI.FieldGroup#NameDetails'
    },
    {
      $Type:  'UI.ReferenceFacet',
      ID:     'AddressFacet',
      Label:  'Addresses',
      Target: 'addresses/@UI.LineItem'
    },
    {
      $Type:  'UI.ReferenceFacet',
      ID:     'RolesFacet',
      Label:  'Roles',
      Target: 'roles/@UI.LineItem'
    },
    {
      $Type:  'UI.ReferenceFacet',
      ID:     'TaxFacet',
      Label:  'Tax Numbers',
      Target: 'taxNumbers/@UI.LineItem'
    }
  ],

  // ── Object Page: General Information field group ─────────────────────────
  UI.FieldGroup#General: {
    Label: 'General Information',
    Data: [
      { Value: bpNumber,          Label: 'BP Number' },
      { Value: categoryCode,      Label: 'Category' },
      { Value: statusCode,        Label: 'Status' },
      { Value: isBlocked,         Label: 'Blocked' },
      { Value: searchTerm,        Label: 'Search Term' },
      { Value: correspondenceLang, Label: 'Correspondence Language' }
    ]
  },

  // ── Object Page: Name Details field group ───────────────────────────────
  UI.FieldGroup#NameDetails: {
    Label: 'Name Details',
    Data: [
      { Value: organizationName, Label: 'Organisation Name' },
      { Value: firstName,        Label: 'First Name' },
      { Value: lastName,         Label: 'Last Name' },
      { Value: fullName,         Label: 'Full Name' }
    ]
  },

  // ── Object Page: header actions (bound actions shown as buttons) ─────────
  UI.Identification: [
    {
      $Type:  'UI.DataFieldForAction',
      Action: 'BPService.EntityContainer/BusinessPartners_blockBP',
      Label:  'Block BP',
      Inline: true
    },
    {
      $Type:  'UI.DataFieldForAction',
      Action: 'BPService.EntityContainer/BusinessPartners_unblockBP',
      Label:  'Unblock BP',
      Inline: true
    }
  ]
);

// ════════════════════════════════════════════════════════════════════════════
// Value Helps (F4)
// ════════════════════════════════════════════════════════════════════════════
annotate BPService.BusinessPartners with {

  categoryCode @(
    Common.ValueList: {
      CollectionPath: 'BPCategories',
      Parameters: [
        { $Type: 'Common.ValueListParameterOut',
          LocalDataProperty: categoryCode,
          ValueListProperty: 'code' },
        { $Type: 'Common.ValueListParameterDisplayOnly',
          ValueListProperty: 'name' }
      ]
    },
    Common.ValueListWithFixedValues: true
  );

  statusCode @(
    Common.ValueList: {
      CollectionPath: 'BPStatuses',
      Parameters: [
        { $Type: 'Common.ValueListParameterOut',
          LocalDataProperty: statusCode,
          ValueListProperty: 'code' },
        { $Type: 'Common.ValueListParameterDisplayOnly',
          ValueListProperty: 'name' }
      ]
    },
    Common.ValueListWithFixedValues: true
  );

}

// ════════════════════════════════════════════════════════════════════════════
// BPAddresses — sub-entity table (Object Page addresses facet)
// ════════════════════════════════════════════════════════════════════════════
annotate BPService.BPAddresses with @(
  UI.LineItem: [
    { Value: isDefault,   Label: 'Default' },
    { Value: country_code, Label: 'Country' },
    { Value: city,        Label: 'City' },
    { Value: postalCode,  Label: 'Postal Code' },
    { Value: streetName,  Label: 'Street' },
    { Value: houseNumber, Label: 'House No.' },
    { Value: addressUsage, Label: 'Usage' }
  ],
  UI.FieldGroup#AddressDetail: {
    Label: 'Address Detail',
    Data: [
      { Value: isDefault },
      { Value: country_code },
      { Value: region },
      { Value: city },
      { Value: postalCode },
      { Value: streetName },
      { Value: houseNumber },
      { Value: language },
      { Value: addressUsage }
    ]
  }
);

// ════════════════════════════════════════════════════════════════════════════
// BPRoles — sub-entity table (Object Page roles facet)
// ════════════════════════════════════════════════════════════════════════════
annotate BPService.BPRoles with @(
  UI.LineItem: [
    { Value: businessPartnerRole, Label: 'Role' },
    { Value: validFrom,           Label: 'Valid From' },
    { Value: validTo,             Label: 'Valid To' }
  ]
);

// ════════════════════════════════════════════════════════════════════════════
// BPTaxNumbers — sub-entity table (Object Page tax facet)
// ════════════════════════════════════════════════════════════════════════════
annotate BPService.BPTaxNumbers with @(
  UI.LineItem: [
    { Value: taxType,   Label: 'Tax Type' },
    { Value: taxNumber, Label: 'Tax Number' }
  ]
);
