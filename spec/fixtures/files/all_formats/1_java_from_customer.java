###############################################################################

# CTG Language File
###############################################################################
# PREFIXES:
# sr = system role
# tit = title (other)
# e = enum
# bt = button
# tab = tab entry
# lbl = label (any other)
# hvr = hover text
# tpl = template text
##
# wrn = warning message
# err = error message
# msg = any other message (ok messages etc)
###############################################################################
ctg.warn_low_memory = The available memory on the server is low. Please notify the system administrator immediately\!    

#------------------------------------------------------------------------------
###############################################################################
# CORE language definitions, required in CTG
###############################################################################
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
# FormEngine labels
#------------------------------------------------------------------------------
err_back_button_not_allowed = The back button of your browser is not permitted. Please use only the navigation bars within the application. You will be now redirected to the last active page.
err_page_relocated = The requested page URL has changed. Please update your bookmarks. <p><a href\="{0}">Go to login page</a></p>  

#------------------------------------------------------------------------------
# Generic buttons / labels / hovers
#------------------------------------------------------------------------------
lbl_are_you_sure = Do you really want to continue?
lbl_entry_changer = Who
lbl_na = -

bt_edit = Submit changes
bt_delete = Delete
bt_submit = Save data
bt_cancel = Cancel
bt_revert = Discard
bt_add = Add
bt_back_to_overview = Back
bt_append = Accept
bt_yes = Yes
bt_no = No
bt_view = View
bt_search = Search
bt_exact_search = Exact search 
ctg.lbl_select_entry = <Select>
#------------------------------------------------------------------------------
# Sortable table
#------------------------------------------------------------------------------
hvr_search = Search
hvr_search_reset = Clear 
hvr_sortabletable_paged_output_forced_paging = Too many results to be displayed
hvr_sortabletable_paged_output_prev_page = Previous page
hvr_sortabletable_paged_output_next_page = Next page
hvr_sortabletable_sorting_asc = Sort ascending
hvr_sortabletable_sorting_desc = Sort descending
bt_sortabletable_paged_output_all = All

ctg.hvr_search_exact = Search for exact match

#------------------------------------------------------------------------------
# Date / time: labels for timezone selection if date is within transition time 
#------------------------------------------------------------------------------
lbl_summer_time = DST
lbl_winter_time = WT 
## {0} =lbl_summer_time {1} = lbl_winter_time
ctg.err_time_reference_time_ambiguous = The event time is ambiguous. Add '{0}' for daylight saving time or '{1}' for winter time.   

#------------------------------------------------------------------------------
# Generic warnings / errors
#------------------------------------------------------------------------------
wrn_javascript_disabled_title = Your browser has Javascript disabled.
wrn_javascript_disabled = In order to be able to use the full functionality of Trium CTG-Online, you have to activate Javascript\! <br>Open the Browser's preferences dialog and activate Javascript and <i>Reload</i> the page.
wrn_unsaved_data = Unsaved data. Click OK to dismiss changes or cancel to abort navigation.
ctg.wrn_unsupported_browser_title = This browser is not supported.
ctg.wrn_unsupported_browser_version_title = This browser version is not supported.
ctg.wrn_unsupported_browser_hint = For safe operation of the full functionality of Trium CTG Online it is highly recommended to use supported browsers only. Please refer to the Trium CTG Online Service Manual for a list of supported browsers. 
ctg.wrn_unsupported_platform_browser = The browser and/or the platform is not supported.
ctg.wrn_unsupported_browser_version_to_old_hint = Your browser version is too old. Upgrade your browser first.
ctg.wrn_unsupported_browser_version_newer_hint = Your browser version is newer than the latest version supported. Unforeseen issues might occur when using this particular browser. For further information contact the Service and Support.

err_missing_element_exception = Please select all fields on this form.
err_authentication_exception = Username or password wrong\!
err_authorization_exception = Permission denied\!
err_generic_exception = Transaction aborted due to an error.
err_critical_failure = A serious error has occurred and your session has been invalidated. Please notify your systems administrator in case that the error still exists after you have tried to login again.
err_database_exception = Transaction aborted due to a database error.
err_stale_object_exception = Transaction aborted due to parallel modification of a relevant record
err_search_too_many_hits = Too many search results found. Please narrow your search parameters.
err_address_invalid_email = The input doesn't look like an correct e-mail address.
err_invalid_date_format = The entered date has an invalid format.
err_page_not_found_exception = The page you requested does not exist.
ctg.err_cgi_imageproducer_generic = Cannot find the specified CTG recording.
ctg.err_cgi_imageproducer_1 = Method call with invalid parameters\!
ctg.err_cgi_imageproducer_2 = Archive file not found. Maybe the file was moved to a long term storage and must be restored first.
ctg.confirm_save_changes_msg = Do you want to save the changes? 
ctg.info_changes_msg = There are changes to save.
ctg.err_missing_or_wrong_parameter = Missing or wrong parameter '{0}'.

ctg.warn_watchdog_not_running = CTG Online Watchdog service is not running. If this problem persists, please notify your system administrator immediately.
ctg.warn_disk_space_check_failed = Failed to run disk space test. If this problem persists, please notify your system administrator immediately.
ctg.err_disk_space_low = The available disk space is critically low in directory {0}. Please notify the system administrator immediately\!
ctg.warn_disk_space_low = The available disk space is low in directory {0}. Please notify the system administrator\!
ctg.err_deprecated_plotter_image_requested = On a client PC, the display may be out of date. Verify that the displayed CTG recording is equivalent to the CTG paper strip output onsite. If this problem persists, please notify your system administrator immediately.
ctg.err_configuration = Initialization of Trium CTG Online failed. Check configuration of installation\! 
#------------------------------------------------------------------------------
# Login
#------------------------------------------------------------------------------

# Labels
lbl_login_user_name = Username
lbl_login_password = Password
lbl_login_password_old = Old password
lbl_login_password_new = New password
lbl_login_password_conf = Confirm new password
lbl_login_force_pwd_change = Change password on next login
lbl_login_roles = Permissions
lbl_login_select_profile = Select a profile
bt_login_submit = Login

# Errors (login)
err_login_account_locked = This account is locked.
err_login_account_expired = This account has expired.
err_login_user_name_required = Please enter an username.
err_login_user_name_not_unqiue = This username is already in use. Please choose a different one.
err_login_passwords_dont_match = The two passwords entered are not equal. Please enter your new password into both text fields again\!
err_login_role_required = Please assign a user role.
err_login_insecure_password = Please choose a safe password.
err_login_new_and_old_passwords_match = Your new password is identical to the previous one.

#------------------------------------------------------------------------------
# Person
#------------------------------------------------------------------------------
# Labels
lbl_person_title = Title
lbl_person_salutation = Salutation
lbl_person_first_name = First name
lbl_person_last_name = Last name

# Salutation
e_gender_male = Mr.
e_gender_female = Mrs.
e_gender_unknown = <Salutation>

# Titles
e_title_prof = Prof.
e_title_none = <None>
e_title_dr = Dr.
e_title_pd = PD
e_title_drmed = MD
e_title_phd = PhD
e_title_md = MD
e_title_md_phd = MD PhD
e_title_mr = Mr.
e_title_mrs = Mrs. 
e_title_miss = Miss

# Errors (person)
err_person_last_name_required = Please enter last name.
err_person_first_name_required = Please enter first name.
err_person_person_not_unqiue = A person with the same name is already registered.

#------------------------------------------------------------------------------
# Communication
#------------------------------------------------------------------------------
lbl_comm_phone = Phone
lbl_comm_fax = Fax
lbl_comm_email = Email
lbl_comm_mobile = Mobile
lbl_comm_pager = Pager

#------------------------------------------------------------------------------
# CTG TRANSLATIONS
#------------------------------------------------------------------------------
tit_application_title = CTG Online
sr_manage_users = Add users
sr_manage_own_details = Manage own details
sr_manage_annotation_templates = Manage templates 
sr_lock_records = Lock recordings
sr_download_pdf = Allow download of PDF
sr_download_raw = Allow download of RAW data
sr_manage_his_export = Allow user to view HIS export list  
sr_manage_edit_annotation = Edit annotation 
sr_manage_delete_annotation = Delete annotation 
sr_view_rainbow_diagram = View JGuideline rainbow diagram in signal history
sr_view_rainbow_in_detail_view = View J-Guideline rainbow diagram in single trace view
###############################################################################
# Generic
###############################################################################
ctg.err_ctg_image_load = Failed to load CTG data\!

# Sortable table
ctg.bt_sortabletable_date_range_max_days = Max ({0} days)
ctg.bt_sortabletable_date_range_all = Unlimited
ctg.bt_sortabletable_date_range_today = Today
ctg.bt_sortabletable_date_range_yesterday = Yesterday
ctg.bt_sortabletable_date_range_week = Week
ctg.bt_sortabletable_date_range_month = Month

ctg.err_recording_not_active = The CTG recording is not active.
ctg.msg_values_changed_but_not_saved = Data have been modified but not yet saved.
ctg.err_search_no_hits = The search produced no results. Please refine your search parameters.
ctg.err_search_no_hits_can_add_patient = The search produced no results. Please refine your search parameters or add a new patient.
ctg.err_add_patient_too_many_search_hits = Too many similar patients were found. \n\
	Please refine your search parameters or add a new patient by pressing the "New patient" button again.   
ctg.err_add_patient_missing_search_criteria = Please enter at least the last name to add a new patient.
ctg.err_search_in_chalkboard_no_hits_1 = No match found. Try other keywords or search  
ctg.err_search_in_chalkboard_no_hits_2 = in the patient archive.
###############################################################################
# Configuration params
###############################################################################
ctg.e_operation_mode_ctgonline = Trium CTG Online
ctg.e_operation_mode_ctgmobile = Trium CTG Mobile

