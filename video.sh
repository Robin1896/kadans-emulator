#!/usr/bin/env bash
# Schermopname voor Google Play (verklaring voorgrondservice, type locatie):
# training starten, melding tonen, scherm uit en aan, training stoppen.
set -u
mkdir -p uit
P=nl.kadans.app

tik() {
  adb shell uiautomator dump /sdcard/s.xml >/dev/null 2>&1
  adb pull /sdcard/s.xml /tmp/s.xml >/dev/null 2>&1
  local b=$(grep -o "<node[^>]*\(text\|content-desc\)=\"$1\"[^>]*>" /tmp/s.xml | head -1 | grep -o 'bounds="[^"]*"' | grep -o '[0-9]\+')
  [ -z "$b" ] && { echo "   (niet gevonden: $1)"; return 1; }
  set -- $b
  adb shell input tap $(( ($1 + $3) / 2 )) $(( ($2 + $4) / 2 ))
  sleep "${WACHT:-4}"
}

adb install -r -g Kadans.apk || exit 1
adb shell pm grant $P android.permission.ACCESS_FINE_LOCATION 2>/dev/null
adb shell pm grant $P android.permission.ACCESS_COARSE_LOCATION 2>/dev/null
adb shell pm grant $P android.permission.POST_NOTIFICATIONS 2>/dev/null
adb shell cmd locale set-app-locales $P --user 0 --locales nl-NL || true
adb shell settings put secure location_mode 3 || true
adb emu geo fix 5.1376 51.4859 || true
adb shell monkey -p $P -c android.intent.category.LAUNCHER 1 >/dev/null
sleep 25

# opname starten (schermopname stopt zelf na 150 s)
adb shell "screenrecord --time-limit 150 --size 720x1560 /sdcard/video.mp4" &
REC=$!
sleep 3

tik "Vandaag" || true
tik "Start" || true
sleep 3
tik "Start" || true
sleep 8
adb exec-out screencap -p > uit/lopen-1.png
adb shell uiautomator dump /sdcard/l.xml >/dev/null 2>&1; adb pull /sdcard/l.xml uit/lopen-1.xml >/dev/null 2>&1
echo "teksten: $(grep -o "text=\"[^\"]+\"" uit/lopen-1.xml | tr "
" "|")"
# de GPS laten bewegen zodat tijd en afstand oplopen
for i in 1 2 3 4 5 6 7 8; do
  adb emu geo fix $(echo "5.1376 + 0.0004*$i" | bc -l) 51.4859 || true
  sleep 2
done

# melding laten zien
adb shell cmd statusbar expand-notifications
sleep 6
adb shell dumpsys notification --noredact | grep -E "pkg=$P|Training|foreground" | head -10 | tee uit/melding.txt
adb shell cmd statusbar collapse
sleep 3

# scherm uit en weer aan, de training loopt door
adb shell input keyevent 26
sleep 8
adb shell input keyevent 26
sleep 2
adb shell input swipe 540 1800 540 600 300
sleep 4
for i in 9 10 11 12 13 14 15 16; do
  adb emu geo fix $(echo "5.1376 + 0.0004*$i" | bc -l) 51.4859 || true
  sleep 2
done
adb exec-out screencap -p > uit/na-scherm-aan.png
adb shell uiautomator dump /sdcard/l.xml >/dev/null 2>&1; adb pull /sdcard/l.xml uit/na-scherm-aan.xml >/dev/null 2>&1
echo "teksten2: $(grep -o "text=\"[^\"]+\"" uit/na-scherm-aan.xml | tr "
" "|")"

# stoppen
tik "Stop" || tik "Pauze" || true
sleep 4
adb exec-out screencap -p > uit/na-stop.png
wait $REC 2>/dev/null
sleep 2
adb pull /sdcard/video.mp4 uit/kadans-training.mp4 || echo "geen video"
adb shell dumpsys activity services $P | grep -i -E "foregroundServiceType|isForeground" | head -5 | tee uit/service.txt
ls -la uit
