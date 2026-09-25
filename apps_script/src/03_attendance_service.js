var AttendanceDataService = (function (Repository) {
  'use strict';

  function Service(gateway, options) {
    this._gateway = gateway;
    this._repository = new Repository(gateway, options);
  }

  Service.prototype.initializeSchema = function () {
    return this._gateway.withLock(function () {
      this._gateway.initializeSchema();
      return { initialized: true };
    }.bind(this));
  };

  Service.prototype.listClasses = function () {
    return this._repository.listClasses();
  };

  Service.prototype.listSlotsForClass = function (classId) {
    return this._repository.listSlotsForClass(classId);
  };

  Service.prototype.getActiveSession = function () {
    return this._settleAndRead(function () { return this._repository.getActiveSession(); });
  };

  Service.prototype.listSessions = function (filters) {
    return this._settleAndRead(function () { return this._repository.listSessions(filters); });
  };

  Service.prototype.getSessionResults = function (sessionId) {
    return this._settleAndRead(function () { return this._repository.getSessionResults(sessionId); });
  };

  Service.prototype.startSession = function (input) {
    return this._mutate(function () {
      this._repository.finalizeReadySessions();
      return this._repository.startSession(input);
    });
  };

  Service.prototype.requestCloseSession = function (sessionId) {
    return this._mutate(function () {
      return this._repository.requestCloseSession(sessionId);
    });
  };

  Service.prototype.finalizeSession = function (sessionId) {
    return this._mutate(function () {
      return this._repository.finalizeSession(sessionId);
    });
  };

  Service.prototype.recordRawFormResponse = function (input) {
    return this._mutate(function () {
      return this._repository.recordRawFormResponse(input);
    });
  };

  Service.prototype.recordAttendance = function (input) {
    return this._mutate(function () {
      return this._repository.recordAttendance(input);
    });
  };

  Service.prototype.recordAttempt = function (input) {
    return this._mutate(function () {
      return this._repository.recordAttempt(input);
    });
  };

  Service.prototype.saveTicketState = function (input) {
    return this._mutate(function () {
      return this._repository.saveTicketState(input);
    });
  };

  Service.prototype.issueQrTicket = function (input) {
    return this._mutate(function () {
      return this._repository.issueQrTicket(input);
    });
  };

  Service.prototype.claimQrTicket = function (input) {
    return this._mutate(function () {
      return this._repository.claimQrTicket(input);
    });
  };

  Service.prototype.processFormSubmission = function (input) {
    return this._mutate(function () {
      return this._repository.processFormSubmission(input);
    });
  };

  Service.prototype._mutate = function (callback) {
    return this._gateway.withLock(callback.bind(this));
  };

  Service.prototype._settleAndRead = function (callback) {
    return this._mutate(function () {
      this._repository.finalizeReadySessions();
      return callback.call(this);
    });
  };

  return {
    create: function (gateway, options) {
      return new Service(gateway, options);
    },
  };
})(typeof module !== 'undefined' && module.exports ? require('./02_attendance_repository.js') : AttendanceRepository);

if (typeof module !== 'undefined' && module.exports) {
  module.exports = AttendanceDataService;
}
