#!/bin/bash
shopt -s nullglob  # ensures loop doesn't break if no files found

folder="."
details_mode=false
error_only=false
save_file=""

# --- Colors (ANSI escape codes) ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'  # No Color

# --- Parse Arguments ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --details)
      details_mode=true
      shift
      ;;
    --error-only)
      error_only=true
      shift
      ;;
    --save)
      save_file="$2"
      shift 2
      ;;
    --help)
      echo
      echo "🎬 VIDEO CHECK REPORT TOOL"
      echo "------------------------------------------------------------"
      echo "Usage: $0 [options]"
      echo
      echo "Options:"
      echo "  --details         Show FPS, Duration, Codecs, and Size for each file"
      echo "  --error-only      Display only videos that have corruption or errors"
      echo "  --save <file>     Save the full scan report to a file (colors disabled)"
      echo "  --help            Show this help message"
      echo
      echo "Examples:"
      echo "  $0                          → Run basic scan"
      echo "  $0 --details                → Detailed mode"
      echo "  $0 --error-only             → Show only problematic videos"
      echo "  $0 --details --save report.txt → Save detailed report"
      echo
      echo "------------------------------------------------------------"
      echo "Note: Requires ffmpeg and ffprobe to be installed."
      exit 0
      ;;
    *)
      echo "❌ Unknown option: $1"
      echo "Use --help for usage information."
      exit 1
      ;;
  esac
done

# --- If saving, disable colors ---
if [ -n "$save_file" ]; then
  RED='' ; GREEN='' ; YELLOW='' ; NC=''
  exec > >(tee "$save_file") 2>&1
  echo "📁 Saving report to: $save_file"
  echo "Generated on: $(date)"
  echo "------------------------------------------------------------"
fi

# --- Header ---
echo
echo "🎬 VIDEO CHECK REPORT"
if [ "$details_mode" = false ]; then
  printf "%-4s | %-40s | %-12s | %-25s | %-10s | %-35s\n" "No." "Filename" "Resolution" "Title" "Status" "Error"
  printf -- "------------------------------------------------------------------------------------------------------------------------------\n"
else
  printf "%-4s | %-25s | %-10s | %-8s | %-7s | %-8s | %-8s | %-10s | %-35s\n" \
    "No." "Filename" "Res" "FPS" "Dur(s)" "VCodec" "ACodec" "Status" "Error"
  printf -- "---------------------------------------------------------------------------------------------------------------------------------\n"
fi

# --- Main Loop ---
count=1
for f in "$folder"/*.{mp4,mkv,mov,avi,flv,wmv}; do
  [ -e "$f" ] || continue

  filename=$(basename "$f")

  # --- Resolution ---
  res=$(ffprobe -v error -select_streams v:0 \
        -show_entries stream=width,height \
        -of csv=s=x:p=0 "$f" 2>/dev/null | head -n 1 | tr -d '\r\n')
  [ -z "$res" ] && res="${YELLOW}Unknown${NC}"

  # --- Title ---
  title=$(ffprobe -v error -show_entries format_tags=title \
          -of default=nw=1:nk=1 "$f" 2>/dev/null | head -n 1 | tr -d '\r\n')
  [ -z "$title" ] && title="${filename%.*}"

  # --- Error Detection ---
  tmpfile=$(mktemp)
  ffmpeg -v error -i "$f" -f null - 2>"$tmpfile"
  if [ -s "$tmpfile" ]; then
    status="${RED}Problem${NC}"
    error_msg=$(head -n 2 "$tmpfile" | tr -d '\r' | tr '\n' ' ' | cut -c -35)
    [ -z "$error_msg" ] && error_msg="Unknown error"
  else
    status="${GREEN}OK${NC}"
    error_msg="None"
  fi
  rm -f "$tmpfile"

  # --- Skip OK files if --error-only ---
  if [ "$error_only" = true ] && [[ "$status" == *OK* ]]; then
    continue
  fi

  # --- Truncate long fields to prevent column break ---
  short_filename=$(printf "%.25s" "$filename")
  short_title=$(printf "%.25s" "$title")
  short_error=$(printf "%.35s" "$error_msg")

  # --- Details Mode ---
  if [ "$details_mode" = true ]; then
    fps=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate \
          -of default=noprint_wrappers=1:nokey=1 "$f" | head -n 1)
    fps=$(awk "BEGIN {if ('$fps' ~ /[0-9]+\/[0-9]+/) split('$fps',a,\"/\"); if (a[2]>0) print a[1]/a[2]; else print '$fps';}")

    duration=$(ffprobe -v error -show_entries format=duration \
              -of default=noprint_wrappers=1:nokey=1 "$f" | awk '{printf \"%.1f\", $1}')

    vcodec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name \
              -of default=noprint_wrappers=1:nokey=1 "$f" | head -n 1)
    acodec=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name \
              -of default=noprint_wrappers=1:nokey=1 "$f" | head -n 1)

    printf "%-4s | %-25.25s | %-10s | %-8s | %-7s | %-8s | %-8s | %-10s | %-35.35s\n" \
      "$count" "$short_filename" "$res" "${fps:-?}" "${duration:-?}" "${vcodec:-?}" "${acodec:-?}" "$status" "$short_error"
  else
    printf "%-4s | %-40.40s | %-12s | %-25.25s | %-10s | %-35.35s\n" \
      "$count" "$short_filename" "$res" "$short_title" "$status" "$short_error"
  fi

  count=$((count + 1))
done

# --- Footer ---
if [ "$details_mode" = false ]; then
  printf -- "------------------------------------------------------------------------------------------------------------------------------\n"
else
  printf -- "---------------------------------------------------------------------------------------------------------------------------------\n"
fi
echo -e "✅ Scan complete!"
if [ -n "$save_file" ]; then
  echo "📄 Report saved to: $save_file"
fi