###############################################################################
# Enums
###############################################################################
ctg.e_person_position_physician = Physician
ctg.e_person_position_midwife = Midwife
ctg.e_person_position_other = <Other>
ctg.e_person_position_consultant = Consultant
ctg.e_person_position_system_manager = System Manager
ctg.e_person_position_specialist = Specialist
ctg.e_person_position_registrar = Registrar
ctg.e_person_position_doctor = Doctor

###############################################################################
# Login
###############################################################################
ctg.tit_login_window_ctgonline = Trium CTG Online
ctg.tit_login_window_ctgmobile = Trium CTG Mobile

# Password notes
ctg.lbl_login_version = Version
ctg.lbl_login_copyright = Copyright
ctg.lbl_login_root_cert_p1 = First time users\: Please download and install Trium
ctg.lbl_login_root_cert_link = CTG root certificate
ctg.lbl_login_root_cert_p2 = first.
ctg.lbl_login_requirements_css = A CSS2 compliant browser is required.

###############################################################################
# MainWindow
###############################################################################
ctg.tit_main_window_frameset = Trium CTG Online - CTG Monitoring
ctg.tit_main_window_navigation = Trium CTG Online - CTG Monitoring
ctg.tit_main_window_charts = Trium CTG Online - CTG Monitoring
ctg.tit_about = About

# -- Navigation buttons --
ctg.bt_main_window_navigation_options = Patient management
ctg.hvr_main_window_navigation_options = Patient data, archive, comment function, configuration, about

###############################################################################
# Bed
###############################################################################
ctg.lbl_bed_name = FM connection
ctg.lbl_bed_select = <FM connection>
ctg.lbl_monitor_name = Fetal monitor
ctg.lbl_monitor_select = <Fetal monitor>
ctg.lbl_bed_sticky = Permanent assignment
ctg.lbl_bed_active_postfix = <Active>
ctg.lbl_bed_tag_name = Location
ctg.lbl_bed_tag_select = <Location>

###############################################################################
# Recording
###############################################################################
ctg.lbl_recording_start = Begin
ctg.lbl_recording_stop = End
ctg.lbl_recording_duration = Duration
ctg.lbl_recording_resume = Resume

ctg.msg_recording_acknowledged = End of recording confirmed 
ctg.hvr_export_recording = Export recording
ctg.hvr_exported_recording = Recording already exported 
ctg.err_recording_pdf_export_failed = Export of PDF report failed.
###############################################################################
# Statistic  Recordings
###############################################################################

ctg.tit_tab_statistic = Statistics
ctg.tit_statistic_recording = Statistics of CTG recordings


ctg.lbl_statistic_recording_date = Date
ctg.lbl_statistic_recording_recs = CTGs
ctg.lbl_statistic_recording_mean_dur = Mean duration
ctg.lbl_statistic_recording_patient = Pat.
ctg.lbl_statistic_recording_ass_pct = Assigned
ctg.lbl_statistic_recording_ass_rec = CTGs
ctg.lbl_statistic_recording_ass_dur = Duration
ctg.lbl_statistic_recording_ass_mean_dur = Mean duration
ctg.lbl_statistic_recording_unass_pct = Unassigned
ctg.lbl_statistic_recording_unass_rec = CTGs
ctg.lbl_statistic_recording_unass_dur = Duration
ctg.lbl_statistic_recording_unass_mean_dur = Mean duration
ctg.lbl_statistic_recording_mid_over = O


ctg.hvr_statistic_number = total number
ctg.hvr_statistic_dur = total duration
ctg.hvr_statistic_mean_dur = mean duration
ctg.hvr_statistic_recording = \ of all recordings
ctg.hvr_statistic_patient = \ of all patients
ctg.hvr_statistic_pct = Percent
ctg.hvr_statistic_ass_recording = \ of assigned recordings
ctg.hvr_statistic_unass_recording = \ of unassigned recordings
ctg.hvr_statistic_recording_mid_over = number of recordings with overlapping date range

ctg.lbl_statistic_filter = Filter\:
ctg.hvr_statistic_set_filter = Set Filter
ctg.lbl_statistic_apply_filter = Apply
ctg.lbl_statistic_reset_filter = Reset
ctg.lbl_statistic_searched_text = Searched text\:
ctg.lbl_statistic_user = User\:
ctg.lbl_statistic_no_search_text = No
ctg.hvr_statistic_button_chart_view = Chart view 
ctg.hvr_statistic_button_table_view = Table view 
ctg.lbl_statistic_result = with {0} Results
ctg.lbl_statistic_restrict_date_disable = Restrict date range (no filter)
ctg.lbl_statistic_restrict_date = Restrict date range
ctg.lbl_statistic_from_date = 'from' date\:
ctg.lbl_statistic_untill_date = 'to' date\:
ctg.lbl_statistic_duration_hour = h
ctg.lbl_statistic_duration_min = min
ctg.lbl_statistic_search_text = \ and contains text '{0}'
ctg.lbl_statistic_recordings_until = Restrict date range until 
ctg.lbl_statistic_recordings_from = Restrict date range from 
ctg.lbl_statistic_recordings_from_to = Restrict date range between {0} and {1}
ctg.lbl_statistic_header_info = Page {0} of {1} with {2} results
ctg.lbl_statistic_page_number_info = Page {0} of {1}
ctg.err_statistic_invalid_date = Please enter a valid date
ctg.err_statistic_from_greater_until = Please enter a valid date range ('until' date should be greater than 'from' date)
ctg.err_statistic_from_and_until_greater_today = Please enter a valid date range ('from' and 'until' date should be less than today)
ctg.err_statistic_from_greater_today = Please enter a valid date range ('from' date should be less than today)
ctg.err_statistic_until_greater_today = Please enter a valid date range ('until' date should be less than today)
ctg.lbl_statistic_group_by = Group by


ctg.bt_sortabletable_group_by_day = Day
ctg.bt_sortabletable_group_by_week = Week
ctg.bt_sortabletable_group_by_month = Month
ctg.bt_sortabletable_group_by_year = Year
ctg.bt_sortabletable_group_by_total = Total

ctg.tit_chartview_combined_plot = Chart of statistic recordings
ctg.tit_chartview_first_plot = Number
ctg.tit_chartview_second_plot = Percent
ctg.tit_chartview_third_plot = Mean duration
ctg.tit_chartview_legend_ass_rec = Assigned recordings
ctg.tit_chartview_legend_unass_rec = Unassigned recordings
ctg.tit_chartview_legend_total_rec = All recordings

###############################################################################
# Options
###############################################################################
ctg.tit_options_frameset = Trium CTG Online - Data management window

#------------------------------------------------------------------------------
# Navigation
#------------------------------------------------------------------------------
ctg.bt_options_navigation_home = Data management window
ctg.bt_options_navigation_extras = Options
ctg.bt_options_navigation_help = Help
ctg.bt_options_navigation_quit = Quit
ctg.bt_options_navigation_about = About

#------------------------------------------------------------------------------
# Chalkboard main tab entries
#------------------------------------------------------------------------------
ctg.tab_chalk_board_patient = Patient list
ctg.tab_chalk_board_patient_search = Patient archive
ctg.tab_add_patient = New patient
ctg.tab_chalk_board_user = Users
ctg.tab_chalk_board_ctg_archive = CTG archive
ctg.tab_chalk_board_orphans = Unassigned CTGs
ctg.tab_chalk_board_recording_ack = Unacknowledged CTGs
ctg.tab_chalkboard_username_format = {0} {1}
#------------------------------------------------------------------------------
# Patient management / chalkboard
#------------------------------------------------------------------------------
ctg.tit_patient_overview = Patient management
ctg.tit_patient_chalkboard = Patient list
ctg.hvr_print_patient_chalkboard_html = Show patient list as printable HTML version
ctg.hvr_print_patient_chalkboard_excel = Show patient list as printable EXCEL version
ctg.tit_print_patient_chalkboard_state = State\: 
ctg.tit_patient_details = Edit patient  <{0} {1}> / discharge
ctg.tit_patient_new_patient = New patient
ctg.tit_patient_create_case = New pregnancy

ctg.lbl_patient_search_hint = Click on one of the search buttons
ctg.lbl_patient_add_similar_patients_hint = Following existing patients were found that match the data you have entered. Please choose one of these patients or add a new patient by pressing the "New patient" button.

ctg.tab_patient_case = Patient data

ctg.lbl_patient_search = Search patient
ctg.lbl_patient_matching = Matching patients
ctg.lbl_patient_details = Patient data
ctg.lbl_patient_id_edit_desc = ID
ctg.lbl_patient_id = ID
ctg.lbl_patient_name = Name
ctg.lbl_patient_first_name = First name
ctg.lbl_patient_last_name = Last name
ctg.lbl_patient_date_of_birth = Date of birth
ctg.lbl_patient_date_of_birth_short = DOB
ctg.lbl_patient_age = Age

###
### do not translate this key!
ctg.lbl_patient_nhs_number = NHS number
###
### do not translate this key!
ctg.lbl_patient_nhs_number_status = NHS number status

ctg.lbl_patient_cases = Pregnancies
ctg.lbl_patient = Patient
ctg.lbl_physician = Physician
ctg.lbl_midwife = Midwife
ctg.lbl_phys_mid = Phys / Mid
ctg.lbl_patient_select = <Patient>
ctg.lbl_physician_select = <Physician>
ctg.lbl_midwife_select = <Midwife>

