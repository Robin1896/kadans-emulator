#!/usr/bin/env bash
# Een rondje door Kadans op een Android-emulator: installeren, openen, inloggen met het testaccount,
# langs de tabs, en van elk scherm een afbeelding plus de teksten die erop staan.
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
  echo "== $naam: $(grep -o 'text="[^"]\+"' "uit/$naam.xml" 2>/dev/null | sed 's/text="//;s/"$//' | head -25 | tr '\n' '|')"
}

# Tik op het eerste element met precies deze tekst (of content-desc). Geeft 1 terug als het er niet is.
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
adb shell pm grant $P android.permission.POST_NOTIFICATIONS 2>/dev/null
adb logcat -c
adb shell monkey -p $P -c android.intent.category.LAUNCHER 1 >/dev/null
sleep 25
foto start

# Inloggen met het testaccount als dat gevraagd wordt.
if tik "Inloggen" || tik "Log in"; then
  foto inloggen
  adb shell input tap 540 900; sleep 1
  for veld in "E-mailadres" "E-mail" "e-mail"; do tik "$veld" && break; done
  adb shell input text "noor@kadans.test"; sleep 1
  tik "Wachtwoord" || adb shell input keyevent 61
  adb shell input text "Kadans-testloper-2026"; sleep 1
  adb shell input keyevent 66; sleep 10
  foto na-inloggen
fi

for tab in Vandaag Plan Samen Jij; do tik "$tab" && foto "$tab"; done
tik "Lopen" && foto lopen
adb shell input keyevent 4; sleep 3

echo "== fouten in logcat:"
adb logcat -d | grep -E "FATAL EXCEPTION|AndroidRuntime|Capacitor/Console.*(Error|error)" | head -40 | tee uit/fouten.txt
adb shell dumpsys package $P | grep -m2 -E "versionName|versionCode"
