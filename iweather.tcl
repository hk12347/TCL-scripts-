## Basic weather using Weather Underground 1.3
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
##   - Windspeed converted to meters
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

  ::http::register https 443 ::tls::socket

	# search url	
	set url "https://www.wunderground.com/weather/fi/"
	set urlback "?MR=1"
  	# user agent
	variable agent "Mozilla/6.0 (Windows NT 6.2; rv:40.0) Gecko/20170101 Firefox/55.0";
	
	proc getweather {nick uhand hand args} {

		set chan [lindex $args 0]
		set input [lindex $args 1]
		set search [lindex $input 0]
		set get [concat $iniweather::url$search$iniweather::urlback]
				
		variable agent;
		http::config -useragent $agent;
		http::register https 443 [list tls::socket -tls1 1]
		set token [geturl_followRedirects "${get}" -timeout 30000]
    
		set status [http::status $token]
		set data [http::data $token]
		http::cleanup $token
		http::unregister https
		
		set city ""; set temp ""; set windspeed ""; set windchill ""; set humidity ""; 
		set country ""; set date ""; set desc ""; set dt ""; set tz ""; set tmp "";
				
		# City
		regexp -nocase -- {"city":(.*?),} $data -> city; regexp {"(.*?)"} $city -> city; 	
		
		#test data
		#putserv "PRIVMSG $chan :[concat status: \002$status\002]"
		#putserv "PRIVMSG $chan :[concat url: \002$get\002]"
		#putserv "PRIVMSG $chan :[concat data: \002$token\002]"
		#putserv "PRIVMSG $chan :[concat city: \002$city\002]"
		
		# Temperature
		regexp -nocase -- {"temperature":(.*?),} $data -> temp; regsub {^[\ ]*} $temp "" temp; 	
		set cdeg [expr ($temp - 32.0) / 9 * 5]; # Fahrenheit to Celcius
		set ctemp [expr {round(10*$cdeg)/10.0}]; # Round to 1 decimals
		
		# Wind Speed
		regexp -nocase -- {"wind_speed":(.*?),} $data -> windspeed; regsub {^[\ ]*} $windspeed "" windspeed; 	
		if {$windspeed != "null"} {
			set wind [expr ($windspeed * 1.609344)]; # Miles to meters
			set windspeedKM [expr {round(10*$wind)/10.0}]; # Round to 1 decimals
		} 	
		
		# Wind Chill
		regexp -nocase -- {"windchill":(.*?),} $data -> windchill; regsub {^[\ ]*} $windchill "" windchill;
		if {$windchill != "null"} {
			set cdeg2 [expr ($windchill - 32.0) / 9 * 5]; # Fahrenheit to Celcius
			set cwindchill [expr {round(10*$cdeg2)/10.0}]; # Round to 1 decimals
		} 	
		
		# Humidity
		regexp -nocase -- {"humidity":(.*?),} $data -> humidity; regsub {^[\ ]*} $humidity "" humidity; 	
		
		# Country
		regexp -nocase -- {"country_name":(.*?),} $data -> country; regexp {"(.*?)"} $country -> country;
		
		# Condition
		regexp -nocase -- {"condition":(.*?),} $data -> desc; regexp {"(.*?)"} $desc -> desc;
		
		# Date time & Timezone (from the current observation)
		regexp -nocase -- {"current_observation":(.*?)"tz_offset_hours"} $data -> tmp
		regexp -nocase -- {"epoch":(.*?),} $tmp -> dt; regsub {^[\ ]*} $dt "" dt;
		regexp -nocase -- {"tz_short":(.*?),} $tmp -> tz; regexp {"(.*?)"} $tz -> tz;

		set datetime [clock format $dt -format "%H:%M $tz \(%b %d, %Y\)"]
    
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
putlog " -  Basic weather 1.3 loaded / 10092017"