ctg.lbl_case_data = Case data
ctg.lbl_case_old_value = Old value
ctg.lbl_case_new_value = New value
ctg.hvr_case_calculate_cdd = Calculate EDD from last menstruation.
ctg.lbl_case_gestation_week = GW
ctg.lbl_case_lmp = LMP
ctg.lbl_case_cdd = EDD (calculated)
ctg.lbl_case_edd = EDD (corrected)
ctg.lbl_case_para = Para
ctg.lbl_case_gravida = Gravida
ctg.lbl_case_gravida_para = G / P
ctg.lbl_case_date_of_delivery = Date of delivery
ctg.lbl_delivery_date = Date of delivery
ctg.lbl_bed_tag = Location

ctg.hvr_patient_add_patient = New patient
ctg.hvr_patient_resume_patient = Readmission / new pregnancy
ctg.hvr_toggle_to_patient_overview = Add patient to patient list
ctg.hvr_add_to_chalkboard = Add to patient list
ctg.hvr_add_to_chalkboard_na = Patient discharged / delivered
ctg.hvr_add_to_chalkboard_na_case_missing = Case missing
ctg.hvr_remove_from_chalkboard = Remove from patient list

ctg.bt_patient_discharge = Discharge
ctg.bt_patient_new_patient = Add
ctg.bt_patient_new_case = New pregnancy
ctg.bt_patient_resume_case = Readmission
ctg.bt_patient_delivered = Delivered

ctg.err_patient_first_name_required = Please enter first name.
ctg.err_patient_last_name_required = Please enter last name.
ctg.err_patient_id_already_exists = The patient ID is already used.
ctg.err_patient_invalid_id = The patient ID has to be numeric.
ctg.err_patient_id_invalid_format = Patient ID format not valid.
ctg.err_patient_external_create_case = Patient with old case. Please use your maternity or hospital information system to add a new case. CTG traces will be stored.   
ctg.err_case_invalid_lmp = The last menstruation date is not plausible.
ctg.err_case_invalid_edd = Please enter a valid corrected date of delivery
ctg.err_case_gravida_range = The allowed range for gravida is between {0} and {1}.
ctg.err_case_para_range = The allowed range for para is between {0} and {1}.
ctg.err_case_para_gte_gravida = Para has to be lower than gravida.
ctg.err_patient_matching_no_results = No matching patient found.
ctg.err_patient_invalid_date_of_birth = The date of birth must be given and valid.
ctg.err_patient_emr_matching_no_results = No match found for patient with patient ID\: {0}. Verify the patient ID or the "EMR access" settings in the configuration tool. 
ctg.err_patient_emr_matching_multiple_results = Multiple matches found for patient with patient ID {0}. Verify the "EMR access" settings in the configuration tool. 
ctg.err_patient_emr_missing_patientId = Missing or wrong patient parameter (patient ID). Verify the patient ID or the "EMR access" settings in the configuration tool. 
ctg.err_patient_unknown_pregnancyId = No match found. Verify the pregnancy ID.
ctg.err_ext_case_invalid_number = Please enter a valid number.
ctg.err_ext_case_invalid_date = Please enter a valid date.
ctg.err_value_between_min_and_max = The allowed range for {0} is between {1} and {2}.
ctg.err_value_is_required = {0} is required.

###
### do not translate this key!
ctg.err_patient_invalid_nhs_number = The NHS number is invalid.
###
### do not translate this key!
ctg.err_patient_invalid_nhs_number_hint = The stored NHS number is invalid\: {0}

ctg.err_case_bed_already_occupied = The monitor was occupied in the meantime.
ctg.err_case_discharge_running_recording = The patient you want to archive is assigned to an ongoing CTG recording. Please terminate the CTG recording first or correct the patient assignment.
ctg.err_case_date_of_birth_of_newborn_out_of_range = The date of birth is not plausible.
ctg.err_case_already_delivery = The specified case is already documented as delivered. Do you want to create a new case?   
ctg.err_case_old_recommend_to_create_new_case = Case seems not to belong to the current pregnancy. To create a new pregnancy select "{0}".      
ctg.err_bed_overlap = Assignment with overlapping recordings. \n\
	Press the "{0}" button to cancel or the "{1}" button to ignore. 
ctg.err_bed_tag_without_bed = {0} without {1} selected. 
ctg.err_case_discharged = Patient is currently marked as discharged. \n\
	Press the "{0}" button to readmit or the "{1}" button to cancel.  
ctg.err_case_closed = Patient is currently marked with case closed. Do you want to create a new case?  
ctg.msg_patient_discharge = Do you really want to discharge the patient?
ctg.msg_patient_discharge_delivered = Do you want to discharge the patient or has the patient already delivered?
ctg.msg_patient_delivery_date_msg = Date of birth of newborn\:

# enums for NHS support (do NOT translate keys "ctg.e_nhs_number_status_xy"!)
ctg.e_nhs_number_status_00 = <status not available>
ctg.e_nhs_number_status_01 = Number present and verified
ctg.e_nhs_number_status_02 = Number present but not traced
ctg.e_nhs_number_status_03 = Trace required
ctg.e_nhs_number_status_04 = Trace attempted - No match or multiple match found
ctg.e_nhs_number_status_05 = Trace needs to be resolved - (NHS Number or patient detail conflict)
ctg.e_nhs_number_status_06 = Trace in progress
ctg.e_nhs_number_status_07 = Number not present and trace not required
ctg.e_nhs_number_status_08 = Trace postponed (baby under six weeks old)

ctg.hvr_already_in_chalkboard = Patient in patient list
ctg.lbl_show_in_chalkboard = Show in patient list
ctg.lbl_cause_of_discharge = Cause of discharge
ctg.bt_patient_case_closed = Case closed
#------------------------------------------------------------------------------
# Partograph
#------------------------------------------------------------------------------

ctg.hvr_open_partogram = Open partogram

## Score
ctg.lbl_alarm_jguideline_1 = normal pattern
ctg.lbl_alarm_jguideline_2 = subnormal pattern 
ctg.lbl_alarm_jguideline_3 = abnormal pattern level I
ctg.lbl_alarm_jguideline_4 = abnormal pattern level II
ctg.lbl_alarm_jguideline_5 = abnormal pattern level III
ctg.lbl_detailed_alarm_panel_lower_limit = Lower limit
ctg.lbl_detailed_alarm_panel_upper_limit = Upper limit
ctg.lbl_detailed_alarm_panel_lower_limit_long = Lower limit
ctg.lbl_detailed_alarm_panel_upper_limit_long = Upper limit

### short
ctg.lbl_alarm_jguideline_1_short = normal pattern
ctg.lbl_alarm_jguideline_2_short = subnormal pattern 
ctg.lbl_alarm_jguideline_3_short = abnormal pattern level I
ctg.lbl_alarm_jguideline_4_short = abnormal pattern level II
ctg.lbl_alarm_jguideline_5_short = abnormal pattern level III
ctg.lbl_threshold_range = (NR {0}-{1})
ctg.lbl_threshold_range_value = (NR {0}-{1} {2})
ctg.lbl_alarm_threshold_in_range = in range
ctg.lbl_alarm_threshold_in_range_short = in range
ctg.lbl_alarm_threshold_in_range_long = in range
ctg.lbl_detailed_alarm_panel_lower_limit_short = B
ctg.lbl_detailed_alarm_panel_upper_limit_short = T
ctg.lbl_report_episode_figo_normal_short = FIGO normal
ctg.lbl_report_episode_figo_suspect_short = FIGO suspect
ctg.lbl_report_episode_figo_pathologic_short = FIGO pathological
ctg.lbl_report_episode_figo_notinterpretable_short = Not interpretable
ctg.lbl_report_episode_figo_undefind_short = Undefined
ctg.lbl_report_print_date = printed on\: {0}
ctg.lbl_report_table_annotation_reference_date = Event date\:
ctg.lbl_report_table_annotation_reference_time = Event time\:
ctg.lbl_report_table_annotation_text = Diagnosis/Result\:
ctg.lbl_report_table_annotation_creator = Created by\:
ctg.lbl_report_table_annotation_creation_date = Creation date\:
ctg.lbl_report_table_annotation_creation_time = Creation time\:
ctg.lbl_report_table_crf_header = Change history of course of labour\:
ctg.lbl_report_table_annotation_deleted = deleted
ctg.lbl_report_table_annotation_moved_to = changed to\:
ctg.lbl_report_table_annotation_changed_moved_to = edited and changed to\:
ctg.lbl_report_table_annotation_edited = (edited)
ctg.lbl_report_table_annotation_change_to_ongoing = changed to "Ongoing"

ctg.lbl_ext_case_ctg_long = CTG
ctg.lbl_ext_case_ctg_short = CTG
ctg.lbl_ana_ctg_score_long = Score
ctg.lbl_ana_ctg_score_short = Score
ctg.lbl_ext_case_presentation_long = Presentation
ctg.lbl_ext_case_multiples_long = Type of gestation
ctg.lbl_ext_case_multiples_short = TOG
ctg.lbl_ext_case_characteristics_short = Characteristics
ctg.lbl_ext_case_characteristics_long = Characteristics
ctg.lbl_ext_case_blood_group_short = Blood group
ctg.lbl_ext_case_blood_group_long = Blood group
ctg.lbl_ext_case_rhesus_short = Rhesus
ctg.lbl_ext_case_rhesus_long = Rhesus
ctg.lbl_ext_case_start_time_long = Start time (partogram)
ctg.lbl_ext_case_start_time_short = Start time
ctg.lbl_ext_case_visible_length = Visible length

