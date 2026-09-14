#!/system/bin/sh

TOKEN_FILE=/tmp/rothko_touch_unblank.token
RESET_NODE=/sys/devices/platform/goodix_ts.0/reset
RAW_NODE=/sys/devices/virtual/touch/touch_dev/enable_touch_raw
BRIGHTNESS_NODE=/sys/class/leds/lcd-backlight/brightness
LOG_FILE=/tmp/recovery.log

log_msg() {
    local message="ROTHKO_TOUCH_RESUME: $*"
    echo "$message" >> "$LOG_FILE"
    echo "$message" > /dev/kmsg 2>/dev/null || true
}

# The DRM atomic unblank returns before the asynchronous MTK display notifier
# has completely settled the panel and Goodix resume path. Give that path time
# to finish, then issue the driver's own hardware reset after the rails and SPI
# bus are stable. A token prevents a stale worker from resetting while blanked.
token="$(cat /proc/uptime 2>/dev/null)"
if [ -z "$token" ] || ! printf '%s\n' "$token" > "$TOKEN_FILE"; then
    log_msg "unable to create unblank token"
    exit 0
fi

(
    sleep 1

    current_token="$(cat "$TOKEN_FILE" 2>/dev/null)"
    [ "$current_token" = "$token" ] || exit 0

    if [ -r "$BRIGHTNESS_NODE" ]; then
        brightness="$(cat "$BRIGHTNESS_NODE" 2>/dev/null)"
        if ! [ "$brightness" -gt 0 ] 2>/dev/null; then
            log_msg "skip reset because panel brightness is still zero"
            exit 0
        fi
    fi

    if [ ! -w "$RESET_NODE" ]; then
        log_msg "Goodix reset node is unavailable; no recovery action needed"
        rm -f "$TOKEN_FILE"
        exit 0
    fi

    if echo 1 > "$RESET_NODE"; then
        if [ -w "$RAW_NODE" ]; then
            echo 0 > "$RAW_NODE" || log_msg "failed to restore touch raw mode"
        fi
        log_msg "delayed Goodix hardware reset completed"
    else
        log_msg "delayed Goodix hardware reset failed"
    fi

    current_token="$(cat "$TOKEN_FILE" 2>/dev/null)"
    [ "$current_token" = "$token" ] && rm -f "$TOKEN_FILE"
) &

exit 0
