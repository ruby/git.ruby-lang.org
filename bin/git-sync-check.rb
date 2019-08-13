#!/usr/bin/env ruby
# This is executed by `/lib/systemd/system/git-sync-check.service` which is
# triggered every 10 minutes by `/lib/systemd/system/git-sync-check.timer`.

puts "hello world #{ENV['USER']}"
