var AttendanceLegacyMigration = (function (Domain) {
  'use strict';

  var LEGACY_HEADERS = {
    slot: ['id', 'classId', 'date', 'slotNumber', 'startTime', 'endTime', 'studentCount', 'subject'],
    roster: ['classId', 'studentId', 'email', 'fullName', 'gender', 'dateOfBirth', 'phone'],
    attendance: ['attendanceId', 'sessionId', 'classId', 'slotId', 'studentId', 'email', 'checkInTime', 'status', 'source'],
    sessions: ['sessionId', 'classId', 'slotId', 'token', 'openedAt', 'expiresAt', 'status'],
  };

  var LEGACY_SHEETS = {
    attendance: 'LegacyAttendance',
    sessions: 'LegacySessions',
  };

  function headersEqual_(actual, expected) {
    return actual.length === expected.length && actual.every(function (header, index) {
      return String(header).trim() === expected[index];
    });
  }

  function headerNames_(sheet) {
    if (sheet.getLastRow() === 0 || sheet.getLastColumn() === 0) {
      return [];
    }
    return sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0].map(function (header) {
      return String(header).trim();
    });
  }

  function readRows_(sheet) {
    var headers = headerNames_(sheet);
    if (headers.length === 0 || sheet.getLastRow() < 2) {
      return [];
    }
    return sheet.getRange(2, 1, sheet.getLastRow() - 1, headers.length).getValues()
      .filter(function (row) {
        return row.some(function (value) { return !Domain.isBlank(value); });
      })
      .map(function (row) {
        var record = {};
        headers.forEach(function (header, index) { record[header] = row[index]; });
        return record;
      });
  }

  function text_(value) {
    return Domain.isBlank(value) ? '' : String(value).trim();
  }

  function date_(value) {
    if (value instanceof Date && !Number.isNaN(value.getTime())) {
      return Utilities.formatDate(value, Session.getScriptTimeZone(), 'yyyy-MM-dd');
    }
    return text_(value);
  }

  function time_(value) {
    if (value instanceof Date && !Number.isNaN(value.getTime())) {
      return Utilities.formatDate(value, Session.getScriptTimeZone(), 'HH:mm');
    }
    return text_(value);
  }

  // Converts only the live class, slot and roster data required for new sessions.
  // Existing Attendance and Sessions are preserved in Legacy* tabs because their
  // old row contracts do not provide a verifiable Form response or QR grant.
  function createPlan(slotRows, rosterRowsByClass, now) {
    var classes = {};
    var classSlots = [];
    var roster = [];
    var seenRoster = {};
    now = now || new Date().toISOString();

    slotRows.forEach(function (slot) {
      var classId = text_(slot.classId);
      if (!classId) {
        return;
      }
      if (!classes[classId]) {
        var subject = text_(slot.subject);
        classes[classId] = {
          class_id: classId,
          course_code: subject || classId,
          name: subject || classId,
          room: '',
          schedule_description: '',
          is_active: 'true',
          created_at: now,
          updated_at: now,
        };
      }
      var slotId = text_(slot.id);
      var slotNumber = Number(slot.slotNumber);
      var sessionDate = date_(slot.date);
      if (slotId && Number.isInteger(slotNumber) && sessionDate) {
        classSlots.push({
          slot_id: slotId,
          class_id: classId,
          slot_number: slotNumber,
          time_range: [time_(slot.startTime), time_(slot.endTime)].filter(Boolean).join(' - '),
          session_date: sessionDate,
          is_active: 'true',
          created_at: now,
          updated_at: now,
        });
      }
    });

    Object.keys(rosterRowsByClass).forEach(function (classId) {
      rosterRowsByClass[classId].forEach(function (student) {
        var email = text_(student.email).toLowerCase();
        if (!email) {
          return;
        }
        var key = classId + '|' + email;
        if (seenRoster[key]) {
          return;
        }
        seenRoster[key] = true;
        roster.push({
          roster_id: text_(student.studentId) || 'LEGACY_' + classId + '_' + roster.length,
          class_id: classId,
          email: email,
          email_key: email,
          student_name: text_(student.fullName),
          is_active: 'true',
          created_at: now,
          updated_at: now,
        });
      });
    });

    return {
      classes: Object.keys(classes).map(function (classId) { return classes[classId]; }),
      classSlots: classSlots,
      roster: roster,
    };
  }

  function requireSafeTarget_(spreadsheet, sheetName) {
    var sheet = spreadsheet.getSheetByName(sheetName);
    if (!sheet) {
      return;
    }
    var headers = headerNames_(sheet);
    if (headersEqual_(headers, Domain.HEADERS[sheetName]) && sheet.getLastRow() <= 1) {
      return;
    }
    Domain.fail('migration_not_safe', 'Cannot replace populated or unknown sheet ' + sheetName + '.', {
      sheet: sheetName,
    });
  }

  function renameLegacySheet_(spreadsheet, currentName, archivedName, expectedHeaders) {
    var sheet = spreadsheet.getSheetByName(currentName);
    if (!sheet) {
      return;
    }
    var headers = headerNames_(sheet);
    if (headersEqual_(headers, Domain.HEADERS[currentName])) {
      return;
    }
    if (!headersEqual_(headers, expectedHeaders)) {
      Domain.fail('migration_not_safe', 'Sheet ' + currentName + ' does not match the expected legacy schema.', {
        sheet: currentName,
        headers: headers,
      });
    }
    if (spreadsheet.getSheetByName(archivedName)) {
      Domain.fail('migration_not_safe', 'Archive sheet ' + archivedName + ' already exists.', {
        sheet: archivedName,
      });
    }
    sheet.setName(archivedName);
  }

  function ensureCanonicalSheet_(spreadsheet, sheetName) {
    var sheet = spreadsheet.getSheetByName(sheetName);
    if (!sheet) {
      sheet = spreadsheet.insertSheet(sheetName);
      sheet.getRange(1, 1, 1, Domain.HEADERS[sheetName].length).setValues([Domain.HEADERS[sheetName]]);
      sheet.setFrozenRows(1);
      return sheet;
    }
    var headers = headerNames_(sheet);
    if (!headersEqual_(headers, Domain.HEADERS[sheetName])) {
      Domain.fail('schema_mismatch', 'Canonical sheet ' + sheetName + ' has unexpected headers.', {
        sheet: sheetName,
      });
    }
    return sheet;
  }

  function appendPlan_(spreadsheet, plan) {
    [
      { sheet: Domain.SHEETS.classes, rows: plan.classes },
      { sheet: Domain.SHEETS.classSlots, rows: plan.classSlots },
      { sheet: Domain.SHEETS.roster, rows: plan.roster },
    ].forEach(function (item) {
      if (item.rows.length === 0) {
        return;
      }
      var sheet = spreadsheet.getSheetByName(item.sheet);
      if (sheet.getLastRow() > 1) {
        Domain.fail('migration_not_safe', 'Canonical sheet ' + item.sheet + ' is already populated.', {
          sheet: item.sheet,
        });
      }
      var values = item.rows.map(function (row) {
        return Domain.HEADERS[item.sheet].map(function (header) { return row[header] || ''; });
      });
      sheet.getRange(2, 1, values.length, Domain.HEADERS[item.sheet].length).setValues(values);
    });
  }

  function migrate(spreadsheet) {
    var slotSheet = spreadsheet.getSheetByName('Slot');
    if (!slotSheet || !headersEqual_(headerNames_(slotSheet), LEGACY_HEADERS.slot)) {
      Domain.fail('migration_not_safe', 'Legacy Slot sheet is missing or has unexpected headers.', null);
    }
    Object.keys(Domain.HEADERS).forEach(function (sheetName) {
      if (sheetName !== Domain.SHEETS.attendance && sheetName !== Domain.SHEETS.sessions) {
        requireSafeTarget_(spreadsheet, sheetName);
      }
    });
    renameLegacySheet_(spreadsheet, Domain.SHEETS.attendance, LEGACY_SHEETS.attendance, LEGACY_HEADERS.attendance);
    renameLegacySheet_(spreadsheet, Domain.SHEETS.sessions, LEGACY_SHEETS.sessions, LEGACY_HEADERS.sessions);

    var rosterRowsByClass = {};
    spreadsheet.getSheets().forEach(function (sheet) {
      var name = sheet.getName();
      if (!/^Class_/.test(name)) {
        return;
      }
      var headers = headerNames_(sheet);
      if (!headersEqual_(headers, LEGACY_HEADERS.roster)) {
        Domain.fail('migration_not_safe', 'Roster tab ' + name + ' has unexpected headers.', { sheet: name });
      }
      var rows = readRows_(sheet);
      var classId = rows.length > 0 ? text_(rows[0].classId) : name;
      rosterRowsByClass[classId || name] = rows;
    });

    Object.keys(Domain.HEADERS).forEach(function (sheetName) { ensureCanonicalSheet_(spreadsheet, sheetName); });
    var plan = createPlan(readRows_(slotSheet), rosterRowsByClass, new Date().toISOString());
    appendPlan_(spreadsheet, plan);
    return {
      migrated: true,
      archived_sheets: [LEGACY_SHEETS.attendance, LEGACY_SHEETS.sessions],
      classes: plan.classes.length,
      slots: plan.classSlots.length,
      roster: plan.roster.length,
    };
  }

  return {
    createPlan: createPlan,
    migrate: migrate,
  };
})(typeof module !== 'undefined' && module.exports ? require('./00_attendance_domain.js') : AttendanceDomain);

if (typeof module !== 'undefined' && module.exports) {
  module.exports = AttendanceLegacyMigration;
}
