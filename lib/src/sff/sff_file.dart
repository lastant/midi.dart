import '../../midi.dart';
import '../midi/file.dart';

enum NoteTranspositionRule {
  transposition,
  fixed,
  guitar
}

enum NoteTranspositionTable {
  bypass,
  melody,
  chord,
  bass,
  melodicMinor,
  melodicMinor5Var,
  harmonicMinor,
  harmonicMinor5Var,
  naturalMinor,
  naturalMinor5Var,
  dorian,
  dorian5Var,
  allPurpose,
  stroke,
  arpeggio
}

enum RetriggerRule {
  stop,
  pitchShift,
  pitchShiftToRoot,
  retrigger,
  retriggerToRoot,
  noteGenerator
}

class SffSegment {
  String name;
  List<TrackEvent> midi;
  int duration;
  Cseg cseg;

  SffSegment(this.name, this.midi, this.duration, this.cseg);
}

class SffFile extends MidiFile {
  List<TrackEvent> setupEvents = [];
  List<SffSegment> intros = [];
  List<SffSegment> mains = [];
  List<SffSegment> fills = [];
  List<SffSegment> endings = [];
}

class Cseg {
  List<String> sdec;
  Map<int, CtabBase> channelCtab = {};
}

class Rules {
  NoteTranspositionRule noteTraspositionRule;
  NoteTranspositionTable noteTranspositionTable;
  bool noteTranspositionTableBassOn;
  int highKey;
  int lowLimit;
  int highLimit;
  RetriggerRule retriggerRule;
}

abstract class CtabBase {
  int sourceChannel;
  String name;
  int destChannel;
  bool editable;
  List<int> notesEnabled;
  List<String> chordsEnabled;
  int sourceChordRoot;
  String sourceChordSymbol;
}

class Ctab extends CtabBase {
  Rules rules;
  List<int> specialFeatures;
}

class Ctb2 extends CtabBase {
  int lowestMiddleNote;
  int highestMiddleNote;
  Rules lowRules;
  Rules middleRules;
  Rules highRules;
}