var TeacherApiContract = (function (Domain, StudentService) {
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
        case 'weekly_overview':
          return Domain.success(service.getWeeklyOverview());
        case 'class_overview':
          return Domain.success(service.getTeachingOverview(Domain.requireString(payload.class_id, 'class_id')));
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
        case 'import_roster':
          return Domain.success(service.importRoster(payload));
        case 'start_session':
          return Domain.success(service.startSession({
            class_id: payload.class_id,
            slot: payload.slot,
            request_id: payload.request_id,
            teacher_id: payload.teacher_id,
          }));
        case 'close_session':
          return Domain.success(service.requestCloseSession(Domain.requireString(payload.session_id, 'session_id')));
        case 'issue_qr':
          return Domain.success(StudentService.issueQrTicket(
            service,
            context.studentConfig,
            Domain.requireString(payload.session_id, 'session_id'),
            payload.request_id,
            context.formGateway
          ));
        default:
          Domain.fail('unknown_action', 'Unsupported POST action.', { action: action });
      }
    }

    Domain.fail('method_not_allowed', 'Only GET and POST are supported.', { method: method });
  }

  return { execute: execute };
})(
  typeof module !== 'undefined' && module.exports ? require('./00_attendance_domain.js') : AttendanceDomain,
  typeof module !== 'undefined' && module.exports ? require('./07_student_attendance_service.js') : StudentAttendanceService
);

function doGet(event) {
  var payload = getTeacherApiPayload_(event);
  if (payload.route === 'claim') {
    return createStudentClaimResponse_(payload);
  }
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
  var started = Date.now();
  try {
    var context = AttendanceConfig.createLiveContext();
    if (payload.action === 'issue_qr') {
      context.studentConfig = AttendanceConfig.getStudentFlowConfig();
      context.formGateway = AttendanceFormGateway;
    }
    envelope = TeacherApiContract.execute(method, payload, context);
  } catch (error) {
    envelope = AttendanceDomain.errorEnvelope(error);
  }
  console.info(JSON.stringify({event: 'teacher_api_complete', action: String(payload.action).slice(0, 40),
    ms: Date.now() - started, ok: envelope.ok, code: envelope.error ? envelope.error.code : null,
    trace_id: /^[0-9-]{1,64}$/.test(String(payload._trace_id || '')) ? payload._trace_id : null}));
  return createTeacherApiOutput_(envelope);
}

function createStudentClaimResponse_(payload) {
  try {
    var context = AttendanceConfig.createLiveContext();
    var claim = StudentAttendanceService.claimQrTicket(
      context.service,
      AttendanceFormGateway,
      AttendanceConfig.getStudentFlowConfig(),
      payload.ticket_id
    );
    return StudentAttendanceService.createClaimHtmlOutput(claim);
  } catch (error) {
    var envelope = AttendanceDomain.errorEnvelope(error);
    return HtmlService.createHtmlOutput(
      '<!doctype html><html><body><p>Không thể mở biểu mẫu điểm danh.</p><p>' +
        String(envelope.error.message).replace(/&/g, '&amp;').replace(/</g, '&lt;') +
      '</p></body></html>'
    ).setTitle('Điểm danh');
  }
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
