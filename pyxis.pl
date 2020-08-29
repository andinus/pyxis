#!/usr/bin/perl

use strict;
use warnings;
use feature 'say';

use Path::Tiny;
use Getopt::Long;
use Term::ANSIColor qw/:pushpop/;

my %options;
GetOptions(
    \%options,
    qw{ verbose help }
) or die "Error in command line arguments\n";

if ($options{help}) {
    say "pyxis is a simple twtxt client.

Commands:
    fetch
        Fetch latest feeds.

Options:
    --verbose
        Verbose operation mode.
    --help
        Print this help.";
        exit 0;
}

# $feeds_dir will store user's feeds.
my $feeds_dir = $ENV{XDG_DATA_HOME} || "$ENV{HOME}/.local/share";
$feeds_dir .= "/pyxis";

# Create $feeds_dir.
path($feeds_dir)->mkpath;

# Config file for pyxis.
my $config_file = $ENV{XDG_CONFIG_HOME} || "$ENV{HOME}/.config";
$config_file .= "/pyxis.pl";

require "$config_file";
my %feeds = get_feeds();

my %dispatch = (
    fetch => sub {
        require HTTP::Tiny;
        my $http = HTTP::Tiny
            ->new(
                verify_SSL => 1,
                # default user-agent string if ending in space.
                # agent => "pyxis: https://andinus.nand.sh/pyxis ",
            );

        foreach my $feed (sort keys %feeds) {
            my $url = $feeds{$feed};
            my $file = "$feeds_dir/$feed";

            my $res = $http->mirror($url, $file);
            $res->{success}
                ? do {say "$feed updated" if $options{verbose}}
                : warn "failed to fetch $feed - $url\n$!\n"
        }
    },
    timeline => sub {
        my %twtxt;
        for my $feed (path($feeds_dir)->children) {
            for my $line ($feed->lines) {
                chomp $line;
                next if (substr($line, 0, 1) eq "#"
                             or length $line == 0);
                my @tmp = split /\t/, $line;

                # Get $date & $entry from @tmp. This can over-write
                # entries if they were posted at same time, very
                # unlikely but possible.
                my $date = shift @tmp;
                my $entry = join '', @tmp;
                $twtxt{$date} = $entry;
            }
        }
        require Time::Moment;

        my %epoch_twtxt;
        foreach my $date (sort keys %twtxt) {
            my $tm = Time::Moment->from_string($date);
            my $epoch = $tm->epoch;
            $epoch_twtxt{$epoch} = $twtxt{$date};
        }

        foreach my $epoch (reverse sort keys %epoch_twtxt) {
            my $tm = Time::Moment->from_epoch($epoch);
            my $date = LOCALCOLOR MAGENTA $tm->strftime(q{%b %d });
            $date .= LOCALCOLOR GREEN $tm->strftime(q{%H:%M});
            say "$date $epoch_twtxt{$epoch}";
        }
    },
);

if ($ARGV[0] and $dispatch{$ARGV[0]}) {
    $dispatch{$ARGV[0]}->();
} else {
    die "pyxis: no such option\n";
}
