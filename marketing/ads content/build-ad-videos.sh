#!/usr/bin/env bash
# Cut the 58s launch film down to the lengths a Google App campaign wants
# (10-30s), in all three orientations Google serves.
#
#   node build-video-plates.mjs && ./build-ad-videos.sh
#
# WHY THESE CUT POINTS: the film's score runs at 96 BPM, so one bar is 2.5s and
# every cue in the film is snapped to that grid. Every in/out point below is a
# multiple of 2.5s, which is the difference between a cut that sounds like an
# edit and one that sounds like a mistake. Sections, for reference:
#
#   0:00-0:11  SMS rain -> "Your bank texts you everything" -> "But who's counting?"
#   0:12-0:19  parsing: "Budgetify is." + Swiggy/Uber/Salary rows
#   0:20-0:29  monthly ring, category budgets, heatmap, net worth
#   0:30-0:37  game layer: 47-day streak, reward road, royals
#   0:38-0:41  six languages
#   0:42-0:51  privacy proof: cloud struck out, airplane mode, "0 trackers"
#   0:52-0:58  logo end card + "Get it free on Google Play"
#
# THE THREE CUTS
#   30s          problem -> product -> privacy -> CTA
#   15s          problem -> product -> CTA
#   privacy-15s  42.5-57.5 straight through -- privacy proof into the end card.
#                One continuous segment, so it has NO seams at all, and it is
#                the cut aimed at installs that stay rather than installs that
#                are cheap.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$HERE/video"
PLATES="$HERE/plates"
mkdir -p "$OUT"

# ffmpeg-static is installed under the git-ignored render dir in the MAIN repo
# checkout, so a worktree has to reach across to it. Fall back to a PATH ffmpeg.
FF=""
for cand in \
  "$HERE/../.render/node_modules/ffmpeg-static/ffmpeg" \
  "$HOME/AndroidStudioProjects/budget_tracker/marketing/.render/node_modules/ffmpeg-static/ffmpeg" \
  "$(command -v ffmpeg || true)"; do
  if [ -n "$cand" ] && [ -x "$cand" ]; then FF="$cand"; break; fi
done
[ -n "$FF" ] || { echo "no ffmpeg found (npm i ffmpeg-static in marketing/.render)"; exit 1; }

SRC=""
for cand in \
  "$HERE/../budgetify-launch-film-60fps.mp4" \
  "$HOME/AndroidStudioProjects/budget_tracker/marketing/budgetify-launch-film-60fps.mp4" \
  "$HOME/Desktop/budgetify-launch-film.mp4"; do
  if [ -f "$cand" ]; then SRC="$cand"; break; fi
done
[ -n "$SRC" ] || { echo "launch film not found"; exit 1; }

echo "ffmpeg: $FF"
echo "source: $SRC"

# The film's ground, sampled from the master, used to pad the square variant so
# the bars read as part of the film rather than as black bars.
INK="#0b0e18"

# Video slot inside the 16:9 plates. MUST match SLOT_* in build-video-plates.mjs.
SLOT_W=552
SLOT_H=980
SLOT_X=1208
SLOT_Y=50

ENC=(-c:v libx264 -preset slow -crf 19 -pix_fmt yuv420p -r 60
     -c:a aac -b:a 192k -movflags +faststart)

# cut <name> <plate> <seg=start:end> [seg...]
# Hard video cuts (the film cuts that way itself) with a 0.12s audio fade at
# each seam, which kills the click without smearing the beat.
cut() {
  local name="$1" plate="$2"; shift 2
  local segs=("$@")
  local n=${#segs[@]}
  local fc="" maps="" i=0
  for seg in "${segs[@]}"; do
    local s="${seg%%:*}" e="${seg##*:}" d
    d=$(echo "$e - $s" | bc -l)
    fc+="[0:v]trim=${s}:${e},setpts=PTS-STARTPTS[v${i}];"
    fc+="[0:a]atrim=${s}:${e},asetpts=PTS-STARTPTS,"
    fc+="afade=t=in:st=0:d=0.12,afade=t=out:st=$(echo "$d - 0.12" | bc -l):d=0.12[a${i}];"
    maps+="[v${i}][a${i}]"
    i=$((i + 1))
  done
  fc+="${maps}concat=n=${n}:v=1:a=1[v][a]"

  # 9:16 native -- the ratio the film was designed and rendered in.
  "$FF" -hide_banner -loglevel error -y -i "$SRC" \
    -filter_complex "$fc" -map "[v]" -map "[a]" "${ENC[@]}" \
    "$OUT/${name}-9x16.mp4"
  echo "  ${name}-9x16.mp4"

  # 1:1 -- scaled to fit and padded onto the film's own ground. A reframe, not
  # a re-render: a centre crop would cut the captions, which sit low in almost
  # every beat.
  "$FF" -hide_banner -loglevel error -y -i "$SRC" \
    -filter_complex "${fc};[v]scale=608:1080,pad=1080:1080:236:0:color=${INK}[vs]" \
    -map "[vs]" -map "[a]" "${ENC[@]}" \
    "$OUT/${name}-1x1.mp4"
  echo "  ${name}-1x1.mp4"

  # 16:9 -- the untouched 9:16 cut composited into a designed landscape frame.
  # Without this the campaign cannot serve on YouTube in-stream at all.
  "$FF" -hide_banner -loglevel error -y \
    -loop 1 -i "$PLATES/plate-${plate}.png" -i "$OUT/${name}-9x16.mp4" \
    -filter_complex "[1:v]scale=${SLOT_W}:${SLOT_H}[v];[0:v][v]overlay=${SLOT_X}:${SLOT_Y}[out]" \
    -map "[out]" -map 1:a -shortest "${ENC[@]}" \
    "$OUT/${name}-16x9.mp4"
  echo "  ${name}-16x9.mp4"
}

echo "30s: problem -> product -> privacy -> CTA"
cut budgetify-30s product 0:17.5 42.5:50 52.5:57.5

echo "15s: problem -> product -> CTA"
cut budgetify-15s product 0:5 12.5:17.5 52.5:57.5

echo "privacy-15s: privacy proof -> CTA, one continuous segment"
cut budgetify-privacy-15s privacy 42.5:57.5

echo
for f in "$OUT"/*.mp4; do
  printf '%-40s %-11s %s\n' "$(basename "$f")" \
    "$("$FF" -hide_banner -i "$f" 2>&1 | grep -o '[0-9]\{3,\}x[0-9]\{3,\}' | head -1)" \
    "$("$FF" -hide_banner -i "$f" 2>&1 | awk -F, '/Duration/{print $1}' | awk '{print $2}')"
done
