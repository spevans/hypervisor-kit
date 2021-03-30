#!/bin/sh
jazzy --clean --author "Simon Evans" --author_url https://github.com/spevans --github_url https://github.com/spevans/hypervisor-kit --module HypervisorKit --output docs 
rm -r docs/docsets docs/undocumented.json
