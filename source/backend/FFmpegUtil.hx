package backend;

import sys.io.Process;

class FFmpegUtil
{
	public static function exists():Bool
	{
		try
		{
			var proc = new Process("ffmpeg", ["-version"]);
			proc.close();
			return true;
		}
		catch(e)
		{
			return false;
		}
	}
}
