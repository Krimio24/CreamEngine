package funkin.ui.transition.preload;

import funkin.modding.FunkinModding;
import funkin.util.TaskBarUtil;
import openfl.events.MouseEvent;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Sprite;
import openfl.Lib;
import flixel.math.FlxMath;
import flixel.system.FlxBasePreloader;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;

#if FEATURE_TOUCH_HERE_TO_PLAY
@:bitmap('art/touchHereToPlay.png')
class TouchHereToPlayImage extends BitmapData
{
}
#end

class FunkinPreloader extends FlxBasePreloader
{
  static inline final MIN_STAGE_TIME:Float = 0.1;
  static inline final MS_PER_SEC:Float = 1000.0;
  static inline final BACKGROUND_COLOR:Int = 0xFF000000;
  static inline final BAR_COLOR:Int = 0xFFA4FF11;
  static final BASE_WIDTH:Float = 1280;
  static final BAR_PADDING:Float = 20;
  static final BAR_HEIGHT:Int = 12;
  static final PIECES_COUNT:Int = 16;
  static final FADE_TIME:Float = 2.5;

  var ratio:Float = 0;
  var currentState:FunkinPreloaderState = FunkinPreloaderState.NotStarted;
  var downloadingAssetsPercent:Float = -1;
  var downloadingAssetsComplete:Bool = false;
  var preloadingPlayAssetsPercent:Float = -1;
  var preloadingPlayAssetsStartTime:Float = -1;
  var preloadingPlayAssetsComplete:Bool = false;
  var cachingGraphicsPercent:Float = -1;
  var cachingGraphicsStartTime:Float = -1;
  var cachingGraphicsComplete:Bool = false;
  var cachingAudioPercent:Float = -1;
  var cachingAudioStartTime:Float = -1;
  var cachingAudioComplete:Bool = false;
  var cachingDataPercent:Float = -1;
  var cachingDataStartTime:Float = -1;
  var cachingDataComplete:Bool = false;
  var parsingSpritesheetsPercent:Float = -1;
  var parsingSpritesheetsStartTime:Float = -1;
  var parsingSpritesheetsComplete:Bool = false;
  var parsingStagesPercent:Float = -1;
  var parsingStagesStartTime:Float = -1;
  var parsingStagesComplete:Bool = false;
  var parsingCharactersPercent:Float = -1;
  var parsingCharactersStartTime:Float = -1;
  var parsingCharactersComplete:Bool = false;
  var parsingSongsPercent:Float = -1;
  var parsingSongsStartTime:Float = -1;
  var parsingSongsComplete:Bool = false;
  var initializingScriptsPercent:Float = -1;
  var funkinModding:FunkinModding;

  var completeTime:Float = -1;

  #if FEATURE_TOUCH_HERE_TO_PLAY
  var touchedHereToPlay:Bool = false;
  var touchHereToPlay:Bitmap;
  var touchHereSprite:Sprite;
  #end
  var progressBarPieces:Array<Sprite>;
  var progressLeftText:TextField;
  var progressRightText:TextField;
  var dspText:TextField;
  var fnfText:TextField;
  var enhancedText:TextField;
  var stereoText:TextField;
  var vfdShader:VFDOverlay;
  var vfdBitmap:Bitmap;
  var rTextGroup:Sprite;
  var progressLines:Sprite;

  public function new()
  {
    super(MIN_STAGE_TIME);

    trace('Starting custom preloader...');
  }

