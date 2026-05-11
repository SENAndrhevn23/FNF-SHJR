package backend;

import flixel.FlxG;
import flixel.util.FlxColor;
import flixel.math.FlxMath;
import flixel.util.FlxSave;
import flixel.input.keyboard.FlxKey;
import flixel.input.gamepad.FlxGamepadInputID;

import states.TitleState;

@:structInit
class SaveVariables
{
	public var showFPS:Bool = true;
	public var downScroll:Bool = false;
	public var middleScroll:Bool = false;
	public var opponentStrums:Bool = true;
	public var flashing:Bool = true;
	public var autoPause:Bool = true;
	public var antialiasing:Bool = true;
	public var shaders:Bool = true;
	public var framerate:Int = 60;

	// Gameplay
	public var noteOffset:Int = 0;
	public var ghostTapping:Bool = true;

	// Combo popups
	public var showRating:Bool = true;
	public var showComboNum:Bool = true;
	public var showCombo:Bool = true;

	// Video Rendering
	public var gameRenderer:Bool = false;
	public var videoRenderFPS:Int = 60;
	public var videoRenderQuality:Int = 8;

	// Audio
	public var hitsoundVolume:Float = 0;

	public var gameplaySettings:Map<String, Dynamic> = [
		'scrollspeed' => 1.0,
		'songspeed' => 1.0,
		'healthgain' => 1.0,
		'healthloss' => 1.0,
		'botplay' => false
	];
}

class ClientPrefs
{
	public static var data:SaveVariables = new SaveVariables();
	public static var defaultData:SaveVariables = new SaveVariables();

	/* =========================
	   KEYBINDS
	=========================*/

	public static var keyBinds:Map<String, Array<FlxKey>> =
	[
		'note_left' => [A, LEFT],
		'note_down' => [S, DOWN],
		'note_up' => [W, UP],
		'note_right' => [D, RIGHT],

		'accept' => [ENTER, SPACE],
		'back' => [ESCAPE, BACKSPACE],
		'pause' => [ENTER],
		'reset' => [R],

		'volume_mute' => [ZERO],
		'volume_up' => [PLUS],
		'volume_down' => [MINUS]
	];

	public static var gamepadBinds:Map<String, Array<FlxGamepadInputID>> =
	[
		'note_left' => [DPAD_LEFT],
		'note_down' => [DPAD_DOWN],
		'note_up' => [DPAD_UP],
		'note_right' => [DPAD_RIGHT]
	];

	/* =========================
	   SAVE
	=========================*/

	public static function saveSettings()
	{
		for (field in Reflect.fields(data))
		{
			Reflect.setField(FlxG.save.data, field,
				Reflect.field(data, field));
		}

		FlxG.save.flush();
		trace("ClientPrefs saved.");
	}

	/* =========================
	   LOAD
	=========================*/

	public static function loadPrefs()
	{
		for (field in Reflect.fields(data))
		{
			if (Reflect.hasField(FlxG.save.data, field))
			{
				Reflect.setField(
					data,
					field,
					Reflect.field(FlxG.save.data, field)
				);
			}
		}

		applySettings();
	}

	/* =========================
	   APPLY SETTINGS
	=========================*/

	public static function applySettings()
	{
		if (Main.fpsVar != null)
			Main.fpsVar.visible = data.showFPS;

		FlxG.autoPause = data.autoPause;

		var fps = Std.int(FlxMath.bound(data.framerate, 30, 240));

		FlxG.updateFramerate = fps;
		FlxG.drawFramerate = fps;

		reloadVolumeKeys();
	}

	/* =========================
	   GAMEPLAY SETTINGS
	=========================*/

	public static function getGameplaySetting(name:String, defaultValue:Dynamic = null)
	{
		if (data.gameplaySettings.exists(name))
			return data.gameplaySettings.get(name);

		return defaultValue;
	}

	/* =========================
	   VOLUME KEYS
	=========================*/

	public static function reloadVolumeKeys()
	{
		if (TitleState.muteKeys != null)
		{
			TitleState.muteKeys = keyBinds.get('volume_mute').copy();
			TitleState.volumeDownKeys = keyBinds.get('volume_down').copy();
			TitleState.volumeUpKeys = keyBinds.get('volume_up').copy();
		}

		FlxG.sound.muteKeys = TitleState.muteKeys;
		FlxG.sound.volumeDownKeys = TitleState.volumeDownKeys;
		FlxG.sound.volumeUpKeys = TitleState.volumeUpKeys;
	}
}
