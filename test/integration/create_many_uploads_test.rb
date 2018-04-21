require "#{File.dirname(__FILE__)}/../test_helper"

class DeleteObjectsTest < ActionDispatch::IntegrationTest
  # IMPORTANT: The projects fixture is loaded but not used. It's needed to keep the project IDs different than the revision IDs.
  fixtures :users, :money_accounts, :languages, :currencies, :identity_verifications # , :projects, :revisions # , :chats

  def test_delete_existing
    UserSession.delete_all
    Bid.delete_all

    # log in as a client
    client = users(:amir)
    project = setup_full_project(client, 'with lots of support files')
    project_id = project.id
    session = login(client)

    for i in 0..20
      create_support_file(session, project_id, 'sample/support_files/styles.css.gz')
    end
  end

  def dont_test_version_create_memleak
    files_to_delete = []
    # log in as a client
    client = users(:amir)
    session = login(client)

    # create a project
    project_id = create_project(session, 'memleak project')
    project = Project.find(project_id)

    # create a new revision
    revision_id = create_revision(session, project_id, 'Created by test')
    revision = Revision.find(revision_id)

    # create a project file that includes the correct support file ID
    f = File.open("#{File.expand_path(Rails.root)}/test/fixtures/sample/multi_languages/big_file1.xml", 'rb')
    txt = f.read
    f.close
    fullpath = "#{File.expand_path(Rails.root)}/test/fixtures/sample/multi_languages/produced_big_file1.xml.gz"
    Zlib::GzipWriter.open(fullpath) do |gz|
      gz.write(txt)
    end
    files_to_delete << fullpath

    fsize = File.size(fullpath)

    for i in 0..50 do
      puts "uploading #{i}"
      # upload a bad project file (upload version)
      version_id = create_version(session, project_id, revision_id, 'sample/multi_languages/produced_big_file1.xml.gz', false)
    end

    # delete all temporary files
    files_to_delete.each { |file_to_delete| File.delete(file_to_delete) }
  end
end
