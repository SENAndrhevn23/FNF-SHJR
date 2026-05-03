package backend;

import haxe.Json;
import lime.utils.Assets;

#if MODS_ALLOWED
import sys.io.File;
import sys.FileSystem;
#end

// Define Section first so Song knows what a "Section" is
typedef SwagSection =
{
	var sectionNotes:Array<Dynamic>;
	var mustHitSection:Bool;

	@:optional var sectionBeats:Null<Float>;
	@:optional var altAnim:Bool;
	@:optional var gfSection:Bool;

	@:optional var bpm:Float;
	@:optional var changeBPM:Bool;
}

typedef SwagSong =
{
	var song:String;
	var notes:Array<SwagSection>;
	var events:Array<Dynamic>;

	var bpm:Float;
	var needsVoices:Bool;
	var speed:Float;
	var offset:Float;

	var player1:String;
	var player2:String;
	var gfVersion:String;
	var stage:String;
	var format:String;

	@:optional var arrowSkin:String;
	@:optional var splashSkin:String;
	@:optional var disableNoteRGB:Bool;

	@:optional var gameOverChar:String;
	@:optional var gameOverSound:String;
	@:optional var gameOverLoop:String;
	@:optional var gameOverEnd:String;

	@:optional var totalSections:Int;
}

class Song
{
	public static var chartPath:String;
	public static var loadedSongName:String;

	public static function loadFromJson(song:String, ?folder:String):SwagSong
	{
		if (folder == null) folder = song;

		var chart = getChart(song, folder);

		if (chart == null)
			throw "Failed to load chart: " + song;

		PlayState.SONG = chart;
		loadedSongName = folder;

		StageData.loadDirectory(chart);

		return chart;
	}

	public static function getChart(song:String, ?folder:String):SwagSong
	{
		if (folder == null) folder = song;

		var f = Paths.formatToSongPath(folder);
		var s = Paths.formatToSongPath(song);

		chartPath = Paths.json('$f/$s');

		var raw = loadText(chartPath);
		if (raw == null) return null;

		var chart = parseJSON(raw);
		chart = loadSplitCharts(chart);
		normalize(chart);

		return chart;
	}

	public static function parseJSON(raw:String, ?folder:String, ?unneededArg:Dynamic):SwagSong
	{
		var data:Dynamic = Json.parse(raw);

		if (data.song != null && data.song.notes != null)
			data = data.song;

		var chart:SwagSong = cast data;

		if (chart.notes == null) chart.notes = [];
		if (chart.events == null) chart.events = [];

		return chart;
	}

	static function loadSplitCharts(songJson:SwagSong):SwagSong
	{
		var folder = Paths.formatToSongPath(loadedSongName);
		var song = Paths.formatToSongPath(loadedSongName);
		var i = 2;

		while (true)
		{
			var path = Paths.json('$folder/$song-$i');
			var raw = loadText(path);

			if (raw == null) break;

			var extra = parseJSON(raw);

			if (extra.notes != null)
				songJson.notes = songJson.notes.concat(extra.notes);

			if (extra.events != null)
				songJson.events = songJson.events.concat(extra.events);

			i++;
		}

		return songJson;
	}

	public static function convert(song:SwagSong)
	{
		normalize(song);
	}

	public static function normalize(song:SwagSong)
	{
		if (song.notes == null) song.notes = [];
		if (song.events == null) song.events = [];

		song.totalSections = song.notes.length;

		// High-performance loop for 15MB+ JSONs
		for (i in 0...song.notes.length)
		{
			var section = song.notes[i];
			if (section == null || section.sectionNotes == null) continue;

			var mustHit = section.mustHitSection;

			for (j in 0...section.sectionNotes.length)
			{
				var note:Array<Dynamic> = section.sectionNotes[j];
				if (note == null || note.length < 2) continue;

				// Skip if already processed to save time
				var dir:Int = Std.int(note[1]);
				if (dir < 8) {
					note[1] = (dir % 4) + (mustHit ? 0 : 4);
				}

				if (note[2] == null) note[2] = 0;
				if (note[3] == null) note[3] = "default";
			}
		}
	}

	static function loadText(path:String):String
	{
		#if MODS_ALLOWED
		if (FileSystem.exists(path))
			return File.getContent(path);
		#end

		if (Assets.exists(path))
			return Assets.getText(path);

		return null;
	}
}