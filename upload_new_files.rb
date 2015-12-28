require 'rubygems'
require 'bundler'
require 'date'
require 'fileutils'
require 'uri'
require 'digest/md5'
require 'date'

Bundler.require(:default, :script)

require_relative 'lib/pdf_file_info'
require_relative 'lib/file_scanner'
require_relative 'lib/evernote_uploader'

# Connect to Sandbox server?
SANDBOX = false

file_scanner = FileScanner.new
file_scanner.execute
