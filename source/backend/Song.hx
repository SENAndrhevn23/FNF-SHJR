package backend;

import haxe.Json;
import lime.utils.Assets;
import sys.FileSystem;
import sys.io.File;

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
	@:optional var sectionBeats:Float;
	@:optional var lengthInSteps:Float;
	var mustHitSection:Bool;
	@:optional var altAnim:Bool;
	@:optional var gfSection:Bool;
	@:optional var bpm:Float;
	@:optional var changeBPM:Bool;
}

class Song
{
	public var song:String;
	public var notes:Array<SwagSection>;
	public var events:Array<Dynamic>;
	public var bpm:Float;
	public var needsVoices:Bool = true;
	public var arrowSkin:String;
	public var splashSkin:String;
	public var gameOverChar:String;
	public var gameOverSound:String;
	public var gameOverLoop:String;
	public var gameOverEnd:String;
	public var disableNoteRGB:Bool = false;
	public var speed:Float = 1;
	public var stage:String;
	public var player1:String = 'bf';
	public var player2:String = 'dad';
	public var gfVersion:String = 'gf';
	public var format:String = 'psych_v1';

	public static function convert(songJson:Dynamic):Void
	{
		if (songJson == null) return;

		if (Reflect.hasField(songJson, "gfVersion") && Reflect.field(songJson, "gfVersion") == null)
		{
			if (Reflect.hasField(songJson, "player3"))
				Reflect.setField(songJson, "gfVersion", Reflect.field(songJson, "player3"));

			if (Reflect.hasField(songJson, "player3"))
				Reflect.deleteField(songJson, "player3");
		}

		var sectionsData:Array<Dynamic> = cast Reflect.field(songJson, "notes");
		if (sectionsData == null) return;

		// Convert old note-based events into Psych event format
		if (!Reflect.hasField(songJson, "events") || Reflect.field(songJson, "events") == null)
		{
			Reflect.setField(songJson, "events", []);

			for (secNum in 0...sectionsData.length)
			{
				var sec:Dynamic = sectionsData[secNum];
				var notes:Array<Dynamic> = cast Reflect.field(sec, "sectionNotes");
				if (notes == null) continue;

				var i:Int = notes.length - 1;
				while (i >= 0)
				{
					var note:Dynamic = notes[i];
					var noteData:Array<Dynamic> = cast note;

					if (noteData != null && noteData.length > 1 && noteData[1] != null && noteData[1] < 0)
					{
						var events:Array<Dynamic> = cast Reflect.field(songJson, "events");
						events.push([noteData[0], [[noteData[2], noteData[3], noteData[4]]]]);
						notes.splice(i, 1);
					}

					i--;
				}
			}
		}

		// Keep section lengths instead of forcing everything to 4 beats
		for (section in sectionsData)
		{
			var beats:Null<Float> = cast Reflect.field(section, "sectionBeats");
			var lengthInSteps:Null<Float> = cast Reflect.field(section, "lengthInSteps");
			var sectionNotes:Array<Dynamic> = cast Reflect.field(section, "sectionNotes");

			if (beats == null || Math.isNaN(beats))
			{
				if (lengthInSteps != null && !Math.isNaN(lengthInSteps))
					Reflect.setField(section, "sectionBeats", lengthInSteps / 4);
				else
					Reflect.setField(section, "sectionBeats", 4);
			}

			if (sectionNotes == null) continue;

			for (note in sectionNotes)
			{
				var noteData:Array<Dynamic> = cast note;
				if (noteData == null || noteData.length < 4) continue;

				var noteLane:Int = Std.int(noteData[1]);
				var gottaHitNote:Bool = (noteLane < 4) ? section.mustHitSection : !section.mustHitSection;

				noteData[1] = (noteLane % 4) + (gottaHitNote ? 0 : 4);

				if (!Std.isOfType(noteData[3], String))
					noteData[3] = Note.defaultNoteTypes[noteData[3]];
			}
		}
	}

	public static var chartPath:String;
	public static var loadedSongName:String;

	public static function loadFromJson(jsonInput:String, ?folder:String):SwagSong
	{
		if (folder == null) folder = jsonInput;

		PlayState.SONG = getChart(jsonInput, folder);
		if (PlayState.SONG == null) return null;

		loadedSongName = folder;
		chartPath = _lastPath;

		#if windows
		chartPath = chartPath.replace('/', '\\');
		#end

		StageData.loadDirectory(PlayState.SONG);
		return PlayState.SONG;
	}

	static var _lastPath:String;

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

	public static function parseJSON(rawData:String, ?nameForError:String = null, ?convertTo:String = 'psych_v1'):SwagSong
	{
		if (rawData == null || rawData.length == 0) return null;

		var songJson:Dynamic = Json.parse(rawData);

		if (Reflect.hasField(songJson, 'song'))
		{
			var subSong:Dynamic = Reflect.field(songJson, 'song');
			if (subSong != null && Type.typeof(subSong) == TObject)
				songJson = subSong;
		}

		if (convertTo != null && convertTo.length > 0)
		{
			var fmt:Null<String> = cast Reflect.field(songJson, "format");
			if (fmt == null)
			{
				fmt = "unknown";
				Reflect.setField(songJson, "format", fmt);
			}

			switch (convertTo)
			{
				case 'psych_v1':
					if (!StringTools.startsWith(fmt, 'psych_v1'))
					{
						trace('converting chart $nameForError with format $fmt to psych_v1 format...');
						Reflect.setField(songJson, "format", "psych_v1_convert");
						convert(songJson);
					}
			}
		}

		return cast songJson;
	}
}
