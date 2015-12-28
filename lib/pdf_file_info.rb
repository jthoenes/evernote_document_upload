class PdfFileInfo

  attr_reader :title, :filename, :path, :time, :tags

  def initialize filepath
    @title = File.basename(filepath)
    @filename = File.basename(filepath)
    @path = filepath
    @tags = []
    @time = File.new(filepath).mtime
  end

  def to_s
    "<PDF:#{@title}:#{@path}>"
  end

end
