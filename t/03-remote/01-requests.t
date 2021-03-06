#!perl

use strict;
use warnings;

use Test::More;
use Test::LWP::UserAgent;

use JSON;
use HTTP::Body;
use HTTP::Response;
use File::Temp;

use Pinto::Remote;
use Pinto::Globals;
use Pinto::Constants qw($PINTO_DEFAULT_PALETTE $PINTO_PROTOCOL_ACCEPT);

#-----------------------------------------------------------------------------
subtest 'request dialog' => sub {

    local $ENV{PINTO_PALETTE} = undef;
    my $ua = local $Pinto::Globals::UA = Test::LWP::UserAgent->new;

    my $res = HTTP::Response->new(200);
    $ua->map_response( qr{.*} => $res );

    my $action      = 'Add';
    my $temp        = File::Temp->new;
    my %pinto_args  = ( username => 'myname' );
    my %chrome_args = ( verbose => 2, color => 0, quiet => 0, palette => $PINTO_DEFAULT_PALETTE );
    my %action_args = ( archives => [ $temp->filename ], author => 'ME', stack => 'mystack' );

    my $chrome = Pinto::Chrome::Term->new(%chrome_args);
    my $pinto = Pinto::Remote->new( root => 'http://myhost:3111', chrome => $chrome, %pinto_args );
    $pinto->run( $action, %action_args );

    my $req = $ua->last_http_request_sent;
    is $req->method, 'POST', "Correct HTTP method in request for action $action";
    is $req->uri, 'http://myhost:3111/action/add', "Correct uri in request for action $action";
    is $req->header('Accept'), $PINTO_PROTOCOL_ACCEPT, 'Accept header';

    my $req_params      = parse_req_params($req);
    my $got_chrome_args = decode_json( $req_params->{chrome} );
    my $got_pinto_args  = decode_json( $req_params->{pinto} );
    my $got_action_args = decode_json( $req_params->{action} );

    my $got_time_offset = delete $got_pinto_args->{time_offset};
    is $got_time_offset, DateTime->now(time_zone => 'local')->offset, 'Correct time_offset';

    is_deeply $got_chrome_args, \%chrome_args, "Correct chrome args in request for action $action";
    is_deeply $got_pinto_args,  \%pinto_args,  "Correct pinto args in request for action $action";
    is_deeply $got_action_args, \%action_args, "Correct action args in request for action $action";

};

#-----------------------------------------------------------------------------

sub parse_req_params {
    my ($req)  = @_;
    my $type   = $req->header('Content-Type');
    my $length = $req->header('Content-Length');
    my $hb = HTTP::Body->new( $type, $length );
    $hb->add( $req->content );
    return $hb->param;
}

#-----------------------------------------------------------------------------

done_testing;