  override function create():Void
  {
    super.create();

    Lib.current.stage.color = BACKGROUND_COLOR;

    this._width = Lib.current.stage.stageWidth;
    this._height = Lib.current.stage.stageHeight;

    trace(' Resolution: ${this._width}x${this._height}');

    #if mobile
    var display = Lib.current.stage.window.display;
    var dpiScale = display.dpi / 160.0;
    var normalizedWidth = this._width / dpiScale;
    ratio = normalizedWidth / BASE_WIDTH;
    #else
    ratio = 1.0;
    #end

    progressBarPieces = [];
    var maxBarWidth:Float = this._width - BAR_PADDING * 2;
    var pieceWidth:Float = maxBarWidth / PIECES_COUNT;
    var pieceGap:Int = 8;

    progressLines = new openfl.display.Sprite();
    progressLines.graphics.lineStyle(2, BAR_COLOR);
    progressLines.graphics.drawRect(-2, 0, this._width + 4, 30);
    progressLines.y = this._height * 0.67;
    addChild(progressLines);

    for (i in 0...PIECES_COUNT)
    {
      var piece:Sprite = new Sprite();
      piece.graphics.beginFill(BAR_COLOR);
      piece.graphics.drawRoundRect(0, 0, pieceWidth - pieceGap, BAR_HEIGHT, 4, 4);
      piece.graphics.endFill();

      piece.x = i * (piece.width + pieceGap);
      piece.y = progressLines.y + 8;
      addChild(piece);
      progressBarPieces.push(piece);
    }

    var progressLeftTextFormat:TextFormat = new TextFormat('DS-Digital', Std.int(32 * ratio), BAR_COLOR, true);
    progressLeftTextFormat.align = TextFormatAlign.LEFT;
    var progressRightTextFormat:TextFormat = new TextFormat('DS-Digital', 16, BAR_COLOR, true);
    progressRightTextFormat.align = TextFormatAlign.RIGHT;

    progressLeftText = makeText(BAR_PADDING * ratio, progressLines.y, 'Downloading assets...', BAR_COLOR);
    progressLeftText.defaultTextFormat = progressLeftTextFormat;
    progressLeftText.width = this._width - BAR_PADDING * 2;
    addChild(progressLeftText);
    progressLeftText.y -= (progressLeftText.textHeight / ratio) * 2.5;

    progressRightText = makeText(BAR_PADDING, this._height - BAR_PADDING - BAR_HEIGHT - 16 - 4, '0%', BAR_COLOR);
    progressRightText.defaultTextFormat = progressRightTextFormat;
    addChild(progressRightText);

    rTextGroup = new Sprite();
    rTextGroup.graphics.beginFill(BAR_COLOR, 1);
    rTextGroup.graphics.drawRoundRect(0, 40, 64, 20, 5, 5);
    rTextGroup.graphics.drawRoundRect(70, 40, 58, 20, 5, 5);
    rTextGroup.graphics.endFill();
    rTextGroup.graphics.beginFill(BAR_COLOR, 0.1);
    rTextGroup.graphics.drawRoundRect(0, 40, 128, 20, 5, 5);
    rTextGroup.graphics.endFill();
    rTextGroup.x = this._width * 0.64;
    rTextGroup.y = progressLeftText.y;
    addChild(rTextGroup);

    dspText = makeText(10, 33, 'DSP', 0x000000);
    dspText.width = this._width;
    dspText.height = 30;
    rTextGroup.addChild(dspText);

    fnfText = makeText(78, 33, 'FNF', 0x000000);
    fnfText.width = this._width;
    fnfText.height = 30;
    rTextGroup.addChild(fnfText);

    enhancedText = makeText(-100, 40, 'ENHANCED', BAR_COLOR);
    enhancedText.width = this._width;
    enhancedText.height = 100;
    rTextGroup.addChild(enhancedText);

    stereoText = makeText(0, 0, 'STEREO', BAR_COLOR);
    stereoText.width = this._width;
    stereoText.height = 100;
    rTextGroup.addChild(stereoText);

    vfdBitmap = new Bitmap(new BitmapData(this._width, this._height, true, 0xFFFFFFFF));
    addChild(vfdBitmap);

    vfdShader = new VFDOverlay();
    vfdBitmap.shader = vfdShader;

    #if FEATURE_TOUCH_HERE_TO_PLAY
    touchHereToPlay = createBitmap(TouchHereToPlayImage, function(bmp:Bitmap)
    {
      bmp.scaleX = bmp.scaleY = ratio * 0.5;
      bmp.x = (this._width - bmp.width) / 2;
      bmp.y = (this._height - bmp.height) / 2;
    });
    touchHereToPlay.alpha = 0.0;

    touchHereSprite = new Sprite();
    touchHereSprite.buttonMode = false;
    touchHereSprite.addChild(touchHereToPlay);
    addChild(touchHereSprite);
    #end
  }

