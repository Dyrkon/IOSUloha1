#!/bin/sh

export POSIXLY_CORRECT=yes
export LC_NUMERIC=en_US.UTF-8

COMMANDS=""
LOG_FILES=""
GZ_LOG_FILES="gunzip -c"
READ_INPUT=""
TICKERS=""
A_DATETIME=" "
B_DATETIME="9999-99-99 99:99:99"
WIDTH=""

printf_help() {
  echo "Usage: tradelog [-h | --help]"
  echo "       tradelog [FILTR] [PŘÍKAZ] [LOG [LOG2 [...]]"
  printf "\n"

  echo "COMMANDS:"
  echo "list-tick:    Prints list of available tickers"
  echo "profit:       Prints total profit of closed positions"
  echo "pos:          Prints values of currently held positions sorted by the value in descending order"
  echo "last-price:   Prints last known prices for every ticker"
  echo "hist-ord:     Prints histogram of count of number of transactions according to ticker"
  echo "graph-pos:    Prints graph of values held according to ticker"
  printf "\n"

  echo "FILTERS:"
  echo "-a DATETIME:  Filters out entries AFTER specified date (excluding entered date) in format [ YYYY-MM-DD HH:MM:SS ]"
  echo "-b DATETIME:  Filters out entries BEFORE specified date (excluding entered date) in format [ YYYY-MM-DD HH:MM:SS ]"
  echo "-t TICKER:    Filters out entries with MATCHING TICKER. If more TICKERS are specified they all will be filtered out"
  echo "-w WIDTH:     Sets WIDTH for graph to be printed. The specified WIDTH must be the length of longest row. \n
                        More than one WIDTH switches specified or the value of WIDTH being less than zero or float point \n
                        number will result in error"
  printf "\n"

  echo "  HELP"
  echo "-h or --help: Prints short description of every command and switch"
}

list_tick() {
  echo "$TICKERS" | tr -s ', ' '\n'
}

profit() {
  OUT=$(echo "$FILTERED_INPUT" | awk -F ';' '{
   if ($3 == "sell")
     { v_sell += $4 * $6 }
   else if ($3 == "buy")
     { v_buy+= $4 * $6 } }
   END { printf "%.2f", v_sell - v_buy }')
  echo "$OUT"
}

pos() {
  for TICK in $TICKERS; do
    OUT=$(echo "$FILTERED_INPUT" | awk -F ';' -v tick="$TICK" '{
      if ($3 == "sell" && $2 == tick)
      {
        v_sell += $6
        price=$4
      }
      else if ($3 == "buy" && $2 == tick)
      {
        v_buy += $6
        price=$4
      } }
      END { printf "%s:%.2f\n", tick,(v_buy - v_sell)*price }')
    PRINT=$(echo "$PRINT $OUT" | awk -F " " '{ printf "%s\n%s", $1, $2 }')
  done
  PRINT=$(echo "$PRINT" | sort -t ":" -k2,2 -nr)

  LENGTH=$(echo "$PRINT" | awk -F ":" '{
    if (length($2) > max)
    {
      max = length($2)
    } }
  END { printf "%d", max }')
  PRINT=$(echo "$PRINT" | awk -v lng="$LENGTH" -F ":" '{ printf "%-9s : %*.2f\n", $1, lng, $2 }')
  echo "$PRINT"
}

