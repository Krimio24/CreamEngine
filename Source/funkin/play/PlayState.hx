package funkin.play;

import flixel.FlxG;
import flixel.FlxState;
import flixel.FlxCamera;
import flixel.FlxCamera.FlxCameraFollowStyle;
import flixel.FlxObject;
import flixel.group.FlxGroup.FlxTypedGroup;
import funkin.Conductor;
import funkin.play.characters.Character;
import funkin.play.stage.Stage;
import funkin.play.song.Song;
import funkin.play.song.Song.SongNote;
import funkin.play.notes.Note;
import funkin.play.notes.Strumline;

class PlayState extends FlxState {
    public static var instance:PlayState;
    public static var currentSong:String = "tutorial";
    public static var currentDifficulty:String = "normal";

    public var songData:Song;
    public var stage:Stage;

    public var boyfriend:Character;
    public var dad:Character;
    public var gf:Character;

    public var camGame:FlxCamera;
    public var camHUD:FlxCamera;
    public var camFollow:FlxObject;

    public var playerStrums:Strumline;
    public var opponentStrums:Strumline;

    public var allNotes:FlxTypedGroup<Note>;
    public var unspawnNotes:Array<SongNote> = [];

    public var health:Float = 1.0;
    public var songScore:Int = 0;
    public var songMisses:Int = 0;

    static inline var NOTE_SPAWN_TIME:Float = 1800;
    static inline var NOTE_SPEED:Float = 0.45;
    static inline var HIT_WINDOW:Float = 160;
    static inline var MISS_WINDOW:Float = 200;

    public function new() {
        super();
        instance = this;
    }

    override public function create():Void {
        super.create();

        camGame = new FlxCamera();
        camHUD = new FlxCamera();
        camHUD.bgColor.alpha = 0;

        FlxG.cameras.reset(camGame);
        FlxG.cameras.add(camHUD, false);

        songData = Song.loadSong(currentSong, currentDifficulty);

        if (songData != null) {
            unspawnNotes = songData.notes.copy();
        }

        var playData:Dynamic = songData != null && songData.metadata != null
            ? songData.metadata.playData
            : null;

        var characters:Dynamic = playData != null
            ? Reflect.field(playData, "characters")
            : null;

        var stageName:String = playData != null && Reflect.field(playData, "stage") != null
            ? Reflect.field(playData, "stage")
            : "mainStage";

        stage = new Stage(stageName);
        add(stage);

        var bfName:String = characters != null && Reflect.field(characters, "player") != null
            ? Reflect.field(characters, "player")
            : "bf";

        var dadName:String = characters != null && Reflect.field(characters, "opponent") != null
            ? Reflect.field(characters, "opponent")
            : "dad";

        gf = new Character(stage.gfPos[0], stage.gfPos[1], "gf", false);
        dad = new Character(stage.dadPos[0], stage.dadPos[1], dadName, false);
        boyfriend = new Character(stage.bfPos[0], stage.bfPos[1], bfName, true);

        add(gf);
        add(dad);
        add(boyfriend);

        camFollow = new FlxObject();
        camFollow.setPosition(
            boyfriend.getMidpoint().x - 100,
            boyfriend.getMidpoint().y - 100
        );

        add(camFollow);

        camGame.follow(camFollow, FlxCameraFollowStyle.LOCKON, 0.04);
        camGame.zoom = stage.defaultZoom;

        opponentStrums = new Strumline(100, 50);
        playerStrums = new Strumline(FlxG.width - 550, 50);

        opponentStrums.cameras = [camHUD];
        playerStrums.cameras = [camHUD];

        add(opponentStrums);
        add(playerStrums);

        allNotes = new FlxTypedGroup<Note>();
        allNotes.cameras = [camHUD];
        add(allNotes);

        startSong();
    }

    public function startSong():Void {
        var songFolder:String = 'assets/gameplay/songs/$currentSong';

        Conductor.instance.play(songFolder, "Inst");

        if (songData != null && songData.metadata != null
            && songData.metadata.timeChanges != null
            && songData.metadata.timeChanges.length > 0) {

            Conductor.instance.mapTimeChanges(songData.metadata.timeChanges);
        } else if (songData != null && songData.bpm > 0) {
            Conductor.instance.forceBPM(songData.bpm);
        }
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (songData == null || allNotes == null) return;

        spawnNotes();
        updateNotes();
        handleInput();
    }

