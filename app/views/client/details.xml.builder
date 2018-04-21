if @projects
	xml.projects do
		for project in @projects
			xml.project(:id => project.id) do
				xml.name(project.name)
				if project.revisions.length > 0
					revision = project.revisions[-1]
					xml.last_revision(:id => revision.id, :name => revision.name, :released => revision.released, :open_to_bids => revision.open_to_bids, :update_counter=>revision.update_counter) do
						for version in revision.versions
							xml.version(:id => version.id)
						end
						for revision_language in revision.revision_languages
							xml.language(:id => revision_language.language.id, :name => revision_language.language.name)
						end
					end
				end
			end
		end
	end
end