xml.project(:id => @project.id, :name => @project.name, :kind=>@project.kind, :source=>@project.source) do
  for support_file in @project.support_files
    xml.support_file(:id => support_file.id)
  end
  for revision in @project.revisions
    xml.revision(:id => revision.id) do
      xml.name(revision.name)
      xml.versions_number(revision.versions.length)
      xml.chats_number(revision.chats.length)
    end
  end
end
