#!/bin/bash

set -e
before="$BEFORE_PORT_80_TCP_ADDR"
[[ $before =~ 'http' ]] || before="http://$before"

after="$AFTER_PORT_80_TCP_ADDR"
[[ $after =~ 'http' ]] || after="http://$after"

# Via http://stackoverflow.com/a/16496491/9621 and http://stackoverflow.com/a/18003735/9621
while getopts p: flag; do
  case $flag in
    p)
      PATHS_ARG="--paths-from-file=$OPTARG"
      ;;
  esac
done
shift $((OPTIND-1))

usage() { echo "Usage: $0 [-p <pathsFile.txt>]" 1>&2; exit 1; }
msg() { echo -e "\033[0;33m[docker_sitediff.sh] $1\033[00m"; }

msg "starting tests..."
[[ -z $BEFORE_URL ]] && BEFORE_URL=$before
[[ -z $AFTER_URL ]] && AFTER_URL=$after
bundle exec bin/sitediff diff \
  --before-url=$before --after-url=$after \
  --before-url-report=$BEFORE_URL --after-url-report=$AFTER_URL \
  $PATHS_ARG \
  --dump-dir=/var/sitediff/output \
  $@
