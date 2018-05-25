# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Prepare and trigger the reboot into the installed system
# Maintainer: Oliver Kurz <okurz@suse.de>

use strict;
use base 'y2logsstep';
use testapi;
use utils;

# restart shutdown by OK key
# and check success by waiting screen change without performing an action
sub wait_shutdown_ok {
    my ($stilltime, $similarity) = @_;
    send_key 'alt-o';
    return wait_screen_change(undef, $stilltime, similarity => $similarity);
}

sub run {
    # on remote installations we can not try to switch to the installation
    # console but we never switched away, see
    # logs_from_installation_system.pm, so we should be safe to ignore this
    # call
    if (check_var('BACKEND', 'spvm')) {
        # this will only work for serial install
        select_console 'novalink-ssh', await_console => 0;
        assert_screen 'rebootnow';
    }
    else {
        select_console 'installation' unless get_var('REMOTE_CONTROLLER');
    }

    # svirt: Make sure we will boot from hard disk next time
    if (check_var('VIRSH_VMM_FAMILY', 'kvm') || check_var('VIRSH_VMM_FAMILY', 'xen')) {
        my $svirt = console('svirt');
        $svirt->change_domain_element(os => boot => {dev => 'hd'});
    }
    # Similar test as in await_install.pm
    # but now about OK key sent multiple time as long as no screen change.
    my $counter = 5;
    # A single changing digit is only a minor change, overide default
    # similarity level considered a screen change
    my $minor_change_similarity = 55;
    while ($counter-- and not wait_shutdown_ok(5, $minor_change_similarity)) {
        save_screenshot:
        record_info('workaround', "While trying to trigger shutdown we expect screen change, retrying up to $counter times more");
    }
    save_screenshot:

    power_action('reboot', observe => 1, keepconsole => 1);
}

1;
