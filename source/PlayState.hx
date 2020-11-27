package;

import flixel.addons.ui.FlxUIState;
import grig.midi.MidiIn;
import grig.midi.MidiOut;
import grig.midi.MidiMessage;
import flixel.addons.ui.FlxUIDropDownMenu;
import flixel.addons.ui.FlxUIButton;
import flixel.addons.ui.StrNameLabel;
import flixel.FlxSprite;

class PlayState extends FlxUIState
{
	var midiIn:MidiIn;
	var midiOut:MidiOut;

	var SUBDIVISION:Int = 8;
	var interval:Float;

	var timer:Float = 0;
	var step:Int = 0;
	var sequence = [ 48, 52, 55, 60, 48, 52, 55, 60 ];

	var scale = [ 48, 50, 52, 53, 55, 57, 59, 60 ];

	var outputReady = false;
	var inputReady = false;
	var playing = false;

	var mode:String = "sequence";
	var active_step:Int = -1;

	var pads:Array<FlxUIButton>;
	var play_indicator:FlxSprite;

	override public function create()
	{
		_xml_id = "play";

		super.create();

		midiIn = new MidiIn(grig.midi.Api.Unspecified);
		midiIn.setCallback(function (midiMessage:MidiMessage, delta:Float) {
		    if ( midiMessage.messageType != MessageType.TimeClock ) {
			    trace('midimessage', midiMessage.messageType, midiMessage.channel, midiMessage.byte1, midiMessage.byte2, midiMessage.byte3 );
		    }
		});

		midiOut = new MidiOut( grig.midi.Api.Unspecified );
		trace("Midi situation", MidiOut.getApis(), MidiIn.getApis(), grig.midi.Api.Unspecified );

		midiIn.getPorts().handle(function(outcome) {
	    switch outcome {
        case Success(ports):
					trace('midi input ports', ports);
          midiIn.openPort(0, 'grig.midi').handle(function(midiOutcome) {
            switch midiOutcome {
              case Success(_):
              	trace( "Midi input ready." );
              	inputReady = true;
              case Failure(error):
                trace( "Error in midi input setup", error );
            }
	        });
	      case Failure(error):
	        trace( "Error in midi input setup", error );
		    }
		});

		midiOut.getPorts().handle( function ( outcome ) {
			switch outcome {
				case Success(ports):
					trace('midi output ports', ports);
					loadMidiDevices( ports );
				case Failure(error):
					trace('Error in midi output setup', error);
			}
		});

		setInterval( 60 );

		pads = new Array<FlxUIButton>();
		for( i in 1...9 ) {
			pads.push( cast _ui.getAsset("pad_" + i ) );
			trace("pad_" + i, pads[i-1]);
		}

		play_indicator = new FlxSprite( -64, -64, AssetPaths.play_indicator__png );
		add( play_indicator );
	}

	function loadMidiDevices( ports:Array<String> ) {
		var devices = [];
		var index = 0;
		devices.push( new StrNameLabel( "-1", "Please select a device." ) );
		for ( port in ports ) {
			devices.push( new StrNameLabel( Std.string( index ), port ) );
			index += 1;
		}
		var midiDeviceDropdown:FlxUIDropDownMenu = cast _ui.getAsset("devices");
		midiDeviceDropdown.setData( devices );
	}

	function selectMidiDevice( port:Int ) {
		midiOut.closePort();
		midiOut.openPort( port, 'grig.midi').handle( function ( midiOutcome ) {
			switch midiOutcome {
				case Success(_):
					trace('Midi output ready.');
					outputReady = true;
				case Failure(error):
					trace('Error in midi output setup', error);
			}
		});
	}

	function setInterval( bpm:Float ) {
		interval = ( 60.0 / bpm ) / SUBDIVISION;
	}

	function beat() {
		step = ( step + 1 ) % ( sequence.length * 2 );
		midiOut.sendMessage(
			MidiMessage.ofArray( [step % 2 == 0 ? 144 : 128, sequence[ Math.floor( step / 2 ) ], 64 ] )
		);
		play_indicator.setPosition( pads[ Math.floor( step / 2 ) ].x - 4, pads[ Math.floor( step / 2 ) ].y - 4 );
	}

	override public function update(elapsed:Float)
	{
		super.update(elapsed);

		if ( playing == true ) {
			timer += elapsed;
			if ( timer >= interval ) {
				timer = timer - interval;
				beat();
			} 
		}
	}

	public override function getEvent(name:String, target:Dynamic, data:Dynamic, ?params:Array<Dynamic>):Void 
	{
		switch (name)
	    {
				case "change_numeric_stepper":
					if (params != null && params.length > 0)
					{
						switch (Std.string(params[0]))
						{
							case "bpm":
								setInterval( data );
						}
					}
	    	case "click_dropdown":
		    	selectMidiDevice( Std.int( data ) );
	      case "click_button":
	        if (params != null && params.length > 0)
	        {
	        	switch ( Std.string(params[0]) )
	        	{
	            	case "play":
	            		if ( outputReady == true ) {
		            		if ( playing == true ) {
		            			// stop
		            			MidiMessage.ofArray( [ 128, sequence[ Math.floor( step / 2 ) ], 64 ] );
		            			playing = false;
		            		} else {
		            			playing = true;
		            		}
	            		}
	            	case "pad":
	            		if ( mode == "sequence" ) {
	            			mode = "note";
	            			active_step = params[1];
	            		} else if ( mode == "note" ) {
	            			sequence[ active_step ] = scale[ params[1] ];
	            			mode = "sequence";
	            		}
            }
          }
      }
  }
}