last_price() {
  LENGTH=$(echo "$FILTERED_INPUT" | awk -F ";" 'BEGIN{max_lngth = 0}
  {
    if (max_lngth < length($4))
    { max_lngth = length($4) } }
    END { print max_lngth }')
  for TICK in $TICKERS; do
    OUT=$(echo "$FILTERED_INPUT" | awk -F ";" -v m_length="$LENGTH" -v tick="$TICK" '{
      if ($2 == tick)
        { price=$4 } }
      END { printf "%-9s : %*.2f", tick, m_length, price }')
    echo "$OUT"
  done
}

hist_ord() {
  if [ z"$WIDTH" = z"" ]; then
    for TICK in $TICKERS; do
      TRANSACTIONS=$(echo "$FILTERED_INPUT" | awk -F ";" -v tick="$TICK" '$2 == tick {sum += 1} END {print sum}')
      HASHTAGS=$(echo "" | awk -v count="$TRANSACTIONS" 'BEGIN{for(i=0;i<count;i++) printf "#"}')
      OUTPUT=$(echo "$TRANSACTIONS" | awk -v tick="$TICK" -v tags="$HASHTAGS" '{
        if (tags == "")
          { printf "%-9s :", tick }
        else
          { printf "%-9s : %s", tick, tags }
       }')
      echo "$OUTPUT"
    done

  else
    LONGEST="0"
    for TICK in $TICKERS; do
      LONGEST=$(echo "$FILTERED_INPUT" | awk -F ";" -v longest="$LONGEST" -v tick="$TICK" '{
      if ($2 == tick) { sum += 1 }
      if (sum > longest) { longest = sum } }
      END { { printf "%d",longest } } ')
    done

    DIVIDER=$(echo "" | awk -v longest="$LONGEST" -v width="$WIDTH" '{ printf "%f", longest/width }')
    TAGS=$(echo "" | awk -v count="$LONGEST" 'BEGIN{for(i=0;i<count;i++) printf "#"}')

    for TICK in $TICKERS; do
      COUNT=$(echo "$FILTERED_INPUT" | awk -F ";" -v tick="$TICK" -v div="$DIVIDER" '$2 == tick {sum += 1} END {printf "%d", sum/div }' | tail -n1)
      OUTPUT=$(echo "" | awk -F ";" -v tick="$TICK" -v width="$COUNT" -v tags="$TAGS" '{
       if (width == 0)
          { printf "%-9s :", tick }
        else
          { printf "%-9s : %.*s", tick, width, tags }
       }')
      echo "$OUTPUT"
    done
  fi
}

graph_pos() {
  if [ z"$WIDTH" = z"" ]; then
    WIDTH="1000"
  else
    WIDTH="$WIDTH"
  fi

  for TICK in $TICKERS; do
    OUT=$(echo "$FILTERED_INPUT" | awk -F ';' -v tick="$TICK" '{
        if ($3 == "sell" && $2 == tick)
        {
          v_sell += $6
          price=$4
        }
        else if ($3 == "buy" && $2 == tick)
        {
          v_buy += $6
          price=$4
        } }
        END { printf "%s:%.2f\n", tick,(v_buy - v_sell)*price }')
    PRINT=$(echo "$PRINT $OUT" | awk -F " " '{ printf "%s\n%s", $1, $2 }')
  done

  PRINT=$(echo "$PRINT" | sort -t ":" -k2,2 -nr)

  DIV=$(echo "$PRINT" | awk -F ":" -v width="$WIDTH" '
    function abs(x)
    {
      return ((x < 0.0) ? -x : x)
    }
    {
      if (abs($2) > max)
      {
        max = abs($2)
      }
    }
    END { printf "%d", max/width }')

  TAGS_PLUS=$(echo "" | awk -v count="$WIDTH" 'BEGIN{ for(i=0; i<count; i++) printf "#" }')
  TAGS_MINUS=$(echo "" | awk -v count="$WIDTH" 'BEGIN{ for(i=0; i<count; i++) printf "!" }')

  PRINT=$(echo "$PRINT" | sort -t ":" -k1,1)

  PRINT=$(echo "$PRINT" | awk -v tagminus="$TAGS_MINUS" -v tagplus="$TAGS_PLUS" -v div="$DIV" -F ":" '
    function abs(x)
    {
      return ((x < 0.0) ? -x : x)
    }

    {
      s_width = $2/div

      if (s_width >= 1)
      { printf "%-9s : %.*s\n", $1, abs(s_width), tagplus }
      else if (s_width <= -1)
      { printf "%-9s : %.*s\n", $1, abs(s_width), tagminus }
      else
      { printf "%-9s :\n", $1 }
    }')
  echo "$PRINT"

}

while [ "$#" -gt 0 ]; do
  case $1 in
  list-tick | pos | profit | last-price | hist-ord | graph-pos)
    COMMANDS="$1 $COMMANDS"
    shift
    ;;
  -h)
    printf_help
    exit 0
    ;;
  -w)
    WIDTH="$2"
    shift
    shift
    ;;
  -a)
    A_DATETIME="$2"
    shift
    shift
    ;;
  -b)
    B_DATETIME="$2"
    shift
    shift
    ;;
  -t)
    TICKERS="$2 $TICKERS"
    shift
    shift
    ;;
  *.gz)
    GZ_LOG_FILES="$GZ_LOG_FILES $1"
    shift
    ;;
  *.log)
    LOG_FILES="$LOG_FILES $1"
    shift
    ;;
  esac
