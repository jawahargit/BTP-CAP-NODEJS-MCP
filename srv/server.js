// srv/server.js
// ─────────────────────────────────────────────────────────────────────────────
// BTP Cloud Foundry requires health-check-type: http
// This registers /health before CAP mounts its own routes
// ─────────────────────────────────────────────────────────────────────────────
const cds = require('@sap/cds');

cds.on('bootstrap', (app) => {
  app.get('/health', (_req, res) => {
    res.json({ status: 'UP', timestamp: new Date().toISOString() });
  });
});

module.exports = cds.server; // ✅ delegate everything else to the default CAP server
