#if desktop
package backend;

import flixel.FlxG;
import lime.graphics.Image;
import lime.math.Rectangle;
import lime.ui.Window;
import sys.FileSystem;
import sys.io.Process;
import haxe.io.Bytes;

import options.GameRendererSettingsSubState;
import states.PlayState;

class FFMpeg
{
	public static var instance:FFMpeg;

	var x:Int;
	var y:Int;
	var image:Image;
	var bytes:Bytes;
	var window:Window;
	var buffer:Rectangle;

	public var target:String = "render_video";
	public var fileName:String = "";
	public var fileExts:String = ".mp4";
	public var wentPreview:String;
	public var process:Process;

	public function new() {}

	public function init():Void
	{
		if (FileSystem.exists(target))
		{
			if (!FileSystem.isDirectory(target))
			{
				FileSystem.deleteFile(target);
				FileSystem.createDirectory(target);
			}
		}
		else
		{
			FileSystem.createDirectory(target);
		}

		window = FlxG.stage.application.window;
		x = window.width;
		y = window.height;
	}

	public function setup(testMode:Bool = false):Void
	{
		var executable:String = #if windows "ffmpeg.exe" #else "ffmpeg" #end;

		if (!FileSystem.exists(executable))
		{
			if (testMode)
			{
				throw "not found ffmpeg";
			}
			else
			{
				trace('"' + executable + '" not found, turning on preview mode...');
				ClientPrefs.data.previewRender = true;
				FlxG.sound.play(Paths.sound('cancelMenu'), ClientPrefs.data.sfxVolume);
				wentPreview = executable + " was not found";
				return;
			}
		}

		var curCodec:String = ClientPrefs.data.codec;
		var isGPU:Bool = CoolUtil.searchFromStrings(curCodec, ['QSV', 'NVENC', 'AMF', 'VAAPI']);

		if (CoolUtil.searchFromString(curCodec, 'VP'))
			fileExts = ".webm";

		if (!testMode)
		{
			fileName = target + '/' + Paths.formatToSongPath(PlayState.SONG.song);
			if (FileSystem.exists(fileName + fileExts))
			{
				var millis = CoolUtil.fillNumber(Std.int(haxe.Timer.stamp() * 1000.0) % 1000, 3, 48);
				fileName += "-" + DateTools.format(Date.now(), "%Y-%m-%d_%H-%M-%S-") + millis;
			}
		}
		else
		{
			fileName = target + '/test-codec-' + curCodec;
		}

		var arguments:Array<String> = [
			'-v', 'quiet', '-y',
			'-f', 'rawvideo', '-pix_fmt', 'rgba',
			'-s', x + 'x' + y,
			'-r', Std.string(ClientPrefs.data.targetFPS),
			'-i', '-',
			'-c:v', GameRendererSettingsSubState.codecMap[curCodec]
		];

		switch (ClientPrefs.data.encodeMode)
		{
			case "CRF/CQP":
				arguments.push('-b:v');
				arguments.push('0');
				arguments.push(isGPU ? '-qp' : '-crf');
				arguments.push(Std.string(ClientPrefs.data.constantQuality));

			case 'VBR', 'CBR':
				arguments.push('-b:v');
				arguments.push(Std.string(ClientPrefs.data.bitrate * 1000000));
				if (ClientPrefs.data.encodeMode == 'CBR')
				{
					arguments.push('-maxrate');
					arguments.push(Std.string(ClientPrefs.data.bitrate * 1000000));
					arguments.push('-minrate');
					arguments.push(Std.string(ClientPrefs.data.bitrate * 1000000));
				}
		}

		arguments.push(fileName + fileExts);

		if (!ClientPrefs.data.previewRender && !testMode)
			trace("running " + arguments.join(" "));

		process = new Process(executable, arguments);

		buffer = new Rectangle(0, 0, x, y);
		FlxG.autoPause = false;

		if (!testMode)
			FlxG.sound.play(Paths.sound('confirmMenu'), ClientPrefs.data.sfxVolume);
	}

	public function pipeFrame():Void
	{
		if (process == null || process.stdin == null || window == null)
			return;

		image = window.readPixels();
		bytes = image.getPixels(buffer);
		process.stdin.write(bytes);
	}

	public function destroy():Void
	{
		if (process != null)
		{
			try
			{
				if (process.stdin != null)
					process.stdin.close();
				process.close();
				process.kill();
			}
			catch (e:Dynamic) {}

			process = null;
		}

		FlxG.autoPause = ClientPrefs.data.autoPause;
	}
}
#end
