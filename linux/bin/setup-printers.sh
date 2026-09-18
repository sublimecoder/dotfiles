#!/usr/bin/env bash
set -euo pipefail

# Wires CUPS on a fresh Omarchy box for the two printers this setup uses:
#
#   1. Any AirPrint/IPP-Everywhere network printer (the Canon PIXMA TS4320).
#      DRIVERLESS -- no Canon package, no PPD download. A 2019-or-later inkjet
#      advertises "mopria-certified" + URF raster over mDNS and CUPS drives it
#      natively. Canon's proprietary Linux driver is strictly worse here.
#
#   2. A Yxwl-engine 4x6 thermal label printer over USB (sold as Labeer, Vevor,
#      and a dozen other badges; this one reports MODEL:Y812BT). Handled by
#      `lprint`, which is in Arch `extra/` and written by the CUPS author.
#
# NOT run by install.sh. Everything below needs root, and this repo's installer
# deliberately touches no system state -- same stance as the packages.txt block.
# Run it by hand, once per machine:  sudo linux/bin/setup-printers.sh
#
# Idempotent: re-running re-points existing queues rather than duplicating them.

[ "$(id -u)" -eq 0 ] || { echo "needs root: sudo $0" >&2; exit 1; }

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# The label printer's resolution. VERIFY THIS PER UNIT before trusting it: print
# a bar of exactly N dots and measure it. 203 was confirmed with a ruler on the
# Y812BT; the only Yxwl-family entry shipped in lprint (Vevor Y428BT) is 300dpi,
# so the family is genuinely mixed and guessing costs every label's scale.
LABEL_DPI="${LABEL_DPI:-203}"
LABEL_QUEUE="${LABEL_QUEUE:-Y812BT}"
LABEL_USB_ID="${LABEL_USB_ID:-5958:0130}"

need() { command -v "$1" >/dev/null || { echo "missing: $1 (see linux/packages.txt)" >&2; exit 1; }; }
need lpadmin
need avahi-browse

echo "== services =="
systemctl enable --now cups.service avahi-daemon.service

# mDNS resolution for .local printer hostnames. Omarchy ships nss-mdns wired,
# but a bare Arch install does not, and without it every ipp://*.local queue
# resolves to nothing with no useful error.
if ! grep -q 'mdns' /etc/nsswitch.conf; then
  echo "WARNING: /etc/nsswitch.conf has no mdns entry -- .local printer names will not resolve."
  echo "         Add 'mdns_minimal [NOTFOUND=return]' before 'resolve' in the hosts: line."
fi

echo
echo "== network printers (driverless IPP Everywhere) =="
# avahi-browse -p is the parseable form: fields are ;-separated and
# field 7=hostname 8=address 9=port 10=TXT record.
found_net=0
while IFS=';' read -r _ _ _ svc _ _ host _ port txt; do
  [ -n "${host:-}" ] || continue
  case "$host" in charizard.local|"$(hostname).local") continue ;; esac  # that's our own lprint

  # rp= is the IPP resource path; without it the URI is a guess.
  rp="$(printf '%s' "$txt" | tr ' ' '\n' | sed -n 's/^"rp=\(.*\)"$/\1/p' | head -1)"
  [ -n "$rp" ] || rp="ipp/print"

  # CUPS queue names allow no spaces, slashes or '#'.
  name="$(printf '%s' "$svc" | sed 's/\\032/_/g; s#[ /#]#_#g')"

  uri="ipp://${host}:${port}/${rp}"
  echo "-> $name  $uri"
  lpadmin -p "$name" -E -v "$uri" -m everywhere -D "$svc" || {
    echo "   FAILED (printer asleep or not IPP-Everywhere) -- skipping"; continue; }
  found_net=$((found_net + 1))
done < <(avahi-browse -prt _ipp._tcp 2>/dev/null | grep '^=' | grep ';IPv4;')
[ "$found_net" -gt 0 ] || echo "(none found -- printer powered off, or on another subnet)"

echo
echo "== USB label printer =="
if ! lsusb -d "$LABEL_USB_ID" >/dev/null 2>&1; then
  echo "(no $LABEL_USB_ID on USB -- skipping label printer)"
  exit 0
fi
need lprint

# lprint claims the USB device through libusb, which DETACHES the kernel usblp
# driver and deletes /dev/usb/lp0. That is expected. The trap it sets: writing
# to that path afterwards silently creates a REGULAR FILE and the job vanishes
# with no error anywhere. Drive the printer through lprint, never the node.
systemctl enable --now lprint.service
sleep 2

dev="$(lprint devices 2>/dev/null | grep '^usb://' | head -1)"
[ -n "$dev" ] || { echo "lprint sees no USB device -- is lprint.service up?" >&2; exit 1; }
echo "-> device $dev"
lprint add -d "$LABEL_QUEUE" -v "$dev" -m "tspl_${LABEL_DPI}dpi"

# Chromium (Brave) sends print-color-mode=color on EVERY job, even when CUPS
# truthfully advertises print-color-mode-supported=monochrome and
# color-supported=false. lprint is monochrome-only, so it rejects the job at
# Validate-Job, the ipp backend exits 5, and CUPS files it "canceled-at-device"
# -- nothing prints and nothing looks stuck. Verified NOT fixable from the
# browser (no B&W option in its dialog) or from the queue
# (print-color-mode-default is not honoured over an explicit client attribute).
#
# So CUPS talks to lprint through this shim instead of over IPP, and the shim
# pins monochrome. CUPS still renders the page exactly as before; only the
# transport changes.
install -m 755 -o root -g root "$REPO/linux/cups/lprint-backend" /usr/lib/cups/backend/lprint
systemctl restart cups.service
sleep 2
lpadmin -p "$LABEL_QUEUE" -E -v "lprint:/$LABEL_QUEUE" \
  -m everywhere -D "Yxwl $LABEL_QUEUE 4x6 label printer" \
  2>/dev/null || lpadmin -p "$LABEL_QUEUE" -E -v "lprint:/$LABEL_QUEUE"

echo
echo "== result =="
lpstat -v
echo
echo "Verify the label printer's scale before trusting it -- print a known-size"
echo "bar and measure it. If it is off, re-run with LABEL_DPI=300."
