require 'rubygems'
require 'bundler'
require 'uri'
require "digest/md5"
require 'ostruct'
require 'date'

OAUTH_CONSUMER_KEY = ENV['EVERNOTE_CONSUMER_KEY']
OAUTH_CONSUMER_SECRET = ENV['EVERNOTE_CONSUMER_SECRET']
OAUTH_AUTH_TOKEN = ENV['EVERNOTE_AUTH_TOKEN']

# Connect to Sandbox server?
SANDBOX = false

Bundler.require(:default, :upload_file)

TARGET_NOTEBOOK_UID=ENV['EVERNOTE_INBOX_GUID']

def client
  @client ||= EvernoteOAuth::Client.new(token: OAUTH_AUTH_TOKEN, consumer_key:OAUTH_CONSUMER_KEY, consumer_secret:OAUTH_CONSUMER_SECRET, sandbox: SANDBOX)
end

def user_store
  @user_store ||= client.user_store
end

def user
  @user ||= user_store.getUser(OAUTH_AUTH_TOKEN)
end

def note_store
  @note_store ||= client.note_store
end

def tag_list
  @tag_list ||= note_store.listTags(OAUTH_AUTH_TOKEN)
end

def find_or_create_tag tag_name
  evernote_tag = tag_list.find{ |evernote_tag| tag_name == evernote_tag.name }
  if evernote_tag
    return evernote_tag.guid
  else
    begin
      new_tag = Evernote::EDAM::Type::Tag.new
      new_tag.name = tag_name

      print "creating tag #{tag_name} ..."
      evernote_tag = note_store.createTag(new_tag)
      puts " done"
      return evernote_tag.guid
    rescue Evernote::EDAM::Error::EDAMUserException => e
      puts "ERROR: #{e.message}, code: #{e.errorCode}, param: #{e.parameter}"
      raise "abort"
    end
  end
end

def evernote_note_body file
  return %Q(<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE en-note SYSTEM "http://xml.evernote.com/pub/enml2.dtd">
<en-note>
    <i>Imported from scanned document #{DateTime.now.strftime('%b %-d, %Y %H:%M %Z')}</i>
    <en-media type=\"#{file[:mimetype]}\" hash=\"#{file[:hash]}\"/>
</en-note>)
end

def create_file_resource title, filepath
  binary = File.open(filepath, "rb") { |io| io.read }
  mimetype = MimeMagic.by_path(filepath).type
  hash = Digest::MD5.new.hexdigest(binary)

  data = Evernote::EDAM::Type::Data.new
  data.size = binary.size
  data.bodyHash = Digest::MD5.new.digest(binary)
  data.body = binary

  resource = Evernote::EDAM::Type::Resource.new
  resource.mime = mimetype
  resource.data = data
  resource.attributes = Evernote::EDAM::Type::ResourceAttributes.new
  resource.attributes.fileName = "#{title}.pdf"

  {
    :mimetype => mimetype,
    :hash => hash,
    :resources => [resource]
  }
end

def create_in_evernote title, filepath, tags
  note = Evernote::EDAM::Type::Note.new
	note.title = title
  note.notebookGuid = TARGET_NOTEBOOK_UID

  file = create_file_resource(title, filepath)

  note.content = evernote_note_body(file)
  note.resources = file[:resources]
  note.tagGuids = tags.map{ |tag| find_or_create_tag(tag)}

  begin
    print "creating #{title} for #{filepath} ..."
    note = note_store.createNote(note)
    puts " done"
  rescue Evernote::EDAM::Error::EDAMUserException => e
    puts "ERROR: #{e.message}, code: #{e.errorCode}, param: #{e.parameter}"
    raise "abort"
  end
end

def extract_tags tags_input
  tags_input ||= ''
  year_tag = Date.today().year.to_s
  ([year_tag, 'TODO', 'scans'] + tags_input.split(',').map(&:strip)).uniq
end

create_in_evernote(ENV['TITLE'], File.expand_path(ENV['FILE']), extract_tags(ENV['TAGS']))
