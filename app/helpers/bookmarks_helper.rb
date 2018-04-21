module BookmarksHelper
  def link(bookmark)
    if bookmark.resource_type == 'User'
      user_link(bookmark.resource)
    else
      'unknown object'
    end
  end
end