done

if [ -z "$LOG_FILES" ] && [ z"$GZ_LOG_FILES" = z"gunzip -c" ]; then
  READ_INPUT=$(cat)
elif [ z"$GZ_LOG_FILES" != z"gunzip -c" ] && [ -z "$LOG_FILES" ]; then
  READ_INPUT=$(eval "$GZ_LOG_FILES")
elif [ z"$GZ_LOG_FILES" != z"gunzip -c" ] && [ z"$LOG_FILES" != z"" ]; then
  GZ=$($GZ_LOG_FILES)
  LOG_FILES=$(echo "$LOG_FILES" | cut -c 2-)
  LG=$(cat "$LOG_FILES")
  READ_INPUT="$LG$GZ"
else
  LOG_FILES=$(echo "$LOG_FILES" | cut -c 2-)
  READ_INPUT=$(cat "$LOG_FILES")
fi

READ_INPUT=$(echo "$READ_INPUT" | sort -t ";" -k1,1)

if [ z"$LOG_FILES" = z"" ] && [ z"$COMMANDS" = z"" ] && [ z"$WIDTH" = z"" ] && [ z"$GZ_LOG_FILES" = z"gunzip -c" ] && [ z"$A_DATETIME" = z" " ]; then
  OUT=$(eval "$READ_INPUT" | awk '{ print }')
  echo "$OUT"
  exit
fi

if [ "$TICKERS" = "" ] && [ z"$READ_INPUT" != z"cat" ]; then
  FILTERED_INPUT=$(echo "$READ_INPUT" | awk -F ";" -v btime="$B_DATETIME" -v atime="$A_DATETIME" '{ if ($1 < btime && $1 > atime) print }')
  TICKERS=$(echo "$FILTERED_INPUT" | sort -t ";" -k2,2 -u | awk -F ";" '{ print $2 }')
elif [ "$TICKERS" = "" ] && [ z"$READ_INPUT" = z"cat" ]; then
  FILTERED_INPUT=$(echo "$READ_INPUT" | awk -F ";" -v btime="$B_DATETIME" -v atime="$A_DATETIME" '{ if ($1 < btime && $1 > atime) print }')
  TICKERS=$(echo "$FILTERED_INPUT" | sort -t ";" -k2,2 -u | awk -F ";" '{ print $2 }')
else
  FILTERED_INPUT=$(echo "$READ_INPUT" | awk -F ";" -v tickers="$TICKERS" -v btime="$B_DATETIME" -v atime="$A_DATETIME" '
    { len=split(tickers,list," ") }
    {
      for (i = 1; i <= len; i++)
      {
        if (list[i] == $2 && $1 < btime && $1 > atime)
          { print }
      }
    }
  ')
fi

case "$COMMANDS" in
*graph-pos*)
  graph_pos
  ;;
*hist-ord*)
  hist_ord
  ;;
*last-price*)
  last_price
  ;;
*list-tick*)
  list_tick
  ;;
*profit*)
  profit
  ;;
*pos*)
  pos
  ;;
*)
  echo "$FILTERED_INPUT"
  ;;
esac
