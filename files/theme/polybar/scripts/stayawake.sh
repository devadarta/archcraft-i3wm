#/bin/bash

# if pgrep -x "stayawake" > /dev/null; then
# Check if xfce4-power-manager are in presentation-mode
PRESENTATION=$(xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/presentation-mode)
if ($PRESENTATION = true); then
  echo " "
else
  echo "󰾫 "
fi
