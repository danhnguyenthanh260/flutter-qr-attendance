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

test('QR retry returns one persisted ticket without extending expiration', () => {
  const {service, gateway, setNow} = createFixture();
  const session = service.startSession(startInput());
  const input = {session_id: session.id, valid_seconds: 30, request_id: 'retry_same_request_123456'};
  const first = service.issueQrTicket(input);
  setNow('2026-09-19T08:00:31.000Z');
  const replay = service.issueQrTicket(input);
  assert.deepEqual(replay, first);
  assert.equal(gateway.rows(Domain.SHEETS.ticketStates).length, 1);
  assert.throws(() => service.claimQrTicket({ticket_id: replay.ticket_id, grace_seconds: 120}), {code: 'ticket_expired'});
  const next = service.issueQrTicket({...input, request_id: 'different_request_123456'});
  assert.equal(next.generation, 2);
  service.requestCloseSession(session.id);
  assert.throws(() => service.issueQrTicket(input), {code: 'session_not_active'});
});

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
function directFixture() {
  const fixture = createFixture();
  fixture.gateway.seed(Domain.SHEETS.roster, {roster_id: 'R_SECOND', class_id: 'CLASS_1',
    email: 'second@example.edu', email_key: 'second@example.edu', student_name: 'Second', is_active: 'true'});
  const session = fixture.service.startSession(startInput());
  const ticket = fixture.service.issueQrTicket({session_id: session.id, valid_seconds: 30,
    direct_form: true, request_id: 'direct_request_123456'});
  return {...fixture, session, ticket};
}

function directSubmission(ticket, overrides = {}) {
  return {form_response_id: 'DIRECT_RESPONSE', grant_id: ticket.submission_token,
    email: 'second@example.edu', submitted_at: '2026-09-19T08:00:40.000Z', ...overrides};
}