ctg.lbl_ext_case_header1_long = Header1
ctg.lbl_ext_case_header2_long = Header2
ctg.lbl_ext_case_header3_long = Header3
ctg.lbl_ext_case_other_long = Other

ctg.lbl_ext_case_trace_of_birth_long = Course of labour
ctg.lbl_ext_case_admission_long = Admission
ctg.lbl_ext_case_onset_of_labour_long = Onset of labour

ctg.lbl_ext_case_rupture_membranes_long = Rupture of membranes
ctg.lbl_ext_case_rupture_membranes_short = ROM

## Key 'ctg.lbl_ext_case_patient_data' duplicates 'ctg.tab_patient_case'
ctg.lbl_ext_case_patient_data = Patient data
ctg.lbl_ext_case_patient_data_long = General
ctg.lbl_ext_case_patient_data_short = General
## Duplicates key 'ctg.parto_case_birth_protocol' (CTGGUI)
ctg.lbl_ext_case_course_of_labour = Course of labour
ctg.lbl_ext_case_course_of_labour_long = General
ctg.lbl_ext_case_course_of_labour_short = General 
ctg.lbl_ext_case_birth1 = Birth 1
ctg.lbl_ext_case_birth1_long = Birth 1
ctg.lbl_ext_case_birth1_short = Birth 1
ctg.lbl_ext_case_birth2 = Birth 2
ctg.lbl_ext_case_birth2_long = Birth 2
ctg.lbl_ext_case_birth2_short = Birth 2
ctg.lbl_ext_case_2nd_stage_short = 2nd stage
ctg.lbl_ext_case_2nd_stage_long = 2nd stage

ctg.lbl_ext_case_date_of_delivery_long = Date of delivery
ctg.lbl_ext_case_date_of_delivery_short = DOD

ctg.lbl_ext_case_physician_long = Certified physician

ctg.lbl_ext_case_cervix_complete_long = Full dilatation
ctg.lbl_ext_case_cervix_complete_short = Full dilatation
ctg.lbl_ext_case_rupture_membranes_type_long = ROM type
ctg.lbl_ext_case_rupture_membranes_type_short = ROM type
ctg.lbl_ext_case_rupture_membrane_type_spontaneous = SROM
ctg.lbl_ext_case_rupture_membrane_type_premature = PROM

ctg.lbl_ext_case_rupture_membrane_type_artifical = AROM

ctg.lbl_ext_case_expulsive_stage_long = active 2nd stage
ctg.lbl_ext_case_expulsive_stage_short = active 2nd stage
ctg.lbl_ext_case_placenta_long = Placenta delivered
ctg.lbl_ext_case_placenta_short = Placenta
ctg.lbl_ext_case_placenta_state_long = Placenta status
ctg.lbl_ext_case_placenta_state_short = Status
ctg.lbl_ext_case_placenta_blood_loss_long = Blood loss
ctg.lbl_ext_case_placenta_blood_loss_short = Blood loss
ctg.lbl_ext_case_placenta_state_complete = Complete
ctg.lbl_ext_case_placenta_state_incomplete = Incomplete
ctg.lbl_ext_case_comments_long = Comments
ctg.lbl_ext_case_comments_short = Comments
ctg.lbl_ext_case_mode_of_delivery_long = Mode of delivery
ctg.lbl_ext_case_mode_of_delivery_short = Mode
ctg.lbl_ext_case_gender_long = Gender
ctg.lbl_ext_case_gender_short = Gender
ctg.lbl_ext_case_gender_female = Female
ctg.lbl_ext_case_gender_male = Male
ctg.lbl_ext_case_gender_unknown = Unknown
ctg.lbl_ext_case_weight_long = Weight
ctg.lbl_ext_case_weight_short = Weight
ctg.lbl_ext_case_length_long = Length
ctg.lbl_ext_case_length_short = Length
ctg.lbl_ext_case_head_circumference_long = Head circumference
ctg.lbl_ext_case_head_circumference_short = Head
ctg.lbl_ext_case_apgar_long = APGAR
ctg.lbl_ext_case_apgar_short = APGAR
ctg.lbl_ext_case_umbilical_cord_ph_long = UmA. pH
ctg.lbl_ext_case_umbilical_cord_ph_short = UmA. pH
ctg.lbl_ext_case_umbilical_cord_be_long = UmA. BE
ctg.lbl_ext_case_umbilical_cord_be_short = UmA. BE

ctg.lbl_unit_min = min
ctg.lbl_unit_ml = ml
ctg.lbl_unit_cm = cm
ctg.lbl_unit_gram = g
ctg.lbl_unit_mmol_l = mmol/l


ctg.tab_partograph_long = Partogram
ctg.tab_partograph_short = Parto
ctg.lbl_parto_vaginale_form_long = Vaginal examination
ctg.lbl_parto_vital_form_long = Vital signs
ctg.lbl_parto_ctg_form_long = CTG
ctg.lbl_parto_it_form_long = IV therapy
ctg.lbl_parto_ann_form_long = Annotation
ctg.lbl_parto_pda_form_long = Epidural

ctg.lbl_parto_cervix_long = Cervix
ctg.lbl_parto_cervix_short = Cervix
ctg.lbl_parto_cervix_position_long = Cervix position
ctg.lbl_parto_cervix_position_short = Cervix pos.
ctg.lbl_parto_cervix_length_long = Cervix effacement
ctg.lbl_parto_cervix_length_short = Cervix eff.
ctg.lbl_parto_cervix_consistency_long = Cervix consistency
ctg.lbl_parto_cervix_consistency_short = Cervix cons.
ctg.lbl_parto_mm_long = Cervix
ctg.lbl_parto_mm_short = C
ctg.lbl_parto_mm_weite_long = Dilatation
ctg.lbl_parto_mm_weite_short = CD
ctg.lbl_parto_fb_long = Amniotic sac
ctg.lbl_parto_fb_short = AS
ctg.lbl_parto_fw_long = Membrane/Fluid
ctg.lbl_parto_fw_short = M/F
ctg.lbl_parto_lg_long = Position
ctg.lbl_parto_lg_short = Po
ctg.lbl_parto_fp_long = Delivery presentation
ctg.lbl_parto_fp_short = DP
ctg.lbl_parto_fp_hh_long = Fetal station
ctg.lbl_parto_fp_hh_short = Station
ctg.lbl_parto_fp_lg_long = Fetal position
ctg.lbl_parto_fp_lg_short = FP
ctg.lbl_parto_ws_long = Uterine activity
ctg.lbl_parto_ws_short = UA
ctg.lbl_parto_ps_long = Patient status
ctg.lbl_parto_ps_short = PS
ctg.lbl_parto_mk_long = Drugs
ctg.lbl_parto_mk_short = Drugs
ctg.lbl_parto_it_long = IV therapy
ctg.lbl_parto_it_short = IV
ctg.lbl_parto_gg_long = Fetal skull  moulding
ctg.lbl_parto_gg_short = Moulding
ctg.lbl_parto_mbu_long = Blood gas analysis
ctg.lbl_parto_mbu_short = BGA
ctg.lbl_parto_mbu_ph_long = pH value 
ctg.lbl_parto_mbu_ph_short = pH
ctg.lbl_parto_mbu_ph_unit = pH
ctg.lbl_parto_mbu_be_long = BE value 
ctg.lbl_parto_mbu_be_short = BE
ctg.lbl_parto_mbu_be_unit = mmol/l
ctg.lbl_parto_mbu_po2_long = PaO2 value 
ctg.lbl_parto_mbu_po2_short = PaO2
ctg.lbl_parto_mbu_po2_unit = mmHg
ctg.lbl_parto_mbu_pso2_long = PaCO2 value 
ctg.lbl_parto_mbu_pso2_short = PaCO2
ctg.lbl_parto_mbu_pso2_unit = mmHg
ctg.lbl_parto_pda_long = Epidural analgesia
ctg.lbl_parto_pda_short = Epidural
ctg.parto_edit_ongoing_long = Ongoing
ctg.lbl_parto_temp_long = Temperature 
ctg.lbl_parto_temp_short = Temp
ctg.lbl_parto_temp_unit = \u00B0C
ctg.lbl_parto_urin_long = Urine
ctg.lbl_parto_urin_short = Urine
ctg.lbl_parto_ann_long = Annotation
ctg.lbl_parto_ann_short = Ann


ctg.lbl_parto_nibp_long = Blood pressure
ctg.lbl_parto_nibp_unit = mmHg
ctg.lbl_parto_nibp_short = BP
ctg.lbl_parto_nibp_dia_long = Diastolic pressure
ctg.lbl_parto_nibp_dia_short = Dia
ctg.lbl_parto_nibp_sys_long = Systolic pressure
ctg.lbl_parto_nibp_sys_short = Sys
ctg.lbl_parto_nibp_mean_long = Mean pressure
ctg.lbl_parto_nibp_mean_short = Mean BP
ctg.lbl_parto_nibp_mhr_long = Maternal heart rate
ctg.lbl_parto_nibp_mhr_short = MHR
ctg.lbl_parto_mhr_unit = bpm

ctg.lbl_parto_so2_long = Oxygen saturation
ctg.lbl_parto_so2_short = SpO2
ctg.lbl_parto_so2_mspo2_long = Maternal oxygen saturation
ctg.lbl_parto_so2_mspo2_short = MSpO2
ctg.lbl_parto_mspo2_unit = %
ctg.lbl_parto_so2_mhr_long = Maternal heart rate
ctg.lbl_parto_so2_mhr_short = MHR

#Enums for multiples
ctg.e_case_multiples_unknown = <Unknown>
ctg.e_case_multiples_single = Single
ctg.e_case_multiples_double = Twins
ctg.e_case_multiples_triple = Triplet
ctg.e_case_multiples_quadruplet = Quadruplet

