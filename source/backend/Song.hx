package backend;

import haxe.Json;
import lime.utils.Assets;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

import objects.Note;

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

	@:optional var gameOverChar:String;
	@:optional var gameOverSound:String;
	@:optional var gameOverLoop:String;
	@:optional var gameOverEnd:String;

	@:optional var disableNoteRGB:Bool;
	@:optional var arrowSkin:String;
	@:optional var splashSkin:String;
}

typedef SwagSection =
{
	var sectionNotes:Array<Dynamic>;
	var sectionBeats:Float;
	var mustHitSection:Bool;
	@:optional var altAnim:Bool;
	@:optional var gfSection:Bool;
	@:optional var bpm:Float;
	@:optional var changeBPM:Bool;
}

class Song
{
	public static var chartPath:String;
	public static var loadedSongName:String;
	static var _lastPath:String;

	public static function convert(songJson:Dynamic):Void
	{
		if (songJson == null) return;

		if (songJson.notes == null) songJson.notes = [];
		if (songJson.events == null) songJson.events = [];

		if (songJson.gfVersion == null)
		{
			songJson.gfVersion = songJson.player3;
			if (Reflect.hasField(songJson, "player3"))
				Reflect.deleteField(songJson, "player3");
		}

		var mergedEvents:Array<Dynamic> = songJson.events.copy();

		for (section in songJson.notes)
		{
			if (section.sectionNotes == null)
				section.sectionNotes = [];

			var fixedNotes:Array<Dynamic> = [];

			for (rawNote in section.sectionNotes)
			{
				var note:Array<Dynamic> = cast rawNote;
				if (note == null || note.length < 2) continue;

				var strumTime:Null<Float> =
					Std.parseFloat(Std.string(note[0]));
				var lane:Null<Int> =
					Std.parseInt(Std.string(note[1]));

				if (strumTime == null || Math.isNaN(strumTime) || lane == null)
					continue;

				note[0] = strumTime;
				note[1] = lane;

				if (note.length > 2)
				{
					var sus:Null<Float> =
						Std.parseFloat(Std.string(note[2]));
					note[2] =
						(sus == null || Math.isNaN(sus) || sus < 0) ? 0 : sus;
				}

				if (lane < 0)
				{
					var ev:Array<Dynamic> = [];
					if (note.length > 2) ev.push(note[2]);
					if (note.length > 3) ev.push(note[3]);
					if (note.length > 4) ev.push(note[4]);

					mergedEvents.push([strumTime, [ev]]);
					continue;
				}

				var gottaHit:Bool =
					(lane < 4) ? section.mustHitSection : !section.mustHitSection;

				note[1] = (lane % 4) + (gottaHit ? 0 : 4);

				if (note.length > 3 && note[3] != null && !Std.isOfType(note[3], String))
				{
					var idx:Int = Std.int(cast note[3]);
					if (idx >= 0 && idx < Note.defaultNoteTypes.length)
						note[3] = Note.defaultNoteTypes[idx];
					else
						note[3] = "";
				}

				fixedNotes.push(note);
			}

			fixedNotes.sort(function(a:Dynamic, b:Dynamic):Int
			{
				var at:Float = a[0];
				var bt:Float = b[0];
				return (at < bt) ? -1 : ((at > bt) ? 1 : 0);
			});

			section.sectionNotes = fixedNotes;
		}

		mergedEvents.sort(function(a:Dynamic, b:Dynamic):Int
		{
			var at:Float = a[0];
			var bt:Float = b[0];
			return (at < bt) ? -1 : ((at > bt) ? 1 : 0);
		});

		songJson.events = mergedEvents;
	}

	public static function loadFromJson(jsonInput:String, ?folder:String):SwagSong
	{
		if (folder == null) folder = jsonInput;

		PlayState.SONG = getChart(jsonInput, folder);
		loadedSongName = folder;
		chartPath = _lastPath;

		if (PlayState.SONG == null)
			return null;

		#if windows
		chartPath = chartPath.replace("/", "\\");
		#end

		StageData.loadDirectory(PlayState.SONG);
		return PlayState.SONG;
	}

	public static function getChart(jsonInput:String, ?folder:String):SwagSong
	{
		if (folder == null) folder = jsonInput;

		var rawData:String = null;

		var formattedFolder:String = Paths.formatToSongPath(folder);
		var formattedSong:String = Paths.formatToSongPath(jsonInput);
		_lastPath = Paths.json('$formattedFolder/$formattedSong');

		#if MODS_ALLOWED
		if (FileSystem.exists(_lastPath))
			rawData = File.getContent(_lastPath);
		else
		#end
			rawData = Assets.getText(_lastPath);

		return rawData != null ? parseJSON(rawData, jsonInput) : null;
	}

	public static function parseJSON(rawData:String, ?nameForError:String = null):SwagSong
	{
		if (rawData == null || rawData.length == 0)
			return null;

		var songJson:Dynamic = Json.parse(rawData);
		if (songJson == null)
			return null;

		if (Reflect.hasField(songJson, "song"))
		{
			var subSong:Dynamic = Reflect.field(songJson, "song");
			if (subSong != null && Type.typeof(subSong) == TObject)
				songJson = subSong;
		}

		if (songJson.notes == null) songJson.notes = [];
		if (songJson.events == null) songJson.events = [];

		var fmt:String = songJson.format;
		if (fmt == null) fmt = songJson.format = "unknown";

		if (!fmt.startsWith("psych_v1"))
		{
			trace('Converting chart $nameForError from $fmt...');
			songJson.format = "psych_v1_convert";
			convert(songJson);
		}

		return cast songJson;
	}
}
