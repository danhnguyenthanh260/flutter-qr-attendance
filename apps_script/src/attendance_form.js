var AttendanceFormGateway = (function (Domain) {
  'use strict';

  function createPrefilledUrl(config, grantId) {
    var form = FormApp.openById(config.formId);
    var grantItem = form.getItemById(config.grantItemId).asTextItem();
    return form
      .createResponse()
      .withItemResponse(grantItem.createResponse(Domain.requireString(grantId, 'grant_id')))
      .toPrefilledUrl();
  }

  function parseSubmission(event, config) {
    if (!event || !event.response) {
      Domain.fail('invalid_form_event', 'The Form submit trigger did not include a response.', null);
    }
    var response = event.response;
    var valuesByItemId = {};
    var rawItems = [];
    response.getItemResponses().forEach(function (itemResponse) {
      var itemId = String(itemResponse.getItem().getId());
      var value = itemResponse.getResponse();
      valuesByItemId[itemId] = value;
      rawItems.push({ item_id: itemId, response: value });
    });
    var grantId = valuesByItemId[String(config.grantItemId)];
    return {
      form_response_id: Domain.requireString(response.getId(), 'form_response_id'),
      submitted_at: response.getTimestamp().toISOString(),
      // This value is supplied by Google Forms only after the respondent signs
      // into a Google account. A manually typed email is deliberately not used.
      email: Domain.requireString(response.getRespondentEmail(), 'respondent_email'),
      grant_id: Domain.requireString(grantId, 'grant_id'),
      raw_payload: { item_responses: rawItems },
    };
  }

  // Run manually once after deployment when no existing Form is supplied.
  // The signed-in respondent email is the attendance identity; the only visible
  // answer field is the prefilled server grant.
  function createAttendanceForm(spreadsheetId, title) {
    var form = FormApp.create(title || 'Điểm danh lớp học');
    form.setDescription('Điểm danh được ghi nhận bằng tài khoản Google đang đăng nhập. Không chỉnh sửa mã xác nhận được điền sẵn.');
    form.setConfirmationMessage('Yêu cầu điểm danh đã được tiếp nhận để kiểm tra.');
    form.setCollectEmail(true);
    var grantItem = form.addTextItem()
      .setTitle('Mã xác nhận')
      .setHelpText('Mã này được hệ thống điền sẵn. Không thay đổi.')
      .setRequired(true);
    form.setDestination(FormApp.DestinationType.SPREADSHEET, Domain.requireString(spreadsheetId, 'spreadsheet_id'));
    PropertiesService.getScriptProperties().setProperties({
      ATTENDANCE_FORM_ID: form.getId(),
      ATTENDANCE_FORM_GRANT_ITEM_ID: String(grantItem.getId()),
    }, false);
    return {
      form_id: form.getId(),
      form_url: form.getPublishedUrl(),
      grant_item_id: grantItem.getId(),
    };
  }

  function ensureSubmitTrigger(formId) {
    var form = FormApp.openById(formId);
    var exists = ScriptApp.getProjectTriggers().some(function (trigger) {
      return trigger.getHandlerFunction() === 'onAttendanceFormSubmit' &&
        trigger.getEventType() === ScriptApp.EventType.ON_FORM_SUBMIT;
    });
    if (!exists) {
      ScriptApp.newTrigger('onAttendanceFormSubmit').forForm(form).onFormSubmit().create();
    }
    return { installed: true };
  }

  return {
    createPrefilledUrl: createPrefilledUrl,
    parseSubmission: parseSubmission,
    createAttendanceForm: createAttendanceForm,
    ensureSubmitTrigger: ensureSubmitTrigger,
  };
})(typeof module !== 'undefined' && module.exports ? require('./attendance_domain.js') : AttendanceDomain);

function onAttendanceFormSubmit(event) {
  var studentConfig = AttendanceConfig.getStudentFlowConfig();
  var submission = AttendanceFormGateway.parseSubmission(event, studentConfig);
  return StudentAttendanceService.processFormSubmission(
    AttendanceConfig.createLiveContext().service,
    submission
  );
}

function createConfiguredAttendanceForm() {
  var config = AttendanceConfig.getConfig();
  var created = AttendanceFormGateway.createAttendanceForm(
    config.spreadsheetId,
    'Điểm danh QR - Test_PRM392'
  );
  AttendanceFormGateway.ensureSubmitTrigger(created.form_id);
  return created;
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = AttendanceFormGateway;
}
