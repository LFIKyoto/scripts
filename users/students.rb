#!/usr/bin/env ruby
# encoding: utf-8

require 'cgi'
require 'rubygems'
require 'net/ldap'

load 'credentials'

cgi = CGI.new
format = cgi['format']
defaultGmailPassword = cgi['defaultGmailPassword']
if defaultGmailPassword == ''
    defaultGmailPassword = '********'
end

students = Hash.new

ldap = Net::LDAP.new :host => $ldapHost,
    :port => 389,
    :auth => {
        :method => :simple,
        :username => $ldapUsername,
        :password => $ldapPassword 
    }

filter = Net::LDAP::Filter.eq( "objectClass", "Eleves" )

ldap.search( :base => "o=gouv,c=fr", :filter => filter ) do 
    | entry |
    login = entry[ :uid ][0]
    name = entry[ :displayname ][0]
    givenName = entry[ :givenname ][0]
    familyName = entry[ :sn ][0]
    level = entry[ :entelevemef ][0]
    dateNaissance = entry[ :datenaissance ][0][ 6..7 ] + entry[ :datenaissance ][0][ 4..5 ] + entry[ :datenaissance ][0][ 0..3 ]
    students[ login ] = { :login => login, :name => name, :level => level, :birthday => dateNaissance, :givenName => givenName, :familyName => familyName } if( login !~ /prim\d\d/ )
end

date = Time.now.strftime("%Y/%m/%d")

print "Content-type: text/html\n\n"
print "<html><head><meta charset=\"UTF-8\"></head><body>"
print "<h1>Comptes des éléves sur le réseau pédagogique (#{date})</h1>"
studentsByLevel = students.group_by { | k, v | v[ :level ] }
[ 'ps', 'ms', 'gs', 'cp', 'ce1', 'ce2', 'cm1', 'cm2', '6e', '5e', '4e', '3e', '2nde', '1er', 'tale' ].each {
    | level |
    if( studentsByLevel.key?( level ) )
	students = studentsByLevel[ level ]
	if( students.count > 0 )
	    colspan = 2
	    width = 700
	    passwordColHeader = ''
	    if( $withPassword and format == '' )
	        colspan = 3
	        width = 900
	        passwordColHeader = "<td width=200>Date de<br/>naissance</td>"
	    end
	    
	    if format == 'gmail_bulk_upload'
		print "<hr/>Niveau: #{level}<br/><br/>"
	    else
	    	print "<table border=1 width=#{width}>"
	    	print "<tr><td colspan=\"#{colspan}\" style=\"font-size: larger;\">Niveau: <b>#{level}</b></td></tr>"
	    end
	    if format == 'gmail'
	    	print "<tr><td width='*'>Nom</td><td width=300>Mail</td></tr>"
	    elsif format == 'gmail_bulk_upload'
		print "First Name [Required],Last Name [Required],Email Address [Required],Password [Required],Password Hash Function [UPLOAD ONLY],Org Unit Path [Required],New Primary Email [UPLOAD ONLY],Recovery Email,Home Secondary Email,Work Secondary Email,Recovery Phone [MUST BE IN THE E.164 FORMAT],Work Phone,Home Phone,Mobile Phone,Work Address,Home Address,Employee ID,Employee Type,Employee Title,Manager Email,Department,Cost Center,Building ID,Floor Name,Floor Section,Change Password at Next Sign-In,New Status [UPLOAD ONLY]<br/>"
	    else
	    	print "<tr><td width='*'>Nom</td><td width=200>Identifiant</td>#{passwordColHeader}</tr>"
	    end
	    students.sort_by { | student | student[ 0 ] }.each {
	        | student |
		if format == 'gmail'
		    row = "<tr><td>#{student[ 1 ][ :name ]}</td><td>#{student[ 1 ][ :login ]}@lfikyoto.org</td></tr>"
		    print row
   		elsif format == 'gmail_bulk_upload'
		    print "#{student[ 1 ][ :givenName ]},#{student[ 1 ][ :familyName ]},#{student[ 1 ][ :login ]}@lfikyoto.org,#{defaultGmailPassword},,/Pedago/Eleves,,,,,,,,,,,,,,,,,,,,True,<br/>"
		else
		    colPasswordValue = ''
	            if( $withPassword )
		        colPasswordValue = "<td>#{student[ 1 ][ :birthday ]}</td>"
		    end
		    row = "<tr><td>#{student[ 1 ][ :name ]}</td><td>#{student[ 1 ][ :login ]}</td>#{colPasswordValue}</tr>"
		    print row
		end
	    }
	    if format != 'gmail_bulk_upload'
	    	print "</table><br/><br/>"
	    end
	end
    end
}

print "</body></html>"
