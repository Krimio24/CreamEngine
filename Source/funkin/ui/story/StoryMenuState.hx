package funkin.ui.story;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxe.Json;
import funkin.modding.ModManager;
import funkin.play.PlayState;
import funkin.ui.mainmenu.MainMenuState;

typedef LevelData = {
    var name:String;
    var songs:Array<String>;
    @:optional var background:String;
    @:optional var chars:Array<String>;
}

class StoryMenuState extends FlxState {
    var scoreText:FlxText;
    var txtTracklist:FlxText;
    var txtWeekTitle:FlxText;

    var weekList:Array<String> = ["tutorial", "week1", "week2", "week3", "week4", "week5", "week6", "week7"];
    var weekDataList:Array<LevelData> = [];
    var curWeek:Int = 0;

    var difficulties:Array<String> = ["easy", "normal", "hard"];
    var curDifficulty:Int = 1;

    var sprDifficulty:FlxSprite;
    var leftArrow:FlxSprite;
    var rightArrow:FlxSprite;

    var yellowBG:FlxSprite;

    override public function create():Void {
        super.create();

        for (wId in weekList) {
            var raw = ModManager.getContent('ui/story-mode/levels/$wId.json');
            if (raw != null) {
                try {
                    var lData:LevelData = Json.parse(raw);
                    weekDataList.push(lData);
                } catch (e:Dynamic) {
                    weekDataList.push({name: wId.toUpperCase(), songs: [wId]});
                }
            } else {
                weekDataList.push({name: wId.toUpperCase(), songs: [wId]});
            }
        }

        yellowBG = new FlxSprite(0, 56).makeGraphic(FlxG.width, 400, 0xFFF9CF51);
        add(yellowBG);
        scoreText = new FlxText(10, 10, 0, "SCORE: 0", 36);
        scoreText.setFormat("funkin-options", 32, FlxColor.WHITE);
        add(scoreText);

        txtWeekTitle = new FlxText(FlxG.width * 0.7, 10, 0, "", 32);
        txtWeekTitle.setFormat("funkin-options", 32, 0xFFE55777, RIGHT);
        txtWeekTitle.alpha = 0.7;
        add(txtWeekTitle);

        txtTracklist = new FlxText(FlxG.width * 0.05, yellowBG.x + yellowBG.height + 100, 0, "TRACKS", 32);
        txtTracklist.alignment = CENTER;
        txtTracklist.color = 0xFFE55777;
        add(txtTracklist);

        // 4. Selector de Dificultad
        sprDifficulty = new FlxSprite(FlxG.width * 0.75, yellowBG.y + yellowBG.height + 60);
        changeDifficulty();
        add(sprDifficulty);

        changeWeek();
    }

    function changeWeek(change:Int = 0):Void {
        curWeek += change;
        if (curWeek < 0) curWeek = weekDataList.length - 1;
        if (curWeek >= weekDataList.length) curWeek = 0;

        var curData = weekDataList[curWeek];
        txtWeekTitle.text = curData.name;
        txtWeekTitle.x = FlxG.width - (txtWeekTitle.width + 10);

        var trackStr = "TRACKS\n\n";
        if (curData.songs != null) {
            for (s in curData.songs) {
                trackStr += s.toUpperCase() + "\n";
            }
        }
        txtTracklist.text = trackStr;
    }

    function changeDifficulty(change:Int = 0):Void {
        curDifficulty += change;
        if (curDifficulty < 0) curDifficulty = difficulties.length - 1;
        if (curDifficulty >= difficulties.length) curDifficulty = 0;

        var diffName = difficulties[curDifficulty];
        var diffPath = ModManager.getAssetPath('assets/ui/story-mode/difficulties/$diffName.png');
        if (ModManager.exists(diffPath)) {
            sprDifficulty.loadGraphic(diffPath);
        }
        sprDifficulty.x = FlxG.width * 0.8 - (sprDifficulty.width / 2);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        var up = FlxG.keys.justPressed.UP || FlxG.keys.justPressed.W;
        var down = FlxG.keys.justPressed.DOWN || FlxG.keys.justPressed.S;
        var left = FlxG.keys.justPressed.LEFT || FlxG.keys.justPressed.A;
        var right = FlxG.keys.justPressed.RIGHT || FlxG.keys.justPressed.D;
        var accept = FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE;
        var back = FlxG.keys.justPressed.ESCAPE || FlxG.keys.justPressed.BACKSPACE;

        if (up) changeWeek(-1);
        if (down) changeWeek(1);
        if (left) changeDifficulty(-1);
        if (right) changeDifficulty(1);

        if (back) {
            FlxG.switchState(() -> new MainMenuState());
        }

        if (accept) {
            selectWeek();
        }
    }

    function selectWeek():Void {
        var curData = weekDataList[curWeek];
        if (curData != null && curData.songs != null && curData.songs.length > 0) {
            PlayState.currentSong = curData.songs[0].toLowerCase();
            PlayState.currentDifficulty = difficulties[curDifficulty];
            FlxG.switchState(() -> new PlayState());
        }
    }
}
