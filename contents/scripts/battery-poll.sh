#!/bin/bash
# Battery & Power Graph - data collection script
BAT=""
for d in /sys/class/power_supply/BAT*; do [ -d "$d" ] && BAT="$d" && break; done
AC=""
for d in /sys/class/power_supply/AC* /sys/class/power_supply/ADP*; do [ -d "$d" ] && AC="$d" && break; done
PCT=-1; WATTS=0; CHARGING=false; AC_ON=false; STATUS="Unknown"
TTE=""; TTF=""; DCAP=0; FCAP=0; CYCLES=-1; TEMP=-1
if [ -n "$BAT" ]; then
    [ -f "$BAT/capacity" ] && PCT=$(cat "$BAT/capacity")
    STATUS=$(cat "$BAT/status" 2>/dev/null || echo Unknown)
    [ "$STATUS" = "Charging" ] && CHARGING=true
    VOLT=0; CURR=0; POW=0
    [ -f "$BAT/voltage_now" ] && VOLT=$(cat "$BAT/voltage_now")
    [ -f "$BAT/current_now" ] && CURR=$(cat "$BAT/current_now")
    [ -f "$BAT/power_now" ] && POW=$(cat "$BAT/power_now")
    if [ "$POW" -gt 0 ] 2>/dev/null; then
        WATTS=$(awk "BEGIN{printf \"%.2f\", $POW/1000000}")
    elif [ "$VOLT" -gt 0 ] 2>/dev/null && [ "$CURR" -gt 0 ] 2>/dev/null; then
        WATTS=$(awk "BEGIN{printf \"%.2f\", $VOLT*$CURR/1000000000000}")
    fi
    [ -f "$BAT/charge_full_design" ] && DCAP=$(cat "$BAT/charge_full_design")
    [ -f "$BAT/energy_full_design" ] && [ "$DCAP" = "0" ] && DCAP=$(cat "$BAT/energy_full_design")
    [ -f "$BAT/charge_full" ] && FCAP=$(cat "$BAT/charge_full")
    [ -f "$BAT/energy_full" ] && [ "$FCAP" = "0" ] && FCAP=$(cat "$BAT/energy_full")
    [ -f "$BAT/cycle_count" ] && CYCLES=$(cat "$BAT/cycle_count")
    if [ -f "$BAT/temp" ]; then
        RAW_TEMP=$(cat "$BAT/temp")
        TEMP=$(awk "BEGIN{printf \"%.1f\", $RAW_TEMP/10}")
    fi
    if [ "$TEMP" = "-1" ] || [ "$TEMP" = "0.0" ]; then
        for tz in /sys/class/thermal/thermal_zone*; do
            TZ_TYPE=$(cat "$tz/type" 2>/dev/null)
            case "$TZ_TYPE" in *bat*|*BAT*|*battery*|*Battery*)
                [ -f "$tz/temp" ] && RAW_TEMP=$(cat "$tz/temp") &&
                TEMP=$(awk "BEGIN{printf \"%.1f\", $RAW_TEMP/1000}"); break;;
            esac
        done
    fi
    if [ "$CHARGING" = "false" ] && [ "$PCT" -gt 0 ] 2>/dev/null; then
        ENERGY_NOW=0
        [ -f "$BAT/energy_now" ] && ENERGY_NOW=$(cat "$BAT/energy_now")
        [ -f "$BAT/charge_now" ] && [ "$ENERGY_NOW" = "0" ] && ENERGY_NOW=$(cat "$BAT/charge_now")
        if [ "$POW" -gt 0 ] 2>/dev/null && [ "$ENERGY_NOW" -gt 0 ] 2>/dev/null; then
            MINS=$(awk "BEGIN{printf \"%d\", $ENERGY_NOW*60/$POW}")
            [ -n "$MINS" ] && [ "$MINS" -gt 0 ] 2>/dev/null && TTE="$((MINS/60))h $((MINS%60))m"
        fi
    fi
    if [ "$CHARGING" = "true" ]; then
        ENERGY_FULL=0; ENERGY_NOW=0
        [ -f "$BAT/energy_full" ] && ENERGY_FULL=$(cat "$BAT/energy_full")
        [ -f "$BAT/energy_now" ] && ENERGY_NOW=$(cat "$BAT/energy_now")
        [ -f "$BAT/charge_full" ] && [ "$ENERGY_FULL" = "0" ] && ENERGY_FULL=$(cat "$BAT/charge_full")
        [ -f "$BAT/charge_now" ] && [ "$ENERGY_NOW" = "0" ] && ENERGY_NOW=$(cat "$BAT/charge_now")
        if [ "$POW" -gt 0 ] 2>/dev/null && [ "$ENERGY_FULL" -gt 0 ] 2>/dev/null; then
            REMAIN=$((ENERGY_FULL - ENERGY_NOW))
            [ "$REMAIN" -gt 0 ] 2>/dev/null && MINS=$(awk "BEGIN{printf \"%d\", $REMAIN*60/$POW}")
            [ -n "$MINS" ] && [ "$MINS" -gt 0 ] 2>/dev/null && TTF="$((MINS/60))h $((MINS%60))m"
        fi
    fi
fi
[ -n "$AC" ] && [ -f "$AC/online" ] && [ "$(cat "$AC/online")" = "1" ] && AC_ON=true

PPD_PROFILE=""; PPD_AVAIL=""
if command -v powerprofilesctl >/dev/null 2>&1; then
    PPD_PROFILE=$(powerprofilesctl get 2>/dev/null)
    PPD_AVAIL=$(powerprofilesctl list 2>/dev/null | grep -oE '^\*?\s*(performance|balanced|power-saver):' | sed 's/[* :]//g' | tr '\n' ',' | sed 's/,$//')
elif command -v gdbus >/dev/null 2>&1; then
    PPD_PROFILE=$(gdbus call --system --dest net.hadess.PowerProfiles --object-path /net/hadess/PowerProfiles --method org.freedesktop.DBus.Properties.Get net.hadess.PowerProfiles ActiveProfile 2>/dev/null | grep -oE '(performance|balanced|power-saver)')
    PPD_AVAIL=$(gdbus call --system --dest net.hadess.PowerProfiles --object-path /net/hadess/PowerProfiles --method org.freedesktop.DBus.Properties.Get net.hadess.PowerProfiles Profiles 2>/dev/null | grep -oE '(performance|balanced|power-saver)' | sort -u | tr '\n' ',' | sed 's/,$//')
fi
[ -z "$PPD_AVAIL" ] && [ -n "$PPD_PROFILE" ] && PPD_AVAIL="power-saver,balanced,performance"

echo "{\"battery_pct\": $PCT, \"power_watts\": $WATTS, \"charging\": $CHARGING, \"ac_online\": $AC_ON, \"status\": \"$STATUS\", \"time_to_empty\": \"$TTE\", \"time_to_full\": \"$TTF\", \"design_capacity\": $DCAP, \"full_capacity\": $FCAP, \"cycle_count\": $CYCLES, \"temp_celsius\": $TEMP, \"power_profile\": \"$PPD_PROFILE\", \"profiles_available\": \"$PPD_AVAIL\"}"
