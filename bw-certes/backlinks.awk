@include "library"

BEGIN {

  Exe["wget"] = "/usr/bin/wget"
  Exe["timeout"] = "/usr/bin/timeout"
  G["maxlag"] = 10
  G["types"] = "(^Talk:|^Wikipedia:|^Wikipedia talk:|^Template talk:|^Portal talk:|^User:|^User talk:|^File talk:|^MediaWiki:|^MediaWiki talk:|^Help:|^Help talk:|^Category talk:|^Book:|^Book talk:|^Draft:|^Draft talk:|^TimedText:|^TimedText talk:|^Module talk:)"
  G["name"] = ARGV[1]

  print backlinks(ARGV[1], ARGV[2])

}

#
# backlinks - backlinks for a Wikipedia page (article, Template:, User:, Category:, etc..)
#
#  example: backlinks("Template:Gutenberg author", "out.txt")
#           where "out.txt" is the name of a file to save the list to.
#
#  return 0 if no links found (0 may or may not mean entity exists, see entity_exists() )
#
function backlinks(entity, outfile      ,url,blinks,ret,k) {

        delete J # global used in json2var to track unique list of names

        url = "http://en.wikipedia.org/w/api.php?action=query&list=backlinks&bltitle=" urlencodeawk(entity) "&blredirect&bllimit=250&continue=&blfilterredir=nonredirects&format=json&utf8=1&maxlag=" G["maxlag"]

        getbacklinks(url, entity, "blcontinue") # normal backlinks

        if ( entity ~ "^Template:") {    # transclusion backlinks
            url = "http://en.wikipedia.org/w/api.php?action=query&list=embeddedin&eititle=" urlencodeawk(entity) "&continue=&eilimit=500&continue=&format=json&utf8=1&maxlag=" G["maxlag"]
            getbacklinks(url, entity, "eicontinue")
        } else if ( entity ~ "^File:") { # file backlinks
            url = "http://en.wikipedia.org/w/api.php?action=query&list=imageusage&iutitle=" urlencodeawk(entity) "&iuredirect&iulimit=250&continue=&iufilterredir=nonredirects&format=json&utf8=1&maxlag=" G["maxlag"]
            getbacklinks(url, entity, "iucontinue")
        }

        ret = length(J)  # J is populated by json2var()

        if(int(ret) > 0) {
          removefile2(outfile)
          for(k in J)
            print k >> outfile
          close(outfile)
        }

       return ret

}
function getbacklinks(url, entity, method,      jsonin, jsonout, continuecode) {

        jsonin = http2var(url)
        if(apierror(jsonin, "json") > 0)
          return ""
        json2var(jsonin)
        continuecode = getcontinue(jsonin, method)

        while ( continuecode != "-1-1!!-1-1" ) {

            if ( method == "eicontinue" )
                url = "http://en.wikipedia.org/w/api.php?action=query&list=embeddedin&eititle=" urlencodeawk(entity) "&eilimit=500&continue=" urlencodeawk("-||") "&eicontinue=" urlencodeawk(continuecode) "&format=json&utf8=1&maxlag=" G["maxlag"]
            if ( method == "iucontinue" )
                url = "http://en.wikipedia.org/w/api.php?action=query&list=imageusage&iutitle=" urlencodeawk(entity) "&iuredirect&iulimit=250&continue=" urlencodeawk("-||") "&iufilterredir=nonredirects&iucontinue=" urlencodeawk(continuecode) "&format=json&utf8=1&maxlag=" G["maxlag"]
            if ( method == "blcontinue" )
                url = "http://en.wikipedia.org/w/api.php?action=query&list=backlinks&bltitle=" urlencodeawk(entity) "&blredirect&bllimit=250&continue=" urlencodeawk("-||") "&blcontinue=" urlencodeawk(continuecode) "&blfilterredir=nonredirects&format=json&utf8=1&maxlag=" G["maxlag"]
            jsonin = http2var(url)
            json2var(jsonin)
            continuecode = getcontinue(jsonin, method)
        }

}
function getcontinue(jsonin, method	,re,a,b,c) {

	# "continue":{"blcontinue":"0|20304297","continue"

        re = "\"continue\"[:][{]\"" method "\"[:]\"[^\"]*\""
        match(jsonin, re, a)
        split(a[0], b, "\"")
        
        if ( length(b[6]) > 0) 
            return b[6]
        return "-1-1!!-1-1"    
}

