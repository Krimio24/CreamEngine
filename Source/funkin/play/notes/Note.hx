package funkin.play.notes;

import sys.FileSystem;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;

class Note extends FlxSprite {
    public var strumTime:Float = 0;
    public var noteData:Int = 0;
    public var canBeHit:Bool = false;
    public var tooLate:Bool = false;
    public var wasGoodHit:Bool = false;
    public var sustainLength:Float = 0;
    public var isSustainNote:Bool = false;

    public static inline var noteWidth:Float = 112;

    public function new(strumTime:Float, noteData:Int, ?prevNote:Note, isSustainNote:Bool = false) {
        super();
        this.strumTime = strumTime;
        this.noteData = noteData;
        this.isSustainNote = isSustainNote;

        var notePng:String = 'assets/gameplay/notestyles/funkin/notes.png';
        var noteXml:String = 'assets/gameplay/notestyles/funkin/notes.xml';

        if (FileSystem.exists(notePng) && FileSystem.exists(noteXml)) {
            frames = FlxAtlasFrames.fromSparrow(notePng, noteXml);
        }

        var col:String = switch (noteData % 4) {
            case 0: "purple";
            case 1: "blue";
            case 2: "green";
            case 3: "red";
            default: "purple";
        };

        animation.addByPrefix("scroll", col + "0");
        animation.play("scroll");

        setGraphicSize(Std.int(width * 0.7));
        updateHitbox();
    }
}
