## A basic weather using Weather Underground 1.1 (finnish)
##--------------------------------------------
## hk / May 9, 2015
##
##   Version 1.1 / 7.08.2015
##   - URL Changed 
##
##  This script is for a personal use only 
##  
##  Usage: !weather <city>
##  ---
##  <x1> !weather Tampere
##  <x2> * S‰‰: Tampere, Finland: Mostly Cloudy, 8∞C, Kosteus: 62%, Tuuli: 17 km/h, Tuulen hyyt‰vyys: 5∞C, 
##        P‰ivitetty: 16:50 EEST (Nov 05, 2015)
##############################################
package require http
package require tls
namespace eval iniweather {

  ::http::register https 443 ::tls::socket

	# search url	
	set url "https://www.wunderground.com/cgi-bin/findweather/getForecast?query="
	set urlback "&MR=1"
  # user agent
	variable agent "Mozilla/6.0 (Windows NT 6.2; rv:40.0) Gecko/20150101 Firefox/40.0";
	
	proc getweather {nick uhand hand args} {

		set chan [lindex $args 0]
		set input [lindex $args 1]
		set search [lindex $input 0]
		set get [concat $iniweather::url$search$iniweather::urlback]
				
		variable agent;
		http::config -useragent $agent;
		http::register https 443 [list tls::socket -tls1 1]
		set token [http::geturl "${get}" -timeout 30000]
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
		
		# Wind Speed
		regexp -nocase -- {"wind_speed":(.*?),} $data -> windspeed; regsub {^[\ ]*} $windspeed "" windspeed; 	
		
		# Wind Chill
		regexp -nocase -- {"windchill":(.*?),} $data -> windchill; regsub {^[\ ]*} $windchill "" windchill; 	
		
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
				putserv "PRIVMSG $chan :[concat \002$nick\002, * S‰‰: \002$city, $country:\002 $desc, $temp\∞C, \002Kosteus:\002 $humidity\%, \002Tuuli:\002 $windspeed km\/h, \002P‰ivitetty: \002$datetime\002]"
			} else {
				putserv "PRIVMSG $chan :[concat \002$nick\002, * S‰‰: \002$city, $country:\002 $desc, $temp\∞C, \002Kosteus:\002 $humidity\%, \002Tuuli:\002 $windspeed km\/h, \002Tuulen hyyt‰vyys:\002 $windchill\∞C, \002P‰ivitetty: \002$datetime\002]"
			}
		}
	}

}

bind pub -|- "!weather" iniweather::getweather

# the script has loaded.
putlog " - Basic weather 1.1 loaded / 07082015"