  function makeText(txtX:Float, txtY:Float, txt:String, color:Int):TextField
  {
    var text:TextField = new TextField();
    text.selectable = false;
    text.width = this._width - BAR_PADDING * 2;
    text.x = txtX;
    text.y = txtY;
    text.text = txt;
    text.textColor = color;
    return text;
  }

  var lastElapsed:Float = 0.0;
  var lastLoggedPercent:Int = -1;
  var lastLoggedState:FunkinPreloaderState = FunkinPreloaderState.NotStarted;

  override public function update(percent:Float):Void
  {
    var elapsed:Float = (Date.now().getTime() - this._startTime) / MS_PER_SEC;

    vfdShader.update(elapsed * 100);

    downloadingAssetsPercent = percent;
    var loadPercent:Float = updateState(percent, elapsed);
    updateGraphics(loadPercent, elapsed);

    TaskBarUtil.setProgress(percent);

    lastElapsed = elapsed;
  }

  public function updateState(percent:Float, elapsed:Float):Float
  {
    switch (currentState)
    {
      case FunkinPreloaderState.NotStarted:
        if (downloadingAssetsPercent > 0.0) currentState = FunkinPreloaderState.DownloadingAssets;

        return percent;

      case FunkinPreloaderState.DownloadingAssets:
        if (downloadingAssetsPercent >= 1.0 || (elapsed > MIN_STAGE_TIME && downloadingAssetsComplete))
        {
          currentState = FunkinPreloaderState.PreloadingPlayAssets;
        }

        return percent;

      case FunkinPreloaderState.PreloadingPlayAssets:
        if (preloadingPlayAssetsPercent < 0.0)
        {
          preloadingPlayAssetsStartTime = elapsed;
          preloadingPlayAssetsPercent = 0.0;

          preloadingPlayAssetsPercent = 1.0;
          preloadingPlayAssetsComplete = true;
          return 0.0;
        }
        else if (MIN_STAGE_TIME > 0)
        {
          var elapsedPreloadingPlayAssets:Float = elapsed - preloadingPlayAssetsStartTime;
          if (preloadingPlayAssetsComplete && elapsedPreloadingPlayAssets >= MIN_STAGE_TIME)
          {
            currentState = FunkinPreloaderState.InitializingScripts;
            return 0.0;
          }
          else
          {
            if (preloadingPlayAssetsPercent < (elapsedPreloadingPlayAssets / MIN_STAGE_TIME))
            {
              return preloadingPlayAssetsPercent;
            }
            else
            {
              return elapsedPreloadingPlayAssets / MIN_STAGE_TIME;
            }
          }
        }
        else
        {
          if (preloadingPlayAssetsComplete) currentState = FunkinPreloaderState.InitializingScripts;
        }

        return preloadingPlayAssetsPercent;

      case FunkinPreloaderState.InitializingScripts:
        if (initializingScriptsPercent < 0.0)
        {
          initializingScriptsPercent = 0.0;

          #if sys
          funkinModding = new FunkinModding();
          funkinModding.init();
          #end

          initializingScriptsPercent = 1.0;
          currentState = FunkinPreloaderState.CachingGraphics;
          return 0.0;
        }

        return initializingScriptsPercent;

      case CachingGraphics:
        if (cachingGraphicsPercent < 0)
        {
          cachingGraphicsPercent = 0.0;
          cachingGraphicsStartTime = elapsed;

          cachingGraphicsPercent = 1.0;
          cachingGraphicsComplete = true;
          return 0.0;
        }
        else if (MIN_STAGE_TIME > 0)
        {
          var elapsedCachingGraphics:Float = elapsed - cachingGraphicsStartTime;
          if (cachingGraphicsComplete && elapsedCachingGraphics >= MIN_STAGE_TIME)
          {
            currentState = FunkinPreloaderState.CachingAudio;
            return 0.0;
          }
          else
          {
            if (cachingGraphicsPercent < (elapsedCachingGraphics / MIN_STAGE_TIME))
            {
              return cachingGraphicsPercent;
            }
            else
            {
              return elapsedCachingGraphics / MIN_STAGE_TIME;
            }
          }
        }
        else
        {
          if (cachingGraphicsComplete)
          {
            currentState = FunkinPreloaderState.CachingAudio;
            return 0.0;
          }
          else
          {
            return cachingGraphicsPercent;
          }
        }

      case CachingAudio:
        if (cachingAudioPercent < 0)
        {
          cachingAudioPercent = 0.0;
          cachingAudioStartTime = elapsed;

          cachingAudioPercent = 1.0;
          cachingAudioComplete = true;
          return 0.0;
        }
        else if (MIN_STAGE_TIME > 0)
        {
          var elapsedCachingAudio:Float = elapsed - cachingAudioStartTime;
          if (cachingAudioComplete && elapsedCachingAudio >= MIN_STAGE_TIME)
          {
            currentState = FunkinPreloaderState.CachingData;
            return 0.0;
          }
          else
          {
            if (cachingAudioPercent < (elapsedCachingAudio / MIN_STAGE_TIME))
            {
              return cachingAudioPercent;
            }
            else
            {
              return elapsedCachingAudio / MIN_STAGE_TIME;
            }
          }
        }
        else
        {
          if (cachingAudioComplete)
          {
            currentState = FunkinPreloaderState.CachingData;
            return 0.0;
          }
          else
          {
            return cachingAudioPercent;
          }
        }

      case CachingData:
        if (cachingDataPercent < 0)
        {
          cachingDataPercent = 0.0;
          cachingDataStartTime = elapsed;

          var assetsToCache:Array<String> = [];
          var sparrowFramesToCache:Array<String> = [];

          cachingDataPercent = 1.0;
          cachingDataComplete = true;
          return 0.0;
        }
        else if (MIN_STAGE_TIME > 0)
        {
          var elapsedCachingData:Float = elapsed - cachingDataStartTime;
          if (cachingDataComplete && elapsedCachingData >= MIN_STAGE_TIME)
          {
            currentState = FunkinPreloaderState.ParsingSpritesheets;
            return 0.0;
          }
          else
          {
            if (cachingDataPercent < (elapsedCachingData / MIN_STAGE_TIME))
            {
              return cachingDataPercent;
            }
            else
            {
              return elapsedCachingData / MIN_STAGE_TIME;
            }
          }
        }
        else
        {
          if (cachingDataComplete)
          {
            currentState = FunkinPreloaderState.ParsingSpritesheets;
            return 0.0;
          }
        }

        return cachingDataPercent;

      case ParsingSpritesheets:
        if (parsingSpritesheetsPercent < 0)
        {
          parsingSpritesheetsPercent = 0.0;
          parsingSpritesheetsStartTime = elapsed;

          var sparrowFramesToCache = [];

          parsingSpritesheetsPercent = 1.0;
          parsingSpritesheetsComplete = true;
          return 0.0;
        }
        else if (MIN_STAGE_TIME > 0)
        {
          var elapsedParsingSpritesheets:Float = elapsed - parsingSpritesheetsStartTime;
          if (parsingSpritesheetsComplete && elapsedParsingSpritesheets >= MIN_STAGE_TIME)
          {
            currentState = FunkinPreloaderState.ParsingStages;
            return 0.0;
          }
          else
          {
            if (parsingSpritesheetsPercent < (elapsedParsingSpritesheets / MIN_STAGE_TIME))
            {
              return parsingSpritesheetsPercent;
            }
            else
            {
              return elapsedParsingSpritesheets / MIN_STAGE_TIME;
            }
          }
        }
        else
        {
          if (parsingSpritesheetsComplete)
          {
            currentState = FunkinPreloaderState.ParsingStages;
            return 0.0;
          }
        }

        return parsingSpritesheetsPercent;

      case ParsingStages:
        if (parsingStagesPercent < 0)
        {
          parsingStagesPercent = 0.0;
          parsingStagesStartTime = elapsed;

          parsingStagesPercent = 1.0;
          parsingStagesComplete = true;
          return 0.0;
        }
        else if (MIN_STAGE_TIME > 0)
        {
          var elapsedParsingStages:Float = elapsed - parsingStagesStartTime;
          if (parsingStagesComplete && elapsedParsingStages >= MIN_STAGE_TIME)
          {
            currentState = FunkinPreloaderState.ParsingCharacters;
            return 0.0;
          }
          else
          {
            if (parsingStagesPercent < (elapsedParsingStages / MIN_STAGE_TIME))
            {
              return parsingStagesPercent;
            }
            else
            {
              return elapsedParsingStages / MIN_STAGE_TIME;
            }
          }
        }
        else
        {
          if (parsingStagesComplete)
          {
            currentState = FunkinPreloaderState.ParsingCharacters;
            return 0.0;
          }
        }

        return parsingStagesPercent;

      case ParsingCharacters:
        if (parsingCharactersPercent < 0)
        {
          parsingCharactersPercent = 0.0;
          parsingCharactersStartTime = elapsed;

          parsingCharactersPercent = 1.0;
          parsingCharactersComplete = true;
          return 0.0;
        }
        else if (MIN_STAGE_TIME > 0)
        {
          var elapsedParsingCharacters:Float = elapsed - parsingCharactersStartTime;
          if (parsingCharactersComplete && elapsedParsingCharacters >= MIN_STAGE_TIME)
          {
            currentState = FunkinPreloaderState.ParsingSongs;
            return 0.0;
          }
          else
          {
            if (parsingCharactersPercent < (elapsedParsingCharacters / MIN_STAGE_TIME))
            {
              return parsingCharactersPercent;
            }
            else
            {
              return elapsedParsingCharacters / MIN_STAGE_TIME;
            }
          }
        }
        else
        {
          if (parsingStagesComplete)
          {
            currentState = FunkinPreloaderState.ParsingSongs;
            return 0.0;
          }
        }

        return parsingCharactersPercent;

      case ParsingSongs:
        if (parsingSongsPercent < 0)
        {
          parsingSongsPercent = 0.0;
          parsingSongsStartTime = elapsed;

          parsingSongsPercent = 1.0;
          parsingSongsComplete = true;

          return 0.0;
        }
        else if (MIN_STAGE_TIME > 0)
        {
          var elapsedParsingSongs:Float = elapsed - parsingSongsStartTime;
          if (parsingSongsComplete && elapsedParsingSongs >= MIN_STAGE_TIME)
          {
            currentState = FunkinPreloaderState.Complete;
            return 0.0;
          }
          else
          {
            if (parsingSongsPercent < (elapsedParsingSongs / MIN_STAGE_TIME))
            {
              return parsingSongsPercent;
            }
            else
            {
              return elapsedParsingSongs / MIN_STAGE_TIME;
            }
          }
        }
        else
        {
          if (parsingSongsComplete)
          {
            currentState = FunkinPreloaderState.Complete;
            return 0.0;
          }
          else
          {
            return parsingSongsPercent;
          }
        }
      case FunkinPreloaderState.Complete:
        if (completeTime <= 0)
        {
          completeTime = elapsed;
        }

        return 1.0;
      #if FEATURE_TOUCH_HERE_TO_PLAY
      case FunkinPreloaderState.TouchHereToPlay:
        if (completeTime < 0)
        {
          completeTime = elapsed;
        }

        if (touchHereToPlay.alpha < 1.0)
        {
          touchHereSprite.buttonMode = true;
          touchHereToPlay.alpha = 1.0;
          removeChild(vfdBitmap);

          touchHereSprite.addEventListener(MouseEvent.MOUSE_DOWN, mouseDownTouchHereToPlay);
        }

        return 1.0;
      #end

      default:
    }

    return 0.0;
  }

