var AttendanceRepository = (function (Domain) {
  'use strict';

  function Repository(gateway, options) {
    options = options || {};
    this._gateway = gateway;
    this._clock = options.clock || function () { return new Date(); };
    this._idFactory = options.idFactory || function (prefix) {
      return prefix + '_' + Utilities.getUuid();
    };
  }

  Repository.prototype.listClasses = function () {
    var roster = this._records(Domain.SHEETS.roster);
    return this._records(Domain.SHEETS.classes)
      .filter(function (record) { return Domain.asBoolean(record.is_active); })
      .map(function (record) {
        var activeRosterCount = roster.filter(function (rosterRecord) {
          return rosterRecord.class_id === record.class_id && Domain.asBoolean(rosterRecord.is_active);
        }).length;
        return {
          id: record.class_id,
          course_code: record.course_code,
          name: record.name,
          room: record.room,
          schedule_description: record.schedule_description,
          total_students: activeRosterCount,
          roster_status: activeRosterCount > 0 ? 'available' : 'missing',
        };
      });
  };

  Repository.prototype.listSlotsForClass = function (classId) {
    this._requireClass(classId);
    return this._records(Domain.SHEETS.classSlots)
      .filter(function (record) {
        return record.class_id === classId && Domain.asBoolean(record.is_active);
      })
      .map(function (record) {
        return {
          id: record.slot_id,
          slot_number: Domain.asInteger(record.slot_number, 'slot_number'),
          time_range: record.time_range,
          date: record.session_date,
        };
      });
  };

  Repository.prototype.getRoster = function (classId) {
    this._requireClass(classId);
    var roster = this._records(Domain.SHEETS.roster)
      .filter(function (record) {
        return record.class_id === classId && Domain.asBoolean(record.is_active);
      })
      .map(function (record) {
        return {
          id: record.roster_id,
          class_id: record.class_id,
          email: record.email,
          email_key: record.email_key,
          student_name: record.student_name,
        };
      });
    if (roster.length === 0) {
      Domain.fail('roster_missing', 'No active roster exists for this class.', {
        class_id: classId,
      });
    }
    return roster;
  };

  Repository.prototype.startSession = function (input) {
    input = input || {};
    var classId = Domain.requireString(input.class_id, 'class_id');
    var slot = input.slot || {};
    var slotNumber = Domain.asInteger(slot.slot_number, 'slot.slot_number');
    var sessionDate = Domain.isoDate(slot.date, 'slot.date');
    var requestId = Domain.optionalString(input.request_id);
    var classRecord = this._requireClass(classId);
    this._requireSlot(classId, slotNumber, sessionDate);

    var sessions = this._records(Domain.SHEETS.sessions);
    if (requestId) {
      var requestMatch = sessions.find(function (record) {
        return record.request_id === requestId;
      });
      if (requestMatch) {
        return this._toSession(requestMatch);
      }
    }

    var activeSession = sessions.find(function (record) {
      return record.status === 'active' || record.status === 'closing';
    });
    if (activeSession) {
      if (
        activeSession.class_id === classId &&
        Domain.asInteger(activeSession.slot_number, 'slot_number') === slotNumber &&
        activeSession.session_date === sessionDate
      ) {
        return this._toSession(activeSession);
      }
      Domain.fail('active_session_exists', 'Another attendance session is still active or closing.', {
        session_id: activeSession.session_id,
      });
    }

    var now = this._nowIso();
    var session = {
      session_id: this._idFactory('SES'),
      class_id: classId,
      slot_number: slotNumber,
      time_range: Domain.requireString(slot.time_range, 'slot.time_range'),
      session_date: sessionDate,
      status: 'active',
      opened_at: now,
      closing_at: '',
      closed_at: '',
      created_by: Domain.requireString(input.teacher_id, 'teacher_id'),
      request_id: requestId,
      updated_at: now,
    };
    this._gateway.append(Domain.SHEETS.sessions, session);
    return this._toSession(session, classRecord);
  };

  Repository.prototype.requestCloseSession = function (sessionId) {
    var entry = this._findEntry(Domain.SHEETS.sessions, function (record) {
      return record.session_id === sessionId;
    });
    if (!entry) {
      Domain.fail('not_found', 'Attendance session does not exist.', { session_id: sessionId });
    }
    var current = entry.data;
    if (current.status === 'closing' || current.status === 'closed') {
      return this._toSession(current);
    }
    if (current.status !== 'active') {
      Domain.fail('session_not_active', 'Attendance session cannot be closed from its current state.', {
        session_id: sessionId,
        status: current.status,
      });
    }

    var now = this._nowIso();
    var updated = this._gateway.update(Domain.SHEETS.sessions, entry.rowNumber, {
      status: 'closing',
      closing_at: now,
      updated_at: now,
    }).data;
    return this._toSession(updated);
  };

  Repository.prototype.finalizeSession = function (sessionId) {
    var entry = this._findEntry(Domain.SHEETS.sessions, function (record) {
      return record.session_id === sessionId;
    });
    if (!entry) {
      Domain.fail('not_found', 'Attendance session does not exist.', { session_id: sessionId });
    }
    if (entry.data.status === 'closed') {
      return this._toSession(entry.data);
    }
    if (entry.data.status !== 'closing') {
      Domain.fail('session_not_closing', 'Only a closing session can be finalized.', {
        session_id: sessionId,
        status: entry.data.status,
      });
    }

    var now = this._nowIso();
    var updated = this._gateway.update(Domain.SHEETS.sessions, entry.rowNumber, {
      status: 'closed',
      closed_at: now,
      updated_at: now,
    }).data;
    return this._toSession(updated);
  };

  Repository.prototype.getActiveSession = function () {
    var entry = this._findEntry(Domain.SHEETS.sessions, function (record) {
      return record.status === 'active';
    });
    return entry ? this._toSession(entry.data) : null;
  };

  Repository.prototype.listSessions = function (filters) {
    filters = filters || {};
    return this._records(Domain.SHEETS.sessions)
      .filter(function (record) {
        return (!filters.class_id || record.class_id === filters.class_id) &&
          (!filters.date || record.session_date === filters.date);
      })
      .map(this._toSession.bind(this));
  };

  Repository.prototype.getSessionResults = function (sessionId) {
    var sessionEntry = this._findEntry(Domain.SHEETS.sessions, function (record) {
      return record.session_id === sessionId;
    });
    if (!sessionEntry) {
      Domain.fail('not_found', 'Attendance session does not exist.', { session_id: sessionId });
    }
    var session = this._toSession(sessionEntry.data);
    return {
      session: session,
      roster: this.getRoster(session.class_id),
      attendance: this._records(Domain.SHEETS.attendance)
        .filter(function (record) { return record.session_id === sessionId; })
        .map(this._toAttendance),
      attempts: this._records(Domain.SHEETS.attempts)
        .filter(function (record) { return record.session_id === sessionId; })
        .map(this._toAttempt),
    };
  };

  Repository.prototype.recordRawFormResponse = function (input) {
    input = input || {};
    var responseId = Domain.requireString(input.form_response_id, 'form_response_id');
    var existing = this._findEntry(Domain.SHEETS.formResponses, function (record) {
      return record.form_response_id === responseId;
    });
    if (existing) {
      return { record: this._toRawFormResponse(existing.data), created: false };
    }

    var sessionId = Domain.requireString(input.session_id, 'session_id');
    this._requireSession(sessionId);
    var email = Domain.normalizeEmail(input.email);
    var now = this._nowIso();
    var record = {
      form_response_id: responseId,
      session_id: sessionId,
      grant_id: Domain.optionalString(input.grant_id),
      submitted_at: Domain.isoTimestamp(input.submitted_at, 'submitted_at', this._clock()),
      received_at: now,
      email: email,
      email_key: email,
      raw_payload: Domain.jsonString(Domain.parseJsonObject(input.raw_payload || {}, 'raw_payload')),
      processing_status: 'received',
      updated_at: now,
    };
    this._gateway.append(Domain.SHEETS.formResponses, record);
    return { record: this._toRawFormResponse(record), created: true };
  };

  Repository.prototype.recordAttendance = function (input) {
    input = input || {};
    var sessionId = Domain.requireString(input.session_id, 'session_id');
    this._requireSession(sessionId);
    var formResponseId = Domain.requireString(input.form_response_id, 'form_response_id');
    var email = Domain.normalizeEmail(input.email);
    var responseMatch = this._findEntry(Domain.SHEETS.attendance, function (record) {
      return record.form_response_id === formResponseId;
    });
    if (responseMatch) {
      return { record: this._toAttendance(responseMatch.data), created: false, reason: 'form_response_replayed' };
    }
    var emailMatch = this._findEntry(Domain.SHEETS.attendance, function (record) {
      return record.session_id === sessionId && record.email_key === email;
    });
    if (emailMatch) {
      return { record: this._toAttendance(emailMatch.data), created: false, reason: 'duplicate_email' };
    }

    var now = this._nowIso();
    var record = {
      attendance_id: this._idFactory('ATT'),
      session_id: sessionId,
      form_response_id: formResponseId,
      email: email,
      email_key: email,
      student_name: Domain.optionalString(input.student_name),
      accepted_at: now,
      updated_at: now,
    };
    this._gateway.append(Domain.SHEETS.attendance, record);
    return { record: this._toAttendance(record), created: true, reason: 'accepted' };
  };

  Repository.prototype.recordAttempt = function (input) {
    input = input || {};
    var sessionId = Domain.requireString(input.session_id, 'session_id');
    this._requireSession(sessionId);
    var now = this._nowIso();
    var email = Domain.normalizeEmail(input.email);
    var record = {
      attempt_id: this._idFactory('ATTEMPT'),
      session_id: sessionId,
      form_response_id: Domain.optionalString(input.form_response_id),
      email: email,
      email_key: email,
      attempt_type: Domain.requireString(input.attempt_type, 'attempt_type'),
      reason: Domain.requireString(input.reason, 'reason'),
      occurred_at: now,
      updated_at: now,
    };
    this._gateway.append(Domain.SHEETS.attempts, record);
    return this._toAttempt(record);
  };

  Repository.prototype.saveTicketState = function (input) {
    input = input || {};
    var ticketId = Domain.requireString(input.ticket_id, 'ticket_id');
    this._requireSession(Domain.requireString(input.session_id, 'session_id'));
    var now = this._nowIso();
    var record = {
      ticket_id: ticketId,
      session_id: input.session_id,
      generation: Domain.asInteger(input.generation, 'generation'),
      issued_at: Domain.isoTimestamp(input.issued_at, 'issued_at', this._clock()),
      expires_at: Domain.isoTimestamp(input.expires_at, 'expires_at', this._clock()),
      status: Domain.requireString(input.status, 'status'),
      updated_at: now,
    };
    var existing = this._findEntry(Domain.SHEETS.ticketStates, function (candidate) {
      return candidate.ticket_id === ticketId;
    });
    if (existing) {
      return this._gateway.update(Domain.SHEETS.ticketStates, existing.rowNumber, record).data;
    }
    this._gateway.append(Domain.SHEETS.ticketStates, record);
    return record;
  };

  Repository.prototype.issueQrTicket = function (input) {
    input = input || {};
    var sessionId = Domain.requireString(input.session_id, 'session_id');
    var session = this._requireSession(sessionId);
    if (session.status !== 'active') {
      Domain.fail('session_not_active', 'QR codes can only be issued for an active session.', {
        session_id: sessionId,
        status: session.status,
      });
    }

    var validSeconds = Domain.asInteger(input.valid_seconds, 'valid_seconds');
    if (validSeconds <= 0) {
      Domain.fail('validation_error', 'valid_seconds must be greater than zero.', {
        field: 'valid_seconds',
      });
    }
    var tickets = this._records(Domain.SHEETS.ticketStates).filter(function (record) {
      return record.session_id === sessionId;
    });
    var generation = tickets.reduce(function (current, record) {
      return Math.max(current, Number(record.generation) || 0);
    }, 0) + 1;
    var issuedAt = this._clock();
    var ticket = this.saveTicketState({
      ticket_id: this._idFactory('TKT'),
      session_id: sessionId,
      generation: generation,
      issued_at: issuedAt.toISOString(),
      expires_at: new Date(issuedAt.getTime() + validSeconds * 1000).toISOString(),
      status: 'active',
    });
    return this._toTicket(ticket);
  };

  Repository.prototype.claimQrTicket = function (input) {
    input = input || {};
    var ticketId = Domain.requireString(input.ticket_id, 'ticket_id');
    var graceSeconds = Domain.asInteger(input.grace_seconds, 'grace_seconds');
    if (graceSeconds <= 0) {
      Domain.fail('validation_error', 'grace_seconds must be greater than zero.', {
        field: 'grace_seconds',
      });
    }
    var ticketEntry = this._findEntry(Domain.SHEETS.ticketStates, function (record) {
      return record.ticket_id === ticketId;
    });
    if (!ticketEntry) {
      Domain.fail('ticket_not_found', 'QR ticket does not exist.', { ticket_id: ticketId });
    }
    var ticket = ticketEntry.data;
    var now = this._clock();
    if (new Date(ticket.expires_at).getTime() <= now.getTime()) {
      this._gateway.update(Domain.SHEETS.ticketStates, ticketEntry.rowNumber, {
        status: 'expired',
        updated_at: now.toISOString(),
      });
      Domain.fail('ticket_expired', 'QR ticket has expired.', { ticket_id: ticketId });
    }
    if (ticket.status !== 'active') {
      Domain.fail('ticket_unavailable', 'QR ticket is not available for a new claim.', {
        ticket_id: ticketId,
        status: ticket.status,
      });
    }
    var session = this._requireSession(ticket.session_id);
    if (session.status !== 'active') {
      Domain.fail('session_not_active', 'Attendance session is no longer accepting new QR claims.', {
        session_id: ticket.session_id,
        status: session.status,
      });
    }

    var grant = {
      grant_id: this._idFactory('GRANT'),
      ticket_id: ticketId,
      session_id: ticket.session_id,
      issued_at: now.toISOString(),
      expires_at: new Date(now.getTime() + graceSeconds * 1000).toISOString(),
      status: 'issued',
      form_response_id: '',
      email: '',
      email_key: '',
      updated_at: now.toISOString(),
    };
    this._gateway.append(Domain.SHEETS.grants, grant);
    return this._toGrant(grant);
  };

  Repository.prototype.processFormSubmission = function (input) {
    input = input || {};
    var formResponseId = Domain.requireString(input.form_response_id, 'form_response_id');
    var existingRaw = this._findEntry(Domain.SHEETS.formResponses, function (record) {
      return record.form_response_id === formResponseId;
    });
    if (existingRaw && existingRaw.data.processing_status !== 'processing_error') {
      return {
        accepted: existingRaw.data.processing_status === 'accepted',
        outcome: existingRaw.data.processing_status,
        replayed: true,
      };
    }

    var grantId = Domain.requireString(input.grant_id, 'grant_id');
    var grantEntry = this._findEntry(Domain.SHEETS.grants, function (record) {
      return record.grant_id === grantId;
    });
    if (!grantEntry) {
      Domain.fail('grant_not_found', 'Attendance grant does not exist.', { grant_id: grantId });
    }
    var grant = grantEntry.data;
    var email = Domain.normalizeEmail(input.email);
    var raw = this.recordRawFormResponse({
      form_response_id: formResponseId,
      session_id: grant.session_id,
      grant_id: grantId,
      submitted_at: input.submitted_at,
      email: email,
      raw_payload: input.raw_payload || {},
    });
    if (!raw.created) {
      return { accepted: false, outcome: raw.record.processing_status, replayed: true };
    }

    var now = this._clock();
    if (grant.status !== 'issued') {
      return this._rejectGrantSubmission(grantEntry, formResponseId, email, 'grant_replayed', 'grant_already_used', '');
    }
    if (new Date(grant.expires_at).getTime() < now.getTime()) {
      return this._rejectGrantSubmission(grantEntry, formResponseId, email, 'grant_expired', 'grace_expired', 'expired');
    }
    var session = this._requireSession(grant.session_id);
    if (session.status !== 'active' && session.status !== 'closing') {
      return this._rejectGrantSubmission(grantEntry, formResponseId, email, 'session_closed', 'session_not_accepting_submissions', 'used');
    }
    var rosterRecord = this._records(Domain.SHEETS.roster).find(function (record) {
      return record.class_id === session.class_id &&
        record.email_key === email &&
        Domain.asBoolean(record.is_active);
    });
    if (!rosterRecord) {
      return this._rejectGrantSubmission(grantEntry, formResponseId, email, 'roster_mismatch', 'email_not_in_roster', 'used');
    }

    var attendance = this.recordAttendance({
      session_id: grant.session_id,
      form_response_id: formResponseId,
      email: email,
      student_name: rosterRecord.student_name,
    });
    if (!attendance.created) {
      this.recordAttempt({
        session_id: grant.session_id,
        form_response_id: formResponseId,
        email: email,
        attempt_type: 'duplicate_email',
        reason: attendance.reason,
      });
      this._consumeGrant(grantEntry, formResponseId, email);
      this._setRawProcessing(formResponseId, 'duplicate');
      return { accepted: false, outcome: 'duplicate', replayed: false };
    }

    this._consumeGrant(grantEntry, formResponseId, email);
    this._setRawProcessing(formResponseId, 'accepted');
    return { accepted: true, outcome: 'accepted', replayed: false, attendance: attendance.record };
  };

  Repository.prototype._rejectGrantSubmission = function (grantEntry, formResponseId, email, attemptType, rawStatus, grantStatus) {
    this.recordAttempt({
      session_id: grantEntry.data.session_id,
      form_response_id: formResponseId,
      email: email,
      attempt_type: attemptType,
      reason: rawStatus,
    });
    if (grantStatus) {
      this._consumeGrant(grantEntry, formResponseId, email, grantStatus);
    }
    this._setRawProcessing(formResponseId, rawStatus);
    return { accepted: false, outcome: rawStatus, replayed: false };
  };

  Repository.prototype._consumeGrant = function (grantEntry, formResponseId, email, status) {
    this._gateway.update(Domain.SHEETS.grants, grantEntry.rowNumber, {
      status: status || 'used',
      form_response_id: formResponseId,
      email: email,
      email_key: email,
      updated_at: this._nowIso(),
    });
  };

  Repository.prototype._setRawProcessing = function (formResponseId, processingStatus) {
    var rawEntry = this._findEntry(Domain.SHEETS.formResponses, function (record) {
      return record.form_response_id === formResponseId;
    });
    if (rawEntry) {
      this._gateway.update(Domain.SHEETS.formResponses, rawEntry.rowNumber, {
        processing_status: processingStatus,
        updated_at: this._nowIso(),
      });
    }
  };

  Repository.prototype._records = function (sheetName) {
    return this._gateway.read(sheetName).map(function (entry) {
      return entry.data;
    });
  };

  Repository.prototype._findEntry = function (sheetName, predicate) {
    var entries = this._gateway.read(sheetName);
    return entries.find(function (entry) { return predicate(entry.data); }) || null;
  };

  Repository.prototype._requireClass = function (classId) {
    var record = this._records(Domain.SHEETS.classes).find(function (candidate) {
      return candidate.class_id === classId && Domain.asBoolean(candidate.is_active);
    });
    if (!record) {
      Domain.fail('class_not_found', 'Class does not exist or is inactive.', { class_id: classId });
    }
    return record;
  };

  Repository.prototype._requireSlot = function (classId, slotNumber, sessionDate) {
    var record = this._records(Domain.SHEETS.classSlots).find(function (candidate) {
      return candidate.class_id === classId &&
        Domain.asInteger(candidate.slot_number, 'slot_number') === slotNumber &&
        candidate.session_date === sessionDate &&
        Domain.asBoolean(candidate.is_active);
    });
    if (!record) {
      Domain.fail('slot_not_found', 'Class slot does not exist or is inactive.', {
        class_id: classId,
        slot_number: slotNumber,
        date: sessionDate,
      });
    }
    return record;
  };

  Repository.prototype._requireSession = function (sessionId) {
    var record = this._records(Domain.SHEETS.sessions).find(function (candidate) {
      return candidate.session_id === sessionId;
    });
    if (!record) {
      Domain.fail('not_found', 'Attendance session does not exist.', { session_id: sessionId });
    }
    return record;
  };

  Repository.prototype._toSession = function (record, classRecord) {
    classRecord = classRecord || this._requireClass(record.class_id);
    return {
      id: record.session_id,
      class_id: record.class_id,
      class_name: classRecord.course_code + ' - ' + classRecord.name,
      slot: {
        slot_number: Domain.asInteger(record.slot_number, 'slot_number'),
        time_range: record.time_range,
        date: record.session_date,
      },
      opened_at: record.opened_at,
      closed_at: Domain.isBlank(record.closed_at) ? null : record.closed_at,
      status: record.status,
    };
  };

  Repository.prototype._toRawFormResponse = function (record) {
    return {
      form_response_id: record.form_response_id,
      session_id: record.session_id,
      grant_id: record.grant_id,
      submitted_at: record.submitted_at,
      received_at: record.received_at,
      email: record.email,
      email_key: record.email_key,
      processing_status: record.processing_status,
    };
  };

  Repository.prototype._toTicket = function (record) {
    return {
      ticket_id: record.ticket_id,
      session_id: record.session_id,
      generation: Domain.asInteger(record.generation, 'generation'),
      issued_at: record.issued_at,
      expires_at: record.expires_at,
      status: record.status,
    };
  };

  Repository.prototype._toGrant = function (record) {
    return {
      grant_id: record.grant_id,
      ticket_id: record.ticket_id,
      session_id: record.session_id,
      issued_at: record.issued_at,
      expires_at: record.expires_at,
      status: record.status,
    };
  };

  Repository.prototype._toAttendance = function (record) {
    return {
      id: record.attendance_id,
      session_id: record.session_id,
      form_response_id: record.form_response_id,
      email: record.email,
      email_key: record.email_key,
      student_name: record.student_name,
      accepted_at: record.accepted_at,
    };
  };

  Repository.prototype._toAttempt = function (record) {
    return {
      id: record.attempt_id,
      session_id: record.session_id,
      form_response_id: record.form_response_id,
      email: record.email,
      email_key: record.email_key,
      attempt_type: record.attempt_type,
      reason: record.reason,
      occurred_at: record.occurred_at,
    };
  };

  Repository.prototype._nowIso = function () {
    return this._clock().toISOString();
  };

  return Repository;
})(typeof module !== 'undefined' && module.exports ? require('./00_attendance_domain.js') : AttendanceDomain);

if (typeof module !== 'undefined' && module.exports) {
  module.exports = AttendanceRepository;
}
