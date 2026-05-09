package backend;

import haxe.ds.Vector;
import haxe.Json;
import backend.SongJson;
import lime.utils.Assets;
import sys.FileSystem;
import sys.io.File;
import haxe.io.Input;

import objects.Note;

typedef SwagSong =
{
	var song:String;
	var notes:Array<SwagSection>;
	var events:Array<Array<Dynamic>>;
	var bpm:Float;
	var needsVoices:Bool;
	var speed:Float;
	var offset:Float;

	var player1:String;
	var player2:String;
	var gfVersion:String;
	var stage:String;
	var format:String;

	@:optional var isOldVersion:Bool;

	@:optional var gameOverChar:String;
	@:optional var gameOverSound:String;
	@:optional var gameOverLoop:String;
	@:optional var gameOverEnd:String;

	@:optional var disableNoteRGB:Bool;
	@:optional var screwYou:String;

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
	public var events:Array<Array<Dynamic>>;
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
		if(songJson.gfVersion == null)
		{
			songJson.gfVersion = songJson.player3;
			if(Reflect.hasField(songJson, 'player3')) Reflect.deleteField(songJson, 'player3');
		}

		if(songJson.events == null)
		{
			songJson.events = [];
			for (secNum in 0...songJson.notes.length)
			{
				var sec:SwagSection = songJson.notes[secNum];

				var i:Int = 0;
				var notes:Array<Dynamic> = sec.sectionNotes;
				var len:Int = notes.length;
				while(i < len)
				{
					var note:Array<Dynamic> = notes[i];
					if(note[1] < 0)
					{
						songJson.events.push([note[0], [[note[2], note[3], note[4]]]]);
						notes.remove(note);
						len = notes.length;
					}
					else i++;
				}
			}
		}

		var sectionsData:Array<SwagSection> = songJson.notes;
		if(sectionsData == null) return;

		for (section in sectionsData)
		{
			var beats:Null<Float> = cast section.sectionBeats;
			if (beats == null || Math.isNaN(beats))
			{
				section.sectionBeats = 4;
				if(Reflect.hasField(section, 'lengthInSteps')) Reflect.deleteField(section, 'lengthInSteps');
			}

			for (note in section.sectionNotes)
			{
				var gottaHitNote:Bool = (note[1] < 4) ? section.mustHitSection : !section.mustHitSection;
				note[1] = (note[1] % 4) + (gottaHitNote ? 0 : 4);

				if(note[3] != null && !Std.isOfType(note[3], String) && !Std.isOfType(note[3], Array) && note[3].cmpSpam == null)
					note[3] = Note.DEFAULT_NOTE_TYPES[note[3]]; //compatibility with Week 7 and 0.1-0.3 psych charts
			}
		}
	}

	public static var chartPath:String;
	public static var loadedSongName:String;
	public static function loadFromJson(jsonInput:String, ?forPlay:Bool, ?folder:String):SwagSong
	{
		SongJson.skipChart = forPlay;
		folder = folder ?? jsonInput;
		PlayState.SONG = getChart(jsonInput, folder);

		loadedSongName = folder;
		chartPath = _lastPath;
		#if windows
		// prevent any saving errors by fixing the path on Windows (being the only OS to ever use backslashes instead of forward slashes for paths)
		chartPath = chartPath.replace('/', '\\');
		#end
		StageData.loadDirectory(PlayState.SONG);
		return PlayState.SONG;
	}

	static var _lastPath:String;

	/**
	 * Stream-chart support:
	 * - Normal charts still load from .json
	 * - Huge charts can be exported as .jsons (one header JSON line, then one section JSON line per section)
	 *
	 * This avoids holding the whole chart in a single String.
	 */
	public static function getChart(jsonInput:String, ?folder:String):SwagSong
	{
		if(folder == null) folder = jsonInput;

		var formattedFolder:String = Paths.formatToSongPath(folder);
		var formattedSong:String = Paths.formatToSongPath(jsonInput);

		var streamPath:String = Paths.json('$formattedFolder/$formattedSong.jsons');
		_lastPath = Paths.json('$formattedFolder/$formattedSong');

		if(FileSystem.exists(streamPath))
		{
			_lastPath = streamPath;
			return parseJSONStreamed(streamPath, jsonInput);
		}

		var rawData:String = null;
		if(FileSystem.exists(_lastPath))
			rawData = NativeFileSystem.getContent(_lastPath);

		return rawData != null ? parseJSON(rawData, jsonInput) : null;
	}

	private static function readNonEmptyLine(input:Input):Null<String>
	{
		while(true)
		{
			try
			{
				var line:String = input.readLine();
				if(line == null) return null;

				line = StringTools.trim(line);
				if(line.length == 0) continue;
				return line;
			}
			catch(e:Dynamic)
			{
				return null;
			}
		}
	}

	/**
	 * Reads a streamed chart format:
	 *   line 1 = header JSON object
	 *   line 2+ = one section JSON object per line
	 *
	 * This is intentionally simple and keeps each parsed chunk below the String limit.
	 */
	public static function parseJSONStreamed(path:String, ?nameForError:String = null, ?convertTo:String = 'psych_v1'):SwagSong
	{
		var input:Input = File.read(path, false);
		try
		{
			var headerLine:String = readNonEmptyLine(input);
			if(headerLine == null || headerLine.length == 0)
				return null;

			var songJson:SwagSong = cast Json.parse(headerLine);

			if(songJson.notes == null) songJson.notes = [];
			if(songJson.events == null) songJson.events = [];

			while(true)
			{
				var line:String = readNonEmptyLine(input);
				if(line == null) break;

				var section:SwagSection = cast Json.parse(line);
				songJson.notes.push(section);
			}

			return finalizeChart(songJson, nameForError, convertTo);
		}
		catch(e:Dynamic)
		{
			trace('Failed to read streamed chart $nameForError from $path: $e');
			return null;
		}
		finally
		{
			try input.close() catch(e:Dynamic) {}
		}
	}

	private static function finalizeChart(songJson:SwagSong, ?nameForError:String = null, ?convertTo:String = 'psych_v1'):SwagSong
	{
		var isOldVer:Vector<Bool> = new Vector(2);

		if(Reflect.hasField(songJson, 'song'))
		{
			isOldVer[0] = true;
			var subSong:SwagSong = Reflect.field(songJson, 'song');
			if(subSong != null && Type.typeof(subSong) == TObject)
				songJson = subSong;
		} else isOldVer[0] = false;

		if(convertTo != null && convertTo.length > 0)
		{
			var fmt:String = songJson.format;
			if(fmt == null)
			{
				fmt = songJson.format = 'unknown';
				isOldVer[1] = true;
				if (isOldVer[0] && isOldVer[1]) songJson.isOldVersion = true;
			}

			switch(convertTo)
			{
				case 'psych_v1':
					if(!fmt.startsWith('psych_v1')) //Convert to Psych 1.0 format
					{
						#if debug trace('converting chart $nameForError with format $fmt to psych_v1 format...'); #end
						songJson.format = 'psych_v1_convert';
						convert(songJson);
					}
			}
		}
		return songJson;
	}

	public static function parseJSON(rawData:String, ?nameForError:String = null, ?convertTo:String = 'psych_v1'):SwagSong
	{
		var songJson:SwagSong = cast SongJson.parse(rawData);
		return finalizeChart(songJson, nameForError, convertTo);
	}
}