# Template for blood group in Partograph
ctg.tpl_case_blood_group_a = A
ctg.tpl_case_blood_group_0 = 0
ctg.tpl_case_blood_group_b = B
ctg.tpl_case_blood_group_ab = AB

# Template for Rhesus in Partograph
ctg.tpl_case_rhesus_positive = Positive
ctg.tpl_case_rhesus_negative = Negative
ctg.tpl_case_rhesus_unknown = Unknown

# Template items for cervix
ctg.tpl_parto_cervix_position_post = Posterior
ctg.tpl_parto_cervix_position_mid = Intermediate
ctg.tpl_parto_cervix_position_ant = Anterior

ctg.tpl_parto_cervix_effacement_30 = 0-30%
ctg.tpl_parto_cervix_effacement_50 = 31-50%
ctg.tpl_parto_cervix_effacement_80 = 51-80%
ctg.tpl_parto_cervix_effacement_100 = > 80%

ctg.tpl_parto_cervix_consistency_firm = Firm
ctg.tpl_parto_cervix_consistency_mid = Intermediate
ctg.tpl_parto_cervix_consistency_soft = Soft

# Template item for Muttermund Weite
ctg.tpl_parto_mm_weite_0 = 0
ctg.tpl_parto_mm_weite_1 = 1
ctg.tpl_parto_mm_weite_2 = 2
ctg.tpl_parto_mm_weite_3 = 3
ctg.tpl_parto_mm_weite_4 = 4
ctg.tpl_parto_mm_weite_5 = 5
ctg.tpl_parto_mm_weite_6 = 6
ctg.tpl_parto_mm_weite_7 = 7
ctg.tpl_parto_mm_weite_8 = 8
ctg.tpl_parto_mm_weite_9 = 9
ctg.tpl_parto_mm_weite_10 = 10


# Template for Fruchtblase/Fruchtwasser
ctg.tpl_parto_fw_intact = Membranes intact
ctg.tpl_parto_fw_PROM = PROM
ctg.tpl_parto_fw_SROM = SROM
ctg.tpl_parto_fw_ARM = ARM

ctg.tpl_parto_fw_clear = Clear
ctg.tpl_parto_fw_green = Meconium stained
ctg.tpl_parto_fw_brown = Brown
ctg.tpl_parto_fw_nicht_beurteilbar = Not evaluable





# Template for F�hrungspunkt (FP)
ctg.tpl_parto_fp_lg_small_font_palpable = Posterior fontanel palpable
ctg.tpl_parto_fp_lg_small_font_front = OA (occipito anterior)
ctg.tpl_parto_fp_lg_small_font_left_front = LOA
ctg.tpl_parto_fp_lg_small_font_left = LOT
ctg.tpl_parto_fp_lg_small_font_left_rear = LOP
ctg.tpl_parto_fp_lg_small_font_rear = OP (occipito posterior)
ctg.tpl_parto_fp_lg_small_font_right_rear = ROP
ctg.tpl_parto_fp_lg_small_font_right = ROT
ctg.tpl_parto_fp_lg_small_font_right_front = ROA

ctg.tpl_parto_fp_lg_large_font_palpable = Anterior fontanel palpable
ctg.tpl_parto_fp_lg_large_font_front = OP (occipito posterior)
ctg.tpl_parto_fp_lg_large_font_left_front = ROP
ctg.tpl_parto_fp_lg_large_font_left = ROT
ctg.tpl_parto_fp_lg_large_font_left_rear = ROA
ctg.tpl_parto_fp_lg_large_font_rear = OA (occipito anterior)
ctg.tpl_parto_fp_lg_large_font_right_rear = LOA
ctg.tpl_parto_fp_lg_large_font_right = LOT
ctg.tpl_parto_fp_lg_large_font_right_front = LOP

ctg.tpl_parto_font_other = Other

ctg.tpl_parto_fp_lg_both_font_palpable = Both fontanels palpable
ctg.tpl_parto_fp_lg_both_fonts_small_front_large_rear = OA (occipito anterior)
ctg.tpl_parto_fp_lg_both_fonts_small_left_front_large_right_rear = LOA
ctg.tpl_parto_fp_lg_both_fonts_small_left_large_right = LOT
ctg.tpl_parto_fp_lg_both_fonts_small_left_rear_large_right_front = LOP
ctg.tpl_parto_fp_lg_both_fonts_small_rear_large_front = OP (occipito posterior)
ctg.tpl_parto_fp_lg_both_fonts_small_right_rear_large_left_front = ROP
ctg.tpl_parto_fp_lg_both_fonts_small_right_large_left = ROT
ctg.tpl_parto_fp_lg_both_fonts_small_right_front_large_left_rear = ROA

ctg.tpl_parto_fp_lg_forehead = Brow
ctg.tpl_parto_fp_lg_forehead_large_font_front = OP (occipito posterior)
ctg.tpl_parto_fp_lg_forehead_large_font_left_front = ROP
ctg.tpl_parto_fp_lg_forehead_large_font_left = ROT
ctg.tpl_parto_fp_lg_forehead_large_font_left_rear = ROA
ctg.tpl_parto_fp_lg_forehead_large_font_rear = OA (occipito anterior)
ctg.tpl_parto_fp_lg_forehead_large_font_right_rear = LOA
ctg.tpl_parto_fp_lg_forehead_large_font_right = LOT
ctg.tpl_parto_fp_lg_forehead_large_font_right_front = LOP

ctg.tpl_parto_fp_lg_face = Face
ctg.tpl_parto_fp_lg_face_chin_front = MA (mento anterior)
ctg.tpl_parto_fp_lg_face_chin_left_front = LMA
ctg.tpl_parto_fp_lg_face_chin_left = LMT
ctg.tpl_parto_fp_lg_face_chin_left_rear = LMP
ctg.tpl_parto_fp_lg_face_chin_rear = MP (mento posterior)
ctg.tpl_parto_fp_lg_face_chin_right_rear = RMP
ctg.tpl_parto_fp_lg_face_chin_right = RMT
ctg.tpl_parto_fp_lg_face_chin_right_front = RMA

ctg.tpl_parto_fp_lg_parietal_bone = Parietal bone
ctg.tpl_parto_fp_lg_parietal_bone_front = Anterior
ctg.tpl_parto_fp_lg_parietal_bone_rear = Posterior

ctg.tpl_parto_fp_lg_extended_legs = Frank breech
ctg.tpl_parto_fp_lg_extended_legs_csm_front = Crista sacra medialis front
ctg.tpl_parto_fp_lg_extended_legs_csm_left_front = Crista sacra medialis left front
ctg.tpl_parto_fp_lg_extended_legs_csm_left = Crista sacra medialis left
ctg.tpl_parto_fp_lg_extended_legs_csm_left_rear = Crista sacra medialis left rear
ctg.tpl_parto_fp_lg_extended_legs_csm_rear = Crista sacra medialis rear
ctg.tpl_parto_fp_lg_extended_legs_csm_right_rear = Crista sacra medialis right rear
ctg.tpl_parto_fp_lg_extended_legs_csm_right = Crista sacra medialis right
ctg.tpl_parto_fp_lg_extended_legs_csm_right_front = Crista sacra medialis right front
ctg.tpl_parto_fp_lg_breech_complete = Complete breech
ctg.tpl_parto_fp_lg_breech_complete_csm_front = Crista sacra medialis front
ctg.tpl_parto_fp_lg_breech_complete_csm_left_front = Crista sacra medialis left front
ctg.tpl_parto_fp_lg_breech_complete_csm_left = Crista sacra medialis left
ctg.tpl_parto_fp_lg_breech_complete_csm_left_rear = Crista sacra medialis left rear
ctg.tpl_parto_fp_lg_breech_complete_csm_rear = Crista sacra medialis rear
ctg.tpl_parto_fp_lg_breech_complete_csm_right_rear = Crista sacra medialis right rear
ctg.tpl_parto_fp_lg_breech_complete_csm_right = Crista sacra medialis right
ctg.tpl_parto_fp_lg_breech_complete_csm_right_front = Crista sacra medialis right front
ctg.tpl_parto_fp_lg_breech_incomplete = Incomplete breech
ctg.tpl_parto_fp_lg_breech_incomplete_csm_front = Crista sacra medialis front
ctg.tpl_parto_fp_lg_breech_incomplete_csm_left_front = Crista sacra medialis left front
ctg.tpl_parto_fp_lg_breech_incomplete_csm_left = Crista sacra medialis left
ctg.tpl_parto_fp_lg_breech_incomplete_csm_left_rear = Crista sacra medialis left rear
ctg.tpl_parto_fp_lg_breech_incomplete_csm_rear = Crista sacra medialis rear
ctg.tpl_parto_fp_lg_breech_incomplete_csm_right_rear = Crista sacra medialis right rear
ctg.tpl_parto_fp_lg_breech_incomplete_csm_right = Crista sacra medialis right
ctg.tpl_parto_fp_lg_breech_incomplete_csm_right_front = Crista sacra medialis right front
ctg.tpl_parto_fp_lg_foot_complete = Complete foot
ctg.tpl_parto_fp_lg_foot_complete_heel_rear = Heel rear / toe front
ctg.tpl_parto_fp_lg_foot_complete_heel_front = Heel front / toe rear
ctg.tpl_parto_fp_lg_foot_incomplete = Incomplete foot
ctg.tpl_parto_fp_lg_foot_incomplete_heel_rear = Heel rear / toe front
ctg.tpl_parto_fp_lg_foot_incomplete_heel_front = Heel front / toe rear


ctg.tpl_parto_fp_lg_no_evaluation_possible = Not known


