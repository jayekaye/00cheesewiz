#!/bin/bash

export BLUE='\033[1;94m'
export GREEN='\033[1;92m'
export RED='\033[1;91m'
export RESETCOLOR='\033[1;00m'


# Destinations you don't want routed through Tor
TOR_EXCLUDE="192.168.0.0/16 172.16.0.0/12 10.0.0.0/8"

# The UID Tor runs as
# change it if, starting tor, the command 'ps -e | grep tor' returns a different UID
TOR_UID="debian-tor"

# Tor's TransPort
TOR_PORT="9040"









function notify {
	if [ -e /usr/bin/notify-send ]; then
		/usr/bin/notify-send "AnonSurf" "$1"
	fi
}
export notify





function clean_dhcp {
	dhclient -r
	rm -f /var/lib/dhcp/dhclient*
	echo -e -n "$BLUE[$GREEN*$BLUE] DHCP address released"
	notify "DHCP address released"
}






	echo -e -n "$BLUE[$GREEN*$BLUE] Kill All Applications Open that May LEak your IP if you are concerned about it.."
	notify "Kill All Applications Open that May LEak your IP if you are concerned about it.."

# Asks the user to hit a key, then continues.

####################
# Functions
####################

# Waits for user key press.
Pause()
{
 OLDCONFIG=`stty -g`
 stty -icanon -echo min 1 time 0
 dd count=1 2>/dev/null
 stty $OLDCONFIG
}

####################
# Main Script
####################

echo "Hit a key to continue ..."
Pause
echo "OK, we'll carry on ..."


	echo -e -n "$BLUE[$GREEN*$BLUE] cleaning some dangerous cache elements\n"
	bleachbit -c adobe_reader.cache chromium.cache chromium.current_session chromium.history elinks.history emesene.cache epiphany.cache firefox.url_history flash.cache flash.cookies google_chrome.cache google_chrome.history  links2.history opera.cache opera.search_history opera.url_history &> /dev/null
	echo -e -n "$BLUE[$GREEN*$BLUE] Cache cleaned\n"
	notify "Cache cleaned"
}








function starti2p {
	echo -e -n " $GREEN*$BLUE starting I2P services"
	gksu service i2p start
	firefox http://127.0.0.1:7657/home &
	echo -e -n "$BLUE[$GREEN*$BLUE] I2P daemon started"
	notify "I2P daemon started"
}

function stopi2p {
	echo -e -n "$BLUE[$GREEN*$BLUE] Stopping I2P services\n"
	gksu service i2p stop
	echo -e -n "$BLUE[$GREEN*$BLUE] I2P daemon stopped\n"
	notify "I2P daemon stopped"
}



function ip {

	MYIP=`wget -qO- https://start.parrotsec.org/ip/`
	echo -e "\nMy ip is:\n"
	echo $MYIP
	echo -e "\n"
	notify "My IP is:\n\n$MYIP"
}



function start {
	# Make sure only root can run this script
	if [ $(id -u) -ne 0 ]; then
		echo -e -e "\n$GREEN[$RED!$GREEN] $RED R U DRUNK?? This script must be run as root$RESETCOLOR\n" >&2
		exit 1
	fi

	echo -e "\n$GREEN[$BLUE i$GREEN ]$BLUE Starting anonymous mode:$RESETCOLOR\n"

	if [ ! -e /tmp/tor.pid ]; then
		echo -e " $RED*$BLUE Tor is not running! $GREEN starting it $BLUE for you\n" >&2
		echo -e -n " $GREEN*$BLUE Stopping service nscd"
		service nscd stop 2>/dev/null || echo " (already stopped)"
		echo -e -n " $GREEN*$BLUE Stopping service resolvconf"
		service resolvconf stop 2>/dev/null || echo " (already stopped)"
		echo -e -n " $GREEN*$BLUE Stopping service dnsmasq"
		service dnsmasq stop 2>/dev/null || echo " (already stopped)"
		killall dnsmasq nscd resolvconf 2>/dev/null || true
		sleep 2
		killall -9 dnsmasq 2>/dev/null || true
		service resolvconf start 
		sleep 5
		systemctl start tor
		sleep 20
	fi


	if ! [ -f /etc/network/iptables.rules ]; then
		iptables-save > /etc/network/iptables.rules
		echo -e " $GREEN*$BLUE Saved iptables rules"
	fi

	iptables -F
	iptables -t nat -F

	cp /etc/resolv.conf /etc/resolv.conf.bak
	touch /etc/resolv.conf
	echo -e 'nameserver 127.0.0.1\nnameserver 92.222.97.145\nnameserver 192.99.85.244' > /etc/resolv.conf
	echo -e " $GREEN*$BLUE Modified resolv.conf to use Tor and ParrotDNS"

	# disable ipv6
	sysctl -w net.ipv6.conf.all.disable_ipv6=1
	sysctl -w net.ipv6.conf.default.disable_ipv6=1

	# set iptables nat
	iptables -t nat -A OUTPUT -m owner --uid-owner $TOR_UID -j RETURN

	#set dns redirect
	iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports 53
	iptables -t nat -A OUTPUT -p tcp --dport 53 -j REDIRECT --to-ports 53
	iptables -t nat -A OUTPUT -p udp -m owner --uid-owner $TOR_UID -m udp --dport 53 -j REDIRECT --to-ports 53

	#resolve .onion domains mapping 10.192.0.0/10 address space
	iptables -t nat -A OUTPUT -p tcp -d 10.192.0.0/10 -j REDIRECT --to-ports $TOR_PORT
	iptables -t nat -A OUTPUT -p udp -d 10.192.0.0/10 -j REDIRECT --to-ports $TOR_PORT

	#exclude local addresses
	for NET in $TOR_EXCLUDE 127.0.0.0/9 127.128.0.0/10; do
		iptables -t nat -A OUTPUT -d $NET -j RETURN
		iptables -A OUTPUT -d "$NET" -j ACCEPT
	done

	#redirect all other output through TOR
	iptables -t nat -A OUTPUT -p tcp --syn -j REDIRECT --to-ports $TOR_PORT
	iptables -t nat -A OUTPUT -p udp -j REDIRECT --to-ports $TOR_PORT
	iptables -t nat -A OUTPUT -p icmp -j REDIRECT --to-ports $TOR_PORT

	#accept already established connections
	iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

	#allow only tor output
	iptables -A OUTPUT -m owner --uid-owner $TOR_UID -j ACCEPT
	iptables -A OUTPUT -j REJECT

	echo -e "$GREEN *$BLUE All traffic was redirected throught Tor\n"
	echo -e "$GREEN[$BLUE i$GREEN ]$BLUE You are under AnonSurf tunnel$RESETCOLOR\n"
	notify "Global Anonymous Proxy Activated"
	sleep 1
	notify "Dance like no one's watching. Encrypt like everyone is :)"
	sleep 10
}





