Jekyll::Hooks.register :posts, :pre_render do |post, payload|
    docExt = post.extname.tr('.', '')
    # only process if we deal with a markdown file
    if payload['site']['markdown_ext'].include? docExt
      newContent = post.content.gsub(/\!\[(.+)\]\(([^\?]+)\??(\w*)\)/, '<div class="post-img-wrapper \3"><img src="\2" alt="\1"><div class="img-caption">\1</div></div>')
      post.content = newContent
    end
  end