# Template for fetal position Hohenstand (leitstelle)
ctg.tpl_parto_fp_hh_isp = Metric
#Metrisch bezgl. ISP

#Metrisch bezgl. ISP
ctg.tpl_parto_fp_hh_isp_minus_five = -5
ctg.tpl_parto_fp_hh_isp_minus_four = -4
ctg.tpl_parto_fp_hh_isp_minus_three = -3
ctg.tpl_parto_fp_hh_isp_minus_two = -2 
ctg.tpl_parto_fp_hh_isp_minus_one = -1
ctg.tpl_parto_fp_hh_isp_zero = 0
ctg.tpl_parto_fp_hh_isp_plus_one = 1
ctg.tpl_parto_fp_hh_isp_plus_two = 2
ctg.tpl_parto_fp_hh_isp_plus_three = 3
ctg.tpl_parto_fp_hh_isp_plus_four = 4
ctg.tpl_parto_fp_hh_isp_plus_five = 5

# Template for GEBURTSGESCHWULST
ctg.tpl_parto_gg_keine = No moulding
ctg.tpl_parto_gg_kleine = Small moulding
ctg.tpl_parto_gg_grosse = Large moulding


# Print Partogram
ctg.lbl_krs_admission = Admission to delivery and labour
ctg.lbl_born_on = Date of birth\:
ctg.lbl_page_footer = Page {0} of partogram of Mrs.


#------------------------------------------------------------------------------
# User management
#------------------------------------------------------------------------------
ctg.tit_user_overview = User overview
ctg.tit_user_details = User details
ctg.hvr_user_add_user = Add user
ctg.lbl_person_ward = Ward
ctg.lbl_person_position = Role

#------------------------------------------------------------------------------
# Archive / Orphans / Patient recordings
#------------------------------------------------------------------------------
ctg.tit_archive_overview = Archived CTG recordings
ctg.tit_orphans_overview = Unassigned CTG recordings
ctg.tit_recording_ack_overview = Unacknowledged CTG recordings

ctg.hvr_patient_recordings = Show patient history
ctg.tit_patient_recordings = Patient history
ctg.lbl_recording_actions = Data

ctg.lbl_recording_nr_of_recordings = CTGs

ctg.hvr_recording_view_annotations = Show annotations
ctg.hvr_recording_download_raw_data = Download CTG raw data
ctg.hvr_recording_download_pdf = Show CTG recording as printable PDF version
ctg.hvr_recording_show_in_browser = Show CTG recording

ctg.hvr_ext_case_download_pdf = Show extended case as printable PDF version
ctg.hvr_ext_case_open_html = Show extended case as printable HMTL version

ctg.lbl_recording_episodes = Episodes
ctg.lbl_recording_data = Recording

ctg.hvr_recording_acknowledge = Acknowledge CTG recording
ctg.hvr_recording_status_no_events = No events
ctg.hvr_recording_status_ack_required = Acknowledgement of recording is required
ctg.hvr_recording_status_mobile_recording_running = Mobile recording active 

ctg.wrn_device_annotation_not_editable = This annotation was created by the fetal monitor and can not be edited.
ctg.wrn_partogram_annotation_not_editable = This annotation can only be edited in partogram.

#------------------------------------------------------------------------------
# Recording reassignment
#------------------------------------------------------------------------------
ctg.tit_recording_reassignment = Modify assignment
ctg.lbl_recording_assignment_action = Action

ctg.bt_recording_reassign = Assign to patient
ctg.bt_recording_assign = Assign to patient
ctg.bt_recording_deassign = Cancel assignment
ctg.bt_hide_discharged = Show all patients

ctg.hvr_recording_search_patient = Enter name or patient ID of patient to search for
ctg.hvr_recording_deassign_reassign = Modify assignment
ctg.hvr_recording_assign = Assign to patient

ctg.lbl_recording_no_suitable_case_found = No suitable cases found, no assignment possible

ctg.err_recording_assignment_case_required = Please select a patient first.
ctg.err_recording_assignment_unassignable_case = The patient cannot be selected anymore.
ctg.hvr_recording_deassigned_recording = The assignment was canceled.

#------------------------------------------------------------------------------
# HisCom Exportlist
#------------------------------------------------------------------------------
ctg.tit_export_list = Export list
ctg.lbl_export_list_document_id = Doc. ID
ctg.lbl_export_list_document_operation = Event
ctg.lbl_export_list_state = State
ctg.lbl_export_list_error_msg = Message
ctg.lbl_export_list_last_try = Send date
ctg.lbl_export_list_document_type = Doc. Type
ctg.lbl_export_list_patient_visit_id = Visit ID
ctg.e_export_state_queued = Queued
ctg.e_export_state_pdf_success = Success
ctg.e_export_state_general_failure = Failure
ctg.e_document_operation_new = MDM^T01
ctg.e_document_operation_update = MDM^T09
ctg.e_document_operation_unassign = MDM^T11
ctg.hvr_export_state_resend = Reschedule export

ctg.err_export_state_reschedule_failure = Failed to reschedule export. Please check that the export service is running and is configured correctly.
#------------------------------------------------------------------------------
# Annotations
#------------------------------------------------------------------------------
ctg.tit_annotation_creation_window_comment = Add annotation
ctg.tit_annotation_edit_window_comment = Edit annotation
ctg.tit_annotation_delete_window_comment = Delete annotation
ctg.lbl_annotation_switch_user = Switch User
ctg.lbl_annotation_current = Current
ctg.tit_annotation_creation_window_alarm_ack = Acknowledge alarm
ctg.tit_annotation_creation_window_recording_ack = Acknowledge recording
ctg.tit_annotation_history_window = History

ctg.hvr_annotation_create_annotation = Add annotation

ctg.lbl_annotation = Annotation
ctg.lbl_annotation_long = Annotation
ctg.lbl_annotations = Annotations
ctg.msg_annotation_delete_message = Do you really want to delete this annotation '{0}' ?

ctg.lbl_annotation_time_event = Event
ctg.lbl_annotation_time_reference = Event time
ctg.lbl_annotation_timestamp = Event time
ctg.lbl_annotation_time_reference_unit = Minutes ago
ctg.lbl_annotation_template = Annotation from template
ctg.lbl_annotation_template_menu_root = Templates
ctg.lbl_annotation_text = Annotation
ctg.lbl_annotation_creation_time = Time of creation
ctg.lbl_annotation_type = Type
ctg.hvr_annotation_template_show_subitems = Show Subitem(s)
ctg.hvr_annotation_template_add_subitems = Add Subitem(s)
ctg.hvr_annotation_template_cut_item = Cut

ctg.msg_annotation_saved = Annotation received successfully.
ctg.msg_annotation_text_assign = CTG recording was retrospectively assigned to patient {0}.
ctg.msg_annotation_text_deassign = CTG recording was originally assigned to patient {0}.
ctg.msg_annotation_delete_template = Do you really want to delete the annotation template '{0}'?
ctg.msg_annotation_delete_template_with_sub = Do you really want to delete '{0}' with all sub templates?
ctg.err_annotation_time_reference = Please enter a valid event time.
ctg.err_annotation_no_records_selectable = No fetal monitor is occupied at the moment.
ctg.err_annotation_text_required = You have to enter an annotation.
ctg.err_annotation_bed_required = You have to assign a fetal monitor connection.

ctg.err_edit_annotation_authorization = You don't have authorization to edit this annotation.
ctg.err_delete_annotation_authorization = You don't have authorization to delete this annotation.
ctg.err_annotation_authorization = You don't have authorization to execute this action.

ctg.msg_mobile_connector_connection_loss_start = Transmission interrupted
ctg.msg_mobile_connector_connection_loss_end = Transmission continued
# Annotation templates
ctg.tpl_manage_templates = Please manage your templates.

# Enums
ctg.e_annotation_type_comment = Annotation
ctg.e_annotation_type_assign = Assignment
ctg.e_annotation_type_deassign = Assignment canceled
ctg.e_annotation_type_fm = Fetal Monitor event
ctg.e_annotation_type_st = ST event
ctg.e_annotation_type_st_other = ST event (other)
ctg.e_annotation_type_alarm_ack = Alarm acknowledge
ctg.e_annotation_type_recording_ack = Recording acknowledge
ctg.e_annotation_type_system = System event
ctg.e_annotation_type_pm = Pause Mode event
ctg.e_annotation_type_partogram = Partogram event

#Pause Mode Labels
ctg.lbl_annotation_type_enable_pm = Pause on
ctg.lbl_annotation_type_disable_pm = Pause off
ctg.lbl_annotation_type_timeout_pm = Pause mode timeout
ctg.lbl_annotation_type_data_pm = Pause off (recording is continuing)


#Manage Annotations
ctg.bt_manage_templates = Manage templates
ctg.bt_add_template = Add template
ctg.bt_delete_template = Delete template
ctg.bt_modify_template = Modify template
ctg.bt_paste_template = Copy from clipboard
ctg.bt_back_template = One level up
ctg.lbl_manage_annotation_templates_action = Actions 
ctg.tit_manage_annotation_templates = Manage annotation templates
ctg.lbl_manage_annotation_templates_path = Category\: 
ctg.lbl_manage_annotation_templates_root = Root
ctg.lbl_select_templates_category = <Select>

