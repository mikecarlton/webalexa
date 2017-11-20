#!/bin/bash

OPTIONS="--voice Samantha --file-format WAVE --data-format=I16@16000" # --rate=250"

SOURCE="clips.txt"
TARGET="public/js/clips.js"
PROG=`basename $0`
TMPFILE=`mktemp /tmp/${PROG}.XXXXXX` || exit 1

# file must be valid json after removing "clips = "
echo "clips = [" > "$TARGET"

first=t
while read clip ; do
  echo "${clip}"
  say -o "${TMPFILE}.wav" $OPTIONS "$clip"
  if [ -z "$first" ] ; then
    echo -n ", " >> $TARGET
  fi
  first=""
  cat >>"$TARGET" <<END
{
  "label": "${clip}",
  "data": "$(base64 < ${TMPFILE}.wav)"
}
END
  rm "${TMPFILE}.wav"
done < "$SOURCE"

echo "]" >> "$TARGET"
