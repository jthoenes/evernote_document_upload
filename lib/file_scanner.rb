class FileScanner


  SOURCE_DIR = ENV['SAMBA_LOCATION']
  TARGET_DIR = "#{ENV['EVERNOTE_FOLDER']}/#{Date.today().strftime('%Y-%m-%d')}"
  DONE_DIR = "#{TARGET_DIR}/done"

  def execute
    ensure_directories
    move_to_local_disk
    upload_to_evernote
  end

  private
  def evernote_uploader
    @evernote_uploader ||= EvernoteUploader.new
  end

  def move_to_local_disk
    Dir.glob("#{SOURCE_DIR}/**/").each do |subdir|
      if File.directory?(subdir) and subdir != "#{SOURCE_DIR}/"
        process_scan_directory(subdir)
      end
    end
  end

  def upload_to_evernote
    Dir.glob("#{TARGET_DIR}/*.pdf").each do |file|
      fileInfo = PdfFileInfo.new(file)
      evernote_uploader.create_in_evernote(fileInfo)
      FileUtils.mv(file, DONE_DIR)
    end
  end

  def process_scan_directory directory_path
    Dir.glob("#{directory_path}/*.pdf").each do |file|
      FileUtils.mv(file, TARGET_DIR)
    end
    FileUtils.rmdir directory_path
  end

  def ensure_directories
    FileUtils.mkdir_p TARGET_DIR
    FileUtils.mkdir_p DONE_DIR
  end
end