ctg.annotation_msg_format_nbp_mean = NBP\: {0}/{1} ({2})
ctg.annotation_msg_format_nbp = NBP\: {0}/{1}
ctg.annotation_msg_format_temp = Temperature\: {0} \u00B0C
ctg.annotation_msg_format_temp_fahrenheit = Temperature\: {0} \u00B0F
ctg.annotation_msg_format_mspo2_mhr = MSpO2\: {0} %; MHR\: {1} /min
ctg.annotation_msg_format_mspo2 = MSpO2\: {0} %
ctg.annotation_msg_format_data_lost = CTG data loss detected
ctg.annotation_msg_format_mhr = MHR\: {0} /min
ctg.annotation_msg_format_nbp_mhr = NBP\: {0}/{1} ({2}); MHR\: {3} /min
ctg.annotation_msg_plotter_format_nbp = NBP {0}/{1} ({2})
ctg.annotation_msg_plotter_format_nbp_mhr = NBP {0}/{1} ({2}) {3} /min
ctg.annotation_msg_plotter_format_temp = Temp {0} \u00B0C
ctg.annotation_msg_plotter_format_temp_fahrenheit = Temp {0} \u00B0F
ctg.annotation_msg_plotter_format_mspo2 = MSpO2 {0} %
ctg.annotation_msg_plotter_format_mspo2_mhr = MSpO2 {0} %  {1} /min
#------------------------------------------------------------------------------
# Alarm options
#------------------------------------------------------------------------------
ctg.tit_alarm_config = Alert settings
ctg.tit_alarm_config_jg_settings = J-Guideline parameter
ctg.tit_alarm_config_figo_settings = FIGO parameter
ctg.tit_alarm_config_threshold_settings = Threshold settings

ctg.lb_alarm_config_figo_baseline = Baseline
ctg.lb_alarm_config_figo_floatingline = Floatingline
ctg.lb_alarm_config_figo_floatingline_short = Floatingline
ctg.lb_alarm_config_figo_floatingline_long = Floatingline
ctg.lb_alarm_config_figo_acc = Accelerations
ctg.lb_alarm_config_figo_dec = Decelerations
ctg.lb_alarm_config_figo_history = Alert history
ctg.tit_alarm_config_threshold_signal_loss = Signal loss
ctg.lb_alarm_config_threshold_signal_loss_active = Active
ctg.lb_alarm_config_threshold_signal_loss_suspect = Warning
ctg.lb_alarm_config_threshold_signal_loss_patho = Alert
ctg.lb_alarm_config_threshold_signal_loss_interval = Interval

ctg.tit_alarm_config_threshold_lower_limit = Bradycardia
ctg.lb_alarm_config_threshold_lower_limit_active = Active
ctg.lb_alarm_config_threshold_lower_limit = Threshold
ctg.lb_alarm_config_threshold_lower_limit_delay = Duration

ctg.tit_alarm_config_threshold_upper_limit = Tachycardia
ctg.lb_alarm_config_threshold_upper_limit_active = Active
ctg.lb_alarm_config_threshold_upper_limit = Threshold
ctg.lb_alarm_config_threshold_upper_limit_delay = Duration
ctg.lb_alarm_config_threshold_indicate_limits = Display threshold limits in FHR panel
ctg.lb_alarm_config_threshold_bpm_unit = bpm
ctg.lb_alarm_config_threshold_delay_unit = sec.

ctg.err_alarm_config_no_beds_active = No FM connection is occupied at the moment.
ctg.err_alarm_config_invalid_config = Thresholds for bradycardia and tachycardia exchanged. Please adjust values first.
ctg.err_alarm_config_stale_config = The selected alert settings have been changed in the meantime.
ctg.msg_alarm_config_settings_saved = Settings have been saved.
## {0} = secs {1} timestamp of last evaluation
ctg.wrn_analyzer_delay_start = Evaluation of FHR1 is delayed for {0} secs (last evaluation at {1}).
ctg.wrn_analyzer_delay_end = Evaluation of FHR1 available.

# Change messages
ctg.msg_alarm_config_change_signal_loss_active_true = Signal loss alarm activated;
ctg.msg_alarm_config_change_signal_loss_active_false = Signal loss alarm deactivated;
ctg.msg_alarm_config_change_signal_loss_suspect = Signal loss percentage level for warning set from {0} to {1};
ctg.msg_alarm_config_change_signal_loss_patho = Signal loss percentage level for alarm set from {0} to {1};
ctg.msg_alarm_config_change_lower_limit_active_true = Bradycardia level activated;
ctg.msg_alarm_config_change_lower_limit_active_false = Bradycardia level deactivated;
ctg.msg_alarm_config_change_lower_limit = Bradycardia level modified from {0} to {1} bpm;
ctg.msg_alarm_config_change_lower_limit_delay = Bradycardia duration modified from {0} to {1} sec;
ctg.msg_alarm_config_change_upper_limit_active_true = Tachycardia level activated;
ctg.msg_alarm_config_change_upper_limit_active_false = Tachycardia level deactivated;
ctg.msg_alarm_config_change_upper_limit = Tachycardia level modified from {0} to {1} bpm;
ctg.msg_alarm_config_change_upper_limit_delay = Tachycardia duration modified from {0} to {1} sec;

#------------------------------------------------------------------------------
# Navigation bar
#------------------------------------------------------------------------------
ctg.hvr_navigation_no_alert = No alert

#------------------------------------------------------------------------------
# History
#------------------------------------------------------------------------------
ctg.history_no_running_recording = No FM connection is occupied at the moment.
ctg.lbl_history_menu_gemini_offset = FHR2\: +20
ctg.lbl_history_menu_gemini_offset_separated = FHR2\: +20
ctg.lbl_history_menu_gemini_offset_not_separated = FHR2\: +0
ctg.lbl_history_menu_mhr = Maternal heart rate as trace
ctg.lbl_history_load_image = Loading CTG data
ctg.bt_history_choice_ok = OK
ctg.bt_history_choice_cancel = Cancel

