#!/bin/bash
<<<<<<< HEAD
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
=======
# ============================================================================
# Battery & Power Graph - Data Collection Script
# 电池与功耗图表 - 数据采集脚本
# ============================================================================
# 
# This script reads battery, power, and temperature data from Linux sysfs interfaces
# and outputs it as JSON for the QML frontend to consume.
# 
# 此脚本从 Linux sysfs 接口读取电池、功耗和温度数据，
# 并输出为 JSON 格式供 QML 前端使用。
#
# Data sources:
# - /sys/class/power_supply/BAT* - Battery information
# - /sys/class/power_supply/AC*  - AC adapter status
# - /sys/class/thermal/thermal_zone* - Temperature sensors
# - powerprofilesctl / tuned-adm - Power profile management
#
# 数据来源：
# - /sys/class/power_supply/BAT* - 电池信息
# - /sys/class/power_supply/AC*  - 电源适配器状态
# - /sys/class/thermal/thermal_zone* - 温度传感器
# - powerprofilesctl / tuned-adm - 电源配置文件管理
# ============================================================================

# Find the first available battery device (BAT0, BAT1, etc.)
# 查找第一个可用的电池设备（BAT0、BAT1 等）
BAT=""
for d in /sys/class/power_supply/BAT*; do [ -d "$d" ] && BAT="$d" && break; done

# Find the first available AC adapter device
# 查找第一个可用的电源适配器设备
AC=""
for d in /sys/class/power_supply/AC* /sys/class/power_supply/ADP*; do [ -d "$d" ] && AC="$d" && break; done

# Initialize variables with default values
# 初始化变量，设置默认值
PCT=-1; WATTS=0; CHARGING=false; AC_ON=false; STATUS="Unknown"
TTE=""; TTF=""; DCAP=0; FCAP=0; CYCLES=-1; TEMP=-1

# Read battery data if a battery device was found
# 如果找到电池设备，则读取电池数据
if [ -n "$BAT" ]; then
    # Read battery capacity percentage (0-100%)
    # 读取电池容量百分比（0-100%）
    [ -f "$BAT/capacity" ] && PCT=$(cat "$BAT/capacity")
    
    # Read battery status (Charging, Discharging, Full, etc.)
    # 读取电池状态（充电中、放电中、充满等）
    STATUS=$(cat "$BAT/status" 2>/dev/null || echo Unknown)
    [ "$STATUS" = "Charging" ] && CHARGING=true
    
    # Read voltage, current, and power data
    # Values are in micro-units (microvolts, microamps, microwatts)
    # 读取电压、电流和功耗数据
    # 值为微单位（微伏、微安、微瓦）
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
    VOLT=0; CURR=0; POW=0
    [ -f "$BAT/voltage_now" ] && VOLT=$(cat "$BAT/voltage_now")
    [ -f "$BAT/current_now" ] && CURR=$(cat "$BAT/current_now")
    [ -f "$BAT/power_now" ] && POW=$(cat "$BAT/power_now")
<<<<<<< HEAD
=======
    
    # Calculate power consumption in Watts
    # Priority: power_now > voltage × current
    # If power_now is available, use it directly (convert from microwatts to watts)
    # Otherwise, calculate from voltage and current (convert from micro units)
    # 计算功耗（瓦特）
    # 优先级：power_now > voltage × current
    # 如果 power_now 可用，直接使用（从微瓦转换为瓦特）
    # 否则，从电压和电流计算（从微单位转换）
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
    if [ "$POW" -gt 0 ] 2>/dev/null; then
        WATTS=$(awk "BEGIN{printf \"%.2f\", $POW/1000000}")
    elif [ "$VOLT" -gt 0 ] 2>/dev/null && [ "$CURR" -gt 0 ] 2>/dev/null; then
        WATTS=$(awk "BEGIN{printf \"%.2f\", $VOLT*$CURR/1000000000000}")
    fi
<<<<<<< HEAD
    [ -f "$BAT/charge_full_design" ] && DCAP=$(cat "$BAT/charge_full_design")
    [ -f "$BAT/energy_full_design" ] && [ "$DCAP" = "0" ] && DCAP=$(cat "$BAT/energy_full_design")
    [ -f "$BAT/charge_full" ] && FCAP=$(cat "$BAT/charge_full")
    [ -f "$BAT/energy_full" ] && [ "$FCAP" = "0" ] && FCAP=$(cat "$BAT/energy_full")
    [ -f "$BAT/cycle_count" ] && CYCLES=$(cat "$BAT/cycle_count")
