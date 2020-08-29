#!/usr/bin/perl

use strict;
use warnings;

my %feeds = (
    andinus => "https://andinus.nand.sh/static/twtxt",
);

sub get_feeds { return %feeds; }

1;
