#!/bin/sh
# Shared configuration loader; source after establishing PROJECT_ROOT.
# All configuration files use default assignments (: "${NAME:=value}").
# Load in descending priority so existing nonempty values are preserved.
# Environment > personal XDG > LET global > repository > built-in fallbacks.

if [ ! -f "$PROJECT_ROOT/site.conf" ]; then
  printf 'missing config file: %s\n' "$PROJECT_ROOT/site.conf" >&2
  exit 1
fi

case "${XDG_CONFIG_HOME:-}" in
  /*) website_config_home=$XDG_CONFIG_HOME ;;
  *)
    if [ -n "${HOME:-}" ]; then
      website_config_home=$HOME/.config
    else
      website_config_home=
    fi
    ;;
esac

if [ -n "$website_config_home" ] &&
   [ -f "$website_config_home/lunar-website/site.conf" ]; then
  # shellcheck disable=SC1090
  . "$website_config_home/lunar-website/site.conf"
fi

if [ -f /etc/let/lunar-website/site.conf ]; then
  . /etc/let/lunar-website/site.conf
fi

# Repository-owned portable defaults; required for standalone use.
# shellcheck disable=SC1090
. "$PROJECT_ROOT/site.conf"
unset website_config_home