  #if FEATURE_TOUCH_HERE_TO_PLAY
  function mouseDownTouchHereToPlay(e:MouseEvent):Void
  {
    if (touchedHereToPlay)
    {
      return;
    }

    touchedHereToPlay = true;

    haxe.Timer.delay(function():Void
    {
      touchHereSprite.removeEventListener(MouseEvent.MOUSE_DOWN, mouseDownTouchHereToPlay);

      immediatelyStartGame();
    }, 1000);
  }

  function scaleAndCenter(bmp:Bitmap, scale:Float)
  {
    bmp.scaleX = bmp.scaleY = scale;
    bmp.x = (this._width - bmp.width) / 2;
    bmp.y = (this._height - bmp.height) / 2;
  }
  #end

  public static final TOTAL_STEPS:Int = 11;
  static final ELLIPSIS_TIME:Float = 0.5;

  function updateGraphics(percent:Float, elapsed:Float):Void
  {
    if (completeTime > 0.0)
    {
      var elapsedFinished:Float = renderDisplayFadeOut(elapsed);
      if (elapsedFinished > FADE_TIME)
      {
        #if FEATURE_TOUCH_HERE_TO_PLAY
        currentState = FunkinPreloaderState.TouchHereToPlay;
        #else
        immediatelyStartGame();
        #end
      }
    }
    else
    {
      var piecesToRender:Int = Std.int(percent * progressBarPieces.length);

      for (i => piece in progressBarPieces) piece.alpha = i <= piecesToRender ? 0.9 : 0.1;
    }

    var ellipsisCount:Int = Std.int(elapsed / ELLIPSIS_TIME) % 3 + 1;
    var ellipsis:String = '';
    for (_ in 0...ellipsisCount) ellipsis += '.';

    updateProgressLeftText(currentState.getProgressLeftText(TOTAL_STEPS, ellipsis));

    var percentage:Int = Math.floor(percent * 100);
    progressRightText.text = '$percentage%';

    if (currentState.getProgressLeftText() != null && (currentState != lastLoggedState || percentage != lastLoggedPercent))
    {
      trace(' $currentState ($percentage%, ${FlxMath.roundDecimal(elapsed, 2)} sec)');
      lastLoggedState = currentState;
      lastLoggedPercent = percentage;
    }

    #if FEATURE_TOUCH_HERE_TO_PLAY
    if (currentState == FunkinPreloaderState.TouchHereToPlay)
    {
      var targetScale:Float = ratio * 0.5;

      if (touchedHereToPlay)
      {
        targetScale = ratio * 0.45;
      }
      else if (touchHereSprite.hitTestPoint(mouseX, mouseY))
      {
        targetScale = ratio * 0.55;
      }

      scaleAndCenter(touchHereToPlay, touchHereToPlay.scaleX + (targetScale - touchHereToPlay.scaleX) * 0.15);
    }
    #end

    super.update(percent);
  }

