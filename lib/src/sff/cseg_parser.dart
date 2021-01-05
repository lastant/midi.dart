import 'package:tekartik_midi/midi.dart';
import 'package:tekartik_midi/midi_parser.dart';
import 'package:tekartik_midi/src/parser/event_parser.dart';
import 'package:tekartik_midi/src/parser/object_parser.dart';
import 'package:tekartik_midi/src/sff/sff_file.dart';

import '../../midi_buffer.dart';

class CsegParser extends ObjectParser {
  CsegParser(MidiParser parser) : super(parser);

  Cseg cseg;
  int csegSize;

  int endPosition;

  static List<String> chords = ['Maj','Maj6','Maj7','Maj7#11','Maj(9)','Maj7(9)','Maj6(9)','aug','min','min6','min7','min7b5','min(9)','min7(9)','min7(11)','minMaj7','minMaj7(9)','dim','dim7','7th','7sus4','7b5','7(9)','7#11','7(13)','7(b9)','7(b13)','7(#9)','Maj7aug','7aug','1+8','1+5','sus4','1+2+5'];
  static final List<int> csegHeader = [
    'C'.codeUnitAt(0),
    'S'.codeUnitAt(0),
    'E'.codeUnitAt(0),
    'G'.codeUnitAt(0)
  ];
  static final List<int> sdecHeader = [
    'S'.codeUnitAt(0),
    'd'.codeUnitAt(0),
    'e'.codeUnitAt(0),
    'c'.codeUnitAt(0)
  ];
  static final List<int> ctabHeader = [
    'C'.codeUnitAt(0),
    't'.codeUnitAt(0),
    'a'.codeUnitAt(0),
    'b'.codeUnitAt(0)
  ];
  static final List<int> ctb2Header = [
    'C'.codeUnitAt(0),
    't'.codeUnitAt(0),
    'b'.codeUnitAt(0),
    '2'.codeUnitAt(0)
  ];
  static final List<int> cnttHeader = [
    'C'.codeUnitAt(0),
    'n'.codeUnitAt(0),
    't'.codeUnitAt(0),
    't'.codeUnitAt(0)
  ];

  void parseHeader() {
    midiParser.readBuffer(4);
    if (!buffer.equalsList(csegHeader)) {
      throw const FormatException('Bad cseg header');
    }
    cseg = Cseg();
    csegSize = midiParser.readUint32();

    endPosition = midiParser.inBuffer.position + csegSize;
  }

  void parseSdec() {
    midiParser.readBuffer(4);
    if (!buffer.equalsList(sdecHeader)) {
      throw const FormatException('Bad sdec header');
    }

    var sdecSize = midiParser.readUint32();
    if (sdecSize > 0) {
      final buffer = OutBuffer(sdecSize);
      midiParser.read(buffer, sdecSize);
      cseg.sdec = String.fromCharCodes(buffer.data).split(',');
    }
  }

  void parseNoteTranspositionTable(Rules rules, version) {
    var noteTranspositionTable = midiParser.readUint8();
    if (rules.noteTraspositionRule == NoteTranspositionRule.guitar) {
      switch (noteTranspositionTable & 0x0F) {
        case 0: rules.noteTranspositionTable = NoteTranspositionTable.allPurpose; break;
        case 1: rules.noteTranspositionTable = NoteTranspositionTable.stroke; break;
        case 2: rules.noteTranspositionTable = NoteTranspositionTable.arpeggio; break;
      }
    } else {
      switch (noteTranspositionTable & 0x0F) {
        case 0: rules.noteTranspositionTable = NoteTranspositionTable.bypass; break;
        case 1: rules.noteTranspositionTable = NoteTranspositionTable.melody; break;
        case 2: rules.noteTranspositionTable = NoteTranspositionTable.chord; break;
        case 3: rules.noteTranspositionTable = version == 1 ? NoteTranspositionTable.bass : NoteTranspositionTable.melodicMinor; break;
        case 4: rules.noteTranspositionTable = version == 1 ? NoteTranspositionTable.melodicMinor : NoteTranspositionTable.melodicMinor5Var; break;
        case 5: rules.noteTranspositionTable = version == 1 ? NoteTranspositionTable.harmonicMinor : NoteTranspositionTable.harmonicMinor; break;
        case 6: rules.noteTranspositionTable = NoteTranspositionTable.harmonicMinor5Var; break;
        case 7: rules.noteTranspositionTable = NoteTranspositionTable.naturalMinor; break;
        case 8: rules.noteTranspositionTable = NoteTranspositionTable.naturalMinor5Var; break;
        case 9: rules.noteTranspositionTable = NoteTranspositionTable.dorian; break;
        case 10: rules.noteTranspositionTable = NoteTranspositionTable.dorian5Var; break;
      }
      rules.noteTranspositionTableBassOn = noteTranspositionTable & 0x80 > 0;
    }
  }

