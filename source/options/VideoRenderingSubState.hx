package options;

class VideoRenderingSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = "Video Rendering";
		rpcTitle = "Video Rendering Menu";

		var option:Option = new Option(
			'Game Renderer',
			"Records gameplay using FFmpeg.\nRequires FFmpeg installed on system PATH.",
			'gameRenderer',
			BOOL
		);
		addOption(option);

		option = new Option(
			'Record FPS',
			"Sets the FPS used for recording output.",
			'videoRenderFPS',
			INT
		);
		option.minValue = 30;
		option.maxValue = 240;
		option.changeValue = 1;
		option.decimals = 0;
		addOption(option);

		option = new Option(
			'Recording Quality',
			"Higher values look better but create larger files.",
			'videoRenderQuality',
			INT
		);
		option.minValue = 1;
		option.maxValue = 10;
		option.changeValue = 1;
		option.decimals = 0;
		addOption(option);

		super();
	}

	override public function update(elapsed:Float)
	{
		super.update(elapsed);
	}
}
