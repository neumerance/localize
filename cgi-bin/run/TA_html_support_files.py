# TA_html_support_files.py

import os
import gzip


def get_support_file_name(support_file_directory, support_id):
    return os.path.join(support_file_directory, "id%i.gz" % support_id)

def get_id_from_support_file_path(file_name):
    base_name = os.path.basename(file_name)
    id = base_name[2:-3]
    return int(id)
    
def Build_support_files_for_project(project, support_file_directory):
    
    if project.is_source_type_local() or True:

        import wx

        project_working_directory = wx.GetApp().get_file_manager().get_project_working_directory(project.get_name())

        support_files = project.get_support_file_names_and_ids()
        
        root_length = len(support_file_directory) + 1
        
        for file in support_files:

                file_name = file[0]

                file_name = "%s\\%s" % (project_working_directory, file_name)
                file_name = os.path.normpath(file_name)

                try:
                    os.makedirs(os.path.dirname(file_name))
                except:
                    pass
                
                try:
                    support_name = get_support_file_name(support_file_directory, file[1])
                    zip = gzip.GzipFile(support_name, 'rb')
                    data = zip.read()
                    zip.close()
                
                    out = open(file_name, 'wb')
                    out.write(data)
                    out.close()
                except:
                    pass
    
def save_project_support_file(destination, project, support_file_directory, file_name):

    # make sure we don't over write existing files.
    
    if os.path.isfile(destination):
        return

    try:
        # we need to put in a try block as some support files may be missing
        # some support files may have been missing when creating the project.
        
        support_file_id = project.get_support_file_id(file_name)
        support_name = get_support_file_name(support_file_directory, support_file_id)
        
        zip = gzip.GzipFile(support_name, 'rb')
        data = zip.read()
        zip.close()
    
        try:
            os.makedirs(os.path.dirname(destination))
        except:
            # path exists.
            pass
        
        out = open(destination, 'wb')
        out.write(data)
        out.close()
    
    except:
        pass
    

def get_support_file_data(project, support_file_directory, file_name):


    try:
        # we need to put in a try block as some support files may be missing
        # some support files may have been missing when creating the project.
        
        support_file_id = project.get_support_file_id(file_name)
        support_name = get_support_file_name(support_file_directory, support_file_id)
        
        zip = gzip.GzipFile(support_name, 'rb')
        data = zip.read()
        zip.close()

        return data
    except:
        return None