=======
    
    # Read battery design capacity (in mAh or Wh)
    # Try charge_full_design first (mAh), fallback to energy_full_design (Wh)
    # 读取电池设计容量（毫安时或瓦时）
    # 先尝试 charge_full_design（毫安时），回退到 energy_full_design（瓦时）
    [ -f "$BAT/charge_full_design" ] && DCAP=$(cat "$BAT/charge_full_design")
    [ -f "$BAT/energy_full_design" ] && [ "$DCAP" = "0" ] && DCAP=$(cat "$BAT/energy_full_design")
    
    # Read current full charge capacity (in mAh or Wh)
    # Try charge_full first (mAh), fallback to energy_full (Wh)
    # 读取当前满充容量（毫安时或瓦时）
    # 先尝试 charge_full（毫安时），回退到 energy_full（瓦时）
    [ -f "$BAT/charge_full" ] && FCAP=$(cat "$BAT/charge_full")
    [ -f "$BAT/energy_full" ] && [ "$FCAP" = "0" ] && FCAP=$(cat "$BAT/energy_full")
    
    # Read battery cycle count (number of charge/discharge cycles)
    # 读取电池循环次数（充放电循环次数）
    [ -f "$BAT/cycle_count" ] && CYCLES=$(cat "$BAT/cycle_count")
    
    # Read battery temperature from sysfs (if available)
    # Temperature is stored in centi-degrees (×100), so divide by 10
    # 从 sysfs 读取电池温度（如果可用）
    # 温度以百分度存储（×100），所以除以 10
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
    if [ -f "$BAT/temp" ]; then
        RAW_TEMP=$(cat "$BAT/temp")
        TEMP=$(awk "BEGIN{printf \"%.1f\", $RAW_TEMP/10}")
    fi
<<<<<<< HEAD
=======
    
    # Fallback: Try to read temperature from thermal zones
    # Some hardware doesn't expose battery temp directly in BAT sysfs
    # Search for thermal zones containing "bat", "BAT", "battery", or "Battery"
    # 回退方案：尝试从热区读取温度
    # 某些硬件不在 BAT sysfs 中直接暴露电池温度
    # 搜索包含"bat"、"BAT"、"battery"或"Battery"的热区
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
    if [ "$TEMP" = "-1" ] || [ "$TEMP" = "0.0" ]; then
        for tz in /sys/class/thermal/thermal_zone*; do
            TZ_TYPE=$(cat "$tz/type" 2>/dev/null)
            case "$TZ_TYPE" in *bat*|*BAT*|*battery*|*Battery*)
                [ -f "$tz/temp" ] && RAW_TEMP=$(cat "$tz/temp") &&
                TEMP=$(awk "BEGIN{printf \"%.1f\", $RAW_TEMP/1000}"); break;;
            esac
        done
    fi
