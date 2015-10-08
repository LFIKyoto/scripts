#
# Backup script
# Written by Frederic Bergeron
# (C) 2015
#
# Dependencies:
# - GNU tar and gzip: http://gnuwin32.sourceforge.net/packages.html for Windows
# - ccrypt: http://ccrypt.sourceforge.net for Windows
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

def sendFilesToServer( ftpServer, ftpUser, ftpPassword, hostname, files, mustCleanup )
    now = Time.new
    year = now.year
    dayNumber = now.yday.to_s.rjust( 3, "0" )

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
        FileUtils.rm( file ) if( mustCleanup )
    }

    ftp.close
end

def compressFiles( files, compressionProgram )
    prevDir = Dir.pwd
    files.each {
        | file |
        Dir.chdir( File.dirname( file ) )

        src = File.basename( file )
        if( compressionProgram == '7z' )
            outputFile = File.basename( "#{file}.7z" )
            command = "7z a -r \"#{outputFile}\" \"#{src}\""
            system( command )
        else
            outputFile = File.basename( "#{file}.tar" )
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
        command = "ccrypt --quiet --force --key \"#{encryptionKey}\" --encrypt \"#{file}\""
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
config[ 'ftp' ].each_with_index {
    | ftp, index |
    puts "Sending file to #{ftp[ 'server' ]}..."
    isLastElement = ( index == config[ 'ftp' ].size() - 1 )
    sendFilesToServer( ftp[ 'server' ], ftp[ 'username' ], ftp[ 'password' ], config[ 'hostname' ],
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