  function updateProgressLeftText(text:Null<String>):Void
  {
    if (progressLeftText == null) return;

    if (text == null)
    {
      progressLeftText.alpha = 0.0;
    }
    else if (progressLeftText.text != text)
    {
      progressLeftText.defaultTextFormat = new TextFormat('DS-Digital', 32, BAR_COLOR, true);
      progressLeftText.defaultTextFormat.align = TextFormatAlign.LEFT;
      progressLeftText.text = text;

      dspText.defaultTextFormat = new TextFormat('Quantico', 20, 0x000000, false);
      dspText.text = 'DSP';
      dspText.textColor = 0x000000;

      fnfText.defaultTextFormat = new TextFormat('Quantico', 20, 0x000000, false);
      fnfText.text = 'FNF';
      fnfText.textColor = 0x000000;

      enhancedText.defaultTextFormat = new TextFormat('Inconsolata Black', 16, BAR_COLOR, false);
      enhancedText.text = 'ENHANCED';
      enhancedText.textColor = BAR_COLOR;

      stereoText.defaultTextFormat = new TextFormat('Inconsolata Bold', 36, BAR_COLOR, false);
      stereoText.text = 'NATURAL STEREO';
    }
  }

  function immediatelyStartGame():Void
  {
    _loaded = true;
  }