<<<<<<< HEAD
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
=======
    
    # Calculate time to empty (discharging only)
    # Formula: time = energy_now / power_now
    # Only calculate when discharging, battery > 0, and power > 0
    # 计算剩余使用时间（仅放电时）
    # 公式：时间 = energy_now / power_now
    # 仅在放电、电量 > 0 且功耗 > 0 时计算
    if [ "$CHARGING" = "false" ] && [ "$PCT" -gt 0 ] 2>/dev/null; then
        ENERGY_NOW=0
        # Try energy_now first (in micro-watt-hours), fallback to charge_now (in micro-amp-hours)
        # 先尝试 energy_now（微瓦时），回退到 charge_now（微安时）
        [ -f "$BAT/energy_now" ] && ENERGY_NOW=$(cat "$BAT/energy_now")
        [ -f "$BAT/charge_now" ] && [ "$ENERGY_NOW" = "0" ] && ENERGY_NOW=$(cat "$BAT/charge_now")
        
        # Calculate remaining time in minutes: (energy / power) × 60
        # Convert from microwatts to watts for accurate calculation
        # 计算剩余时间（分钟）：(能量 / 功率) × 60
        # 从微瓦转换为瓦特以进行准确计算
        if [ "$POW" -gt 0 ] 2>/dev/null && [ "$ENERGY_NOW" -gt 0 ] 2>/dev/null; then
            MINS=$(awk "BEGIN{printf \"%d\", $ENERGY_NOW*60/$POW}")
            # Format as "Xh Ym" (e.g., "2h 15m")
            # 格式化为"X 小时 Y 分钟"（例如："2 小时 15 分钟"）
            [ -n "$MINS" ] && [ "$MINS" -gt 0 ] 2>/dev/null && TTE="$((MINS/60))h $((MINS%60))m"
        fi
    fi
    
    # Calculate time to full (charging only)
    # Formula: time = (energy_full - energy_now) / power_now
    # Only calculate when charging, power > 0, and energy_full > 0
    # 计算充满时间（仅充电时）
    # 公式：时间 = (energy_full - energy_now) / power_now
    # 仅在充电、功耗 > 0 且 energy_full > 0 时计算
    if [ "$CHARGING" = "true" ]; then
        ENERGY_FULL=0; ENERGY_NOW=0
        # Read full capacity and current capacity
        # Try energy_* first (Wh), fallback to charge_* (mAh)
        # 读取满充容量和当前容量
        # 先尝试 energy_*（瓦时），回退到 charge_*（毫安时）
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
        [ -f "$BAT/energy_full" ] && ENERGY_FULL=$(cat "$BAT/energy_full")
        [ -f "$BAT/energy_now" ] && ENERGY_NOW=$(cat "$BAT/energy_now")
        [ -f "$BAT/charge_full" ] && [ "$ENERGY_FULL" = "0" ] && ENERGY_FULL=$(cat "$BAT/charge_full")
        [ -f "$BAT/charge_now" ] && [ "$ENERGY_NOW" = "0" ] && ENERGY_NOW=$(cat "$BAT/charge_now")
<<<<<<< HEAD
        if [ "$POW" -gt 0 ] 2>/dev/null && [ "$ENERGY_FULL" -gt 0 ] 2>/dev/null; then
            REMAIN=$((ENERGY_FULL - ENERGY_NOW))
            [ "$REMAIN" -gt 0 ] 2>/dev/null && MINS=$(awk "BEGIN{printf \"%d\", $REMAIN*60/$POW}")
=======
        
        # Calculate remaining energy needed to reach full charge
        # 计算达到满充所需的剩余能量
        if [ "$POW" -gt 0 ] 2>/dev/null && [ "$ENERGY_FULL" -gt 0 ] 2>/dev/null; then
            REMAIN=$((ENERGY_FULL - ENERGY_NOW))
            # Only calculate if there's actually remaining capacity to charge
            # 仅在确实有剩余容量需要充电时才计算
            [ "$REMAIN" -gt 0 ] 2>/dev/null && MINS=$(awk "BEGIN{printf \"%d\", $REMAIN*60/$POW}")
            # Format as "Xh Ym"
            # 格式化为"X 小时 Y 分钟"
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
            [ -n "$MINS" ] && [ "$MINS" -gt 0 ] 2>/dev/null && TTF="$((MINS/60))h $((MINS%60))m"
        fi
    fi
fi
<<<<<<< HEAD
[ -n "$AC" ] && [ -f "$AC/online" ] && [ "$(cat "$AC/online")" = "1" ] && AC_ON=true

PPD_PROFILE=""; PPD_AVAIL=""
if command -v powerprofilesctl >/dev/null 2>&1; then
    PPD_PROFILE=$(powerprofilesctl get 2>/dev/null)
    PPD_AVAIL=$(powerprofilesctl list 2>/dev/null | grep -oE '^\*?\s*(performance|balanced|power-saver):' | sed 's/[* :]//g' | tr '\n' ',' | sed 's/,$//')
    [ -z "$PPD_AVAIL" ] && [ -n "$PPD_PROFILE" ] && PPD_AVAIL="power-saver,balanced,performance"
=======

# Read AC adapter online status (1 = plugged in, 0 = unplugged)
# This is a separate check from battery status to detect AC connection independently
# 读取电源适配器在线状态（1 = 已插入，0 = 未插入）
# 这是与电池状态分开的检查，以独立检测交流电源连接
[ -n "$AC" ] && [ -f "$AC/online" ] && [ "$(cat "$AC/online")" = "1" ] && AC_ON=true

