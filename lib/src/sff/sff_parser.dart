import '../../midi.dart';
import '../../midi_parser.dart';
import '../parser/object_parser.dart';
import 'cseg_parser.dart';
import 'sff_file.dart';

class SffParser extends ObjectParser {
  SffParser(MidiParser midiParser) : super(midiParser);

  SffFile file;
  
  final List<Cseg> _csegs = [];

  static final List<int> fileHeader = [
    'M'.codeUnitAt(0),
    'T'.codeUnitAt(0),
    'h'.codeUnitAt(0),
    'd'.codeUnitAt(0)
  ];
  static final List<int> casmHeader = [
    'C'.codeUnitAt(0),
    'A'.codeUnitAt(0),
    'S'.codeUnitAt(0),
    'M'.codeUnitAt(0)
  ];
  static const partNames = ['Intro A', 'Intro B', 'Intro C', 'Intro D', 'Main A', 'Main B', 'Main C', 'Main D', 'Fill In AA', 'Fill In BB', 'Fill In CC', 'Fill In DD', 'Fill In BA', 'Ending A', 'Ending B', 'Ending C', 'Ending D'];

  void parseTracks() {
    final trackParser = TrackParser(midiParser);

    // Clear track count
    final trackCount = file.trackCount;
    file.trackCount = 0;
    for (var i = 0; i < trackCount; i++) {
      //print(hexPretty(_midiParser.inBuffer.buildRemainingData().sublist(0, 20)));
      trackParser.parseTrack();
      file.addTrack(trackParser.track);
    }
  }

  void linkSegments() {
    file.tracks.forEach((track) {
      SffSegment curSeg;
      var i = 0;
      while (i < track.events.length) {
        if (curSeg != null) {
          curSeg.duration += track.events[i].deltaTime;
        }

        if (track.events[i].midiEvent is MetaEvent && (track.events[i].midiEvent as MetaEvent).data != null) {
          var metaData = String.fromCharCodes((track.events[i].midiEvent as MetaEvent).data);
          if (partNames.contains(metaData)) {
            if (curSeg != null) {
              curSeg.midi.add(TrackEvent(track.events[i].deltaTime, MetaEvent(0x01, []))); // add padding
            }

            curSeg = SffSegment(metaData, [], 0, _csegs.firstWhere((element) => element.sdec.contains(metaData)));
            var segType = metaData.split(' ')[0].toLowerCase();
            switch (segType) {
              case 'intro': file.intros.add(curSeg); break;
              case 'main': file.mains.add(curSeg); break;
              case 'fill': file.fills.add(curSeg); break;
              case 'ending': file.endings.add(curSeg); break;
            }
            i++;
            continue;
          }
        }

        if (curSeg != null) {
          curSeg.midi.add(track.events[i]);
        } else {
          file.setupEvents.add(track.events[i]);
        }

        i++;
      }
    });
  }

  void parseCasm() {
    readBuffer(4);
    if (!buffer.equalsList(casmHeader)) {
      throw const FormatException('Bad casm header');
    }
    final casmSize = midiParser.readUint32();
    
    var endPosition = midiParser.inBuffer.position + casmSize;
    final csegParser = CsegParser(midiParser);
    while (midiParser.inBuffer.position < endPosition) {
      _csegs.add(csegParser.parseCseg());
    }
  }

  void parseFile() {
    parseHeader();
    parseTracks();
    parseCasm();
    linkSegments();
  }

  void parseHeader() {
    readBuffer(4);
    if (!buffer.equalsList(fileHeader)) {
      throw const FormatException('Bad file header');
    }
    final dataHeaderLen = midiParser.readUint32();
    if (dataHeaderLen < 6) {
      throw const FormatException('Bad data header len');
    }
    file = SffFile();

    file.fileFormat = readUint16();
    file.trackCount = readUint16();
    file.timeDivision = readUint16();
    if (dataHeaderLen > 6) {
      skip(dataHeaderLen - 6);
    }
  }

  /// Parser helper
  static SffFile dataFile(List<int> data) {
    final parser = SffParser(MidiParser(data));
    parser.parseFile();
    return parser.file;
  }
}