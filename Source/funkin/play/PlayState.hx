package funkin.play;

import flixel.FlxG;
import flixel.FlxState;
import flixel.FlxCamera;
import flixel.FlxObject;
import flixel.group.FlxGroup.FlxTypedGroup;
import funkin.Conductor;
import funkin.modding.ModManager;
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

    public function new() {
        super();
        instance = this;
    }

    override public function create() {
        super.create();

        camGame = new FlxCamera();
        camHUD = new FlxCamera();
        camHUD.bgColor.alpha = 0;
        FlxG.cameras.reset(camGame);
        FlxG.cameras.add(camHUD, false);

        songData = Song.loadSong(currentSong, currentDifficulty);
        if (songData != null) {

            if (songData.bpm > 0)
                Conductor.instance.forceBPM(songData.bpm);
            unspawnNotes = songData.notes.copy();
        }

        var stageName = (songData != null && songData.metadata != null && songData.metadata.playData != null && songData.metadata.playData.stage != null)
            ? songData.metadata.playData.stage
            : "mainStage";
        stage = new Stage(stageName);
        add(stage);

        var bfName = (songData != null && songData.metadata != null && songData.metadata.playData != null && songData.metadata.playData.characters != null)
            ? songData.metadata.playData.characters.player
            : "bf";
        var dadName = (songData != null && songData.metadata != null && songData.metadata.playData != null && songData.metadata.playData.characters != null)
            ? songData.metadata.playData.characters.opponent
            : "dad";

        gf = new Character(stage.gfPos[0], stage.gfPos[1], "gf", false);
        dad = new Character(stage.dadPos[0], stage.dadPos[1], dadName, false);
        boyfriend = new Character(stage.bfPos[0], stage.bfPos[1], bfName, true);

        add(gf);
        add(dad);
        add(boyfriend);

        camFollow = new FlxObject(0, 0, 1, 1);
        camFollow.setPosition(boyfriend.getMidpoint().x - 100, boyfriend.getMidpoint().y - 100);
        add(camFollow);
        camGame.follow(camFollow, LOCKON, 0.04);
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
        var songFolder = 'gameplay/songs/$currentSong';
        var instPrefix = 'Inst';
        Conductor.instance.play(songFolder, instPrefix);
    }

    override public function update(elapsed:Float) {
        super.update(elapsed);


        while (unspawnNotes.length > 0 && (unspawnNotes[0].t - Conductor.instance.songPosition) < 1800) {
            var nData = unspawnNotes.shift();
            var note = new Note(nData.t, nData.d);
            allNotes.add(note);
        }

        allNotes.forEachAlive(function(daNote:Note) {
            var isPlayerNote = daNote.noteData >= 4;
            var targetStrum = isPlayerNote ? playerStrums : opponentStrums;
            var dir = daNote.noteData % 4;
            var receptor = targetStrum.receptors[dir];

            daNote.x = receptor.x;
            var noteSpeed = (songData != null) ? songData.speed : 1.0;
            daNote.y = receptor.y + (0.45 * (Conductor.instance.songPosition - daNote.strumTime) * noteSpeed);

            // CPU hit (oponente)
            if (!isPlayerNote && daNote.strumTime <= Conductor.instance.songPosition) {
                targetStrum.playConfirm(dir);
                dad.playAnim(getSingAnim(dir), true);
                daNote.kill();
                allNotes.remove(daNote, true);
                daNote.destroy();
            }

            // Nota perdida (player)
            if (isPlayerNote && daNote.strumTime < Conductor.instance.songPosition - 200 && !daNote.wasGoodHit) {
                daNote.tooLate = true;
                noteMiss(dir);
                daNote.kill();
                allNotes.remove(daNote, true);
                daNote.destroy();
            }
        });

        handleInput();
    }

    function handleInput():Void {
        var pressArray:Array<Bool> = [
            FlxG.keys.justPressed.LEFT || FlxG.keys.justPressed.A,
            FlxG.keys.justPressed.DOWN || FlxG.keys.justPressed.S,
            FlxG.keys.justPressed.UP   || FlxG.keys.justPressed.W,
            FlxG.keys.justPressed.RIGHT || FlxG.keys.justPressed.D
        ];

        var releaseArray:Array<Bool> = [
            FlxG.keys.justReleased.LEFT || FlxG.keys.justReleased.A,
            FlxG.keys.justReleased.DOWN || FlxG.keys.justReleased.S,
            FlxG.keys.justReleased.UP   || FlxG.keys.justReleased.W,
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
        var minDiff:Float = 160;

        allNotes.forEachAlive(function(daNote:Note) {
            if (daNote.noteData >= 4 && (daNote.noteData % 4) == direction && !daNote.wasGoodHit) {
                var diff = Math.abs(daNote.strumTime - Conductor.instance.songPosition);
                if (diff < minDiff) {
                    minDiff = diff;
                    hitNote = daNote;
                }
            }
        });

        if (hitNote != null) {
            hitNote.wasGoodHit = true;
            playerStrums.playConfirm(direction);
            boyfriend.playAnim(getSingAnim(direction), true);
            songScore += 350;
            health = Math.min(2.0, health + 0.04);

            hitNote.kill();
            allNotes.remove(hitNote, true);
            hitNote.destroy();
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

    function getSingAnim(dir:Int):String {
        return switch (dir) {
            case 0: "singLEFT";
            case 1: "singDOWN";
            case 2: "singUP";
            case 3: "singRIGHT";
            default: "singUP";
        };
    }
}
