var AttendanceDomain = (function () {
  'use strict';

  var SHEETS = {
    classes: 'Classes',
    classSlots: 'ClassSlots',
    roster: 'Roster',
    sessions: 'Sessions',
    formResponses: 'FormResponses',
    attendance: 'Attendance',
    attempts: 'Attempts',
    ticketStates: 'TicketStates',
  };

  var HEADERS = {};
  HEADERS[SHEETS.classes] = [
    'class_id',
    'course_code',
    'name',
    'room',
    'schedule_description',
    'is_active',
    'created_at',
    'updated_at',
  ];
  HEADERS[SHEETS.classSlots] = [
    'slot_id',
    'class_id',
    'slot_number',
    'time_range',
    'session_date',
    'is_active',
    'created_at',
    'updated_at',
  ];
  HEADERS[SHEETS.roster] = [
    'roster_id',
    'class_id',
    'email',
    'email_key',
    'student_name',
    'is_active',
    'created_at',
    'updated_at',
  ];
  HEADERS[SHEETS.sessions] = [
    'session_id',
    'class_id',
    'slot_number',
    'time_range',
    'session_date',
    'status',
    'opened_at',
    'closing_at',
    'closed_at',
    'created_by',
    'request_id',
    'updated_at',
  ];
  HEADERS[SHEETS.formResponses] = [
    'form_response_id',
    'session_id',
    'ticket_id',
    'submitted_at',
    'received_at',
    'email',
    'email_key',
    'raw_payload',
    'processing_status',
    'updated_at',
  ];
  HEADERS[SHEETS.attendance] = [
    'attendance_id',
    'session_id',
    'form_response_id',
    'email',
    'email_key',
    'student_name',
    'accepted_at',
    'updated_at',
  ];
  HEADERS[SHEETS.attempts] = [
    'attempt_id',
    'session_id',
    'form_response_id',
    'email',
    'email_key',
    'attempt_type',
    'reason',
    'occurred_at',
    'updated_at',
  ];
  HEADERS[SHEETS.ticketStates] = [
    'ticket_id',
    'session_id',
    'generation',
    'issued_at',
    'expires_at',
    'status',
    'updated_at',
  ];

  function AttendanceError(code, message, details) {
    this.name = 'AttendanceError';
    this.code = code;
    this.message = message;
    this.details = details || null;
    if (Error.captureStackTrace) {
      Error.captureStackTrace(this, AttendanceError);
    }
  }
  AttendanceError.prototype = Object.create(Error.prototype);
  AttendanceError.prototype.constructor = AttendanceError;

  function fail(code, message, details) {
    throw new AttendanceError(code, message, details);
  }

  function isBlank(value) {
    return value === null || value === undefined || String(value).trim() === '';
  }

  function requireString(value, fieldName) {
    if (isBlank(value)) {
      fail('validation_error', fieldName + ' is required.', { field: fieldName });
    }
    return String(value).trim();
  }

  function optionalString(value) {
    return isBlank(value) ? '' : String(value).trim();
  }

  function normalizeEmail(value) {
    var email = requireString(value, 'email').toLowerCase();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      fail('validation_error', 'email must be a valid email address.', {
        field: 'email',
      });
    }
    return email;
  }

  function asBoolean(value) {
    return value === true || value === 1 || String(value).toLowerCase() === 'true';
  }

  function asInteger(value, fieldName) {
    if (isBlank(value)) {
      fail('validation_error', fieldName + ' is required.', {
        field: fieldName,
      });
    }
    var number = Number(value);
    if (!Number.isInteger(number)) {
      fail('validation_error', fieldName + ' must be an integer.', {
        field: fieldName,
      });
    }
    return number;
  }

  function isoTimestamp(value, fieldName, now) {
    if (isBlank(value)) {
      return now.toISOString();
    }
    var parsed = new Date(value);
    if (Number.isNaN(parsed.getTime())) {
      fail('validation_error', fieldName + ' must be an ISO timestamp.', {
        field: fieldName,
      });
    }
    return parsed.toISOString();
  }

  function isoDate(value, fieldName) {
    var text = requireString(value, fieldName);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(text)) {
      fail('validation_error', fieldName + ' must use YYYY-MM-DD.', {
        field: fieldName,
      });
    }
    return text;
  }

  function parseJsonObject(value, fieldName) {
    if (value && typeof value === 'object' && !Array.isArray(value)) {
      return value;
    }
    try {
      var parsed = JSON.parse(requireString(value, fieldName));
      if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
        fail('validation_error', fieldName + ' must be a JSON object.', {
          field: fieldName,
        });
      }
      return parsed;
    } catch (error) {
      if (error instanceof AttendanceError) {
        throw error;
      }
      fail('validation_error', fieldName + ' must be valid JSON.', {
        field: fieldName,
      });
    }
  }

  function jsonString(value) {
    return JSON.stringify(value || {});
  }

  function success(data) {
    return { ok: true, data: data };
  }

  function errorEnvelope(error) {
    var known = error && error.code && error.message;
    return {
      ok: false,
      error: {
        code: known ? error.code : 'internal_error',
        message: known ? error.message : 'Unexpected server error.',
        details: known ? error.details : null,
      },
    };
  }

  return {
    SHEETS: SHEETS,
    HEADERS: HEADERS,
    AttendanceError: AttendanceError,
    fail: fail,
    isBlank: isBlank,
    requireString: requireString,
    optionalString: optionalString,
    normalizeEmail: normalizeEmail,
    asBoolean: asBoolean,
    asInteger: asInteger,
    isoTimestamp: isoTimestamp,
    isoDate: isoDate,
    parseJsonObject: parseJsonObject,
    jsonString: jsonString,
    success: success,
    errorEnvelope: errorEnvelope,
  };
})();

if (typeof module !== 'undefined' && module.exports) {
  module.exports = AttendanceDomain;
}
