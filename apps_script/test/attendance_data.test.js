const assert = require('node:assert/strict');
const test = require('node:test');

const Domain = require('../src/attendance_domain.js');
const Repository = require('../src/attendance_repository.js');
const DataService = require('../src/attendance_service.js');
const TeacherApiContract = require('../src/teacher_api.js');

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
  const now = new Date('2026-09-19T08:00:00.000Z');
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

test('separates raw form responses from accepted attendance and keeps retries idempotent', () => {
  const { gateway, service } = createFixture();
  const session = service.startSession(startInput());

  const raw = service.recordRawFormResponse({
    form_response_id: 'FORM_1',
    session_id: session.id,
    ticket_id: 'TICKET_1',
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