  function easeInOutCirc(value:Float):Float
  {
    var x = FlxMath.bound(value, 0, 1);
    return x < 0.5 ? (1 - Math.sqrt(1 - Math.pow(2 * x, 2))) / 2 : (Math.sqrt(1 - Math.pow(-2 * x + 2, 2)) + 1) / 2;
  }

  function renderDisplayFadeOut(elapsed:Float):Float
  {
    var elapsedFinished:Float = elapsed - completeTime;
    var alphaToFade:Float = 1.0 - easeInOutCirc(elapsedFinished / FADE_TIME);

    progressLeftText.alpha = alphaToFade;
    progressRightText.alpha = alphaToFade;
    rTextGroup.alpha = alphaToFade;
    progressLines.alpha = alphaToFade;

    for (piece in progressBarPieces) piece.alpha = alphaToFade;

    return elapsedFinished;
  }

  override function destroy():Void
  {
    super.destroy();
  }

  override function onLoaded():Void
  {
    super.onLoaded();
    _loaded = false;
    downloadingAssetsComplete = true;
  }
}

enum abstract FunkinPreloaderState(String) to String
{
  public var NotStarted;
  public var DownloadingAssets;
  public var PreloadingPlayAssets;
  public var InitializingScripts;
  public var CachingGraphics;
  public var CachingAudio;
  public var CachingData;
  public var ParsingSpritesheets;
  public var ParsingStages;
  public var ParsingCharacters;
  public var ParsingSongs;
  public var Complete;

