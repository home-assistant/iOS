#!/usr/bin/env ruby

require "rubygems"
require "highline/import"

choices = "ynaq"
answer = ask("Your choice [#{choices}]? ") do |q|
           q.echo      = false
           q.character = true
           q.validate  = /\A[#{choices}]\Z/
         end
say("Your choice: #{answer}")