test('direct QR links to the prefilled Form without any Apps Script intermediary', () => {
  const {service, session} = directFixture();
  const response = StudentAttendanceService.issueQrTicket(service,
    {directForm: true, qrValidSeconds: 30}, session.id, 'direct_other_123456', {
      createPrefilledUrl: (_, token) => 'https://docs.google.com/forms/d/e/test/viewform?entry.1=' + token,
    });
  assert.match(response.form_url, /^https:\/\/docs.google.com\/forms\//);
  assert.doesNotMatch(response.form_url, /route=claim|script.google/);
  assert.equal(response.flow, 'direct_form');
  assert.equal(response.submission_window_seconds, 120);
  assert.equal(response.valid_seconds, 30);
});

test('direct shared code accepts multiple roster students, rejects duplicate email and trigger replay', () => {
  const {service, gateway, ticket, setNow} = directFixture();
  gateway.seed(Domain.SHEETS.roster, {roster_id: 'R_THIRD', class_id: 'CLASS_1',
    email: 'third@example.edu', email_key: 'third@example.edu', student_name: 'Third', is_active: 'true'});
  setNow('2026-09-19T08:01:00Z');
  const input = directSubmission(ticket);
  assert.equal(service.processFormSubmission(input).accepted, true);
  assert.equal(service.processFormSubmission(input).replayed, true);
  assert.equal(service.processFormSubmission({...input, form_response_id: 'THIRD', email: 'third@example.edu'}).accepted, true);
  assert.equal(service.processFormSubmission({...input, form_response_id: 'DUP'}).outcome, 'duplicate');
  assert.equal(gateway.rows(Domain.SHEETS.attendance).length, 2);
  assert.equal(gateway.rows(Domain.SHEETS.grants)[0].status, 'direct');
});

test('direct submission deadline uses trusted submit time, inclusive at 120 seconds; late trigger can follow finalization', () => {
  const {service, ticket, session, setNow} = directFixture();
  service.requestCloseSession(session.id);
  setNow('2026-09-19T08:02:00Z');
  assert.equal(service.listSessions({})[0].status, 'closing');
  setNow('2026-09-19T08:02:01Z');
  assert.equal(service.listSessions({})[0].status, 'closed');
  setNow('2026-09-19T08:05:00Z');
  assert.equal(service.processFormSubmission(directSubmission(ticket, {submitted_at: '2026-09-19T08:02:00Z'})).accepted, true);
  assert.equal(service.processFormSubmission(directSubmission(ticket, {form_response_id: 'LATE', submitted_at: '2026-09-19T08:02:00.001Z'})).outcome, 'grace_expired');
});

test('direct code cannot accept forged token, non-roster identity or impossible timestamp', () => {
  const {service, ticket, setNow} = directFixture();
  setNow('2026-09-19T08:01:00Z');
  assert.throws(() => service.processFormSubmission(directSubmission(ticket, {grant_id: 'FORM_forged'})), {code: 'grant_not_found'});
  assert.throws(() => service.processFormSubmission(directSubmission(ticket, {submitted_at: ''})), {code: 'validation_error'});
  assert.equal(service.processFormSubmission(directSubmission(ticket, {email: 'outsider@example.edu'})).outcome, 'email_not_in_roster');
  assert.equal(service.processFormSubmission(directSubmission(ticket, {form_response_id: 'EARLY', submitted_at: '2026-09-19T07:59:59Z'})).outcome, 'invalid_submission_time');
  assert.equal(service.processFormSubmission(directSubmission(ticket, {form_response_id: 'FUTURE', submitted_at: '2026-09-19T08:01:01Z'})).outcome, 'invalid_submission_time');
  assert.equal(service.processFormSubmission(directSubmission(ticket, {form_response_id: 'VALID'})).accepted, true);
});

test('direct issue replay repairs partial persistence without extending either deadline', () => {
  const fixture = createFixture();
  const {service, gateway, setNow} = fixture;
  const session = service.startSession(startInput());
  const append = gateway.append.bind(gateway);
  let fail = true;
  gateway.append = (sheet, data) => {
    if (sheet === Domain.SHEETS.grants && fail) { fail = false; throw new Error('injected failure'); }
    return append(sheet, data);
  };
  const input = {session_id: session.id, valid_seconds: 30, direct_form: true, request_id: 'direct_repair_123456'};
  assert.throws(() => service.issueQrTicket(input), /injected/);
  setNow('2026-09-19T08:00:20Z');
  const repaired = service.issueQrTicket(input);
  assert.equal(repaired.expires_at, '2026-09-19T08:00:30.000Z');
  assert.equal(gateway.rows(Domain.SHEETS.grants)[0].expires_at, '2026-09-19T08:02:00.000Z');
  service.issueQrTicket(input);
  assert.equal(gateway.rows(Domain.SHEETS.ticketStates).length, 1);
  assert.equal(gateway.rows(Domain.SHEETS.grants).length, 1);
});

test('direct trigger replay recovers a write interrupted after attendance append', () => {
  const {service, gateway, ticket, setNow} = directFixture();
  setNow('2026-09-19T08:01:00Z');
  const update = gateway.update.bind(gateway);
  let fail = true;
  gateway.update = (sheet, row, patch) => {
    if (sheet === Domain.SHEETS.formResponses && fail) { fail = false; throw new Error('injected failure'); }
    return update(sheet, row, patch);
  };
  const input = directSubmission(ticket);
  assert.throws(() => service.processFormSubmission(input), /injected/);
  assert.equal(service.processFormSubmission(input).accepted, true);
  assert.equal(gateway.rows(Domain.SHEETS.attendance).length, 1);
  assert.equal(gateway.rows(Domain.SHEETS.formResponses)[0].processing_status, 'accepted');
});

test('teacher API passes direct-form gateway and legacy claim still works beside new tickets', () => {
  const {service, gateway, setNow} = createFixture();
  const session = service.startSession(startInput());
  const legacy = service.issueQrTicket({session_id: session.id, valid_seconds: 30});
  const grant = service.claimQrTicket({ticket_id: legacy.ticket_id, grace_seconds: 120});
  const response = TeacherApiContract.execute('POST', {teacher_key: 'secret', action: 'issue_qr',
    session_id: session.id, request_id: 'live_contract_123456'}, {
    config: {teacherApiKey: 'secret'}, studentConfig: {directForm: true, qrValidSeconds: 30}, service,
    formGateway: {createPrefilledUrl: (_, token) => 'https://docs.google.com/forms/d/e/test/viewform?entry.1=' + token},
  });
  assert.equal(response.ok, true);
  assert.equal(response.data.flow, 'direct_form');
  assert.match(response.data.form_url, /FORM_TKT_REQ_live_contract/);
  gateway.seed(Domain.SHEETS.roster, {roster_id: 'MIGRATE', class_id: 'CLASS_1', email: 'migration@example.edu',
    email_key: 'migration@example.edu', student_name: 'Migration', is_active: 'true'});
  setNow('2026-09-19T08:00:40Z');
  assert.equal(service.processFormSubmission({form_response_id: 'LEGACY', grant_id: grant.grant_id,
    email: 'migration@example.edu', submitted_at: '2026-09-19T08:00:39Z'}).accepted, true);
  service.requestCloseSession(session.id);
  assert.throws(() => service.finalizeSession(session.id), {code: 'session_closing'});
});


test('class overview is scoped and exposes roster without opening attendance', () => {
  const {service, gateway} = createFixture();
  const overview = service.getTeachingOverview('CLASS_1');
  assert.equal(overview.roster.length, 1);
  assert.equal(overview.slots.length, 1);
  assert.equal(overview.sessions.length, 0);
  assert.equal(gateway.rows(Domain.SHEETS.sessions).length, 0);
});

test('import adds an isolated offering with student identifiers and is replay-safe', () => {
  const {service, gateway} = createFixture();
  const input = {class_name:'SE1913',course_code:'PRM393',term:'FALL2026',students:[
    {roll_number:'SE001',email:'person@example.edu',student_name:'Student',member_code:'MEM001'}
  ]};
  const first = service.importRoster(input);
  assert.equal(first.added,1);
  assert.equal(service.importRoster(input).added,0);
  assert.equal(service.getTeachingOverview(first.class_id).roster[0].roll_number,'SE001');
  assert.equal(service.listSlotsForClass(first.class_id).length,0);
  assert.equal(gateway.rows(Domain.SHEETS.roster).length,2);
  assert.throws(() => service.importRoster({...input,students:[{...input.students[0],email:'other@example.edu'}]}), /Existing roster differs/);
  assert.equal(gateway.rows(Domain.SHEETS.roster).length,2);
});

test('import validates all rows before any write and rejects duplicate identities', () => {
  const {service, gateway} = createFixture();
  const student={roll_number:'SE001',email:'person@example.edu',student_name:'Student',member_code:''};
  const input={class_name:'SE1913',course_code:'PRM393',term:'FALL2026',students:[student,student]};
  assert.throws(()=>service.importRoster(input), /Duplicate/);
  assert.equal(gateway.rows(Domain.SHEETS.classes).length,2);
  assert.equal(gateway.rows(Domain.SHEETS.roster).length,1);
});


test('partial roster import is hidden until replay completes and rejects unauthorized calls', () => {
  const {service, gateway} = createFixture();
  const input={class_name:'SE1919',course_code:'PRN232',term:'FALL2026',students:[
    {roll_number:'SE001',email:'one@example.edu',student_name:'One',member_code:''},
    {roll_number:'SE002',email:'two@example.edu',student_name:'Two',member_code:''}
  ]};
  const append=gateway.append.bind(gateway);
  let fail=true;
  gateway.append=(sheet,row)=>{
    if (sheet===Domain.SHEETS.roster && row.roll_number==='SE002' && fail) {fail=false; throw new Error('interrupted');}
    return append(sheet,row);
  };
  assert.throws(()=>service.importRoster(input),/interrupted/);
  assert.equal(service.listClasses().length,2);
  const result=service.importRoster(input);
  assert.equal(result.added,1);
  assert.equal(service.listClasses().length,3);
  assert.equal(service.getTeachingOverview(result.class_id).roster.length,2);
  assert.throws(()=>TeacherApiContract.execute('POST',{...input,action:'import_roster',teacher_key:'wrong'},{service,config:{teacherApiKey:'secret'}}),/authentication/);
});

test('gateway reuses sheet reads within a request and invalidates after append', () => {
  const gateway=Object.create(GoogleSheetsGateway.prototype);
  gateway._domain=Domain; gateway._readCache={};
  const rows=[Domain.HEADERS[Domain.SHEETS.classes],['C','M','Class','','',true,'','']];
  let reads=0;
  gateway._requireSheet=()=>({getLastRow:()=>rows.length,getLastColumn:()=>rows[0].length,
    getRange:(row,col,height,width)=>({getValues:()=>{reads++;return rows.slice(row-1,row-1+height).map(r=>r.slice(col-1,col-1+width));},setValues:(values)=>{values.forEach((v,i)=>rows[row-1+i]=v);}})});
  assert.equal(gateway.read(Domain.SHEETS.classes).length,1);
  gateway.read(Domain.SHEETS.classes);
  assert.equal(reads,1);
  gateway.append(Domain.SHEETS.classes,{class_id:'D',course_code:'N',name:'Other',is_active:true});
  assert.equal(gateway.read(Domain.SHEETS.classes).length,2);
});
test('session lists preserve class names beyond the first record', () => {
  const {service,gateway}=createFixture();
  for (let i=0;i<2;i++) gateway.seed(Domain.SHEETS.sessions,{session_id:'s'+i,class_id:'CLASS_1',slot_number:2,time_range:'09:15 - 10:45',session_date:'2026-09-19',status:'closed',opened_at:'2026-09-19T08:00:00Z'});
  const sessions=service.listSessions({class_id:'CLASS_1'});
  assert.equal(sessions[0].class_name,sessions[1].class_name);
  assert.equal(sessions[1].class_name,'PRM392 - Flutter');
});

test('weekly overview includes all classes and empty rosters without creating sessions', () => {
  const {service,gateway}=createFixture();
  const context={service,config:{teacherApiKey:'teacher'}};
  const result=TeacherApiContract.execute('GET',{action:'weekly_overview',teacher_key:'teacher'},context);
  assert.equal(result.ok,true);
  assert.deepEqual(Object.keys(result.data).sort(),['CLASS_1','CLASS_2']);
  assert.equal(result.data.CLASS_1.roster.length,1);
  assert.equal(result.data.CLASS_2.roster.length,0);
  assert.equal(result.data.CLASS_1.slots[0].id,'SLOT_1');
  assert.equal(result.data.CLASS_2.slots[0].id,'SLOT_2');
  assert.equal(gateway.rows(Domain.SHEETS.sessions).length,0);
  assert.throws(()=>TeacherApiContract.execute('GET',{action:'weekly_overview',teacher_key:'wrong'},context),/authentication/);
});
test('Vietnam day boundary blocks past starts and QR but allows close and receipt replay', () => {
  const {service, gateway, setNow} = createFixture();
  setNow('2026-09-18T17:00:00Z');
  const session = service.startSession(startInput()); // midnight Sep 19 VN
  setNow('2026-09-19T17:00:00Z');
  assert.throws(() => service.startSession(startInput({request_id: 'NEW'})), {code: 'past_session_date'});
  assert.equal(gateway.rows(Domain.SHEETS.sessions).length, 1);
  assert.equal(service.startSession(startInput()).id, session.id);
  assert.throws(() => service.issueQrTicket({session_id: session.id, valid_seconds: 30}), {code: 'past_session_date'});
  service.requestCloseSession(session.id);
});
test('future scheduled lesson can be opened before its calendar date', () => {
  const {service, setNow} = createFixture();
  setNow('2026-09-18T16:59:59Z');
  assert.equal(service.startSession(startInput()).slot.date, '2026-09-19');
});
test('workspace returns only active class catalog and corresponding overview together', () => {
  const {service,gateway} = createFixture();
  const before=service.getWorkspace();
  assert.equal(before.classes.length,2);
  assert.deepEqual(Object.keys(before.overview).sort(),before.classes.map(c=>c.id).sort());
  gateway.update(Domain.SHEETS.classes,2,{is_active:false});
  const after=service.getWorkspace();
  assert.deepEqual(after.classes.map(c=>c.id),['CLASS_2']);
  assert.deepEqual(Object.keys(after.overview),['CLASS_2']);
  assert.equal(after.active_session,null);
});
test('QR receipt is read-only, scoped and never extends ticket lifetime', () => {
  const {service,gateway,setNow}=createFixture();
  const session=service.startSession(startInput());
  const requestId='receipt_test_1234567890';
  assert.equal(service.getQrReceipt(session.id,requestId),null);
  const ticket=service.issueQrTicket({session_id:session.id,request_id:requestId,valid_seconds:30,direct_form:true});
  const before=JSON.stringify(gateway._tables);
  setNow('2026-09-19T08:00:10Z');
  assert.deepEqual(service.getQrReceipt(session.id,requestId),ticket);
  assert.equal(JSON.stringify(gateway._tables),before);
  assert.equal(service.getQrReceipt(session.id,'different_request_123456'),null);
  service.requestCloseSession(session.id);
  assert.throws(()=>service.getQrReceipt(session.id,requestId),{code:'session_not_active'});
});
}
