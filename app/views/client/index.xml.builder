if @projects
  xml.projects do
    for project in @projects
      xml.project(:id => project.id) do
        xml.name(project.name)
        xml.revisions_number(project.revisions.length)
      end
    end
  end
end
