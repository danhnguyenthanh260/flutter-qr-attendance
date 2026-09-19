var TeacherApiContract = (function (Domain) {
  'use strict';

  function authenticate_(payload, expectedKey) {
    var suppliedKey = Domain.optionalString(payload.teacher_key);
    if (!suppliedKey || suppliedKey !== expectedKey) {
      Domain.fail('unauthorized', 'Teacher authentication failed.', null);
    }
  }

  function execute(method, payload, context) {
    payload = payload || {};
    authenticate_(payload, context.config.teacherApiKey);
    var action = Domain.requireString(payload.action, 'action');
    var service = context.service;

    if (method === 'GET') {
      switch (action) {
        case 'classes':
          return Domain.success(service.listClasses());
        case 'slots':
          return Domain.success(service.listSlotsForClass(Domain.requireString(payload.class_id, 'class_id')));
        case 'active_session':
          return Domain.success(service.getActiveSession());
        case 'sessions':
          return Domain.success(service.listSessions({
            class_id: Domain.optionalString(payload.class_id),
            date: Domain.optionalString(payload.date),
          }));
        case 'session_results':
          return Domain.success(service.getSessionResults(Domain.requireString(payload.session_id, 'session_id')));
        default:
          Domain.fail('unknown_action', 'Unsupported GET action.', { action: action });
      }
    }

    if (method === 'POST') {
      switch (action) {
        case 'start_session':
          return Domain.success(service.startSession({
            class_id: payload.class_id,
            slot: payload.slot,
            request_id: payload.request_id,
            teacher_id: payload.teacher_id,
          }));
        case 'close_session':
          return Domain.success(service.requestCloseSession(Domain.requireString(payload.session_id, 'session_id')));
        default:
          Domain.fail('unknown_action', 'Unsupported POST action.', { action: action });
      }
    }

    Domain.fail('method_not_allowed', 'Only GET and POST are supported.', { method: method });
  }

  return { execute: execute };
})(typeof module !== 'undefined' && module.exports ? require('./attendance_domain.js') : AttendanceDomain);

function doGet(event) {
  return createTeacherApiResponseFromEvent_('GET', event);
}

function doPost(event) {
  return createTeacherApiResponseFromEvent_('POST', event);
}

function createTeacherApiResponseFromEvent_(method, event) {
  try {
    return createTeacherApiResponse_(method, getTeacherApiPayload_(event));
  } catch (error) {
    return createTeacherApiOutput_(AttendanceDomain.errorEnvelope(error));
  }
}

function createTeacherApiResponse_(method, payload) {
  var envelope;
  try {
    envelope = TeacherApiContract.execute(method, payload, AttendanceConfig.createLiveContext());
  } catch (error) {
    envelope = AttendanceDomain.errorEnvelope(error);
  }
  return createTeacherApiOutput_(envelope);
}

function createTeacherApiOutput_(envelope) {
  return ContentService
    .createTextOutput(JSON.stringify(envelope))
    .setMimeType(ContentService.MimeType.JSON);
}

function getTeacherApiPayload_(event) {
  var query = (event && event.parameter) || {};
  var body = {};
  if (event && event.postData && event.postData.contents) {
    try {
      body = JSON.parse(event.postData.contents);
    } catch (error) {
      AttendanceDomain.fail('invalid_json', 'Request body must be valid JSON.', null);
    }
  }
  var payload = {};
  Object.keys(query).forEach(function (key) {
    payload[key] = query[key];
  });
  Object.keys(body).forEach(function (key) {
    payload[key] = body[key];
  });
  return payload;
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = TeacherApiContract;
}
