var GoogleSheetsGateway = (function () {
  'use strict';

  function Gateway(Domain, spreadsheetId) {
    this._domain = Domain;
    this._spreadsheet = SpreadsheetApp.openById(
      Domain.requireString(spreadsheetId, 'ATTENDANCE_SPREADSHEET_ID')
    );
  }

  Gateway.prototype.read = function (sheetName) {
    var sheet = this._requireSheet(sheetName);
    var lastRow = sheet.getLastRow();
    var lastColumn = sheet.getLastColumn();
    if (lastRow === 0 || lastColumn === 0) {
      this._domain.fail('schema_missing', 'Sheet ' + sheetName + ' has no header row.', {
        sheet: sheetName,
      });
    }

    var values = sheet.getRange(1, 1, lastRow, lastColumn).getValues();
    var headers = values[0].map(function (header) {
      return String(header).trim();
    });
    this._assertHeaders(sheetName, headers);

    return values.slice(1).reduce(function (records, row, index) {
      var hasValue = row.some(function (value) {
        return !this._domain.isBlank(value);
      }, this);
      if (!hasValue) {
        return records;
      }

      var data = {};
      headers.forEach(function (header, columnIndex) {
        data[header] = row[columnIndex];
      });
      records.push({ rowNumber: index + 2, data: data });
      return records;
    }.bind(this), []);
  };

  Gateway.prototype.append = function (sheetName, data) {
    var sheet = this._requireSheet(sheetName);
    var headers = this._headersForSheet(sheetName, sheet);
    var row = headers.map(function (header) {
      return Object.prototype.hasOwnProperty.call(data, header) ? data[header] : '';
    });
    var rowNumber = sheet.getLastRow() + 1;
    sheet.getRange(rowNumber, 1, 1, headers.length).setValues([row]);
    return { rowNumber: rowNumber, data: data };
  };

  Gateway.prototype.update = function (sheetName, rowNumber, patch) {
    var sheet = this._requireSheet(sheetName);
    var headers = this._headersForSheet(sheetName, sheet);
    if (!Number.isInteger(rowNumber) || rowNumber < 2 || rowNumber > sheet.getLastRow()) {
      this._domain.fail('not_found', 'Row does not exist in ' + sheetName + '.', {
        sheet: sheetName,
        rowNumber: rowNumber,
      });
    }

    var values = sheet.getRange(rowNumber, 1, 1, headers.length).getValues()[0];
    var next = {};
    headers.forEach(function (header, index) {
      next[header] = Object.prototype.hasOwnProperty.call(patch, header)
        ? patch[header]
        : values[index];
    });
    sheet.getRange(rowNumber, 1, 1, headers.length).setValues([
      headers.map(function (header) {
        return next[header];
      }),
    ]);
    return { rowNumber: rowNumber, data: next };
  };

  Gateway.prototype.withLock = function (callback) {
    var lock = LockService.getScriptLock();
    try {
      lock.waitLock(10000);
    } catch (error) {
      this._domain.fail('concurrency_timeout', 'Attendance data is busy. Retry the request.', null);
    }

    try {
      return callback();
    } finally {
      lock.releaseLock();
    }
  };

  Gateway.prototype.initializeSchema = function () {
    var spreadsheet = this._spreadsheet;
    var domain = this._domain;
    Object.keys(domain.HEADERS).forEach(function (sheetName) {
      var headers = domain.HEADERS[sheetName];
      var sheet = spreadsheet.getSheetByName(sheetName);
      if (!sheet) {
        sheet = spreadsheet.insertSheet(sheetName);
        sheet.getRange(1, 1, 1, headers.length).setValues([headers]);
        sheet.setFrozenRows(1);
        return;
      }

      if (sheet.getLastRow() === 0) {
        sheet.getRange(1, 1, 1, headers.length).setValues([headers]);
        sheet.setFrozenRows(1);
        return;
      }

      this._assertHeaders(sheetName, this._headersForSheet(sheetName, sheet));
    }, this);
  };

  Gateway.prototype._requireSheet = function (sheetName) {
    var sheet = this._spreadsheet.getSheetByName(sheetName);
    if (!sheet) {
      this._domain.fail('schema_missing', 'Sheet ' + sheetName + ' is missing.', {
        sheet: sheetName,
      });
    }
    return sheet;
  };

  Gateway.prototype._headersForSheet = function (sheetName, sheet) {
    if (sheet.getLastRow() === 0 || sheet.getLastColumn() === 0) {
      this._domain.fail('schema_missing', 'Sheet ' + sheetName + ' has no header row.', {
        sheet: sheetName,
      });
    }
    var headers = sheet
      .getRange(1, 1, 1, sheet.getLastColumn())
      .getValues()[0]
      .map(function (header) {
        return String(header).trim();
      });
    this._assertHeaders(sheetName, headers);
    return headers;
  };

  Gateway.prototype._assertHeaders = function (sheetName, actualHeaders) {
    var expectedHeaders = this._domain.HEADERS[sheetName];
    if (!expectedHeaders) {
      this._domain.fail('schema_missing', 'Unknown attendance sheet: ' + sheetName + '.', {
        sheet: sheetName,
      });
    }
    var missing = expectedHeaders.filter(function (header) {
      return actualHeaders.indexOf(header) === -1;
    });
    if (missing.length > 0) {
      this._domain.fail('schema_mismatch', 'Sheet ' + sheetName + ' is missing required columns.', {
        sheet: sheetName,
        missing: missing,
      });
    }
  };

  return Gateway;
})(typeof module !== 'undefined' && module.exports ? require('./attendance_domain.js') : AttendanceDomain);

if (typeof module !== 'undefined' && module.exports) {
  module.exports = GoogleSheetsGateway;
}
