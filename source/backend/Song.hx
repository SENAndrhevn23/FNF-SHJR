package backend;

import haxe.Json;
import lime.utils.Assets;

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

	public static function convert(songJson:Dynamic) // Convert old charts to psych_v1 format
	{
		if (songJson == null) return;

		if (songJson.notes == null)
			songJson.notes = [];

		if (songJson.events == null)
			songJson.events = [];

		if (songJson.gfVersion == null)
		{
			songJson.gfVersion = songJson.player3;
			if (Reflect.hasField(songJson, 'player3'))
				Reflect.deleteField(songJson, 'player3');
		}

		var sectionsData:Array<SwagSection> = songJson.notes;
		if (sectionsData == null) return;

		var mergedEvents:Array<Dynamic> = songJson.events.copy();

		for (section in sectionsData)
		{
			if (section == null) continue;

			if (section.sectionNotes == null)
				section.sectionNotes = [];

			var beats:Null<Float> = cast section.sectionBeats;
			if (beats == null || Math.isNaN(beats))
			{
				section.sectionBeats = 4;
				if (Reflect.hasField(section, 'lengthInSteps'))
					Reflect.deleteField(section, 'lengthInSteps');
			}

			var fixedNotes:Array<Dynamic> = [];

			for (rawNote in section.sectionNotes)
			{
				if (rawNote == null) continue;

				var note:Array<Dynamic> = cast rawNote;
				if (note == null || note.length < 2) continue;

				var strumTime:Dynamic = note[0];
				var lane:Float = note[1];

				// Old event-note conversion
				if (lane < 0)
				{
					var ev:Array<Dynamic> = [];
					if (note.length > 2) ev.push(note[2]);
					if (note.length > 3) ev.push(note[3]);
					if (note.length > 4) ev.push(note[4]);

					mergedEvents.push([strumTime, [ev]]);
					continue;
				}

				var gottaHitNote:Bool = (lane < 4) ? section.mustHitSection : !section.mustHitSection;
				note[1] = (lane % 4) + (gottaHitNote ? 0 : 4);

				// Convert numeric note type IDs to strings safely
				if (note.length > 3 && note[3] != null && !Std.isOfType(note[3], String))
				{
					var noteTypeIndex:Int = Std.int(cast note[3]);
					if (noteTypeIndex >= 0 && noteTypeIndex < Note.defaultNoteTypes.length)
						note[3] = Note.defaultNoteTypes[noteTypeIndex];
				}

				fixedNotes.push(note);
			}

			// Keep notes in time order so later notes do not get skipped by bad ordering
			fixedNotes.sort(function(a:Dynamic, b:Dynamic):Int
			{
				var at:Float = a[0];
				var bt:Float = b[0];
				return at < bt ? -1 : (at > bt ? 1 : 0);
			});

			section.sectionNotes = fixedNotes;
		}

		songJson.events = mergedEvents;
	}

	public static var chartPath:String;
	public static var loadedSongName:String;

	public static function loadFromJson(jsonInput:String, ?folder:String):SwagSong
	{
		if (folder == null) folder = jsonInput;

		PlayState.SONG = getChart(jsonInput, folder);
		loadedSongName = folder;
		chartPath = _lastPath;

		if (PlayState.SONG == null)
			return null;

		#if windows
		// prevent any saving errors by fixing the path on Windows
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
		if (rawData == null || rawData.length == 0)
			return null;

		var songJson:Dynamic = Json.parse(rawData);

		if (songJson == null)
			return null;

		if (Reflect.hasField(songJson, 'song'))
		{
			var subSong:Dynamic = Reflect.field(songJson, 'song');
			if (subSong != null && Type.typeof(subSong) == TObject)
				songJson = subSong;
		}

		if (songJson.notes == null)
			songJson.notes = [];

		if (songJson.events == null)
			songJson.events = [];

		if (convertTo != null && convertTo.length > 0)
		{
			var fmt:String = songJson.format;
			if (fmt == null) fmt = songJson.format = 'unknown';

			switch (convertTo)
			{
				case 'psych_v1':
					if (!fmt.startsWith('psych_v1'))
					{
						trace('converting chart $nameForError with format $fmt to psych_v1 format...');
						songJson.format = 'psych_v1_convert';
						convert(songJson);
					}
			}
		}

		return cast songJson;
	}
}
