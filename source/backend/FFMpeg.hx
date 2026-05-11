#if desktop
package backend;

import flixel.FlxG;
import haxe.io.Bytes;
import lime.graphics.Image;
import lime.math.Rectangle;
import lime.ui.Window;
import sys.FileSystem;
import sys.io.Process;
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
			trace('"' + executable + '" not found.');
			return;
		}

		var fps:Int = Std.int(ClientPrefs.data.videoRenderFPS);
		if (fps < 1) fps = 60;

		var quality:Int = Std.int(ClientPrefs.data.videoRenderQuality);
		if (quality < 1) quality = 1;
		if (quality > 10) quality = 10;

		if (!testMode)
		{
			fileName = target + '/' + Paths.formatToSongPath(PlayState.SONG.song);
			if (FileSystem.exists(fileName + fileExts))
			{
				var millis = Std.int(haxe.Timer.stamp() * 1000.0) % 1000;
				fileName += "-" + DateTools.format(Date.now(), "%Y-%m-%d_%H-%M-%S-") + millis;
			}
		}
		else
		{
			fileName = target + '/test-render';
		}

		var crf:Int = 51 - (quality * 4);
		if (crf < 0) crf = 0;
		if (crf > 51) crf = 51;

		var arguments:Array<String> = [
			'-y',
			'-f', 'rawvideo',
			'-pix_fmt', 'rgba',
			'-s', x + 'x' + y,
			'-r', Std.string(fps),
			'-i', '-',
			'-c:v', 'libx264',
			'-crf', Std.string(crf),
			fileName + fileExts
		];

		trace("running ffmpeg " + arguments.join(" "));
		process = new Process(executable, arguments);

		buffer = new Rectangle(0, 0, x, y);
		FlxG.autoPause = false;
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
