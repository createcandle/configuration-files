#!/bin/bash

# Change default audio output while we're at it.
VIRTUAL_SINK=$(wpctl status | grep '\[Audio/Sink\]' | grep "virtual_combine_all_sinks")
echo "pipewire VIRTUAL_SINK: $VIRTUAL_SINK"
if [ -n "$VIRTUAL_SINK" ]; then
	if echo "$VIRTUAL_SINK" | grep -q '\*'; then
		echo "virtual audio sink already seems to be the default"
	else
		echo "changing pipewire default audio output to VIRTUAL_SINK: $VIRTUAL_SINK"
		SINK_ID=$(wpctl status | grep '\[Audio/Sink\]' | grep "virtual_combine_all_sinks" | grep -E '^ │( )*[0-9]*' -o | cut -c6-55 | grep -E -o '[0-9]*')
		if [[ $SINK_ID =~ ^[0-9]+$ ]]; then
			echo "setting pipewire virtual sink as the default.  SINK_ID: $SINK_ID"
			wpctl set-default "$SINK_ID"
		else
			echo ""
		    echo "ERROR, pipewire SINK_ID is not a number: $SINK_ID"
			echo ""
		fi
	fi
fi