  #if FEATURE_TOUCH_HERE_TO_PLAY
  var TouchHereToPlay;
  #end

  public function getProgressLeftText(?steps:Int, ?suffix:String):String
  {
    steps = steps ?? 11;
    suffix = suffix ?? '';
    switch (this)
    {
      case NotStarted:
        return 'Loading \n0/$steps $suffix';
      case DownloadingAssets:
        return 'Downloading assets \n1/$steps $suffix';
      case PreloadingPlayAssets:
        return 'Preloading assets \n2/$steps $suffix';
      case InitializingScripts:
        return 'Initializing scripts \n3/$steps $suffix';
      case CachingGraphics:
        return 'Caching graphics \n4/$steps $suffix';
      case CachingAudio:
        return 'Caching audio \n5/$steps $suffix';
      case CachingData:
        return 'Caching data \n6/$steps $suffix';
      case ParsingSpritesheets:
        return 'Parsing spritesheets \n7/$steps $suffix';
      case ParsingStages:
        return 'Parsing stages \n8/$steps $suffix';
      case ParsingCharacters:
        return 'Parsing characters \n9/$steps $suffix';
      case ParsingSongs:
        return 'Parsing songs \n10/$steps $suffix';
      case Complete:
        return 'Finishing up \n$steps/$steps $suffix';
      #if FEATURE_TOUCH_HERE_TO_PLAY
      case TouchHereToPlay:
        return null;
      #end
      default:
        return null;
    }
  }
}