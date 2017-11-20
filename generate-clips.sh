#!/bin/bash

OPTIONS="--voice Samantha --file-format WAVE --data-format=I16@16000" # --rate=250"

SOURCE="clips.txt"
TARGET="public/js/clips.js"
PROG=`basename $0`
TMPFILE=`mktemp /tmp/${PROG}.XXXXXX` || exit 1

echo "clips = [ ] ;" > "$TARGET"

while read clip ; do
  echo "${clip}"
  say -o "${TMPFILE}.wav" $OPTIONS "$clip"
  cat >>"$TARGET" <<END
clips.push({
  "label": "${clip}",
  "data": "$(base64 < ${TMPFILE}.wav)"
  });
END
  rm "${TMPFILE}.wav"
done < "$SOURCE"
