#!/usr/bin/env perl

my $version = 'fastly_invalidate_cache $Rev: 1236 $ $LastChangedDate: 2015-05-27 08:29:23 +0100 (Wed, 27 May 2015) $';

# This CDS method requests that the Fastly CDN performs a cache invalidation on either the given URL or surrogate key.
# This is necessary when uploading content to be shared over Fastly to ensure that old versions are removed and the correct version of content
# is returned.
#
# Purging can be done either on a specific URL, or a "surrogate key".  This is an identifier which is provided to Fastly to link multiple
# items of content together (for example, HLS components)
#
#Arguments:
#  <cdn_domain>cdn.mydomain.com - if a provided URL does not match this domain, then no request is sent.
#  <url>/url/to/invalidate - invalidate this specific URL. In this case, an API key is not required.
#  <service_id>nnnnn - if purging with a "surrogate key", then you need to specify this to identify your service
#  <surrogate_key>nnnn - if purging with a "surrogate key", then you must specify it
#  <api_key>nnnnn - if purging with a "surrogate key", then you must specify a valid API key here.
#  <soft/> [OPTIONAL] - use a "soft purge" instead of a "fast purge" command
#END DOC

use LWP::UserAgent;
use CDS::Datastore;
use JSON;
use Data::Dumper;

#NO trailing /!
our $fastly_root = "https://api.fastly.com";

sub check_args {
    foreach(@_){
        if (not $ENV{$_}) {
            print STDERR "-ERROR: You need to define <$_> in the route file. Refer to the documentation.\n";
            exit(1);
        }
    }
}

sub invalidate_by_url {
    my $store=shift;
    my $ua = LWP::UserAgent->new;
    
    my $url_string = $store->substitute_string($ENV{'url'});
    my $wanted_host = $store->substitute_string($ENV{'cdn_domain'});
    
    my $uri;
    if ($url_string=~/^[a-z0-9A-Z]+:\/\//) {
        $uri = URI->new($url_string);
        if ($uri->host ne $wanted_host) {
            print STDERR "-ERROR: The requested url to invalidate, $url_string, does not match the CDN domain given by $wanted_host (got ".$uri->host."). Unable to continue.\n";
            return 1;
        }
    } else {
        $uri = URI->new($url_string,"http");
        $uri->host($wanted_host);
    }
    print "INFO: URL to invalidate: ".$uri->as_string."\n";
    
    my $req = HTTP::Request->new(PURGE=>$uri->as_string);
    if ($ENV{'debug'}) {
        print "DEBUG: dump of request:\n";
        local $Data::Dumper::Pad="\t";
        print Dumper($req);
    }
    
    my $response = $ua->request($req);
    if ($response->is_success) {
        if ($ENV{'debug'}) {
            print "INFO: response from server:\n";
            foreach(split /\n/,$response->decoded_content){
                print "\t$_\n";
            }
        }
        print "+SUCCESS: Invalidation requested\n";
        return 0;
    } else {
        print "-ERROR: Unable to request validation (".$response->status_line.") - ". $response->decoded_content ."\n";
        return 1;
    }
    
}

sub invalidate_by_surrogate_key {
    my $store=shift;
    my $ua = LWP::UserAgent->new;
    
    check_args(qw/service_id surrogate_key api_key/);
    
    my $service_id=$store->substitute_string($ENV{'service_id'});
    my $surrogate_key=$store->substitute_string($ENV{'surrogate_key'});
    my $api_key=$store->substitute_string($ENV{'api_key'});
    
    print "INFO: purging by surrogate key $surrogate_key\n";
    
    my $request_url = "$fastly_root/service/$service_id/purge/$surrogate_key";
    print "DEBUG: request url is $request_url\n" if($ENV{'debug'});
    
    my $req = HTTP::Request->new(POST=>$request_url);
    $req->header("Fastly-Key"=>$api_key);
    $req->header("Accept"=>"application/json");
    if ($ENV{'soft'}) {
        $req->header("Fastly-Soft-Purge"=>"1");
    }
    
    if ($ENV{'debug'}) {
        print "DEBUG: invalidation request:\n";
        local $Data::Dumper::Pad="\t";
        print Dumper($req);
    }
    
    my $response = $ua->request($req);
    if ($response->is_success) {
        my $bodycontent;
        eval {
            $bodycontent=from_json($response->decoded_content);
        };
        if ($@) {
            print "-WARNING: Unable to parse json response: $@\n";
            $bodycontent = $response->decoded_content;
        }
        
        print "+SUCCESS: Invalidation requested. ".$response->decoded_content;
        return 0;
    } else {
        my $bodycontent;
        eval {
            $bodycontent=from_json($response->decoded_content);
        };
        if ($@) {
            print "-WARNING: Unable to parse json response: $@\n";
            $bodycontent = $response->decoded_content;
        }
        print "-ERROR: Unable to request invalidation: ";
        local $Data::Dumper::Pad = "\t";
        print Dumper($bodycontent);
        return 1;
    }
}

#START MAIN
check_args(qw/cdn_domain/);

my $store=CDS::Datastore->new('fastly_invalidate_cache');

my $rv=-1;
if ($ENV{'url'}) {
    $rv=invalidate_by_url($store);
} elsif($ENV{'surrogate_key'}){
    $rv=invalidate_by_surrogate_key($store);
} else {
    print STDERR "-ERROR: You must specify something to invalidate! Either specify <url> to invalidate a specific URL or <surrogate_key> to invalidate everything matching a specific key\n";
    exit(1);
}

exit($rv);
