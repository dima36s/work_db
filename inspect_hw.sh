#!/bin/bash
################################################################################
# Collects basic hardware information on Linux workstations.
# Tested on Debian 6, 8, CentOS 6.5, works fine without installing additional packets.
# Needs root privilegies (for dmidecode and hdparm)
# Version: 1.2.0 (2015-12-03)
################################################################################

# Check if user is root
#[[ $UID -ne 0 ]] && { echo "Must be run as root!"; exit 1; }

################################################################################
## Collecting info
info_user=$(users | sed -e "s/ *root //g" | cut -d " " -f1)

# Motherboard
# info_motherboard=$(dmidecode | sed -n "/Base Board/,/Handle/p" | grep -E "Manufacturer|Product Name" \
#   | sed -e "s/.*: //" -e "s/ASUSTe.*/ASUS/" -e "s/Gigabyte Te.*/Gigabyte/" -e "s/Intel Co.*/Intel/" \
#   | sed ':a;N;$!ba;s/\n/ /g')

info_motherboard=$(/usr/sbin/dmidecode | sed -n "/Base Board/,/Handle/p" | grep -E "Manufacturer|Product Name" \
  | sed -e "s/.*: //" -e "s/ASUSTe.*/ASUS/" -e "s/Gigabyte Te.*/Gigabyte/" -e "s/Intel Co.*/Intel/" \
  | sed ':a;N;$!ba;s/\n/ /g')


# CPU
info_cpu_threads=$(grep -c "processor" /proc/cpuinfo)
info_cpu=$(cat /proc/cpuinfo | grep -m 1 "model name" \
| sed -e "s/.*: //" -e "s/(TM)//g" -e "s/(R)//g" -e "s/CPU//" | tr -s ' ')

# RAM
 info_ram=$(/usr/sbin/dmidecode --type memory | sed -n '/^Memory Device/,/^Handle/p')
 info_ram_modules=$(echo "$info_ram" | grep -E '^.Size:|^.Type:|^.Speed:' \
   | sed -e ':a;N;$!ba;s/\n.Type://g' | sed -e ':a;N;$!ba;s/\n.Speed://g' -e 's/.Unknown//g' \
   | sed -e 's/ Installed.*$//')
 info_ram_total=0
 for r in $(echo -e "$info_ram_modules" | grep -v No | awk '{print $2}'); do
   info_ram_total=$((info_ram_total+r))
 done
 info_ram_total=$((info_ram_total/1024))

my_array=()
while IFS= read -r line; do
    my_array+=( "$line" )
done < <( /usr/sbin/dmidecode --type memory | grep "Size: " )
info_ram_total=0
sticks_info=""
for i in "${my_array[@]}"
do
    if [[ $i == *"MB"* ]]; then
        IFS=', ' read -r -a array <<< "$i"

        stick_gb=$((array[1]/1024))
        info_ram_total=$((info_ram_total+(array[1]/1024)))
        sticks_info="${sticks_info}/${stick_gb}"
    fi
    if [[ $i == *"GB"* ]]; then
        IFS=', ' read -r -a array <<< "$i"
        info_ram_total=$((info_ram_total+array[1]))
        sticks_info="${sticks_info}/${array[1]}"
    fi
done
info_ram_total="${info_ram_total} ${sticks_info}"

# NVIDIA display adapters
nvidia_output=$(nvidia-smi -q 2>&1)
if [[ $? -eq 0 ]]; then
  info_video=$(echo -e "$nvidia_output" | grep "Product Name" | cut -d: -f2 | sed -e "s/^.//")
else
  info_video='N/A'
fi

# Displays
if pgrep -f /usr/bin/Xorg >/dev/null; then
  if journalctl >/dev/null 2>&1; then
    info_display=$(journalctl _COMM=Xorg | grep -Eo 'NVIDIA.* connected' \
      | sed 's/^[^:]*: */\t/' | sort -u)
  else
    info_display=$(grep -E 'GPU.* connected|connected\)' /var/log/Xorg.0.log \
      | sed 's/.*NVIDIA([A-Z0-9-]*): *//' | sort -u \
      | sed -r 's/^(.+)$/\t\1/')
  fi
  [[ -z "$info_display" ]] && info_display='\tN/A'
else
  info_display='\tN/A'
fi

