#!/usr/bin/perl

use strict;
use warnings;
use feature 'say';

use Path::Tiny;
use Getopt::Long;
use Term::ANSIColor qw/:pushpop/;

my $version = "Pyxis v0.1.0";

my %options;
GetOptions(
    \%options,
    qw{ verbose help version }
) or die "Error in command line arguments\n";

if ($options{help}) {
    say "pyxis is a simple twtxt client.

Commands:
    fetch
        Fetch latest feeds.
    timeline
        Show timeline.
            Use `timeline <feed_1> <feed_2>' to show custom feeds.

Options:
    --verbose
        Verbose operation mode.
    --version
        Print Pyxis version.
    --help
        Print this help.";
        exit 0;
} elsif ($options{version}) {
    say $version;
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
                : warn "failed to fetch $feed - $url\n$!\n";
        }
    },
    timeline => sub {
        my %twtxt;

        # If $ARGV[1] is passed then only load that feed.
        my @feeds;

        shift @ARGV; # Drop `timeline' from @ARGV.

        # Add all arguments to @feeds, this allows user to run `pyxis
        # timeline f1 f2' & it'll load both `f1' & `f2'. But user can
        # also type `pyxis timeline f1 f1' & it'll load `f1' twice.
        scalar @ARGV
            ? do {push @feeds, path("$feeds_dir/$_") foreach @ARGV}
            : push @feeds, path($feeds_dir)->children;

        foreach my $feed (@feeds) {
            # Skip if feed file doesn't exist.
            warn "pyxis: unknown feed `$feed'\n"
                and next
                unless -e $feed;

            # Get the feed name, $feed is the path, there is no easy
            # way of keeping it as name so we split here to get feed
            # name again.
            my ($dummy_var, $feed_name) = split "$feeds_dir/", $feed;

            for my $line ($feed->lines) {
                chomp $line;
                next if (substr($line, 0, 1) eq "#"
                             or length $line == 0);
                my @tmp = split /\t/, $line;

                my $date = shift @tmp;
                my $message = join '', @tmp;

                # Include feed name in hash.
                push @{$twtxt{$date}}, [$feed_name, $message];
            }
        }
        # Exit if there are no feeds to load.
        die "pyxis: no feed to load\n"
            unless scalar keys %twtxt > 0;

        require Time::Moment;

        my %epoch_twtxt;
        foreach my $date (sort keys %twtxt) {
            my $tm = Time::Moment->from_string($date);
            my $epoch = $tm->epoch;
            $epoch_twtxt{$epoch} = $twtxt{$date};
        }

        foreach my $epoch (reverse sort keys %epoch_twtxt) {
            foreach my $entry (@{$epoch_twtxt{$epoch}}) {
                my $tm = Time::Moment->from_epoch($epoch);
                my $date = LOCALCOLOR MAGENTA $tm->strftime(q{%b %d });
                $date .= LOCALCOLOR GREEN $tm->strftime(q{%H:%M});
                my $feed_name = LOCALCOLOR CYAN $entry->[0];
                say "$date $feed_name $entry->[1]";
            }
        }
    },
);

if ($ARGV[0] and $dispatch{$ARGV[0]}) {
    $dispatch{$ARGV[0]}->();
} else {
    die "pyxis: no such option\n";
}
