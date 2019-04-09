manageiq-ssh-util

The manageiq-ssh-util library is a wrapper library around net-ssh. It's
main benefit is that it automatically handles channels and logging for
various states when running remote commands. It also automatically handles
terminal passwords and running commands via sudo, as well as automatic
retry for host key mismatches.
