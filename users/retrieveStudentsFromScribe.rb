#!/usr/bin/env ruby
# encoding: utf-8

require 'rubygems'
require 'net/ldap'

load 'credentials'

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
    level = entry[ :entelevemef ][0]
    dateNaissance = entry[ :datenaissance ][0][ 6..7 ] + entry[ :datenaissance ][0][ 4..5 ] + entry[ :datenaissance ][0][ 0..3 ]
    students[ login ] = { :login => login, :name => name, :level => level, :birthday => dateNaissance } if( login !~ /prim\d\d/ )
end

date = Time.now.strftime("%Y/%m/%d")

print "Content-type: text/html\n\n"
print "<html><head><meta charset=\"UTF-8\"></head><body>"
print "<h1>Comptes des éléves sur le réseau pédagogique (#{date})</h1>"
studentsByLevel = students.group_by { | k, v | v[ :level ] }
[ 'ps', 'ms', 'gs', 'cp', 'ce1', 'ce2', 'cm1', 'cm2', '6e', '5e', '4e', '3e', '2nde', '1ere', 'tale' ].each {
    | level |
    if( studentsByLevel.key?( level ) )
	students = studentsByLevel[ level ]
	if( students.count > 0 )
	    colspan = 2
	    width = 500
	    passwordColHeader = ''
	    if( $withPassword )
	        colspan = 3
	        width = 700
	        passwordColHeader = "<td width=200>Date de<br/>naissance</td>"
	    end
	    print "<table border=1 width=#{width}>"
	    print "<tr><td colspan=\"#{colspan}\" style=\"font-size: larger;\">Niveau: <b>#{level}</b></td></tr>"
	    print "<tr><td width='*'>Nom</td><td width=200>Identifiant</td>#{passwordColHeader}</tr>"
	    students.sort_by { | student | student[ 0 ] }.each {
	        | student |
	        colPasswordValue = ''
	        if( $withPassword )
	            colPasswordValue = "<td>#{student[ 1 ][ :birthday ]}</td>"
	        end
	        row = "<tr><td>#{student[ 1 ][ :name ]}</td><td>#{student[ 1 ][ :login ]}</td>#{colPasswordValue}</tr>"
	        print row
	    }
	    print "</table><br/><br/>"
	end
    end
}

print "</body></html>"