#------------------------------------------------------------------------------
# About
#------------------------------------------------------------------------------
ctg.lbl_about_manufacturer = Manufacturer
ctg.about_manufacturer_contact_city = Munich
ctg.about_manufacturer_contact_country = Germany
ctg.lbl_about_serial_number = Serial number
ctg.about_disclaimer_patents = This software is protected by copyright. Patents pending. This product includes software developed by the Apache Software Foundation (http\://www.apache.org/).
ctg.lbl_about_support = Support
ctg.lbl_support_contact_web = WWW
ctg.lbl_support_contact_phone = Phone
ctg.lbl_support_contact_email = Email
ctg.lbl_about_update_portal = e-Distribution portal
ctg.lbl_about_login = Site ID

#------------------------------------------------------------------------------
# PDA view
#------------------------------------------------------------------------------
ctg.err_pdaview_missing_license = You don't have the permission to access the PDA view. Please acquire the appropriate license.
ctg.err_pdaview_password_change_request = You have to change your password before logging into Trium CTG Online. Password change is not possible in the PDA view.
ctg.bt_pdaview_reload = Reload
ctg.bt_pdaview_quit = Quit
ctg.bt_pdaview_back = Back
ctg.pdaview_bed_bedtag_separator = - 

#------------------------------------------------------------------------------
# Reports
#------------------------------------------------------------------------------
ctg.tit_history_window = History 
ctg.lbl_report_header = Trium CTG Online Report
ctg.lbl_report_mobile_signature = Signature
ctg.lbl_report_mobile_time = Time
ctg.lbl_report_mobile_date = Date
ctg.lbl_report_mobile_notice = Notice
ctg.lbl_report_patient_label = Patient label
ctg.lbl_report_contact = Contact with patient
ctg.lbl_report_report = Diagnose
ctg.lbl_report_report_no_suspect = NAD
ctg.lbl_report_report_suspect = Suspicious\:
ctg.lbl_report_report_therapy = Therapy decision
ctg.lbl_report_patientdetails = Patient details
ctg.lbl_report_initials = Initials
ctg.lbl_report_receiver = Receiver
ctg.lbl_report_receive_state = Reception status
ctg.lbl_report_episode_start_date = Start time
ctg.lbl_report_episode_stop_date = Stop time
ctg.lbl_report_episode_duration = Duration
ctg.lbl_report_episode_figo = FIGO
ctg.lbl_report_receive_bedTagName = Location
ctg.lbl_report_episode_state_incomplete = Incomplete
ctg.lbl_report_episode_state_complete = Complete
ctg.lbl_report_episode_state_complete_rest = Complete (Rest)
ctg.lbl_report_episode_state_undefined = Undefined
ctg.lbl_report_episode_start_transmission = CTG Start transmission
ctg.lbl_report_episode_state_running = Transmission running
ctg.lbl_report_episode_state_running_rest = Retransmission running
ctg.lbl_report_episode_figo_normal = Normal
ctg.lbl_report_episode_figo_suspect = Suspicious
ctg.lbl_report_episode_figo_pathologic = Pathological
ctg.lbl_report_episode_figo_notinterpretable = Not interpretable
ctg.lbl_report_episode_figo_undefind = Undefined
ctg.lbl_report_episode_details_header = CTG recording
ctg.lbl_report_header_pages = Pages
ctg.lbl_report_landscape_footer_patid = ID
ctg.lbl_report_landscape_footer_birthdate = Date of birth
ctg.lbl_report_landscape_footer_edd = EDD
ctg.lbl_report_landscape_footer_gravida = Gravida
ctg.lbl_report_landscape_footer_parity = Para
ctg.lbl_report_portrait_footer_patid = ID
ctg.lbl_report_portrait_footer_birthdate = Date of birth
ctg.lbl_report_portrait_footer_edd = EDD
ctg.lbl_report_portrait_footer_gravida = Gravida
ctg.lbl_report_portrait_footer_parity = Para
ctg.lbl_report_no_patient = No patient has been assigned to this recording\!
ctg.lbl_report_month_1 = January
ctg.lbl_report_month_2 = February
ctg.lbl_report_month_3 = March
ctg.lbl_report_month_4 = April
ctg.lbl_report_month_5 = May
ctg.lbl_report_month_6 = June
ctg.lbl_report_month_7 = July
ctg.lbl_report_month_8 = August
ctg.lbl_report_month_9 = September
ctg.lbl_report_month_10 = October
ctg.lbl_report_month_11 = November
ctg.lbl_report_month_12 = December
ctg.lbl_report_born_on = Born on
ctg.lbl_report_episode_no_diagnosis_warning = Only for information purposes, NO diagnosis\!
ctg.lbl_report_missing_patient_assignment_first_line = Attention\!
ctg.lbl_report_missing_patient_assignment_second_line = CTG recording is NOT ASSIGNED to a patient\!
ctg.lbl_report_patient = Patient\: {0}, {1}
### legend labels
ctg.lbl_legend_prefix = Color coding of possible signals\:*
ctg.lbl_legend_note = *NOTE\: For a correct interpretation a colored representation is necessary\! 
ctg.lbl_signal_fhr1 = FHR1
ctg.lbl_signal_fhr2 = FHR2
ctg.lbl_signal_mhr = MHR
ctg.lbl_signal_fmp = FMP
ctg.lbl_signal_toco = TOCO
ctg.lbl_signal_fspo2 = FSpO2

### sensor labels 
ctg.annotation_msg_format_transducers = Transducers\: 
ctg.annotation_msg_format_no_transducers = No transducers 
ctg.lbl_sensor_no_transducer = No transducer
ctg.lbl_sensor_us = US
ctg.lbl_sensor_fecg = FECG
ctg.lbl_sensor_mecg = MECG
ctg.lbl_sensor_extmhr = Ext. MHR
ctg.lbl_sensor_mspo2p = Pulse from MSpO2
ctg.lbl_sensor_tocomp = Pulse from Toco MP
ctg.lbl_sensor_unknown = Unknown transducer
ctg.lbl_sensor_toco = Toco
ctg.lbl_sensor_iup = IUP

###
ctg.lbl_stv_format = STV %.1fms 
### do not translate the next 4 keys!
ctg.lbl_report_landscape_footer_nhsnumber = NHS Number
ctg.lbl_report_portrait_footer_nhsnumber = NHS Number
ctg.lbl_report_landscape_footer_nhsstatus = Status
ctg.lbl_report_portrait_footer_nhsstatus = Status
ctg.tit_manage_templates = Manage templates
ctg.hvr_print_patient_chalkboard = Print patient list

#DEC_INIT=-1, DEC_NONE=0, DEC_EARLY=1, DEC_VARIABLE_MILD=2,DEC_VARIABLE_SEV=3,
#	 * DEC_LATE_MILD=4,DEC_LATE_SEV=5,DEC_PROLONGED_MILD=6,DEC_PROLONGED_SEV=7,DEC_GHOST=8
ctg.lbl_dec_init_short = I
ctg.lbl_dec_none_short = N
ctg.lbl_dec_early_short = E
ctg.lbl_dec_variable_mild_short = VM
ctg.lbl_dec_variable_sev_short = VS
ctg.lbl_dec_late_mild_short = LM
ctg.lbl_dec_late_sev_short = LS
ctg.lbl_dec_prolonged_mild_short = PM
ctg.lbl_dec_prolonged_sev_short = PS
ctg.lbl_dec_ghost_short = G

ctg.lbl_detailed_alarm_panel_baseline = Baseline
ctg.lbl_detailed_alarm_panel_oscillation = Oscillation
ctg.lbl_detailed_alarm_panel_deceleration = Deceleration
ctg.lbl_alarm_init = INIT
ctg.lbl_alarm_none = NONE

## decelerations
ctg.lbl_alarm_deceleration_early = EARLY
ctg.lbl_alarm_deceleration_variable_mild = VARIABLE_MILD
ctg.lbl_alarm_deceleration_variable_severe = VARIABLE_SEVERE
ctg.lbl_alarm_deceleration_late_mild = LATE_MILD
ctg.lbl_alarm_deceleration_late_severe = LATE_SEVERE
ctg.lbl_alarm_deceleration_prolonged_mild = PROLONGED_MILD
ctg.lbl_alarm_deceleration_prolonged_severe = PROLONGED_SEVERE

## variability
ctg.lbl_alarm_variability_moderate = MODERATE
ctg.lbl_alarm_variability_marked = MARKED
ctg.lbl_alarm_variability_minimal = MINIMAL
ctg.lbl_alarm_variability_undetectable = UNDETECTABLE
ctg.lbl_alarm_variability_sinusoidal = SINUSOIDAL

## baseline
ctg.lbl_alarm_baseline_normocardia = NORMOCARDIA
ctg.lbl_alarm_baseline_tachycardia = TACHYCARDIA
ctg.lbl_alarm_baseline_bradycardia = BRADYCARDIA
ctg.lbl_alarm_baseline_bradycardia_80 = BRADYCARDIA < 80

### Extended chalkboard for GH ###
ctg.tab_prenatal_patients = Prenatal patients
ctg.tab_extended_case = Extended case data
ctg.lbl_extended_case_long = Extended case data
ctg.lbl_case_location_long = Location
ctg.lbl_case_location_short = Loc.

ctg.lbl_case_diagnose_long = Diagnosis
ctg.lbl_case_diagnose_short = Diag.
ctg.lbl_case_antibiotics_long = Antibiotics
ctg.lbl_case_antibiotics_short = AB
ctg.lbl_case_ultrasound_long = Ultrasound
ctg.lbl_case_ultrasound_short = US
ctg.lbl_case_ultrasound_date_long = Ultrasound Date
ctg.lbl_case_ultrasound_date_short = US Date
ctg.lbl_case_tocolysis_long = Tocolysis
ctg.lbl_case_tocolysis_short = Tocol.
ctg.lbl_case_labor_long = Laboratory
ctg.lbl_case_labor_short = Lab
ctg.lbl_case_lab_date_long = Date
ctg.lbl_case_lab_date_short = Date
ctg.lbl_case_lab_crp_long = CRP
ctg.lbl_case_lab_crp_short = CRP
ctg.lbl_case_lab_text_long = Other
ctg.lbl_case_lab_text_short = Other
ctg.lbl_case_ctg_long = CTG
ctg.lbl_case_ctg_short = CTG
ctg.lbl_case_lab_leucos_long = Leucocytes
ctg.lbl_case_lab_leucos_short = Leucos
ctg.lbl_case_lab_hb_long = Haemoglobin
ctg.lbl_case_lab_hb_short = Hb
ctg.lbl_case_rds_long = RDS
ctg.lbl_case_rds_short = RDS
ctg.lbl_case_rds_date_long = RDS Date
ctg.lbl_case_rds_date_short = RDS
ctg.lbl_case_rds_cycle_long = RDS Cycle
ctg.lbl_case_rds_cycle_short = RDS
ctg.lbl_case_rds_label = {0} {1}

ctg.lbl_case_agreement_long = Agreement
ctg.lbl_case_agreement_short = A
ctg.lbl_case_anesthesia_long = Anaesthesia
ctg.lbl_case_anesthesia_short = A
ctg.lbl_case_section_long = Caesarean
ctg.lbl_case_section_short = S
ctg.lbl_case_paediatrist_long = Paediatrician
ctg.lbl_case_paediatrist_short = P

ctg.e_case_rds_cycle_empty = <none>
ctg.e_case_rds_cycle_1 = 1. Cycle
ctg.e_case_rds_cycle_2 = 2. Cycle
ctg.e_case_rds_cycle_3 = 3. Cycle
ctg.e_case_rds_cycle_4 = 4. Cycle

ctg.e_case_tocolysis_empty = <none>
ctg.e_case_tocolysis_1_mg = 1\u00B5g/min
ctg.e_case_tocolysis_2_mg = 2\u00B5g/min
ctg.e_case_tocolysis_3_mg = 3\u00B5g/min
ctg.e_case_tocolysis_4_mg_per_3_min = 4\u00B5g/3min 
ctg.e_case_tocolysis_4_mg_per_6_min = 4\u00B5g/6min 
ctg.e_case_tocolysis_4_mg_per_12_min = 4\u00B5g/12min 
ctg.e_case_tocolysis_4_mg_per_24_min = 4\u00B5g/24min

ctg.e_case_ctgs_number_empty = -
ctg.e_case_ctgs_number_1 = 1
ctg.e_case_ctgs_number_2 = 2
ctg.e_case_ctgs_number_3 = 3

ctg.lbl_case_station_long = Ward
ctg.lbl_case_station_short = Ward
ctg.e_case_station_empty = <none>

ctg.lbl_case_room_long = Room
ctg.lbl_case_room_short = Room
ctg.lbl_case_show_in_extended_chalkboard_long = Show in prenatal patient list
ctg.lbl_case_show_in_extended_chalkboard_short = Show in prenatal patient list

ctg.lbl_patient_name_age = Name/Age
ctg.lbl_case_diagnose_befund = Diagnosis/Result

ctg.lbl_case_prenatal_patients = Prenatal patient list
ctg.hvr_switch_to_standard_chalkboard = Switch to patient list
ctg.hvr_switch_to_extended_chalkboard = Switch to prenatal list

ctg.lb_alarm_config_figo_accdecc = Accelerations / Decelerations
ctg.lbl_parto_med_form_long = Drugs
ctg.lbl_parto_fw_form_long = Amniotic fluid
ctg.tpl_parto_fw_klar = Clear
ctg.tpl_parto_fw_blutig = Brown
ctg.tpl_parto_fw_mekonium_haltig = Meconium stained
