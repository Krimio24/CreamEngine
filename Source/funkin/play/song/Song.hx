package funkin.play.song;

import haxe.Json;
import funkin.modding.ModManager;

typedef SongNote = {
    var t:Float;
    var d:Int;
    @:optional var l:Null<Float>;
    @:optional var k:Null<String>;
}

typedef SongEvent = {
    var t:Float;
    var e:String;
    var v:Dynamic;
}

typedef SongMetadata = {
    var songName:String;
    @:optional var artist:String;
    @:optional var playData:Dynamic;
    @:optional var timeChanges:Array<Dynamic>;
}

typedef SongChart = {
    @:optional var scrollSpeed:Dynamic;
    @:optional var events:Array<SongEvent>;
    @:optional var notes:Dynamic;
}

class Song {
    public var songId:String;
    public var metadata:SongMetadata;
    public var chart:SongChart;
    public var notes:Array<SongNote> = [];
    public var speed:Float = 1.0;
    public var bpm:Float = 100.0;

    public function new(songId:String) {
        this.songId = songId;
    }

    public static function loadSong(songId:String, difficulty:String = "normal"):Null<Song> {
        var song = new Song(songId);

        var metaPath = 'gameplay/songs/$songId/$songId-metadata.json';
        var metaRaw = ModManager.getContent(metaPath);
        if (metaRaw != null) {
            try {
                song.metadata = Json.parse(metaRaw);
            } catch (e:Dynamic) {
                trace('Error reading song metadata: $e');
            }
        }

        if (song.metadata != null && song.metadata.timeChanges != null && song.metadata.timeChanges.length > 0) {
            song.bpm = song.metadata.timeChanges[0].bpm;
        }

        var chartPath = 'gameplay/songs/$songId/$songId-chart.json';
        var chartRaw = ModManager.getContent(chartPath);
        if (chartRaw != null) {
            try {
                song.chart = Json.parse(chartRaw);
            } catch (e:Dynamic) {
                trace('Error reading song chart: $e');
            }
        }

        if (song.chart != null) {
            if (song.chart.scrollSpeed != null) {
                var speedVal = Reflect.field(song.chart.scrollSpeed, difficulty);
                if (speedVal != null) song.speed = speedVal;
                else song.speed = 1.0;
            }

            if (song.chart.notes != null) {
                var notesList:Array<Dynamic> = Reflect.field(song.chart.notes, difficulty);
                if (notesList == null) notesList = Reflect.field(song.chart.notes, "normal");
                if (notesList != null) {
                    for (n in notesList) {
                        song.notes.push({
                            t: n.t,
                            d: n.d,
                            l: (n.l != null) ? n.l : 0,
                            k: n.k
                        });
                    }
                    song.notes.sort(function(a, b) return a.t < b.t ? -1 : 1);
                }
            }
        }

        return song;
    }
}
