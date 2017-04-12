## tvmaze LOOKUP SCRIPT 1.1
## ###########################################
## The script doesn't need JSON TCL package (only reqexp used)
## Much cleaner version/output than the TVmaze.com Script (Try Google)
##
##--------------------------------------------
## hk / Sep 24, 2015
##############################################
#
# Usage: !tv <show>
#        !tvnext <show>
#
# Usage and Examples:
#
#<x1> !tv x-files
#<x2> Show: The X-Files (FOX/1993) - http://www.tvmaze.com/shows/430/the-x-files
#<x2> The last episode: #10x06 - My Struggle II (Feb/22/2016)
#<x2> The next episode of The X-Files is not yet scheduled.
#
#<x1> !tvnext simpsons
#<x2> The next episode of The Simpsons is #27x08 - Paths of Glory, it will air on Sunday at 20:00 (Dec/06/2015) (America/New_York)
#
###############################################
#
#  Changelog:
#
#  9.24.2015 - 1. version
#   - 1st release 
#  3.20.2016 - 1.1 version
#   - bug fixes
# 
#  Todo: !tvprev (show the previous episode)
#        - add more paramaters and information ()
# 
##############################################
package require http 2.7; # TCL 8.5

    namespace eval tvmaze {
  
      bind pub -|- "!tv" tvmaze::tv
      bind pub -|- "!tvnext" tvmaze::tvnext 
  
      # user agent
      variable agent "Lynx/2.8.5rel.1 libwww-FM/2.14 SSL-MM/1.4.1 OpenSSL/0.9.7e";
  
      # Headers color
      variable color1 \00314
      # Information color
      variable color2 \00303
      
      # flood protection (seconds)
      variable antiflood "5";

      # internal
      bind pub -|- "!tv" [namespace current]::public;
      bind msg -|- "!tv" [namespace current]::private;

      bind pub -|- "!tvnext" [namespace current]::public_;
      bind msg -|- "!tvnext" [namespace current]::private_;

      variable flood;
      namespace export *;
    }
  
    proc tvmaze::public {nick host hand chan argv} {
      tvmaze::tv $nick $host $hand $chan $argv
    }

    proc tvmaze::private {nick host hand argv} {
      tvmaze::tv $nick $host $hand $nick $argv
    }

    proc tvmaze::public_ {nick host hand chan argv} {
      tvmaze::tvnext $nick $host $hand $chan $argv
    }

    proc tvmaze::private_ {nick host hand argv} {
      tvmaze::tvnext $nick $host $hand $nick $argv
    }
  
    proc tvmaze::tv { nick host hand chan argv } {
  
        variable color1; variable color2;
        variable flood; variable antiflood;

        if {![info exists flood($chan)]} { set flood($chan) 0; }
        if {[unixtime] - $flood($chan) <= $antiflood} { return 0; }
        set flood($chan) [unixtime];
  
        set argv [string trim $argv];
        set argv [string map { " " "%20" } $argv]
        
        if {$argv == ""} {
          puthelp "NOTICE $nick :\002${color1}Syntax\002: ${color2}$::lastbind <title>\003";
          return 0;
        }

        # get next ep
        set next [getnext $argv];
        if {$next == ""} {
          putquick "PRIVMSG $chan :$prefix Error! (timeout or something similar) - Error 1";
          return 0;
        }

        # Get last ep
        set last [getlast $argv];
        if {$last == ""} {
          putquick "PRIVMSG $chan :$prefix Error! (timeout or something similar) - Error 2";
          return 0;
        }
 
        # Next episode info (General show info)
        set show_name         [lindex $next 0];   set show_network      [lindex $next 1];
        set show_premiered    [lindex $next 2];   set show_url          [lindex $next 3];
        set show_next_season  [lindex $next 4];   set show_next_number  [lindex $next 5];
        set show_next_title   [lindex $next 6];   set show_next_airdate [lindex $next 7];

        # Previous episode info
        set show_latest_season  [lindex $last 0];   set show_latest_number  [lindex $last 1];
        set show_latest_airdate [lindex $last 2];   set show_latest_title   [lindex $last 3];

        putquick "PRIVMSG $chan :Show: $show_name \($show_network/$show_premiered\) - $show_url"
        putquick "PRIVMSG $chan :The last episode: \002#$show_latest_season\x$show_latest_number - $show_latest_title\ $show_latest_airdate\002"

        if {$show_next_title == ""} {
          putquick "PRIVMSG $chan :The next episode of \002$show_name\002 is not yet scheduled."
        } else {
          putquick "PRIVMSG $chan :The next episode: \002#$show_next_season\x$show_next_number - $show_next_title\002, it will air on \002$show_next_airdate\002"
        }

    }

    # Get next ep only - no info about show
    proc tvmaze::tvnext { nick host hand chan argv } {

        variable color1; variable color2;
        variable flood; variable antiflood;

        if {![info exists flood($chan)]} { set flood($chan) 0; }
        if {[unixtime] - $flood($chan) <= $antiflood} { return 0; }
        set flood($chan) [unixtime];
  
        set argv [string trim $argv];
        set argv [string map { " " "%20" } $argv]
 
        set next [getnext $argv];

        if {$next == ""} {
          putquick "PRIVMSG $chan :$prefix Error! (timeout or something similar)";
          return 0;
        }

        # Next episode info (General show info)     
        set show_name         [lindex $next 0];   set show_network      [lindex $next 1];
        set show_premiered    [lindex $next 2];   set show_url          [lindex $next 3];
        set show_next_season  [lindex $next 4];   set show_next_number  [lindex $next 5];
        set show_next_title   [lindex $next 6];   set show_next_airdate [lindex $next 7];

        if {$show_next_title == ""} {
            putquick "PRIVMSG $chan :The next episode of \002$show_name\002 is not yet scheduled. That makes me a sad panda :("
        } else {
            putquick "PRIVMSG $chan :The next episode of \002$show_name\002 is \002#$show_next_season\x$show_next_number - $show_next_title\002, it will air on \002$show_next_airdate\002"
        }
  }
  

  # Get the next episode
  proc tvmaze::getnext {id} {
        
        variable agent; 
        http::config -useragent $agent;
        if {[catch {http::geturl "http://api.tvmaze.com/singlesearch/shows?q=$id&embed=nextepisode" -timeout 20000} token]} {
          return;
        }
        set data [http::data $token];
        http::cleanup $token;
      
        set show_name ""; set show_network ""; set show_premiered ""; set show_url "";
        set show_season ""; set show_number "";  set show_airdate ""; set show_timezone "";
        set show_title ""; set tmp "";

        regexp -nocase -- {"name":"([A-Za-z 0-9\&\'-:]+)"} $data -> show_name;
        regexp -nocase -- {"network":\{"id":\d{1,2},"name":"([A-Za-z 0-9]+)} $data -> show_network;
        regexp -nocase -- {"premiered":"([0-9]+)} $data -> show_premiered;
        regexp -nocase -- {"url":"(.*?)"} $data -> show_url; 
        regexp -nocase -- {"season":([A-Za-z_0-9/-]+)} $data -> show_season;
        regexp -nocase -- {"number":([A-Za-z_0-9/-]+)} $data -> show_number;
        regexp -nocase -- {"timezone":"([A-Za-z_0-9/-]+)} $data -> show_timezone;

        regexp -nocase -- {"_embedded":(.*?)"season"} $data -> tmp;
        regexp -nocase -- {"name":"(.*?)",} $tmp -> show_title;

        regexp {"airstamp":"(.*?)"} $data -> show_airdate;
        regsub -all {T} $show_airdate { } show_airdate;        # remove T char
        set show_airdate [string range $show_airdate 0 end-6]; # remove tz -> clock format doesnt work with tz
        set show_airdate [clock format [clock scan $show_airdate] -format "%A at %H:%M \(%b/%d/%Y\) \($show_timezone\)"];

        if {$show_number != ""} {
          set show_number [format "%02.f" $show_number];
        }

        return [list $show_name $show_network $show_premiered $show_url $show_season $show_number $show_title $show_airdate];
  }


  # Get the previously aired episode
  proc tvmaze::getlast {id} {
        
        variable agent; 
        http::config -useragent $agent;
        if {[catch {http::geturl "http://api.tvmaze.com/singlesearch/shows?q=$id&embed=previousepisode" -timeout 20000} token]} {
          return;
        }
        set data [http::data $token];
        http::cleanup $token;
      
        set show_season ""; set show_number "";  set show_airdate "";
        set show_title "";

        regexp -nocase -- {"season":([A-Za-z_0-9/-]+)} $data -> show_season;
        regexp -nocase -- {"number":([A-Za-z_0-9/-]+)} $data -> show_number;
        regexp -nocase -- {"airdate":"([A-Za-z_0-9/-]+)} $data -> show_airdate;
        set show_airdate [clock format [clock scan $show_airdate] -format "\(%b/%d/%Y\)"];

        regexp -nocase -- {"_embedded":(.*?)"season"} $data -> tmp;
        regexp -nocase -- {"name":"(.*?)",} $tmp -> show_title;

        if {$show_number != ""} {
          set show_number [format "%02.f" $show_number];
        }

        return [list $show_season $show_number $show_airdate $show_title];
  }


putlog "TVmaze.com 1.1 Script Loaded / 2015-24-09"

#eof
