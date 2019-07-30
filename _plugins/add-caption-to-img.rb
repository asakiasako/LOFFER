class ResponsiveImageify < Jekyll::Converter
  priority :high

  def matches(ext)
    ext.downcase == ".md"
  end

  def convert(content)
    content.gsub(/\!\[(.+)\]\((.+)\)/, '{% responsive_image path: \2 alt: \1  %}')
  end
end