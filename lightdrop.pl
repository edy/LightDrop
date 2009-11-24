#!/usr/bin/perl
#
# LightDrop - Lightweight Perl IRC Bot
#
# Copyright (c) 2003, Eduard Baun <eduard@baun.de>
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
# 
#     * Redistributions of source code must retain the above copyright notice,
#       this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright notice,
#       this list of conditions and the following disclaimer in the documentation
#       and/or other materials provided with the distribution.
#     * Neither the name of TM Diff nor the names of its contributors
#       may be used to endorse or promote products derived from this software
#       without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
# ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

use IO::Socket;

$owner    = 'LightDrop';                     # Owner nickname
$host     = "irc.example.com";               # Server (IP or hostname)
$port     = "6667";                          # Port (default: 6667)
$channel  = '#channelname channelpassword';  # Channels LightDrop should join (separate multiple channels using comma)
$username = "LightDrop";                     # LightDrop username: NICKNAME!USERNAME@your.host.com
$nick     = "LightDrop";                     # LightDrop nickname: NICKNAME!USERNAME@your.host.com
$debug    = 1;                               # debugging: 1=on, 0=off

# ident server
if ( my $identpid = fork() ) {}
else {
 my $data;
 my $identport=113;
 my $identserver=IO::Socket::INET->new(LocalPort=>$identport,Type=>SOCK_STREAM,Reuse =>1,Listen =>10,Timeout =>10);
 print "Ident Server is listening on port $identport ... \n";
 while (  ($identclient,$client_adress) = $identserver->accept() )
  {
      $identclient->recv($data,10000);
      print $identclient "$data : USERID : UNIX : $username";
      close($identclient);
      last;
  }

    close $identserver;
    print "Ident Server closed...\n";
    exit;
    print "Ident Server noch da O_o...\n";
}


$version = "[LightDrop 1.0]";
$remote  = IO::Socket::INET->new( PeerAddr => $host, PeerPort => $port, Proto => "tcp" ) or die $@;

raw("USER $username $nick $nick :$version\n");
raw("NICK $nick");

$i = 0;
while ( $i < 6 ) { 
    recv( $remote, $output, 2048, 0 );
    if ($debug) { print "$output"; }
    if ( $output =~ /ping :(\S+)/i ) { raw("PONG :$1"); }
    $i++;
}

raw("JOIN $channel");
$LEBENDIG = 1;
while ($LEBENDIG) {
    recv( $remote, $output, 1024, 0 );
    if ($debug) { print "$output"; }

    if ( $output =~ /ping :(\S+)/i ) {
        raw("PONG :$1");
    }

    &input;
    &tv_remind;

    if ( $privmsg{'nick'} eq $owner ) {
        if ( $privmsg{'msg'} =~ /!die/ ) {
            raw("QUIT :$version");
            sleep(2);
            close($remote);
            $LEBENDIG = 0;
        }
    }
}

sub input {
    %privmsg = ();

    if ( $output =~ /:(\S+)!(\S+) PRIVMSG (\S+) :(.*)/ ) {
        %privmsg = (
            nick     => "$1",
            mask     => "$2",
            chan     => "$3",
            msg      => "$4",
            hostmask => "$1!$2"
        );
        chomp( substr( $privmsg{'msg'}, -1 ) );
    }

    &commands;
}

sub tv_remind {
    $i++;
    print "\nremind $i";
}

sub commands {
    if ( $privmsg{'msg'} =~ /^!say (.*)/ ) {
        msg( $privmsg{'chan'}, $1 );
    }

    elsif ( $privmsg{'msg'} =~ /^!join (.*)/ ) {
        raw("JOIN $1");
    }

    elsif ( $privmsg{'msg'} =~ /^!part (.*)/ ) {
        raw("PART $1");
    }

    elsif ( $privmsg{'msg'} =~ /^!nick (\S+)/ ) {
        raw("NICK $1");
    }

    elsif ( $privmsg{'msg'} =~ /^!me (.*)/ ) {
        msg( $privmsg{'chan'}, "\001ACTION $1\001" );
    }

    elsif ( $privmsg{'msg'} =~ /^!hop/ ) {
        raw("PART $privmsg{'chan'} :$version");
        raw("JOIN $privmsg{'chan'}");
    }

    elsif ( $privmsg{'msg'} =~ /\001VERSION\001/ ) {
        notice( $privmsg{'nick'}, "\001VERSION $version\001" );
    }

    elsif ( $privmsg{'msg'} =~ /\001TIME\001/ ) {
        my $uhrzeit = localtime(time);
        notice( $privmsg{'nick'}, "\001TIME $uhrzeit\001" );
    }

    elsif ( $privmsg{'msg'} =~ /\001PING (\S+)\001/ ) {
        my $uhrzeit = localtime(time);
        notice( $privmsg{'nick'}, "\001PING $1\001" );
    }
    elsif ( $privmsg{'msg'} =~ /!about/ ) {
        msg( $privmsg{'chan'}, "$version" );
    }
}

sub msg {
    my ( $nickorchan, $message ) = ( $_[0], $_[1] );
    my $str = "PRIVMSG $nickorchan :$message";
    raw($str);
}

sub notice {
    my ( $nick, $message ) = ( $_[0], $_[1] );
    my $str = "NOTICE $nick :$message";
    raw($str);
}

sub raw {
    my $raw = shift;
    send( $remote, "$raw\x0D\x0A", 0 );
}

exit;
