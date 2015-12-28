
class EvernoteUploader
  OAUTH_CONSUMER_KEY = ENV['EVERNOTE_CONSUMER_KEY']
  OAUTH_CONSUMER_SECRET = ENV['EVERNOTE_CONSUMER_SECRET']
  OAUTH_AUTH_TOKEN = ENV['EVERNOTE_AUTH_TOKEN']

  TARGET_NOTEBOOK_UID=ENV['EVERNOTE_INBOX_GUID']

  def create_in_evernote fileInfo
    note = Evernote::EDAM::Type::Note.new
  	note.title = fileInfo.title
    note.notebookGuid = TARGET_NOTEBOOK_UID

    file = create_file_resource(fileInfo)

    note.content = evernote_note_body(file)
    note.resources = file[:resources]
    note.tagGuids = read_tags(fileInfo)

    begin
      print "creating #{fileInfo} ..."
      note = note_store.createNote(note)
      puts " done"
    rescue Evernote::EDAM::Error::EDAMUserException => e
      puts "ERROR: #{e.message}, code: #{e.errorCode}, param: #{e.parameter}"
      raise "abort"
    end
  end

  private

  def read_tags fileInfo
    tags_input ||= ''
    year_tag = fileInfo.time.year.to_s

    tags = ([year_tag, 'TODO', 'scans'] + fileInfo.tags).uniq
    tags.map{ |tag| find_or_create_tag(tag)}
  end

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

  def create_file_resource fileInfo
    binary = File.open(fileInfo.path, "rb") { |io| io.read }
    mimetype = MimeMagic.by_path(fileInfo.path).type
    hash = Digest::MD5.new.hexdigest(binary)

    data = Evernote::EDAM::Type::Data.new
    data.size = binary.size
    data.bodyHash = Digest::MD5.new.digest(binary)
    data.body = binary

    resource = Evernote::EDAM::Type::Resource.new
    resource.mime = mimetype
    resource.data = data
    resource.attributes = Evernote::EDAM::Type::ResourceAttributes.new
    resource.attributes.fileName = fileInfo.filename

    {
      :mimetype => mimetype,
      :hash => hash,
      :resources => [resource]
    }
  end
end