    function spawnNotes():Void {
        var songPosition:Float = Conductor.instance.songPosition;

        while (unspawnNotes.length > 0
            && unspawnNotes[0].t - songPosition < NOTE_SPAWN_TIME) {

            var noteData:SongNote = unspawnNotes.shift();
            var note:Note = new Note(noteData.t, noteData.d);

            if (noteData.l != null && noteData.l > 0) {
                note.sustainLength = noteData.l;
            }

            allNotes.add(note);
        }
    }

    function updateNotes():Void {
        var songPosition:Float = Conductor.instance.songPosition;
        var notesToRemove:Array<Note> = [];

        allNotes.forEachAlive(function(note:Note) {
            var isPlayerNote:Bool = note.noteData >= 4;
            var direction:Int = note.noteData % 4;

            var targetStrum:Strumline = isPlayerNote
                ? playerStrums
                : opponentStrums;

            if (direction < 0 || direction >= targetStrum.receptors.length) {
                notesToRemove.push(note);
                return;
            }

            var receptor = targetStrum.receptors[direction];

            note.x = receptor.x;

            var noteSpeed:Float = songData.speed > 0
                ? songData.speed
                : 1.0;

            note.y = receptor.y
                + NOTE_SPEED * (songPosition - note.strumTime) * noteSpeed;

            if (!isPlayerNote && note.strumTime <= songPosition) {
                targetStrum.playConfirm(direction);
                dad.playAnim(getSingAnim(direction), true);
                notesToRemove.push(note);
            }

            if (isPlayerNote
                && note.strumTime < songPosition - MISS_WINDOW
                && !note.wasGoodHit) {

                note.tooLate = true;
                noteMiss(direction);
                notesToRemove.push(note);
            }
        });

        for (note in notesToRemove) {
            removeNote(note);
        }
    }

    function removeNote(note:Note):Void {
        if (note == null) return;

        note.kill();
        allNotes.remove(note, true);
        note.destroy();
    }

    function handleInput():Void {
        var pressArray:Array<Bool> = [
            FlxG.keys.justPressed.LEFT || FlxG.keys.justPressed.A,
            FlxG.keys.justPressed.DOWN || FlxG.keys.justPressed.S,
            FlxG.keys.justPressed.UP || FlxG.keys.justPressed.W,
            FlxG.keys.justPressed.RIGHT || FlxG.keys.justPressed.D
        ];

        var releaseArray:Array<Bool> = [
            FlxG.keys.justReleased.LEFT || FlxG.keys.justReleased.A,
            FlxG.keys.justReleased.DOWN || FlxG.keys.justReleased.S,
            FlxG.keys.justReleased.UP || FlxG.keys.justReleased.W,
            FlxG.keys.justReleased.RIGHT || FlxG.keys.justReleased.D
        ];

        for (i in 0...4) {
            if (releaseArray[i]) {
                playerStrums.playStatic(i);
            }

            if (pressArray[i]) {
                playerStrums.playPress(i);
                checkNoteHit(i);
            }
        }
    }

    function checkNoteHit(direction:Int):Void {
        var hitNote:Note = null;
        var minDiff:Float = HIT_WINDOW;

        allNotes.forEachAlive(function(note:Note) {
            if (note.noteData >= 4
                && note.noteData % 4 == direction
                && !note.wasGoodHit
                && !note.tooLate) {

                var diff:Float = Math.abs(
                    note.strumTime - Conductor.instance.songPosition
                );

                if (diff < minDiff) {
                    minDiff = diff;
                    hitNote = note;
                }
            }
        });

        if (hitNote != null) {
            hitNote.wasGoodHit = true;

            playerStrums.playConfirm(direction);
            boyfriend.playAnim(getSingAnim(direction), true);

            songScore += 350;
            health = Math.min(2.0, health + 0.04);

            removeNote(hitNote);
        } else {
            noteMiss(direction);
        }
    }

    function noteMiss(direction:Int):Void {
        songMisses++;
        songScore -= 10;
        health = Math.max(0, health - 0.05);

        boyfriend.playAnim(getSingAnim(direction) + "miss", true);
    }

    function getSingAnim(direction:Int):String {
        return switch (direction) {
            case 0: "singLEFT";
            case 1: "singDOWN";
            case 2: "singUP";
            case 3: "singRIGHT";
            default: "singUP";
        };
    }

    override public function destroy():Void {
        if (Conductor.instance != null) {
            Conductor.instance.stop();
        }

        if (instance == this) {
            instance = null;
        }

        super.destroy();
    }
}

