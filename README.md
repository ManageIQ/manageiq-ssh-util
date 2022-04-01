manageiq-ssh-util

[![Gem Version](https://badge.fury.io/rb/manageiq-ssh-util.svg)](http://badge.fury.io/rb/manageiq-ssh-util)
[![CI](https://github.com/ManageIQ/manageiq-ssh-util/actions/workflows/ci.yaml/badge.svg)](https://github.com/ManageIQ/manageiq-ssh-util/actions/workflows/ci.yaml)
[![Code Climate](https://codeclimate.com/github/ManageIQ/manageiq-ssh-util.svg)](https://codeclimate.com/github/ManageIQ/manageiq-ssh-util)
[![Test Coverage](https://codeclimate.com/github/ManageIQ/manageiq-ssh-util/badges/coverage.svg)](https://codeclimate.com/github/ManageIQ/manageiq-ssh-util/coverage)

The manageiq-ssh-util library is a wrapper library around net-ssh. Its
main benefit is that it automatically handles channels and logging for
various states when running remote commands. It also automatically handles
terminal passwords and running commands via sudo, as well as automatic
retry for host key mismatches.

Some differences with the original MiqSshUtil library include:

* The name has been changed and scoped under the ManageIQ namespace.
* The ability to override the default value for the :use_agent option.
* Bug fixes for the on_extended_data ssh channel.

For details of the original bugs (and fixes) please see https://github.com/ManageIQ/manageiq-gems-pending/pull/437.

The remaining differences are internal refactoring updates.
