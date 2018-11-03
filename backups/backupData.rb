#
# Backup script
# Written by Frederic Bergeron
# (C) 2015-2017
#
# Dependencies:
# - GNU tar, gzip, grep, coreutils, openssl: http://gnuwin32.sourceforge.net/packages.html for Windows
# - ccrypt: http://ccrypt.sourceforge.net for Windows
# - gdcp: https://github.com/ctberthiaume/gdcp
#

require 'fileutils'
require 'net/ftp'

$blockSize = 16 * 1024

$configFile = ARGV[ 0 ] || ENV[ 'HOME' ] + '/backup.ini'

def readConfigFile( configFile )
    config = Hash.new
    isReadingFilesToBackup = false
    file = File.open( configFile )
    file.each {
        | line |
        if( line =~ /^#.*/ )
            next
        elsif( line =~ /(.*?)=(.*)/ )
            propName = $1
            propValue = $2
            if( propName =~ /(.*)(\d)\.(.*)/ )
                arrayName = $1
                arrayIndex = $2.to_i - 1
                propName = $3
                array = config[ arrayName ]
                if( array == nil )
                    array = Array.new
                    config[ arrayName ] = array
                end
                hash = array[ arrayIndex ]
                if( hash == nil )
                    hash = Hash.new
                    array[ arrayIndex ] = hash
                end
                hash[ propName ] = propValue
            else
                config[ propName ] = propValue
            end
        elsif( line =~ /^filesToBackup:BEGIN.*/ )
            isReadingFilesToBackup = true
        elsif( line =~ /^filesToBackup:END.*/ )
            isReadingFilesToBackup = false
        else
            if( isReadingFilesToBackup )
                if( !config.key?( 'filesToBackup' ) )
                    config[ 'filesToBackup' ] = Array.new
                end
                config[ 'filesToBackup' ] << line.chomp
            end
        end
    }
    return config
end

def sendFilesToServer( host, hostname, files, mustCleanup )
    now = Time.new
    year = now.year
    dayNumber = now.yday.to_s.rjust( 3, "0" )
    if( host[ 'method' ] == 'ftp' )
        sendFilesToServerByFtp( host[ 'server' ], host[ 'username' ], host[ 'password' ], hostname, files, year, dayNumber )
    elsif( host[ 'method' ] == 'scp' )
        sendFilesToServerByScp( host[ 'server' ], host[ 'username' ], host[ 'identity' ], host[ 'port' ], hostname, files, year, dayNumber )
    elsif( host[ 'method' ] == 'gdcp' )
        sendFilesToServerByGdcp( hostname, files, year, dayNumber )	
    end
    if( mustCleanup )
        puts "Cleaning up..."
        files.each {
            | file |
            if File.exist?( file )  
                puts "Deleting #{file}."
        	FileUtils.rm( file )
            end
        }
    end
end

def sendFilesToServerByGdcp( hostname, files, year, dayNumber )
    path = "/tmp/servers/#{hostname}/#{year}/#{dayNumber}"
    FileUtils.mkdir_p(path)

    if (getOS() == 'windows')
	getServersFolderIdCommand = "c:\\gdcp.bat list | grep servers  | cut -f 2"
    else
        getServersFolderIdCommand = "PYTHONIOENCODING=utf-8 ~/gdcp-0.7.13/gdcp list | grep servers  | cut -f 2"
    end 
    serversFolderId = `#{getServersFolderIdCommand}`
    serversFolderId.chomp!

    if (getOS() == 'windows')
	getHostnameFolderIdCommand = "c:\\gdcp.bat \"list -i #{serversFolderId}\" | grep #{hostname}  | cut -f 2"
    else
        getHostnameFolderIdCommand = "PYTHONIOENCODING=utf-8 ~/gdcp-0.7.13/gdcp list -i #{serversFolderId} | grep #{hostname}  | cut -f 2"
    end 
    hostnameFolderId = `#{getHostnameFolderIdCommand}`
    hostnameFolderId.chomp!

    if (getOS() == 'windows')
	getYearFolderIdCommand = "c:\\gdcp.bat \"list -i #{hostnameFolderId}\" | grep #{year}  | cut -f 2"
    else
        getYearFolderIdCommand = "PYTHONIOENCODING=utf-8 ~/gdcp-0.7.13/gdcp list -i #{hostnameFolderId} | grep #{year}  | cut -f 2"
    end 
    yearFolderId = `#{getYearFolderIdCommand}`
    yearFolderId.chomp!

    files.each {
        | file |
        if (getOS() == 'windows')
            tmpFile = ENV['TMP'] + '/' + File.basename( "#{file}" )
            mvCommand = "mv #{tmpFile} #{path}/."
        else
            mvCommand = "mv #{file} #{path}/."
        end 
        system( mvCommand )
    }
    if (getOS() == 'windows')
        uploadCommand = "cd /tmp/servers/#{hostname}/#{year} && c:/gdcp.bat \"upload -p #{yearFolderId} #{dayNumber}\""
    else
        uploadCommand = "cd /tmp/servers/#{hostname}/#{year} && ~/gdcp-0.7.13/gdcp upload -p #{yearFolderId} #{dayNumber}"
    end 
    system( uploadCommand )

    puts "Cleaning up tmp files..."
    rmCommand = "rm -rf /tmp/servers"
    system( rmCommand )
end

def sendFilesToServerByScp( scpServer, scpUser, scpIdentity, scpPort, hostname, files, year, dayNumber )
    path = "bak/#{hostname}/#{year}/#{dayNumber}"
    makePathCommand = "ssh -p #{scpPort} -i #{scpIdentity} #{scpUser}@#{scpServer} \"mkdir -p #{path}\""
    puts makePathCommand
    system( makePathCommand )
    files.each {
        | file |
        scpCommand = "scp -P #{scpPort} -i #{scpIdentity} #{file} #{scpUser}@#{scpServer}:#{path}/."
        puts scpCommand
        system( scpCommand )
    }
end

def sendFilesToServerByFtp( ftpServer, ftpUser, ftpPassword, hostname, files, year, dayNumber )
    ftp = Net::FTP.new( ftpServer )
    ftp.login ftpUser, ftpPassword
    ftp.passive = true

    begin
        ftp.chdir( 'bak' )
    rescue Net::FTPPermError => err
        if( /550/ =~ err.message )
            ftp.mkdir( 'bak' )
            ftp.chdir( 'bak' )
        end
    end

    begin
        ftp.chdir( hostname )
    rescue Net::FTPPermError => err
        if( /550/ =~ err.message )
            ftp.mkdir( hostname )
            ftp.chdir( hostname )
        end
    end

    begin
        ftp.chdir( year.to_s )
    rescue Net::FTPPermError => err
        if( /550/ =~ err.message )
            ftp.mkdir( year.to_s )
            ftp.chdir( year.to_s )
        end
    end

    begin
        ftp.chdir( dayNumber )
    rescue Net::FTPPermError => err
        if( /550/ =~ err.message )
            ftp.mkdir( dayNumber )
            ftp.chdir( dayNumber )
        end
    end

    files.each {
        | file |
        dstFile = File.basename( file )
        ftp.putbinaryfile( file, dstFile )
    }

    ftp.close
end

def compressFiles( files, compressionProgram )
    prevDir = Dir.pwd
    files.each {
        | file |
	puts "compressing file #{file}"
        Dir.chdir( File.dirname( file ) )

        src = File.basename( file )
        if( compressionProgram == '7z' )
	    if (getOS() == 'windows')
	        outputFile = ENV['TMP'] + '/' + File.basename( "#{file}.7z" )
	    else
                outputFile = File.basename( "#{file}.7z" )
	    end 
            command = "7z a -r \"#{outputFile}\" \"#{src}\""
            system( command )
        else
	    if (getOS() == 'windows')
	        outputFile = ENV['TMP'] + '/' + File.basename( "#{file}.tar" )
	    else
	        outputFile = File.basename( "#{file}.tar" )
	    end 
            command = "tar -cf \"#{outputFile}\" \"#{src}\""
            system( command )

            gzipCommand = "gzip --force \"#{outputFile}\""
            system( gzipCommand )
        end
    }
    Dir.chdir( prevDir )
end

def encryptFiles( encryptionKey, files )
    files.each {
        | file |
        if (getOS() == 'windows')
	    tmpFile = ENV['TMP'] + '/' + File.basename(file)
            command = "ccrypt --quiet --force --key \"#{encryptionKey}\" --encrypt \"#{tmpFile}\""
        else
            command = "ccrypt --quiet --force --key \"#{encryptionKey}\" --encrypt \"#{file}\""
        end 
        system( command )
    }
end

def decryptFiles( encryptionKey, files )
    files.each {
        | file |
        command = "ccrypt --quiet --force --key \"#{encryptionKey}\" --decrypt \"#{file}.cpt\""
        system( command )
    }
end

def getOS()
    if( /cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM )
        return( 'windows' )
    else
        return( 'linux' )
    end
end

config = readConfigFile( $configFile )
compressFiles( config[ 'filesToBackup' ], config[ 'compressionProgram' ] )
encryptFiles( config[ 'encryptionKey' ],
    config[ 'filesToBackup' ].map {
       | file |
        if( config[ 'compressionProgram' ] == '7z' )
            "#{file}.7z"
        else
            "#{file}.tar.gz"
        end
    } )
config[ 'host' ].each_with_index {
    | host, index |
    puts "Sending file to #{host[ 'server' ]}..."
    isLastElement = ( index == config[ 'host' ].size() - 1 )
    sendFilesToServer( host, config[ 'hostname' ],
        config[ 'filesToBackup' ].map {
            | file |
            if( config[ 'compressionProgram' ] == '7z' )
                "#{file}.7z.cpt"
            else
                "#{file}.tar.gz.cpt"
            end
        }, isLastElement )
    puts "Done."
}
exit
