#!/system/bin/sh

# Cancel a delayed Goodix recovery if the panel was blanked again before the
# post-unblank worker reached its reset point.
rm -f /tmp/rothko_touch_unblank.token

exit 0
