#!/bin/bash

#CB1 - example PG9 (32) -> GND (30)
#gpiochip=gpiochip0
#pin=201

#OPI3LTS - PL03 (X7-5,6 for panama-pi)
gpiochip=gpiochip0
pin=3

safe_temp=50

#avoid exit if no physical button is connected
if [ `gpioget -B pull-up $gpiochip $pin` -eq 1 ]; then
        >&2 echo "Button should not be pressed so early, potential wiring problem"
        exit 1
fi;


while :
do
        #button check placeholder
        sleep 0.2
        [ `gpioget -B pull-up $gpiochip $pin` -eq 0 ] && continue

        echo "button event"

        # ready to poweroff in klipper shutdown state
        curl -s http://127.0.0.1:7125/printer/objects/query?webhooks | jq -M .result.status.webhooks.state | grep -q shutdown && break

        # prevent poweroff if printing
        curl -s http://127.0.0.1:7125/printer/objects/query?print_stats | jq -M .result.status.print_stats.state | grep -q printing && continue

        #prevent poweroff if hotend is hot
        hotend_temp=`curl -s http://127.0.0.1:7125/printer/objects/query?extruder | jq .result.status.extruder.temperature`
        is_safe=$(echo "$hotend_temp < $safe_temp" | bc -l)
        echo $hotend_temp $is_safe
        [ $is_safe -eq 1 ] && break
        [ -z $is_safe ] && break
done

sudo poweroff

