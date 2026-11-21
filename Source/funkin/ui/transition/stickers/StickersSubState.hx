package funkin.ui.transition.stickers;

import flixel.FlxSubState;
import flixel.util.typeLimit.NextState;
import flixel.FlxG;
import flixel.FlxState;

typedef StickerSubStateParams =
{
    var stickerPaths:Array<String>;
    var nextState:NextState;
    @:optional var onComplete:Void->Void;
}

class StickersSubState extends FlxSubState
{
    public var grpStickers:StickerSpriteGroup;

    var onComplete:Null<Void->Void>;

    var _params:StickerSubStateParams;

    public function new(params:StickerSubStateParams)
    {
        super();

        _params = params;

        onComplete = params.onComplete;

        grpStickers = new StickerSpriteGroup(params.stickerPaths);
    }

    override public function create():Void
    {
        super.create();

        add(grpStickers);

        grpStickers.show(function()
        {
            if (onComplete != null)
                onComplete();
            FlxG.switchState(_params.nextState);
            finish();
        });
    }

    public function finish():Void
    {
        grpStickers.hide(function()
        {
            destroy();
            close();
        });
    }

    override public function destroy():Void
    {
        grpStickers = null;
        super.destroy();
    }
}
