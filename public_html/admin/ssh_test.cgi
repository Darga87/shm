#!/usr/bin/perl

use v5.14;

use SHM qw(:all);
my $user = SHM->new();

use Core::System::ServiceManager qw( get_service );
use Core::Utils qw(
    parse_args
);

our %in = parse_args();
my $ssh = get_service( 'Transport::Ssh' );

if ( $in{params} && $in{params}{cmd} ) {
    my $t = get_service('Task')->res({
        server_id => 0,
        user_service_id => 0,
        event_id => 0,
    });

    my $parser = get_service('parser');
    $in{params}{cmd} = $parser->parse( $in{params}{cmd} );
}

my $pipeline_id = get_service('console')->new_pipe;

my (undef, $res ) = $ssh->exec(
    host => $in{host},
    cmd => $in{cmd} || 'uname -a',
    key_id => 1,
    wait => $in{wait} || 0,
    pipeline_id => $pipeline_id,
    %{ $in{params} || {} },
);

print_header();
print_json({
    ssh => $res,
    pipeline => {
        id => $pipeline_id,
    },
});

exit 0;