# HDD
if [[ -f /usr/bin/udisksctl ]]; then
  # Debian 8
  hddlist=$(udisksctl dump \
    | sed -n '/^\/org\/freedesktop\/UDisks2\/drives\/.*/,/^$/p' \
    | grep -E "org|Ejectable| Id:|Model|Smart|Size|^$")
  info_hdd=""
  let i=1
  strskip=1
  while [[ $strskip -lt $(echo "$hddlist" | wc -l) ]]; do
    tmp_hdinfo=$(echo "$hddlist" | sed -n "$strskip,/^$/ p")
    if ! echo "$tmp_hdinfo" | grep "Ejectable.*true" >/dev/null; then
      if [[ $i -ne 1 ]]; then info_hdd+="\n\n"; fi
      info_hdd+="\t$(echo $i: internal hard drive)\n"
      info_hdd+="\t$(echo "$tmp_hdinfo" | sed -n '/Model:/s/.*: *//p')\n"
      hdd_size_bytes="$(echo "$tmp_hdinfo" | sed -n '/Size:/s/.*: *//p')"
      hdd_size_gb="$(echo $hdd_size_bytes/1000000000 | bc)"
      info_hdd+="\t($hdd_size_gb GB)\n"
      if echo "$tmp_hdinfo" | grep "SmartEnabled.*true" >/dev/null; then
        info_hdd+="\tSmartFailing: $(echo "$tmp_hdinfo" | sed -n '/SmartFailing:/s/.*: *//p')\n"
        info_hdd+="\t$(echo "$tmp_hdinfo" | sed -n '/SmartNumBadSectors:/s/.*: *//p') bad sectors\n"
        info_hdd_powsec="$(echo "$tmp_hdinfo" | sed -n '/PowerOnSeconds:/s/.*: *//p')"
        info_hdd_powdays=$(echo "scale=1; $info_hdd_powsec/86400" | bc -l)
        info_hdd+="\t$info_hdd_powdays days"
      else
        info_hdd+="\tSmart disabled!\n\tSmart disabled!\n\tSmart disabled!"
      fi
      i=$((i+1))
    fi
    strskip=$((strskip + 1 + $(echo "$tmp_hdinfo" | wc -l)))
  done
else
  # Centos 6.*, Debian 6
  hddlist=$(\ls -g /dev/sd? | grep disk | awk '{print $9}')
  info_hdd=""
  i=1
  for hdd in $hddlist; do
    udisks --show-info $hdd | grep -E '^    interface: +usb$' > /dev/null && continue
    [[ $i -ne 1 ]] && info_hdd+="\n\n"
    info_hdd+="\t$(echo $i: $hdd)\n"
    tmp_hdinfo=$(hdparm -I $hdd)
    info_hdd+="\t$(echo "$tmp_hdinfo" | sed -n '/Model Number/s/.*: *//p')\n"
    info_hdd+="\t$(echo "$tmp_hdinfo" | sed -n '/device size with M = 1000/s/.*(/(/p')\n"

    tmp_hdinfo=$(udisks --show-info $hdd)
    info_hdd+="\t$(echo "$tmp_hdinfo" | sed -n '/overall assessment/s/\ *overall assessment:\ *//p')\n"
    info_hdd+="\t$(echo "$tmp_hdinfo" | grep 'reallocated-sector-count' | awk '{print substr($0, 52)}' | cut -d 's' -f1)realloc. sectors\n"
    info_hdd+="\t$(echo "$tmp_hdinfo" | grep 'power-on-hours' | awk '{print substr($0, 52)}' | cut -d 's' -f1)s"
    i=$((i+1))
  done
fi

### MAC
mac=$(ip addr | grep ether | awk '{print $2}')
###

### displays
displays=$(nvidia-xconfig --query-gpu-info | grep 'EDID Name' | awk '{print $4"_"$5}')
###

### os_version
. /etc/os-release
VER=$VERSION_ID
DISTRIB=$NAME
OS_VERSION=$DISTRIB"_"$VER
###
NOMACHINE=$(systemctl status nxserver.service | tail -1)
###

################################################################################
# Output

echo "----------------------------------------------------------------------"

echo -e "Wrs:\t$(hostname)"
echo -e "user:\t$info_user"
echo -e "Mthb:\t$info_motherboard"
echo -e "CPU:\t${info_cpu_threads} x ${info_cpu}"
echo -e "RAM:\t$info_ram_total GB"
echo "$info_ram_modules"
echo -e "Video:\t$info_video"
echo -e "Display(s):\n$info_display"
echo "HDD(s):"
echo -e "$info_hdd"
echo -e "MAC:\t$mac"
echo -e "Displays:\t$displays"
echo -e "OS:\t$OS_VERSION"
echo -e "NOMACHINE:\t$NOMACHINE"

echo "----------------------------------------------------------------------"
