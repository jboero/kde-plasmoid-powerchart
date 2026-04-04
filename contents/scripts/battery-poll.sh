#!/bin/bash
# ============================================================================
# Battery & Power Graph - Data Collection Script
# 电池与功耗图表 - 数据采集脚本
# ============================================================================
# 
# This script collects real-time battery data from Linux sysfs interface
# and outputs it in JSON format for the KDE Plasma plasmoid to consume.
# 
# 此脚本从 Linux sysfs 接口收集实时电池数据，
# 并以 JSON 格式输出供 KDE Plasma 小部件使用。
#
# Data Sources / 数据来源:
#   - /sys/class/power_supply/BAT* - Battery information / 电池信息
#   - /sys/class/power_supply/AC*  - AC adapter status / 电源适配器状态
#   - /sys/class/thermal/thermal_zone* - Temperature sensors / 温度传感器
#   - powerprofilesctl / tuned-adm - Power management profiles / 电源管理配置文件
#
# Output Format / 输出格式:
#   JSON object with fields: battery_pct, power_watts, charging, ac_online,
#   status, time_to_empty, time_to_full, design_capacity, full_capacity,
#   cycle_count, temp_celsius, power_profile, profiles_available,
#   tuned_profile, tuned_available
# ============================================================================

# Find the first available battery device
# 查找第一个可用的电池设备
BAT=""
for d in /sys/class/power_supply/BAT*; do [ -d "$d" ] && BAT="$d" && break; done

# Find AC adapter (try both AC and ADP naming conventions)
# 查找电源适配器（尝试 AC 和 ADP 两种命名约定）
AC=""
for d in /sys/class/power_supply/AC* /sys/class/power_supply/ADP*; do [ -d "$d" ] && AC="$d" && break; done

# Initialize variables with default values
# 初始化变量及默认值
PCT=-1; WATTS=0; CHARGING=false; AC_ON=false; STATUS="Unknown"
TTE=""; TTF=""; DCAP=0; FCAP=0; CYCLES=-1; TEMP=-1

