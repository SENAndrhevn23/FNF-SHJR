package options;

import backend.ClientPrefs;
import backend.FFMpeg;
import backend.Paths;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import states.MusicBeatState;

class VideoRenderingSubState extends MusicBeatSubState
{
	var optionGroup:FlxTypedGroup<FlxText>;
	var options:Array<String> = [
		'Preview Render',
		'Target FPS',
		'Codec',
		'Encode Mode',
		'Bitrate',
		'Constant Quality',
		'Test Render'
	];

	var curSelected:Int = 0;
	var displayText:FlxText;
	var infoText:FlxText;

	override function create()
	{
		super.create();

		var bg:FlxSprite = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		bg.alpha = 0.65;
		bg.setGraphicSize(FlxG.width, FlxG.height);
		bg.updateHitbox();
		add(bg);

		displayText = new FlxText(0, 35, FlxG.width, 'Video Rendering');
		displayText.setFormat(null, 28, FlxColor.WHITE, "center");
		add(displayText);

		infoText = new FlxText(0, FlxG.height - 70, FlxG.width, '');
		infoText.setFormat(null, 18, FlxColor.WHITE, "center");
		add(infoText);

		optionGroup = new FlxTypedGroup<FlxText>();
		add(optionGroup);

		for (i in 0...options.length)
		{
			var t = new FlxText(0, 0, 0, "");
			t.setFormat(null, 22, FlxColor.WHITE, "center");
			t.screenCenter(X);
			t.y = 110 + (i * 42);
			optionGroup.add(t);
		}

		refresh();
	}

	function refresh()
	{
		var i:Int = 0;
		for (t in optionGroup.members)
		{
			if (t == null)
			{
				i++;
				continue;
			}

			var label = options[i];
			var value = getValue(label);
			t.text = (i == curSelected ? "> " : "  ") + label + ": " + value;
			t.x = 0;
			t.screenCenter(X);
			t.alpha = (i == curSelected) ? 1 : 0.65;
			i++;
		}

		infoText.text = getHelp(options[curSelected]);
	}

	function getValue(label:String):String
	{
		return switch (label)
		{
			case 'Preview Render': Std.string(ClientPrefs.data.previewRender);
			case 'Target FPS': Std.string(ClientPrefs.data.targetFPS);
			case 'Codec': Std.string(ClientPrefs.data.codec);
			case 'Encode Mode': Std.string(ClientPrefs.data.encodeMode);
			case 'Bitrate': Std.string(ClientPrefs.data.bitrate) + " Mbps";
			case 'Constant Quality': Std.string(ClientPrefs.data.constantQuality);
			case 'Test Render': "Start";
			default: "";
		}
	}

	function getHelp(label:String):String
	{
		return switch (label)
		{
			case 'Preview Render': 'Uses preview mode if ffmpeg is missing.';
			case 'Target FPS': 'Controls the output render FPS.';
			case 'Codec': 'Chooses the output codec.';
			case 'Encode Mode': 'Selects CRF/CQP, VBR, or CBR.';
			case 'Bitrate': 'Used for VBR/CBR renders.';
			case 'Constant Quality': 'Used for CRF/CQP renders.';
			case 'Test Render': 'Runs a short render test.';
			default: '';
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (controls.UI_UP_P)
		{
			curSelected = (curSelected - 1 + options.length) % options.length;
			refresh();
		}
		if (controls.UI_DOWN_P)
		{
			curSelected = (curSelected + 1) % options.length;
			refresh();
		}

		if (controls.BACK)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			close();
			return;
		}

		if (controls.ACCEPT)
		{
			switch (options[curSelected])
			{
				case 'Preview Render':
					ClientPrefs.data.previewRender = !ClientPrefs.data.previewRender;

				case 'Target FPS':
					ClientPrefs.data.targetFPS = ClientPrefs.data.targetFPS == 60 ? 30 : 60;

				case 'Codec':
					ClientPrefs.data.codec = ClientPrefs.data.codec == 'libx264' ? 'libvpx-vp9' : 'libx264';

				case 'Encode Mode':
					ClientPrefs.data.encodeMode = switch (ClientPrefs.data.encodeMode)
					{
						case 'CRF/CQP': 'VBR';
						case 'VBR': 'CBR';
						default: 'CRF/CQP';
					}

				case 'Bitrate':
					ClientPrefs.data.bitrate = ClientPrefs.data.bitrate == 8 ? 16 : 8;

				case 'Constant Quality':
					ClientPrefs.data.constantQuality = ClientPrefs.data.constantQuality == 18 ? 22 : 18;

				case 'Test Render':
					if (FFMpeg.instance == null)
						FFMpeg.instance = new FFMpeg();

					FFMpeg.instance.init();
					FFMpeg.instance.setup(true);
			}

			ClientPrefs.saveSettings();
			refresh();
		}
	}
}
