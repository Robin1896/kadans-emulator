#!/usr/bin/env bash
# Een rondje door Kadans op een Android-emulator: installeren, de telefoon op Nederlands, openen,
# langs de tabs en een paar schermen, en van elk scherm een afbeelding plus de teksten die erop staan.
set -u
mkdir -p uit
P=nl.kadans.app
n=0

foto() {
  n=$((n + 1))
  local naam=$(printf '%02d-%s' "$n" "$1")
  adb exec-out screencap -p > "uit/$naam.png"
  adb shell uiautomator dump /sdcard/s.xml >/dev/null 2>&1
  adb pull /sdcard/s.xml "uit/$naam.xml" >/dev/null 2>&1
  echo "== $naam: $(grep -o 'text="[^"]\+"' "uit/$naam.xml" 2>/dev/null | sed 's/text="//;s/"$//' | head -30 | tr '\n' '|')"
}

# Tik op het eerste element met precies deze tekst (of content-desc). Geeft 1 terug als het er niet is.
tik() {
  adb shell uiautomator dump /sdcard/s.xml >/dev/null 2>&1
  adb pull /sdcard/s.xml /tmp/s.xml >/dev/null 2>&1
  local b=$(grep -o "<node[^>]*\(text\|content-desc\)=\"$1\"[^>]*>" /tmp/s.xml | head -1 | grep -o 'bounds="[^"]*"' | grep -o '[0-9]\+')
  [ -z "$b" ] && { echo "   (niet gevonden: $1)"; return 1; }
  set -- $b
  adb shell input tap $(( ($1 + $3) / 2 )) $(( ($2 + $4) / 2 ))
  sleep "${WACHT:-5}"
}

veeg() { adb shell input swipe 540 1700 540 600 300; sleep 2; }

adb install -r -g Kadans.apk || exit 1
adb shell pm grant $P android.permission.ACCESS_FINE_LOCATION 2>/dev/null
adb shell pm grant $P android.permission.POST_NOTIFICATIONS 2>/dev/null
# Kadans in het Nederlands, via de taal per app (Android 13 en nieuwer).
adb shell cmd locale set-app-locales $P --user 0 --locales nl-NL || echo "   (taal per app lukte niet)"
adb logcat -c
adb shell monkey -p $P -c android.intent.category.LAUNCHER 1 >/dev/null
sleep 25
foto vandaag

tik "Plan" && foto plan && veeg && foto plan-onder
tik "Logboek" && foto logboek
tik "Samen" && foto samen
tik "Vandaag" && tik "Start" && foto lopen-klaar
adb shell input keyevent 4; sleep 3
foto terug

echo "== fouten in logcat:"
adb logcat -d | grep -E "FATAL EXCEPTION|AndroidRuntime|Capacitor/Console.*(Error|error)|chromium.*Uncaught" | head -40 | tee uit/fouten.txt
adb shell dumpsys package $P | grep -m2 -E "versionName|versionCode"
