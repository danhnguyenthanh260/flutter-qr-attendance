var StudentAttendanceService = (function (Domain) {
  'use strict';

  function issueQrTicket(service, config, sessionId, requestId, formGateway) {
    var ticket = service.issueQrTicket({
      session_id: Domain.requireString(sessionId, 'session_id'),
      valid_seconds: config.qrValidSeconds,
      request_id: requestId,
      direct_form: config.directForm === true,
    });
    return ticketResponse(ticket, config, formGateway);
  }

  function getQrReceipt(service, config, sessionId, requestId, formGateway) {
    var ticket = service.getQrReceipt(sessionId, requestId);
    return ticket ? ticketResponse(ticket, config, formGateway) : null;
  }

  function ticketResponse(ticket, config, formGateway) {
    return {
      ticket_code: ticket.ticket_id,
      form_url: ticket.submission_token
        ? formGateway.createPrefilledUrl(config, ticket.submission_token)
        : buildClaimUrl(config.webAppUrl, ticket.ticket_id),
      flow: ticket.submission_token ? 'direct_form' : 'claim',
      submission_window_seconds: ticket.submission_token ? 120 : null,
      generation: ticket.generation,
      valid_seconds: config.qrValidSeconds,
      created_at: ticket.issued_at,
      expires_at: ticket.expires_at,
      server_time: new Date().toISOString(),
    };
  }

  function claimQrTicket(service, formGateway, config, ticketId) {
    var grant = service.claimQrTicket({
      ticket_id: Domain.requireString(ticketId, 'ticket_id'),
      grace_seconds: config.graceSeconds,
    });
    return {
      grant_id: grant.grant_id,
      form_url: formGateway.createPrefilledUrl(config, grant.grant_id),
      expires_at: grant.expires_at,
    };
  }

  function processFormSubmission(service, submission) {
    return service.processFormSubmission(submission);
  }

  function buildClaimUrl(webAppUrl, ticketId) {
    var base = Domain.requireString(webAppUrl, 'ATTENDANCE_WEB_APP_URL');
    return base + (base.indexOf('?') === -1 ? '?' : '&') +
      'route=claim&ticket_id=' + encodeURIComponent(ticketId);
  }

  function createClaimHtmlOutput(claim) {
    var safeUrl = JSON.stringify(claim.form_url).replace(/</g, '\\u003c');
    var html = '<!doctype html><html><head><base target="_top">' +
      '<meta name="viewport" content="width=device-width, initial-scale=1">' +
      '<title>Mở biểu mẫu điểm danh</title></head><body>' +
      '<p>Đang mở biểu mẫu điểm danh…</p>' +
      '<p><a id="continue" href="' + escapeHtml_(claim.form_url) + '" target="_top">Tiếp tục đến biểu mẫu</a></p>' +
      '<script>window.top.location.replace(' + safeUrl + ');</script>' +
      '</body></html>';
    return HtmlService.createHtmlOutput(html).setTitle('Điểm danh');
  }

  function escapeHtml_(value) {
    return String(value)
      .replace(/&/g, '&amp;')
      .replace(/"/g, '&quot;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;');
  }

  return {
    issueQrTicket: issueQrTicket,
    getQrReceipt: getQrReceipt,
    claimQrTicket: claimQrTicket,
    processFormSubmission: processFormSubmission,
    buildClaimUrl: buildClaimUrl,
    createClaimHtmlOutput: createClaimHtmlOutput,
  };
})(typeof module !== 'undefined' && module.exports ? require('./00_attendance_domain.js') : AttendanceDomain);

if (typeof module !== 'undefined' && module.exports) {
  module.exports = StudentAttendanceService;
}
