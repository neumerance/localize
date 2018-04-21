module ParentWithSiblings

  def can_delete_with_siblings
    return false unless can_delete_me
    siblings.each do |child|
      return false unless child.can_delete_with_siblings
    end
    true
  end

  def delete_siblings
    siblings.each do |child|
      child.delete_siblings
      child.destroy
    end
  end

end