# ============================================================================
# Power Profile Detection (power-profiles-daemon)
# 电源配置文件检测（power-profiles-daemon）
# ============================================================================
PPD_PROFILE=""; PPD_AVAIL=""

# Method 1: Use powerprofilesctl command (preferred)
# 方法 1：使用 powerprofilesctl 命令（首选）
if command -v powerprofilesctl >/dev/null 2>&1; then
    PPD_PROFILE=$(powerprofilesctl get 2>/dev/null)
    PPD_AVAIL=$(powerprofilesctl list 2>/dev/null | grep -oE '^\*?\s*(performance|balanced|power-saver):' | sed 's/[* :]//g' | tr '\n' ',' | sed 's/,$//')
    # Fallback to standard profiles if detection failed but service is running
    # 如果检测失败但服务正在运行，则回退到标准配置文件
    [ -z "$PPD_AVAIL" ] && [ -n "$PPD_PROFILE" ] && PPD_AVAIL="power-saver,balanced,performance"

# Method 2: Use gdbus to query D-Bus directly
# 方法 2：使用 gdbus 直接查询 D-Bus
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
elif command -v gdbus >/dev/null 2>&1; then
    PPD_PROFILE=$(gdbus call --system --dest net.hadess.PowerProfiles --object-path /net/hadess/PowerProfiles --method org.freedesktop.DBus.Properties.Get net.hadess.PowerProfiles ActiveProfile 2>/dev/null | grep -oE '(performance|balanced|power-saver)')
    PPD_AVAIL=$(gdbus call --system --dest net.hadess.PowerProfiles --object-path /net/hadess/PowerProfiles --method org.freedesktop.DBus.Properties.Get net.hadess.PowerProfiles Profiles 2>/dev/null | grep -oE '(performance|balanced|power-saver)' | sort -u | tr '\n' ',' | sed 's/,$//')
    [ -z "$PPD_AVAIL" ] && [ -n "$PPD_PROFILE" ] && PPD_AVAIL="power-saver,balanced,performance"
fi

<<<<<<< HEAD
# TuneD profiles (tuned-adm) — use | separator since descriptions contain commas
TUNED_PROFILE=""; TUNED_AVAIL=""
if command -v tuned-adm >/dev/null 2>&1; then
    TUNED_PROFILE=$(tuned-adm active 2>/dev/null | grep -oP 'Current active profile: \K.*' || true)
    TUNED_AVAIL=$(tuned-adm list 2>/dev/null | grep '^- ' | sed 's/^- //' | tr '\n' '|' | sed 's/|$//' || true)
fi

=======
# ============================================================================
# TuneD Profile Detection (tuned-adm)
# TuneD 配置文件检测（tuned-adm）
# ============================================================================
TUNED_PROFILE=""; TUNED_AVAIL=""

# Use tuned-adm command to detect active profile and available profiles
# Descriptions are separated by "  - " (2+ spaces and dash), use | as separator
# 使用 tuned-adm 命令检测活动配置文件和可用配置文件
# 描述由"  - "（2 个以上空格和破折号）分隔，使用 | 作为分隔符
if command -v tuned-adm >/dev/null 2>&1; then
    TUNED_PROFILE=$(tuned-adm active 2>/dev/null | grep -oP 'Current active profile: \K.*' || true)
    TUNED_AVAIL=$(tuned-adm list 2>/dev/null | grep '^- ' | sed 's/^- //' | tr '\n' '|' | sed 's|$//' || true)
fi

# ============================================================================
# Output JSON format for QML to parse
# 输出 JSON 格式供 QML 解析
# ============================================================================
>>>>>>> aaebcee (docs: Add comprehensive bilingual comments and enhance code documentation)
echo "{\"battery_pct\": $PCT, \"power_watts\": $WATTS, \"charging\": $CHARGING, \"ac_online\": $AC_ON, \"status\": \"$STATUS\", \"time_to_empty\": \"$TTE\", \"time_to_full\": \"$TTF\", \"design_capacity\": $DCAP, \"full_capacity\": $FCAP, \"cycle_count\": $CYCLES, \"temp_celsius\": $TEMP, \"power_profile\": \"$PPD_PROFILE\", \"profiles_available\": \"$PPD_AVAIL\", \"tuned_profile\": \"$TUNED_PROFILE\", \"tuned_available\": \"$TUNED_AVAIL\"}"
