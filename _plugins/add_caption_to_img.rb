
class AddCaptionToImage < Jekyll::Converter
  priority :highest

  def matches(ext)
    ext.downcase == ".md"
  end

  def convert(content)
    content.gsub(/\!\[(.+)\]\(([^\?]+)\??(\w*)\)/, '<div class="post-img-wrapper \3"><img src="\2" alt="\1"><div class="img-caption">\1</div></div>')
  end
end