# Read battery data if a battery device was found
# 如果找到电池设备则读取电池数据
if [ -n "$BAT" ]; then
    # Battery percentage (0-100)
    # 电池电量百分比（0-100）
    [ -f "$BAT/capacity" ] && PCT=$(cat "$BAT/capacity")
    
    # Battery status: Charging, Discharging, Full, or Unknown
    # 电池状态：充电、放电、充满或未知
    STATUS=$(cat "$BAT/status" 2>/dev/null || echo Unknown)
    [ "$STATUS" = "Charging" ] && CHARGING=true
    
    # Calculate power consumption in Watts
    # 计算功耗（瓦特）
    VOLT=0; CURR=0; POW=0
    [ -f "$BAT/voltage_now" ] && VOLT=$(cat "$BAT/voltage_now")         # Voltage in microvolts / 电压（微伏）
    [ -f "$BAT/current_now" ] && CURR=$(cat "$BAT/current_now")         # Current in microamps / 电流（微安）
    [ -f "$BAT/power_now" ] && POW=$(cat "$BAT/power_now")              # Power in microwatts / 功率（微瓦）
    
    # Calculate watts from power_now if available, otherwise from voltage × current
    # 优先使用 power_now 计算瓦特，否则使用电压×电流计算
    if [ "$POW" -gt 0 ] 2>/dev/null; then
        # Convert microwatts to watts: μW ÷ 1,000,000 = W
        # 从微瓦转换为瓦特：μW ÷ 1,000,000 = W
        WATTS=$(awk "BEGIN{printf \"%.2f\", $POW/1000000}")
    elif [ "$VOLT" -gt 0 ] 2>/dev/null && [ "$CURR" -gt 0 ] 2>/dev/null; then
        # Calculate power: V × I = P (voltage × current = power)
        # 计算功率：V × I = P（电压 × 电流 = 功率）
        # Convert: (μV × μA) ÷ 1,000,000,000,000 = W
        # 转换：(μV × μA) ÷ 1,000,000,000,000 = W
        WATTS=$(awk "BEGIN{printf \"%.2f\", $VOLT*$CURR/1000000000000}")
    fi
    
    # Read battery capacity information
    # 读取电池容量信息
    [ -f "$BAT/charge_full_design" ] && DCAP=$(cat "$BAT/charge_full_design")      # Design capacity (mAh) / 设计容量（毫安时）
    [ -f "$BAT/energy_full_design" ] && [ "$DCAP" = "0" ] && DCAP=$(cat "$BAT/energy_full_design")  # Fallback to Wh / 回退到瓦时
    [ -f "$BAT/charge_full" ] && FCAP=$(cat "$BAT/charge_full")                    # Current full capacity (mAh) / 当前满充容量（毫安时）
    [ -f "$BAT/energy_full" ] && [ "$FCAP" = "0" ] && FCAP=$(cat "$BAT/energy_full")  # Fallback to Wh / 回退到瓦时
    
    # Read battery cycle count (if available)
    # 读取电池循环次数（如果可用）
    [ -f "$BAT/cycle_count" ] && CYCLES=$(cat "$BAT/cycle_count")
    
    # Read battery temperature from BAT sensor
    # 从 BAT 传感器读取电池温度
    if [ -f "$BAT/temp" ]; then
        RAW_TEMP=$(cat "$BAT/temp")
        # Convert from millidegrees Celsius to degrees Celsius: m°C ÷ 10 = °C
        # 从毫摄氏度转换为摄氏度：m°C ÷ 10 = °C
        TEMP=$(awk "BEGIN{printf \"%.1f\", $RAW_TEMP/10}")
    fi
    
    # Fallback: Try thermal zone sensors if BAT temp is unavailable
    # 回退：如果 BAT 温度不可用，尝试热区传感器
    if [ "$TEMP" = "-1" ] || [ "$TEMP" = "0.0" ]; then
        for tz in /sys/class/thermal/thermal_zone*; do
            TZ_TYPE=$(cat "$tz/type" 2>/dev/null)
            case "$TZ_TYPE" in *bat*|*BAT*|*battery*|*Battery*)
                [ -f "$tz/temp" ] && RAW_TEMP=$(cat "$tz/temp") &&
                # Convert from millidegrees to degrees: m°C ÷ 1000 = °C
                # 从毫度转换为度：m°C ÷ 1000 = °C
                TEMP=$(awk "BEGIN{printf \"%.1f\", $RAW_TEMP/1000}"); break;;
            esac
        done
    fi
    
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
        [ -f "$BAT/energy_full" ] && ENERGY_FULL=$(cat "$BAT/energy_full")
        [ -f "$BAT/energy_now" ] && ENERGY_NOW=$(cat "$BAT/energy_now")
        [ -f "$BAT/charge_full" ] && [ "$ENERGY_FULL" = "0" ] && ENERGY_FULL=$(cat "$BAT/charge_full")
        [ -f "$BAT/charge_now" ] && [ "$ENERGY_NOW" = "0" ] && ENERGY_NOW=$(cat "$BAT/charge_now")
        
        # Calculate remaining energy needed to reach full charge
        # 计算达到满充所需的剩余能量
        if [ "$POW" -gt 0 ] 2>/dev/null && [ "$ENERGY_FULL" -gt 0 ] 2>/dev/null; then
            REMAIN=$((ENERGY_FULL - ENERGY_NOW))
            # Only calculate if there's actually remaining capacity to charge
            # 仅在确实有剩余容量需要充电时才计算
            [ "$REMAIN" -gt 0 ] 2>/dev/null && MINS=$(awk "BEGIN{printf \"%d\", $REMAIN*60/$POW}")
            # Format as "Xh Ym"
            # 格式化为"X 小时 Y 分钟"
            [ -n "$MINS" ] && [ "$MINS" -gt 0 ] 2>/dev/null && TTF="$((MINS/60))h $((MINS%60))m"
        fi
    fi
fi

