#!/usr/bin/perl

use strict;
use Test::More tests => 1;

SKIP: {
    if (!eval { require Module::Signature; 1 }) {
        skip("Next time around, consider install Module::Signature, ".
             "so you can verify the integrity of this distribution.", 1);
    }
    else {
        $Module::Signature::CanKeyRetrieve = 
        $Module::Signature::CanKeyRetrieve = 0;
        ok(Module::Signature::verify() == Module::Signature::SIGNATURE_OK()
            => "Valid signature" );
    }
}

__END__