#
# Basic check of API results for error
#
function apierror(input, type,code) {

        if(length(input) < 5) {
          return 1
        }                  

        if(type == "json") {
          if(match(input, /"error"[:]{"code"[:]"[^\"]*","info"[:]"[^\"]*"/, code) > 0) {
            return 1
          }
        }
        else if(type == "xml") {
          if(match(input, /error code[=]"[^\"]*" info[=]"[^\"]*"/, code) > 0) {
            return 1
          }
        }
        else
          return
}


# =====================================================================================================
# JSON parse function. Returns a list of values parsed from json data.
#   example:  jsonout = json2var(jsonin)
# Returns a string containing values separated by "\n".
# See the section marked "<--" in parse_value() to customize for your application.
#
# Credits: by User:Green Cardamom at en.wikipedia.org
#          JSON parser derived from JSON.awk
#          https://github.com/step-/JSON.awk.git
# MIT license. May 2015        
# =====================================================================================================
function json2var(jsonin) {

        TOKEN=""
        delete TOKENS
        NTOKENS=ITOKENS=0
        VALUE=""
        BRIEF=0 

        tokenize(jsonin)
        parse()

}
function parse_value(a1, a2,   jpath,ret,x) {
        jpath=(a1!="" ? a1 "," : "") a2 # "${1:+$1,}$2"
        if (TOKEN == "{") {
                if (parse_object(jpath)) {
                        return 7
                }
        } else if (TOKEN == "[") {
                if (ret = parse_array(jpath)) {
                        return ret
        }
        } else if (TOKEN ~ /^(|[^0-9])$/) {
                # At this point, the only valid single-character tokens are digits.
                return 9
        } else {
                VALUE=TOKEN
        }
        if (! (1 == BRIEF && ("" == jpath || "" == VALUE))) {

                # This will print the full JSON data to help in building custom filter
              #   x = sprintf("[%s]\t%s", jpath, VALUE)
              #   print x

                if ( a2 == "\"*\"" || a2 == "\"title\"" ) {     # <-- Custom filter for MediaWiki API. Add custom filters here.
                    x = substr(VALUE, 2, length(VALUE) - 2)
                    if(x !~ G["types"] ) {
                      gsub(/\\["]/,"\"",x)      # convert \" to "
                      if(x == "") 
                        continue
                      if(J[x] == "") 
                        J[x] = "x"
                    }
                }
        }
        return 0
}
function get_token() {
        TOKEN = TOKENS[++ITOKENS] # for internal tokenize()
        return ITOKENS < NTOKENS
}
function parse_array(a1,   idx,ary,ret) {
        idx=0
        ary=""
        get_token()
        if (TOKEN != "]") {
                while (1) {
                        if (ret = parse_value(a1, idx)) {
                                return ret
                        }
                        idx=idx+1
                        ary=ary VALUE
                        get_token()
                        if (TOKEN == "]") {
                                break
                        } else if (TOKEN == ",") {
                                ary = ary ","
                        } else {
                                return 2
                        }
                        get_token()
                }
        }
        VALUE=""
        return 0
}
function parse_object(a1,   key,obj) {
        obj=""
        get_token()
        if (TOKEN != "}") {
                while (1) {
                        if (TOKEN ~ /^".*"$/) {
                                key=TOKEN
                        } else {
                                return 3
                        }
                        get_token()
                        if (TOKEN != ":") {
                                return 4
                        }
                        get_token()
                        if (parse_value(a1, key)) {
                                return 5
                        }
                        obj=obj key ":" VALUE
                        get_token()
                        if (TOKEN == "}") {
                                break
                        } else if (TOKEN == ",") {
                                obj=obj ","
                        } else {
                                return 6
                        }
                        get_token()
                }
        }
        VALUE=""
        return 0
}
function parse(   ret) {
        get_token()
        if (ret = parse_value()) {
                return ret
        }
        if (get_token()) {
                return 11
        }
        return 0
}
function tokenize(a1,   myspace) {

        # POSIX character classes (gawk) 
        # Replaced regex constant for string constant, see https://github.com/step-/JSON.awk/issues/1
        myspace="[[:space:]]+"
        gsub(/\"[^[:cntrl:]\"\\]*((\\[^u[:cntrl:]]|\\u[0-9a-fA-F]{4})[^[:cntrl:]\"\\]*)*\"|-?(0|[1-9][0-9]*)([.][0-9]*)?([eE][+-]?[0-9]*)?|null|false|true|[[:space:]]+|./, "\n&", a1)
        gsub("\n" myspace, "\n", a1)
        sub(/^\n/, "", a1)
        ITOKENS=0 
        return NTOKENS = split(a1, TOKENS, /\n/)
}

