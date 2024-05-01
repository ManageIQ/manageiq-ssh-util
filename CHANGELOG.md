# Changelog

## Unreleased

## [0.2.0] - 2024-05-01
### Removed
- BREAKING: Drop support for Ruby 2.5 [[#21]](https://github.com/ManageIQ/manageiq-ssh-util/pull/21)

### Changed
- Bump net-ssh for OpenSSL 3.0 support [[#21]](https://github.com/ManageIQ/manageiq-ssh-util/pull/21)
- Update paambaati/codeclimate-action action to v6 [[#22]](https://github.com/ManageIQ/manageiq-ssh-util/pull/22)
- Add renovate.json [[#15]](https://github.com/ManageIQ/manageiq-ssh-util/pull/15)
- Update codeclimate channel to the latest in manageiq-style [[#19]](https://github.com/ManageIQ/manageiq-ssh-util/pull/19)
- Test with ruby 3.1 and 3.0 [[#18]](https://github.com/ManageIQ/manageiq-ssh-util/pull/18)
- Update actions/checkout version to v4 [[#17]](https://github.com/ManageIQ/manageiq-ssh-util/pull/17)
- Update GitHub Actions versions [[#16]](https://github.com/ManageIQ/manageiq-ssh-util/pull/16)
- Add timeout-minutes to setup-ruby job [[#14]](https://github.com/ManageIQ/manageiq-ssh-util/pull/14)
- Switch to GitHub Actions, Handle newer version of activesupport [[#13]](https://github.com/ManageIQ/manageiq-ssh-util/pull/13)
- Add .whitesource configuration file [[#12]](https://github.com/ManageIQ/manageiq-ssh-util/pull/12)
- Update manageiq-style [[#10]](https://github.com/ManageIQ/manageiq-ssh-util/pull/10)
- Add badges to readme [[#9]](https://github.com/ManageIQ/manageiq-ssh-util/pull/9)
- Remove codeclimate-test-reporter [[#8]](https://github.com/ManageIQ/manageiq-ssh-util/pull/8)
- Switch to manageiq-style [[#7]](https://github.com/ManageIQ/manageiq-ssh-util/pull/7)

## [0.1.1] - 2020-05-04
### Changed
- Removed custom ManageIQ exceptions. Now just uses standard net-ssh exceptions. [[#4]](https://github.com/ManageIQ/manageiq-ssh-util/pull/4)
- Fixed a bug where the password variable was not getting set properly. [[#5]](https://github.com/ManageIQ/manageiq-ssh-util/pull/5)

## [0.1.0] - 2020-01-28
- Initial release, pulled from manageiq-gems-pending.

[Unreleased]: https://github.com/ManageIQ/manageiq-ssh-util/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/ManageIQ/manageiq-ssh-util/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/ManageIQ/manageiq-ssh-util/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/ManageIQ/manageiq-ssh-util/tree/v0.1.0
