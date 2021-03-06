## Basic weather using Weather Underground 1.6
##--------------------------------------------
## hk / May 9, 2015
##
##   Version 1.1 / 7.08.2015
##   - URL Changed 
##
##   Version 1.2 / 19.8.2017
##   - URL Redirect fixed
##
##   Version 1.3 / 10.9.2017
##   - Temperatures converted to C
##   - Windspeed converted to km
##
##  Version 1.5 / 08.03.2019 
##  - Added Json changes: 
##    -> wind_speed -> windspeed
##    -> tz_short   -> effectiveTimeLocalTimeZone 
##    -> condition  -> wxPhraseLong
##    -> wind_chill  -> temperatureWindChill
##
##   Version 1.6 / 08.06.2019
##   - Datetime fix (epoch was missing)
##
##  This script is for a personal use only 
##  
##  Usage: !weather <city>
##  ---
##  <x1> !weather Tampere
##  <x2> * Sää: Tampere, Finland: Mostly Cloudy, 8°C, Kosteus: 62%, Tuuli: 17 m/s, Tuulen hyytävyys: 5°C, 
##        Päivitetty: 16:50 EEST (Nov 05, 2015)
##
##############################################
package require http
package require tls
package require uri

namespace eval iniweather {

	# search url	
	set url "https://www.wunderground.com/weather/fi/"
	set urlback "?MR=1"
 	# user agent
	variable agent "Mozilla/6.0 (Windows NT 6.2; rv:40.0) Gecko/20170101 Firefox/55.0";
		
	proc getweather {nick uhand hand args} {

		set chan [lindex $args 0]
		set input [lindex $args 1]
		set search [lindex $input 0]

		if {$search == "tampere2"} {
		set get "https://www.wunderground.com/weather/fi/tampere/ITAMPERE125"
		} else {
		 set get [concat $iniweather::url$search$iniweather::urlback]
		}

		variable agent;
		http::config -useragent $agent;
		#http::register https 443 [list tls::socket -tls1 1]
		http::register https 443 ::tls::socket
		set token [geturl_followRedirects "${get}" -timeout 30000]

		set status [http::status $token]
		set data [http::data $token]
		http::cleanup $token
		http::unregister https

		set city ""; set temp ""; set windspeed ""; set windspeedKM ""; set windchill ""; set humidity ""; 
		set country ""; set date ""; set desc ""; set dt ""; set tz ""; set tmp "";

		#FIX 22.8.2019: Apostrophe was changed to &q; e.g. " -> &q;
		regsub -all {&q;} $data "\"" data 		

		# City
		if {$search == "tampere2"} {
			set city "Tampere"
		} else {
			regexp -nocase -- {"city":\["(.*?)"} $data -> city; regexp {"(.*?)"} $city -> city; 	
		}

		#test data
		#putserv "PRIVMSG $chan :[concat status: \002$status\002]"
		#putserv "PRIVMSG $chan :[concat url: \002$get\002]"
		#putserv "PRIVMSG $chan :[concat data: \002$data\002]"
		#putserv "PRIVMSG $chan :[concat city: \002$city\002]"

		# Temperature
		regexp -nocase -- {"temperature":(.*?),} $data -> temp; regsub {^[\ ]*} $temp "" temp; 	
		set cdeg [expr ($temp - 32.0) / 9 * 5]; # Fahrenheit to Celcius
		set ctemp [expr {round(10*$cdeg)/10.0}]; # Round to 1 decimals

		# Wind Speed - Fix 22.8.2019 -> correct windspeed is before first wxPhrase
		set windspeed [string range $data [expr {[string first "wxPhraseLong" $data]-20}] [expr {[string first "wxPhraseLong" $data]-2}]]
		regexp -nocase -- {"windspeed":(.*?),} $windspeed -> windspeed; 
		if {($windspeed != "null") && ($windspeed != "\[null") && ($windspeed != "")} {
			set windspeedKM $windspeed; # Windspeed is kmh - not converted (23.8.2019)
		} 	

		# Wind Chill
		regexp -nocase -- {"temperatureWindChill":(.*?),} $data -> windchill; regsub {^[\ ]*} $windchill "" windchill;
		if {($windchill != "null") && ($windchill != "\[null")&& ($windchill != "")} {
			set cdeg2 [expr ($windchill - 32.0) / 9 * 5]; # Fahrenheit to Celcius
			set cwindchill [expr {round(10*$cdeg2)/10.0}]; # Round to 1 decimals
		} 	

		# Humidity
		regexp -nocase -- {"humidity":(.*?),} $data -> humidity; regsub {^[\ ]*} $humidity "" humidity; 	

		# Country
		regexp -nocase -- {"country":\["(.*?)"} $data -> country; regexp {"(.*?)"} $country -> country;

		# Condition
		regexp -nocase -- {"wxPhraseLong":(.*?),} $data -> desc; regexp {"(.*?)"} $desc -> desc;

		# Date time & Timezone (from the current observation)
		regexp -nocase -- {"epoch":(.*?),} $data -> dt; regsub {^[\ ]*} $dt "" dt;
		regexp -nocase -- {"timeZoneAbbreviation":(.*?)\},} $data -> tz; regexp {"(.*?)"} $tz -> tz;

		# If timezone is empty - set default timezone / 08.03.2019
		if {$tz == ""} {
			set tz "EET"
		}     

		if {$dt == ""} {
			regexp -nocase -- {"dateTime":"(.*?)\.} $data -> dt; regsub {^[\ ]*} $dt "" dt;
			regsub ***=T $dt " " dt
			set datetime [clock format [clock scan $dt] -format "%H:%M $tz \(%b %d, %Y\)"]
		} else {
			set datetime [clock format $dt -format "%H:%M $tz \(%b %d, %Y\)"]	
		}

		if {$city != ""} {
			if {$windchill == "null"} {
				putserv "PRIVMSG $chan :[concat \002$nick\002, * Sää: \002$city, $country:\002 $desc, $ctemp\°C, \002Kosteus:\002 $humidity\%, \002Tuuli:\002 $windspeedKM m\/s, \002Päivitetty: \002$datetime\002]"
			} else {
				putserv "PRIVMSG $chan :[concat \002$nick\002, * Sää: \002$city, $country:\002 $desc, $ctemp\°C, \002Kosteus:\002 $humidity\%, \002Tuuli:\002 $windspeedKM m\/s, \002Tuulen hyytävyys:\002 $cwindchill\°C, \002Päivitetty: \002$datetime\002]"
			}
		}
	}

	proc geturl_followRedirects {url args} {
		array set URI [::uri::split $url]
    		for {set i 0} {$i < 5} {incr i} {
        		set token [::http::geturl $url {*}$args]
        		if {![string match {30[1237]} [::http::ncode $token]]} {return $token}
        		array set meta [string tolower [set ${token}(meta)]]
        		if {![info exist meta(location)]} {
          			return $token
        		}
        		array set uri [::uri::split $meta(location)]
        		unset meta
        		if {$uri(host) eq {}} {set uri(host) $URI(host)}
        		# problem w/ relative versus absolute paths
        		set url [::uri::join {*}[array get uri]]
    		}
  	}

}

bind pub -|- "!weather" iniweather::getweather

# the script has loaded.
putlog " -  Basic weather 1.6 loaded / 08062019"
