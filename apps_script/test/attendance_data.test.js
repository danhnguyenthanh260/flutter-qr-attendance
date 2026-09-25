if (typeof require === 'function') {
const assert = require('node:assert/strict');
const test = require('node:test');

const Domain = require('../src/00_attendance_domain.js');
const GoogleSheetsGateway = require('../src/01_sheets_gateway.js');
const Repository = require('../src/02_attendance_repository.js');
const DataService = require('../src/03_attendance_service.js');
const TeacherApiContract = require('../src/08_teacher_api.js');
const StudentAttendanceService = require('../src/07_student_attendance_service.js');
const LegacyMigration = require('../src/04_legacy_sheet_migration.js');
const AttendanceFormGateway = require('../src/06_attendance_form.js');

class MemorySheetGateway {
  constructor() {
    this._tables = Object.fromEntries(
      Object.keys(Domain.HEADERS).map((sheetName) => [sheetName, []]),
    );
    this.lockCalls = 0;
  }

  read(sheetName) {
    return this._table(sheetName).map((data, index) => ({
      rowNumber: index + 2,
      data: { ...data },
    }));
  }

  append(sheetName, data) {
    this._table(sheetName).push({ ...data });
    return { rowNumber: this._table(sheetName).length + 1, data: { ...data } };
  }

  update(sheetName, rowNumber, patch) {
    const index = rowNumber - 2;
    const table = this._table(sheetName);
    if (!table[index]) {
      throw new Domain.AttendanceError('not_found', 'Missing row.');
    }
    table[index] = { ...table[index], ...patch };
    return { rowNumber, data: { ...table[index] } };
  }

  withLock(callback) {
    this.lockCalls += 1;
    return callback();
  }

  seed(sheetName, data) {
    this._table(sheetName).push({ ...data });
  }

  rows(sheetName) {
    return this._table(sheetName).map((row) => ({ ...row }));
  }

  _table(sheetName) {
    if (!this._tables[sheetName]) {
      throw new Error(`Unknown table ${sheetName}`);
    }
    return this._tables[sheetName];
  }
}

function createFixture() {
  const gateway = new MemorySheetGateway();
  let now = new Date('2026-09-19T08:00:00.000Z');
  let id = 0;
  const options = {
    clock: () => now,
    idFactory: (prefix) => `${prefix}_${++id}`,
  };

  gateway.seed(Domain.SHEETS.classes, {
    class_id: 'CLASS_1',
    course_code: 'PRM392',
    name: 'Flutter',
    room: 'BE-302',
    schedule_description: 'Slot 2',
    is_active: 'true',
  });
  gateway.seed(Domain.SHEETS.classes, {
    class_id: 'CLASS_2',
    course_code: 'SWP391',
    name: 'Software Project',
    room: 'AL-205',
    schedule_description: 'Slot 3',
    is_active: 'true',
  });
  gateway.seed(Domain.SHEETS.classSlots, {
    slot_id: 'SLOT_1',
    class_id: 'CLASS_1',
    slot_number: 2,
    time_range: '09:15 - 10:45',
    session_date: '2026-09-19',
    is_active: 'true',
  });
  gateway.seed(Domain.SHEETS.classSlots, {
    slot_id: 'SLOT_2',
    class_id: 'CLASS_2',
    slot_number: 3,
    time_range: '12:30 - 14:00',
    session_date: '2026-09-19',
    is_active: 'true',
  });
  gateway.seed(Domain.SHEETS.roster, {
    roster_id: 'ROSTER_1',
    class_id: 'CLASS_1',
    email: 'student@example.edu',
    email_key: 'student@example.edu',
    student_name: 'Student One',
    is_active: 'true',
  });

  return {
    gateway,
    repository: new Repository(gateway, options),
    service: DataService.create(gateway, options),
    setNow: (value) => { now = new Date(value); },
  };
}

function startInput(overrides = {}) {
  return {
    class_id: 'CLASS_1',
    slot: {
      slot_number: 2,
      time_range: '09:15 - 10:45',
      date: '2026-09-19',
    },
    teacher_id: 'teacher-1',
    request_id: 'START_1',
    ...overrides,
  };
}

test('normalizes email keys and rejects malformed email', () => {
  assert.equal(Domain.normalizeEmail('  Student@Example.EDU '), 'student@example.edu');
  assert.throws(
    () => Domain.normalizeEmail('not-an-email'),
    (error) => error.code === 'validation_error',
  );
  assert.throws(
    () => Domain.asInteger('', 'slot_number'),
    (error) => error.code === 'validation_error',
  );
});

test('serializes Google Sheets session dates as calendar dates', () => {
  const gateway = Object.create(GoogleSheetsGateway.prototype);
  const value = gateway._normalizeCellValue(
    'session_date',
    new Date('2026-09-19T00:00:00.000Z'),
  );

  assert.equal(value, '2026-09-19');
  assert.equal(gateway._normalizeCellValue('opened_at', new Date('2026-09-19T00:00:00.000Z')).toISOString(), '2026-09-19T00:00:00.000Z');
});

test('separates raw form responses from accepted attendance and keeps retries idempotent', () => {
  const { gateway, service } = createFixture();
  const session = service.startSession(startInput());

  const raw = service.recordRawFormResponse({
    form_response_id: 'FORM_1',
    session_id: session.id,
    grant_id: 'GRANT_1',
    submitted_at: '2026-09-19T08:00:10.000Z',
    email: ' Student@Example.edu ',
    raw_payload: { field_email: 'Student@Example.edu' },
  });
  const repeatedRaw = service.recordRawFormResponse({
    form_response_id: 'FORM_1',
    session_id: session.id,
    email: 'student@example.edu',
    raw_payload: { ignored: true },
  });
  const firstAttendance = service.recordAttendance({
    session_id: session.id,
    form_response_id: 'FORM_1',
    email: 'student@example.edu',
    student_name: 'Student One',
  });
  const repeatedAttendance = service.recordAttendance({
    session_id: session.id,
    form_response_id: 'FORM_1',
    email: 'student@example.edu',
  });
  const duplicateEmail = service.recordAttendance({
    session_id: session.id,
    form_response_id: 'FORM_2',
    email: 'STUDENT@example.edu',
  });

  assert.equal(raw.created, true);
  assert.equal(repeatedRaw.created, false);
  assert.equal(firstAttendance.created, true);
  assert.equal(repeatedAttendance.created, false);
  assert.equal(repeatedAttendance.reason, 'form_response_replayed');
  assert.equal(duplicateEmail.created, false);
  assert.equal(duplicateEmail.reason, 'duplicate_email');
  assert.equal(gateway.rows(Domain.SHEETS.formResponses).length, 1);
  assert.equal(gateway.rows(Domain.SHEETS.attendance).length, 1);
  assert.equal(gateway.rows(Domain.SHEETS.formResponses)[0].email_key, 'student@example.edu');
  assert.ok(gateway.lockCalls >= 5);
});

test('issues a 30-second QR ticket, grants grace after claim, and produces a prefilled Form URL', () => {
  const { gateway, service } = createFixture();
  const session = service.startSession(startInput());
  const config = {
    webAppUrl: 'https://script.google.com/macros/s/example/exec',
    qrValidSeconds: 30,
    graceSeconds: 120,
  };
  const ticket = StudentAttendanceService.issueQrTicket(service, config, session.id);
  const claim = StudentAttendanceService.claimQrTicket(service, {
    createPrefilledUrl: (_config, grantId) => `https://forms.example/form?grant=${grantId}`,
  }, config, ticket.ticket_code);

  assert.equal(ticket.generation, 1);
  assert.match(ticket.form_url, /route=claim/);
  assert.equal(gateway.rows(Domain.SHEETS.ticketStates).length, 1);
  assert.equal(gateway.rows(Domain.SHEETS.grants).length, 1);
  assert.match(claim.form_url, new RegExp(claim.grant_id));
});

test('accepts a claimed grant once, records duplicate email attempts, and rejects grant replay', () => {
  const { gateway, service } = createFixture();
  const session = service.startSession(startInput());
  const config = { webAppUrl: 'https://script.example/exec', qrValidSeconds: 30, graceSeconds: 120 };
  const ticket = StudentAttendanceService.issueQrTicket(service, config, session.id);
  const formGateway = { createPrefilledUrl: (_config, grantId) => `https://forms.example/?grant=${grantId}` };
  const firstGrant = StudentAttendanceService.claimQrTicket(service, formGateway, config, ticket.ticket_code);
  const accepted = StudentAttendanceService.processFormSubmission(service, {
    form_response_id: 'FORM_1',
    submitted_at: '2026-09-19T08:00:40.000Z',
    email: 'student@example.edu',
    grant_id: firstGrant.grant_id,
    raw_payload: { email: 'student@example.edu' },
  });
  const repeatedGrant = StudentAttendanceService.processFormSubmission(service, {
    form_response_id: 'FORM_2',
    submitted_at: '2026-09-19T08:00:41.000Z',
    email: 'other@example.edu',
    grant_id: firstGrant.grant_id,
    raw_payload: { email: 'other@example.edu' },
  });
  const secondGrant = StudentAttendanceService.claimQrTicket(service, formGateway, config, ticket.ticket_code);
  const duplicateEmail = StudentAttendanceService.processFormSubmission(service, {
    form_response_id: 'FORM_3',
    submitted_at: '2026-09-19T08:00:42.000Z',
    email: 'student@example.edu',
    grant_id: secondGrant.grant_id,
    raw_payload: { email: 'student@example.edu' },
  });

  assert.equal(accepted.accepted, true);
  assert.equal(repeatedGrant.outcome, 'grant_already_used');
  assert.equal(duplicateEmail.outcome, 'duplicate');
  assert.equal(gateway.rows(Domain.SHEETS.attendance).length, 1);
  assert.equal(gateway.rows(Domain.SHEETS.attempts).length, 2);
});

test('rejects an expired QR ticket and a submitted grant after grace expires', () => {
  const { service, setNow } = createFixture();
  const session = service.startSession(startInput());
  const config = { webAppUrl: 'https://script.example/exec', qrValidSeconds: 30, graceSeconds: 120 };
  const ticket = StudentAttendanceService.issueQrTicket(service, config, session.id);
  setNow('2026-09-19T08:00:31.000Z');
  assert.throws(
    () => StudentAttendanceService.claimQrTicket(service, { createPrefilledUrl: () => '' }, config, ticket.ticket_code),
    (error) => error.code === 'ticket_expired',
  );

  const { service: graceService, setNow: setGraceNow } = createFixture();
  const graceSession = graceService.startSession(startInput());
  const graceTicket = StudentAttendanceService.issueQrTicket(graceService, config, graceSession.id);
  const grant = StudentAttendanceService.claimQrTicket(graceService, { createPrefilledUrl: () => 'https://forms.example/' }, config, graceTicket.ticket_code);
  setGraceNow('2026-09-19T08:02:01.000Z');
  const expired = StudentAttendanceService.processFormSubmission(graceService, {
    form_response_id: 'FORM_LATE',
    submitted_at: '2026-09-19T08:02:01.000Z',
    email: 'student@example.edu',
    grant_id: grant.grant_id,
    raw_payload: {},
  });
  assert.equal(expired.outcome, 'grace_expired');
});

test('does not present a missing roster as a successful empty roster', () => {
  const { repository } = createFixture();
  assert.throws(
    () => repository.getRoster('CLASS_2'),
    (error) => error.code === 'roster_missing' && error.details.class_id === 'CLASS_2',
  );
});

test('returns the same active session for a retry and blocks a conflicting session', () => {
  const { service } = createFixture();
  const first = service.startSession(startInput());
  const retry = service.startSession(startInput({ request_id: 'START_2' }));

  assert.equal(first.id, retry.id);
  assert.throws(
    () => service.startSession({
      class_id: 'CLASS_2',
      slot: {
        slot_number: 3,
        time_range: '12:30 - 14:00',
        date: '2026-09-19',
      },
      teacher_id: 'teacher-1',
      request_id: 'START_3',
    }),
    (error) => error.code === 'active_session_exists',
  );
});

test('preserves the closing state until a later finalization step', () => {
  const { service } = createFixture();
  const session = service.startSession(startInput());
  const closing = service.requestCloseSession(session.id);
  const repeatedClose = service.requestCloseSession(session.id);
  const closed = service.finalizeSession(session.id);

  assert.equal(closing.status, 'closing');
  assert.equal(repeatedClose.status, 'closing');
  assert.equal(closed.status, 'closed');
});

test('start settles abandoned closing sessions and creates a fresh active session', () => {
  const { service, gateway } = createFixture();
  const first = service.startSession(startInput());
  service.requestCloseSession(first.id);
  const next = service.startSession(startInput({ request_id: 'START_NEW' }));
  assert.notEqual(next.id, first.id);
  assert.equal(next.status, 'active');
  assert.equal(gateway.rows(Domain.SHEETS.sessions)[0].status, 'closed');
  assert.equal(service.issueQrTicket({ session_id: next.id, valid_seconds: 30 }).session_id, next.id);
});

test('closing preserves outstanding grants, blocks new starts, and settles after submission', () => {
  const { service, setNow } = createFixture();
  const first = service.startSession(startInput());
  const ticket = service.issueQrTicket({ session_id: first.id, valid_seconds: 30 });
  const grant = service.claimQrTicket({ ticket_id: ticket.ticket_id, grace_seconds: 120 });
  service.requestCloseSession(first.id);
  setNow('2026-09-19T08:00:40.000Z');
  assert.throws(() => service.startSession(startInput({ request_id: 'NEXT' })),
    error => error.code === 'session_closing');
  assert.throws(() => service.finalizeSession(first.id), error => error.code === 'session_closing');
  assert.equal(service.getSessionResults(first.id).session.status, 'closing');
  assert.equal(service.processFormSubmission({
    form_response_id: 'CLOSING_FORM', grant_id: grant.grant_id,
    email: 'student@example.edu', submitted_at: '2026-09-19T08:00:40.000Z',
  }).accepted, true);
  assert.equal(service.getSessionResults(first.id).session.status, 'closed');
  const next = service.startSession(startInput({ request_id: 'NEXT' }));
  assert.notEqual(next.id, first.id);
});

test('reads finalize after the last issued grant expires, never at its valid boundary', () => {
  const { service, setNow } = createFixture();
  const first = service.startSession(startInput());
  const ticket = service.issueQrTicket({ session_id: first.id, valid_seconds: 30 });
  service.claimQrTicket({ ticket_id: ticket.ticket_id, grace_seconds: 120 });
  setNow('2026-09-19T08:00:20.000Z');
  service.claimQrTicket({ ticket_id: ticket.ticket_id, grace_seconds: 120 });
  service.requestCloseSession(first.id);
  setNow('2026-09-19T08:02:00.001Z');
  assert.equal(service.listSessions()[0].status, 'closing');
  setNow('2026-09-19T08:02:20.000Z');
  assert.equal(service.listSessions()[0].status, 'closing');
  setNow('2026-09-19T08:02:20.001Z');
  assert.equal(service.getActiveSession(), null);
  assert.equal(service.listSessions()[0].status, 'closed');
  assert.equal(service.startSession(startInput()).status, 'closed'); // idempotency: old request stays old
  assert.equal(service.startSession(startInput({ request_id: 'NEW' })).status, 'active');
});

test('teacher API requires the configured key and returns typed data envelopes', () => {
  const { service } = createFixture();
  const context = {
    config: { teacherApiKey: 'teacher-key' },
    service,
  };

  assert.throws(
    () => TeacherApiContract.execute('GET', { action: 'classes' }, context),
    (error) => error.code === 'unauthorized',
  );

  const result = TeacherApiContract.execute('GET', {
    action: 'classes',
    teacher_key: 'teacher-key',
  }, context);

  assert.equal(result.ok, true);
  assert.equal(result.data.length, 2);
  assert.equal(result.data[0].roster_status, 'available');
});

test('creates a canonical seed plan from the legacy Slot and Class tabs without importing old attendance', () => {
  const plan = LegacyMigration.createPlan([
    {
      id: 'SLOT_01', classId: 'Class_001', date: '2026-09-22', slotNumber: 2,
      startTime: '09:15', endTime: '10:45', subject: 'PRM392',
    },
  ], {
    Class_001: [
      { studentId: 'SE1', email: 'Student@Example.edu', fullName: 'Student One' },
      { studentId: 'SE1-duplicate', email: 'student@example.edu', fullName: 'Ignored duplicate' },
    ],
  }, '2026-09-22T08:00:00.000Z');

  assert.deepEqual(plan.classes, [{
    class_id: 'Class_001', course_code: 'PRM392', name: 'PRM392', room: '',
    schedule_description: '', is_active: 'true', created_at: '2026-09-22T08:00:00.000Z',
    updated_at: '2026-09-22T08:00:00.000Z',
  }]);
  assert.equal(plan.classSlots.length, 1);
  assert.equal(plan.classSlots[0].time_range, '09:15 - 10:45');
  assert.equal(plan.roster.length, 1);
  assert.equal(plan.roster[0].email_key, 'student@example.edu');
});

test('uses the authenticated Form respondent email instead of a manually supplied value', () => {
  const submission = AttendanceFormGateway.parseSubmission({
    response: {
      getId: () => 'FORM_1',
      getTimestamp: () => new Date('2026-09-22T08:00:00.000Z'),
      getRespondentEmail: () => 'SignedIn@Example.edu',
      getItemResponses: () => [{
        getItem: () => ({ getId: () => 42 }),
        getResponse: () => 'GRANT_1',
      }],
    },
  }, { grantItemId: 42 });

  assert.equal(submission.email, 'SignedIn@Example.edu');
  assert.equal(submission.grant_id, 'GRANT_1');
});

test('teacher API issues a server-side QR claim URL only with teacher authentication', () => {
  const { service } = createFixture();
  const session = service.startSession(startInput());
  const result = TeacherApiContract.execute('POST', {
    action: 'issue_qr',
    teacher_key: 'teacher-key',
    session_id: session.id,
  }, {
    config: { teacherApiKey: 'teacher-key' },
    studentConfig: {
      webAppUrl: 'https://script.example/exec',
      qrValidSeconds: 30,
      graceSeconds: 120,
    },
    service,
  });

  assert.equal(result.ok, true);
  assert.match(result.data.form_url, /route=claim/);
  assert.equal(result.data.valid_seconds, 30);
});
}
