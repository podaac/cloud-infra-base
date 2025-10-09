# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- CloudWatch logging for kernel messages, bootstrap logs, and command lines

### Changed
### Removed

## [1.0.0]
- First official stable release

### Added
- SIT/UAT deployment configurations
- SNS notifications on instance rotation
- Variable rotation periods dependent on last rotation instead of calendar date
- Verbose initialization messages at top of session to indicate Carpathia status
- Support for passing through Terraform arguments to deploy/destroy scripts
- Setsail configurations/support

### Fixed
- Crontab non-persistence
- Intermittent sudo issues with password prompts
- Fixed issue with bash wrapper not properly passing arguments to real bash exec
- Initialization messages not appearing due to early script exits
- Environment rotation misconfigurations
- S3FS mounts failing due to incorrect prefixes

### Changed
- UAT/OPS machine instance sizes changed to higher instance types for higher memory

### Removed
- Older deployment configuration styles
