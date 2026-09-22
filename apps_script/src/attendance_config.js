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

  return {
    getConfig: getConfig,
    createLiveContext: createLiveContext,
    initializeConfiguredSpreadsheet: initializeConfiguredSpreadsheet,
  };
})(
  typeof module !== 'undefined' && module.exports ? require('./attendance_domain.js') : AttendanceDomain,
  typeof module !== 'undefined' && module.exports ? require('./sheets_gateway.js') : GoogleSheetsGateway,
  typeof module !== 'undefined' && module.exports ? require('./attendance_service.js') : AttendanceDataService
);

if (typeof module !== 'undefined' && module.exports) {
  module.exports = AttendanceConfig;
}
