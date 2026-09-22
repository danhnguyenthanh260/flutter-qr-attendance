var AttendanceConfig = (function (Domain, Gateway, DataService) {
  'use strict';

  function requireScriptProperty_(properties, name) {
    var value = properties.getProperty(name);
    if (Domain.isBlank(value)) {
      Domain.fail('configuration_missing', name + ' is not configured in Script Properties.', {
        property: name,
      });
    }
    return String(value).trim();
  }

  function getConfig() {
    var properties = PropertiesService.getScriptProperties();
    return {
      spreadsheetId: requireScriptProperty_(properties, 'ATTENDANCE_SPREADSHEET_ID'),
      teacherApiKey: requireScriptProperty_(properties, 'TEACHER_API_KEY'),
    };
  }

  function getStudentFlowConfig() {
    var properties = PropertiesService.getScriptProperties();
    var graceSeconds = Number(requireScriptProperty_(properties, 'ATTENDANCE_GRACE_SECONDS'));
    if (!Number.isInteger(graceSeconds) || graceSeconds <= 0) {
      Domain.fail('configuration_missing', 'ATTENDANCE_GRACE_SECONDS must be a positive integer.', {
        property: 'ATTENDANCE_GRACE_SECONDS',
      });
    }
    return {
      formId: requireScriptProperty_(properties, 'ATTENDANCE_FORM_ID'),
      grantItemId: Number(requireScriptProperty_(properties, 'ATTENDANCE_FORM_GRANT_ITEM_ID')),
      webAppUrl: requireScriptProperty_(properties, 'ATTENDANCE_WEB_APP_URL'),
      graceSeconds: graceSeconds,
      qrValidSeconds: 30,
    };
  }

  function createLiveContext() {
    var config = getConfig();
    var gateway = new Gateway(Domain, config.spreadsheetId);
    return {
      config: config,
      service: DataService.create(gateway),
    };
  }

  function initializeConfiguredSpreadsheet() {
    var context = createLiveContext();
    return context.service.initializeSchema();
  }

  // Run manually once for the pre-existing Test_PRM392 layout. It preserves the
  // old attendance/session tabs as LegacyAttendance and LegacySessions, then
  // creates the canonical sheets used by the QR + Google Form flow.
  function migrateConfiguredLegacySpreadsheet() {
    var config = getConfig();
    return AttendanceLegacyMigration.migrate(SpreadsheetApp.openById(config.spreadsheetId));
  }

  return {
    getConfig: getConfig,
    getStudentFlowConfig: getStudentFlowConfig,
    createLiveContext: createLiveContext,
    initializeConfiguredSpreadsheet: initializeConfiguredSpreadsheet,
    migrateConfiguredLegacySpreadsheet: migrateConfiguredLegacySpreadsheet,
  };
})(
  typeof module !== 'undefined' && module.exports ? require('./attendance_domain.js') : AttendanceDomain,
  typeof module !== 'undefined' && module.exports ? require('./sheets_gateway.js') : GoogleSheetsGateway,
  typeof module !== 'undefined' && module.exports ? require('./attendance_service.js') : AttendanceDataService
);

if (typeof module !== 'undefined' && module.exports) {
  module.exports = AttendanceConfig;
}

function migrateLegacyTestPrm392() {
  return AttendanceConfig.migrateConfiguredLegacySpreadsheet();
}