function stop {
	# Make sure only root can run our script
	if [ $(id -u) -ne 0 ]; then
		echo -e "\n$GREEN[$RED!$GREEN] $RED R U DRUNK?? This script must be run as root$RESETCOLOR\n" >&2
		exit 1
	fi
	echo -e "\n$GREEN[$BLUE i$GREEN ]$BLUE Stopping anonymous mode:$RESETCOLOR\n"

	iptables -F
	iptables -t nat -F
	echo -e " $GREEN*$BLUE Deleted all iptables rules"

	if [ -f /etc/network/iptables.rules ]; then
		iptables-restore < /etc/network/iptables.rules
		rm /etc/network/iptables.rules
		echo -e " $GREEN*$BLUE Iptables rules restored"
	fi
	echo -e -n " $GREEN*$BLUE Restore DNS service"
	if [ -e /etc/resolv.conf.bak ]; then
		rm /etc/resolv.conf
		cp /etc/resolv.conf.bak /etc/resolv.conf
	fi

	# re-enable ipv6
	sysctl -w net.ipv6.conf.all.disable_ipv6=0
	sysctl -w net.ipv6.conf.default.disable_ipv6=0

	service tor stop
	sleep 2
	killall tor
	sleep 6
	echo -e -n " $GREEN*$BLUE Restarting services\n"
	service resolvconf start || service resolvconf restart || true
	service dnsmasq start || true
	service nscd start || true
	echo -e " $GREEN*$BLUE It is safe to not worry for dnsmasq and nscd start errors if they are not installed or started already."
	sleep 1

	echo -e " $GREEN*$BLUE Anonymous mode stopped\n"
	notify "Global Anonymous Proxy Closed - Stop dancing :("
	sleep 4
}

function change {
	exitnode-selector
	sleep 10
	echo -e " $GREEN*$BLUE Tor daemon reloaded and forced to change nodes\n"
	notify "Identity changed - let's dance again!"
	sleep 1
}

function status {
	service tor@default status
	cat /tmp/anonsurf-tor.log || cat /var/log/tor/log
}



case "$1" in
	start)
		zenity --question --text="Do you want anonsurf to kill dangerous applications and clean some application caches?" && init
		start
	;;
	stop)
		zenity --question --text="Do you want anonsurf to kill dangerous applications and clean some application caches?" && init
		stop
	;;
	change)
		change
	;;
	status)
		status
	;;
	myip)
		ip
	;;
	ip)
		ip
	;;
	starti2p)
		starti2p
	;;
	stopi2p)
		stopi2p
	;;
	restart)
		$0 stop
		sleep 1
		$0 start
	;;
   *)
echo -e "
Parrot AnonSurf Module (v 2.5)
	Developed by Lorenzo \"Palinuro\" Faletra <palinuro@parrotsec.org>
		     Lisetta \"Sheireen\" Ferrero <sheireen@parrotsec.org>
		     Francesco \"Mibofra\" Bonanno <mibofra@parrotsec.org>
		and a huge amount of Caffeine + some GNU/GPL v3 stuff
	Usage:
	$RED┌──[$GREEN$USER$YELLOW@$BLUE`hostname`$RED]─[$GREEN$PWD$RED]
	$RED└──╼ \$$GREEN"" anonsurf $RED{$GREEN""start$RED|$GREEN""stop$RED|$GREEN""restart$RED|$GREEN""change$RED""$RED|$GREEN""status$RED""}

	$RED start$BLUE -$GREEN Start system-wide TOR tunnel	
	$RED stop$BLUE -$GREEN Stop anonsurf and return to clearnet
	$RED restart$BLUE -$GREEN Combines \"stop\" and \"start\" options
	$RED change$BLUE -$GREEN Restart TOR to change identity
	$RED status$BLUE -$GREEN Check if AnonSurf is working properly
	$RED myip$BLUE -$GREEN Check your ip and verify your tor connection

	----[ I2P related features ]----
	$RED starti2p$BLUE -$GREEN Start i2p services
	$RED stopi2p$BLUE -$GREEN Stop i2p services
$RESETCOLOR
Dance like no one's watching. Encrypt like everyone is.
" >&2

exit 1
;;
esac

echo -e $RESETCOLOR
exit 0
