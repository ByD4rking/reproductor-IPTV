import '../state/playback_state_machine.dart';

class PlaybackSession {
  PlaybackSession(this.id, {int generation = 0})
      : generation = generation,
        _stateMachine = PlaybackStateMachine();

  final String id;
  final int generation;
  final PlaybackStateMachine _stateMachine;
  bool _stopped = false;
  int _operation = 0;

  PlaybackStateMachine get stateMachine => _stateMachine;
  bool get isStopped => _stopped;
  int get operation => _operation;

  void start() {
    _stopped = false;
    _stateMachine.start(id, generation);
  }

  int beginOperation() {
    if (_stopped) return -1;
    return ++_operation;
  }

  bool isCurrentOperation(int operation) =>
      !_stopped && operation == _operation;

  void stop() {
    _stopped = true;
    _operation++;
    _stateMachine.stop();
  }
}