  Rules parseRules(int version) {
    var rules = Rules();

    switch(midiParser.readUint8()) {
      case 0: rules.noteTraspositionRule = NoteTranspositionRule.transposition; break;
      case 1: rules.noteTraspositionRule = NoteTranspositionRule.fixed; break;
      case 2: rules.noteTraspositionRule = NoteTranspositionRule.guitar; break;
    }

    parseNoteTranspositionTable(rules, version);
    rules.highKey = midiParser.readUint8();
    rules.lowLimit = midiParser.readUint8();
    rules.highLimit = midiParser.readUint8();

    var retriggerRule = midiParser.readUint8();
    switch (retriggerRule) {
      case 0: rules.retriggerRule = RetriggerRule.stop; break;
      case 1: rules.retriggerRule = RetriggerRule.pitchShift; break;
      case 2: rules.retriggerRule = RetriggerRule.pitchShiftToRoot; break;
      case 3: rules.retriggerRule = RetriggerRule.retrigger; break;
      case 4: rules.retriggerRule = RetriggerRule.retriggerToRoot; break;
      case 5: rules.retriggerRule = RetriggerRule.noteGenerator; break;
    }

    return rules;
  }

  void parseCtab() {
    var ctab = Ctab();
    var ctabSize = midiParser.readUint32();
    var ctabEndPosition = midiParser.inBuffer.position + ctabSize;

    parseCtabCommon(ctab);
    ctab.rules = parseRules(1);

    var specialFeatures = midiParser.readUint8();
    if (specialFeatures == 1) {
      final buffer = OutBuffer(4);
      midiParser.read(buffer, 4);
      ctab.specialFeatures = buffer.data;
    }

    cseg.channelCtab[ctab.sourceChannel] = ctab;

    midiParser.skip(ctabEndPosition - midiParser.inBuffer.position);
  }

  void parseCtabCommon(CtabBase ctab) {
    ctab.sourceChannel = midiParser.readUint8();
    
    final buffer = OutBuffer(8);
    midiParser.read(buffer, 8);
    ctab.name = String.fromCharCodes(buffer.data);

    ctab.destChannel = midiParser.readUint8();

    ctab.editable = midiParser.readUint8() > 0;

    var notesEnabled = midiParser.readUint16();
    ctab.notesEnabled = [];
    for (var i = 0; i < 12; i++) {
      if (notesEnabled & (1 << i) > 0) ctab.notesEnabled.add(i);
    }

    var chordsEnabled = (midiParser.readUint8() << 32) + midiParser.readUint32();
    ctab.chordsEnabled = [];
    for (var i = 0; i < 34; i++) {
      if (chordsEnabled & (1 << i) > 0) ctab.chordsEnabled.add(chords[i]);
    }

    ctab.sourceChordRoot = midiParser.readUint8();

    ctab.sourceChordSymbol = chords[midiParser.readUint8()];
  }

  void parseCtb2() {
    var ctab = Ctb2();
    var ctabSize = midiParser.readUint32();
    var ctabEndPosition = midiParser.inBuffer.position + ctabSize;

    parseCtabCommon(ctab);

    ctab.lowestMiddleNote = midiParser.readUint8();
    ctab.highestMiddleNote = midiParser.readUint8();
    
    ctab.lowRules = parseRules(2);
    ctab.middleRules = parseRules(2);
    ctab.highRules = parseRules(2);

    cseg.channelCtab[ctab.sourceChannel] = ctab;

    midiParser.skip(ctabEndPosition - midiParser.inBuffer.position);
  }

  void parseCntt() {
    var cnttSize = midiParser.readUint32();
    var cnttEndPosition = midiParser.inBuffer.position + cnttSize;
    var ctab = cseg.channelCtab[midiParser.readUint8()] as Ctab;
    parseNoteTranspositionTable(ctab.rules, 1);
    midiParser.skip(cnttEndPosition - midiParser.inBuffer.position);
  }

  Cseg parseCseg() {
    parseHeader();
    parseSdec();
    while (midiParser.inBuffer.position < endPosition) {
      midiParser.readBuffer(4);
      if (buffer.equalsList(ctabHeader)) {
        parseCtab();
      } else if (buffer.equalsList(ctb2Header)) {
        parseCtb2();
      } else if (buffer.equalsList(cnttHeader)) {
        parseCntt();
      }
    }
    return cseg;
  }
}