# Read AC adapter online status (1 = plugged in, 0 = unplugged)
# This is a separate check from battery status to detect AC connection independently
# 读取电源适配器在线状态（1 = 已插入，0 = 未插入）
# 这是与电池状态分开的检查，以独立检测交流电源连接
[ -n "$AC" ] && [ -f "$AC/online" ] && [ "$(cat "$AC/online")" = "1" ] && AC_ON=true

# Get power-profiles-daemon profile information
# 获取 power-profiles-daemon 配置文件信息
PPD_PROFILE=""; PPD_AVAIL=""
if command -v powerprofilesctl >/dev/null 2>&1; then
    # Use powerprofilesctl CLI tool (preferred method)
    # 使用 powerprofilesctl CLI 工具（首选方法）
    PPD_PROFILE=$(powerprofilesctl get 2>/dev/null)
    PPD_AVAIL=$(powerprofilesctl list 2>/dev/null | grep -oE '^\*?\s*(performance|balanced|power-saver):' | sed 's/[* :]//g' | tr '\n' ',' | sed 's/,$//')
    # Fallback to standard profiles if detection fails but service is running
    # 如果检测失败但服务正在运行，回退到标准配置文件
    [ -z "$PPD_AVAIL" ] && [ -n "$PPD_PROFILE" ] && PPD_AVAIL="power-saver,balanced,performance"
elif command -v gdbus >/dev/null 2>&1; then
    # Use D-Bus directly via gdbus (fallback method)
    # 通过 gdbus 直接使用 D-Bus（回退方法）
    PPD_PROFILE=$(gdbus call --system --dest net.hadess.PowerProfiles --object-path /net/hadess/PowerProfiles --method org.freedesktop.DBus.Properties.Get net.hadess.PowerProfiles ActiveProfile 2>/dev/null | grep -oE '(performance|balanced|power-saver)')
    PPD_AVAIL=$(gdbus call --system --dest net.hadess.PowerProfiles --object-path /net/hadess/PowerProfiles --method org.freedesktop.DBus.Properties.Get net.hadess.PowerProfiles Profiles 2>/dev/null | grep -oE '(performance|balanced|power-saver)' | sort -u | tr '\n' ',' | sed 's/,$//')
    # Fallback to standard profiles if detection fails but service is running
    # 如果检测失败但服务正在运行，回退到标准配置文件
    [ -z "$PPD_AVAIL" ] && [ -n "$PPD_PROFILE" ] && PPD_AVAIL="power-saver,balanced,performance"
fi

# TuneD profiles (tuned-adm) — use | separator since descriptions contain commas
# TuneD 配置文件（tuned-adm）— 使用 | 分隔符，因为描述包含逗号
TUNED_PROFILE=""; TUNED_AVAIL=""
if command -v tuned-adm >/dev/null 2>&1; then
    # Get currently active TuneD profile
    # 获取当前活动的 TuneD 配置文件
    TUNED_PROFILE=$(tuned-adm active 2>/dev/null | grep -oP 'Current active profile: \K.*' || true)
    # List all available TuneD profiles
    # 列出所有可用的 TuneD 配置文件
    TUNED_AVAIL=$(tuned-adm list 2>/dev/null | grep '^- ' | sed 's/^- //' | tr '\n' '|' | sed 's/|$//' || true)
fi

# Output all collected data as a JSON object
# 将所有收集的数据作为 JSON 对象输出
# This JSON is parsed by the QML executable DataSource in main.qml
# 此 JSON 由 main.qml 中的 QML executable DataSource 解析
echo "{\"battery_pct\": $PCT, \"power_watts\": $WATTS, \"charging\": $CHARGING, \"ac_online\": $AC_ON, \"status\": \"$STATUS\", \"time_to_empty\": \"$TTE\", \"time_to_full\": \"$TTF\", \"design_capacity\": $DCAP, \"full_capacity\": $FCAP, \"cycle_count\": $CYCLES, \"temp_celsius\": $TEMP, \"power_profile\": \"$PPD_PROFILE\", \"profiles_available\": \"$PPD_AVAIL\", \"tuned_profile\": \"$TUNED_PROFILE\", \"tuned_available\": \"$TUNED_AVAIL\"}"
