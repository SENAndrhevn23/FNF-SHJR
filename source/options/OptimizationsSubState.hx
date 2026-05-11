package options;

import flixel.FlxG;
import flixel.util.FlxSave;

class GCControl
{
    public static var lastTime:Float = 0;
}

class OptimizationsSubState extends BaseOptionsMenu
{
    var limitComboOption:Option;
    var scrollTimer:Float = 0;
    var scrollDirection:Int = 0;

    public function new()
    {
        title = "Optimizations";
        rpcTitle = "Optimizations Menu";

        // -------------------------
        // Rating / Combo Pop-Up Options
        // -------------------------
        var option:Option = new Option('Show Rating Pop-Up',
            "If checked, the \"Rating Pop-Up\" will display every time you hit notes.\nUnchecking reduces RAM usage slightly.",
            'showRating',
            BOOL);
        addOption(option);

        option = new Option('Show Combo Number Pop-Up',
            "If checked, the \"Combo Number Pop-Up\" will display every time you hit notes.\nUnchecking reduces RAM usage slightly.",
            'showComboNum',
            BOOL);
        addOption(option);

        option = new Option('Show Combo Pop-Up',
            "If checked, the \"Combo Pop-Up\" will display every time you hit notes.\nUnchecking reduces RAM usage slightly.",
            'showCombo',
            BOOL);
        addOption(option);

        // -------------------------
        // Real-Time Slow Motion
        // -------------------------
        option = new Option('Real-Time Slow Motion',
            "If enabled, playbackRate only affects visuals.\nThe engine still runs at full speed, preventing lag at very low playback rates.",
            'realtimeSlowmo',
            BOOL);
        addOption(option);

        // -------------------------
        // Disable GC Lag Option
        // -------------------------
        option = new Option('Disable Garbage Collection',
            "If enabled, forces manual GC control, preventing automatic garbage collection spikes that can cause frame drops.\nWarning: may increase memory usage over time.",
            'disableGCLag',
            BOOL);
        addOption(option);

        // -------------------------
        // Note Shader Toggle
        // -------------------------
        option = new Option('Note Shaders',
            "If unchecked, disables note shaders.\nPlease use the noteSkin older than psych v0.6.x!",
            'noteShaders',
            BOOL);
        addOption(option);

        // -------------------------
        // Change Combo Limit Option
        // -------------------------
        limitComboOption = new Option('Change Combo Limit',
            "What should be the max combo displayed?\nSet to 0 to remove the limit (infinite).",
            'limitCombo',
            INT);
        limitComboOption.minValue = 0;
        limitComboOption.maxValue = 2147483647;
        limitComboOption.changeValue = 1;
        limitComboOption.decimals = 0;
        addOption(limitComboOption);

        super();
    }

    override public function update(elapsed:Float)
    {
        super.update(elapsed);

        // -------------------------
        // Scroll Combo Limit
        // -------------------------
        if(FlxG.keys.pressed.UP)
            scrollDirection = -1;
        else if(FlxG.keys.pressed.DOWN)
            scrollDirection = 1;
        else
        {
            scrollDirection = 0;
            scrollTimer = 0;
        }

        if(scrollDirection != 0)
        {
            scrollTimer += elapsed;
            var multiplier:Int = Std.int(Math.pow(2, scrollTimer * 2));
            var increment:Int = Std.int(limitComboOption.changeValue * multiplier);
            var current:Int = limitComboOption.getValue();
            current += scrollDirection * increment;

            if(current < limitComboOption.minValue)
                current = limitComboOption.minValue;

            limitComboOption.setValue(current);
        }

        // -------------------------
        // Manual GC Control
        // -------------------------
        if(Reflect.field(FlxG.save.data, "disableGCLag") == true)
        {
            GCControl.lastTime += elapsed;
            if(GCControl.lastTime >= 5)
            {
                #if neko || js
                Sys.gc();
                #end
                GCControl.lastTime = 0;
            }
        }
    }
}
